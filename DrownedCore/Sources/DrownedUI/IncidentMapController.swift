import AppKit
import DrownedModel
import DrownedStore
import MapKit

@MainActor
public final class IncidentMapController: NSObject, MKMapViewDelegate {
    let mapView = MKMapView()

    private var shown: [String: IncidentAnnotation] = [:]
    private var incidentDetails: [String: Incident] = [:]
    private var cameraRestored = false
    private var lastRequestedCamera: CameraState?
    private var lastRequestedFitID: UUID?
    private var needsFrame = false
    private var clusteringMode = ClusteringMode.grouped
    private var mapIdleTask: Task<Void, Never>?
    private var detailTask: Task<Void, Never>?
    private var detailPopover: NSPopover?
    private static let mapIdleDelay: UInt64 = 350_000_000

    var fetchIncident: ((String) async throws -> Incident?)?
    var onCameraIdle: ((CameraState) -> Void)?
    var onVisibleRegionChange: ((CoordinateBounds) -> Void)?

    override init() {
        super.init()
        mapView.delegate = self
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = true
        mapView.showsZoomControls = true
        mapView.showsScale = true
        mapView.showsCompass = true
        mapView.showsPitchControl = false
        mapView.register(IncidentAnnotationView.self, forAnnotationViewWithReuseIdentifier: "incident")
        mapView.register(
            IncidentClusterAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier
        )
    }

    func apply(_ state: CameraState) {
        mapView.camera = state.mkCamera
        cameraRestored = true
    }

    func applyRequestedCamera(_ state: CameraState?) {
        guard let state, state != lastRequestedCamera else { return }
        lastRequestedCamera = state
        cameraRestored = true
        needsFrame = false
        mapView.setCamera(state.mkCamera, animated: true)
    }

    func applyRequestedFit(_ request: MapFitRequest?) {
        guard let request, request.id != lastRequestedFitID else { return }
        lastRequestedFitID = request.id
        cameraRestored = true
        needsFrame = false
        mapView.setVisibleMapRect(
            mapRect(for: request.bounds),
            edgePadding: NSEdgeInsets(top: 48, left: 48, bottom: 48, right: 48),
            animated: true
        )
    }

    func update(mapType: MKMapType) {
        guard mapView.mapType != mapType else { return }
        mapView.mapType = mapType
    }

    func update(_ incidents: [Incident]) {
        let shouldFrameInitialAnnotations = shown.isEmpty && !incidents.isEmpty
        let incoming = Set(incidents.map(\.id))
        let displayCoordinates = displayCoordinates(for: incidents)
        incidentDetails = Dictionary(uniqueKeysWithValues: incidents.map { ($0.id, $0) })
        guard incoming != Set(shown.keys) else { return }

        let toRemove = shown.keys.filter { !incoming.contains($0) }
        for id in toRemove {
            if let annotation = shown.removeValue(forKey: id) {
                mapView.removeAnnotation(annotation)
            }
        }

        for incident in incidents where shown[incident.id] == nil {
            guard let annotation = IncidentAnnotation(incident, displayCoordinate: displayCoordinates[incident.id]) else {
                continue
            }
            shown[incident.id] = annotation
            mapView.addAnnotation(annotation)
        }

        needsFrame = shouldFrameInitialAnnotations
    }

    func frame(fallback: MKCoordinateRegion) {
        guard !cameraRestored else {
            cameraRestored = false
            needsFrame = false
            return
        }
        guard needsFrame else { return }

        if mapView.annotations.isEmpty {
            mapView.setRegion(fallback, animated: false)
        } else {
            mapView.showAnnotations(mapView.annotations, animated: false)
        }
        needsFrame = false
    }

    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKClusterAnnotation {
            return mapView.dequeueReusableAnnotationView(
                withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier,
                for: annotation
            ) as? IncidentClusterAnnotationView
        }

        guard let incidentAnnotation = annotation as? IncidentAnnotation else { return nil }
        let view = mapView.dequeueReusableAnnotationView(
            withIdentifier: "incident",
            for: annotation
        ) as? IncidentAnnotationView
        view?.clusteringIdentifier = clusteringIdentifier(for: incidentAnnotation, mode: clusteringMode)
        return view
    }

    public func mapView(_ mapView: MKMapView, didSelect annotationView: MKAnnotationView) {
        guard let annotation = annotationView.annotation as? IncidentAnnotation,
              let incident = incidentDetails[annotation.incidentID] else {
            return
        }
        detailTask?.cancel()
        detailPopover?.close()

        let callout = IncidentCalloutView(incident: incident, state: .loading)
        let popover = NSPopover()
        let contentController = NSViewController()
        contentController.view = callout
        contentController.preferredContentSize = callout.fittingSize
        popover.contentViewController = contentController
        popover.behavior = .transient
        detailPopover = popover
        popover.show(relativeTo: annotationView.bounds, of: annotationView, preferredEdge: .maxY)

        detailTask = Task { @MainActor [weak self, weak mapView, weak annotationView, weak callout] in
            guard let self, let fetchIncident else { return }

            do {
                guard let fullIncident = try await fetchIncident(annotation.incidentID),
                      !Task.isCancelled,
                      mapView?.selectedAnnotations.contains(where: { selected in
                          (selected as? IncidentAnnotation)?.incidentID == annotation.incidentID
                      }) == true,
                      annotationView?.annotation === annotation else {
                    return
                }

                callout?.update(incident: fullIncident, state: .loaded)
            } catch is CancellationError {
                return
            } catch {
                callout?.update(incident: incident, state: .failed(error.localizedDescription))
            }
        }
    }

    public func mapView(_ mapView: MKMapView, didDeselect annotationView: MKAnnotationView) {
        detailTask?.cancel()
        detailTask = nil
        detailPopover?.close()
        detailPopover = nil
    }

    public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        scheduleMapIdleUpdate(for: mapView)
    }

    private func scheduleMapIdleUpdate(for mapView: MKMapView) {
        mapIdleTask?.cancel()
        mapIdleTask = Task { @MainActor [weak self, weak mapView] in
            do {
                try await Task.sleep(nanoseconds: Self.mapIdleDelay)
            } catch {
                return
            }

            guard let self, let mapView else { return }
            updateClustering(for: mapView)
            onCameraIdle?(CameraState(mapView.camera))
            onVisibleRegionChange?(CoordinateBounds(region: mapView.region))
        }
    }

    private func updateClustering(for mapView: MKMapView) {
        let mode = clusteringMode(for: mapView)
        guard mode != clusteringMode else { return }
        let annotations = Array(shown.values)
        mapView.removeAnnotations(annotations)
        clusteringMode = mode
        mapView.addAnnotations(annotations)
    }

    private func clusteringMode(for mapView: MKMapView) -> ClusteringMode {
        mapView.camera.centerCoordinateDistance < 50_000 ? .individual : .grouped
    }

    private func clusteringIdentifier(for annotation: IncidentAnnotation, mode: ClusteringMode) -> String {
        switch mode {
            case .grouped:
                return "incident"
            case .individual:
                return "incident-\(annotation.incidentID)"
        }
    }

    private func mapRect(for bounds: CoordinateBounds) -> MKMapRect {
        let mapPoints = bounds.rectangleCoordinates.map(MKMapPoint.init)
        let baseRect = mapPoints.reduce(MKMapRect.null) { rect, point in
            rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
        }
        let minimumSize: Double = 20_000
        let horizontalInset = max(0, minimumSize - baseRect.width) / 2
        let verticalInset = max(0, minimumSize - baseRect.height) / 2
        return baseRect.insetBy(dx: -horizontalInset, dy: -verticalInset)
    }

    private func displayCoordinates(for incidents: [Incident]) -> [String: CLLocationCoordinate2D] {
        let groups = Dictionary(grouping: incidents) { incident in
            DisplayCoordinateKey(incident.coordinate)
        }

        var coordinates: [String: CLLocationCoordinate2D] = [:]
        for (_, incidents) in groups {
            let incidents = incidents.sorted { $0.id < $1.id }
            guard incidents.count > 1 else { continue }
            for (index, incident) in incidents.enumerated() {
                guard let coordinate = incident.coordinate else { continue }
                coordinates[incident.id] = spreadCoordinate(
                    CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
                    index: index,
                    count: incidents.count
                )
            }
        }

        return coordinates
    }

    private func spreadCoordinate(
        _ coordinate: CLLocationCoordinate2D,
        index: Int,
        count: Int
    ) -> CLLocationCoordinate2D {
        guard count > 1 else { return coordinate }
        let radiusMeters = min(90.0, 28.0 + Double(count) * 3.0)
        let angle = (Double(index) / Double(count)) * 2.0 * Double.pi
        let latitudeOffset = cos(angle) * radiusMeters / 111_320.0
        let longitudeScale = max(0.2, cos(coordinate.latitude * Double.pi / 180.0))
        let longitudeOffset = sin(angle) * radiusMeters / (111_320.0 * longitudeScale)

        return CLLocationCoordinate2D(
            latitude: coordinate.latitude + latitudeOffset,
            longitude: coordinate.longitude + longitudeOffset
        )
    }
}

private struct DisplayCoordinateKey: Hashable {
    let latitude: Int
    let longitude: Int

    init(_ coordinate: Coordinate?) {
        guard let coordinate else {
            latitude = .min
            longitude = .min
            return
        }
        latitude = Int((coordinate.latitude * 1_000_000).rounded())
        longitude = Int((coordinate.longitude * 1_000_000).rounded())
    }
}

private extension CoordinateBounds {
    var rectangleCoordinates: [CLLocationCoordinate2D] {
        [
            CLLocationCoordinate2D(latitude: minimumLatitude, longitude: minimumLongitude),
            CLLocationCoordinate2D(latitude: minimumLatitude, longitude: maximumLongitude),
            CLLocationCoordinate2D(latitude: maximumLatitude, longitude: maximumLongitude),
            CLLocationCoordinate2D(latitude: maximumLatitude, longitude: minimumLongitude)
        ]
    }
}

private enum ClusteringMode {
    case grouped
    case individual
}

extension CameraState {
    init(_ camera: MKMapCamera) {
        self.init(
            latitude: camera.centerCoordinate.latitude,
            longitude: camera.centerCoordinate.longitude,
            distance: camera.centerCoordinateDistance,
            pitch: camera.pitch,
            heading: camera.heading
        )
    }

    var mkCamera: MKMapCamera {
        MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            fromDistance: distance,
            pitch: 0,
            heading: heading
        )
    }
}

private final class IncidentCalloutView: NSView {
    private static let calloutWidth: CGFloat = 520
    private static let calloutHeight: CGFloat = 360
    private static let contentInset: CGFloat = 6
    private static let titleColumnWidth: CGFloat = 132
    private static let columnSpacing: CGFloat = 12
    private static let valueColumnWidth = calloutWidth - titleColumnWidth - contentInset * 4 - columnSpacing

    private let containerStack = NSStackView()
    private let headerLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()
    private let bodyStack = FlippedStackView()

    enum State {
        case loading
        case loaded
        case failed(String)
    }

    init(incident: Incident, state: State) {
        super.init(frame: NSRect(origin: .zero, size: Self.calloutSize))

        containerStack.orientation = .vertical
        containerStack.alignment = .width
        containerStack.spacing = 8
        containerStack.edgeInsets = NSEdgeInsets(
            top: Self.contentInset,
            left: Self.contentInset,
            bottom: Self.contentInset,
            right: Self.contentInset
        )
        containerStack.translatesAutoresizingMaskIntoConstraints = false

        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.font = .boldSystemFont(ofSize: 15)
        headerLabel.alignment = .left
        headerLabel.lineBreakMode = .byWordWrapping
        headerLabel.maximumNumberOfLines = 3
        headerLabel.preferredMaxLayoutWidth = Self.calloutWidth - Self.contentInset * 2
        headerLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.autoresizingMask = [.width, .height]

        bodyStack.orientation = .vertical
        bodyStack.alignment = .width
        bodyStack.spacing = 6
        bodyStack.edgeInsets = NSEdgeInsets(
            top: Self.contentInset,
            left: Self.contentInset,
            bottom: Self.contentInset,
            right: Self.contentInset
        )

        scrollView.documentView = bodyStack
        containerStack.addArrangedSubview(headerLabel)
        containerStack.addArrangedSubview(scrollView)
        addSubview(containerStack)
        NSLayoutConstraint.activate([
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerStack.topAnchor.constraint(equalTo: topAnchor),
            containerStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            headerLabel.widthAnchor.constraint(equalToConstant: Self.calloutWidth - Self.contentInset * 2)
        ])

        update(incident: incident, state: state)
    }

    override var intrinsicContentSize: NSSize {
        Self.calloutSize
    }

    override var fittingSize: NSSize {
        Self.calloutSize
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(incident: Incident, state: State) {
        bodyStack.arrangedSubviews.forEach { view in
            bodyStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        switch state {
            case .loading:
                headerLabel.isHidden = true
                bodyStack.addArrangedSubview(Self.loadingRow())
            case .loaded:
                headerLabel.stringValue = incident.locationDescription
                headerLabel.isHidden = false
                addFullDetails(for: incident)
            case .failed(let message):
                headerLabel.stringValue = incident.locationDescription
                headerLabel.isHidden = false
                bodyStack.addArrangedSubview(Self.valueLabel(message, color: .secondaryLabelColor))
        }

        resizeToFitContent()
    }

    override func layout() {
        super.layout()
    }

    private func addFullDetails(for incident: Incident) {
        addRow("Reported", value: incident.reportedDate.formatted(date: .abbreviated, time: .omitted))
        addRow("Cause of death", value: incident.causeOfDeath)
        addRow("Total dead and missing", value: incident.totalDeadAndMissing.map { $0.formatted() } ?? "Unknown")
        addOptionalNumberRow("Dead", value: incident.numberDead)
        addOptionalNumberRow("Missing", value: incident.numberMissing)
        addOptionalNumberRow("Survivors", value: incident.numberOfSurvivors)
        addOptionalNumberRow("Female", value: incident.numberOfFemale)
        addOptionalNumberRow("Male", value: incident.numberOfMale)
        addOptionalNumberRow("Children", value: incident.numberOfChildren)
        addOptionalRow("Route", value: incident.migrationRoute)
        addRow("Country", value: incident.countryOfIncident)
        addRow("Region", value: incident.rawRegion)
        addRow("Grouping", value: incident.unsdGeographicGrouping)
        addOptionalRow("Origin region", value: incident.regionOrigin)
        addOptionalRow("Origin country", value: incident.countryOrigin)
        addOptionalRow("Source", value: incident.informationSource)
        addOptionalURLRow("Source URL", value: incident.sourceURL)

        if let sourceQuality = incident.sourceQuality {
            addRow("Source quality", value: sourceQuality.formatted())
        }

        if let latitude = incident.latitude, let longitude = incident.longitude {
            addRow("Coordinates", value: "\(latitude.formatted()), \(longitude.formatted())")
        }

        addRow("Web ID", value: incident.webID)
        addRow("Content hash", value: incident.contentHash.formatted())
    }

    private func addOptionalRow(_ title: String, value: String?) {
        guard let value, !value.isEmpty else { return }
        addRow(title, value: value)
    }

    private func addOptionalURLRow(_ title: String, value: String?) {
        guard let value, !value.isEmpty else { return }
        let urls = Self.urls(in: value)
        guard !urls.isEmpty else {
            addRow(title, value: value)
            return
        }

        let linkStack = NSStackView()
        linkStack.orientation = .vertical
        linkStack.alignment = .leading
        linkStack.spacing = 3

        for url in urls {
            linkStack.addArrangedSubview(Self.linkLabel(url))
        }

        addRow(title, valueView: linkStack)
    }

    private func addOptionalNumberRow(_ title: String, value: Int?) {
        guard let value else { return }
        addRow(title, value: value.formatted())
    }

    private func addRow(_ title: String, value: String) {
        addRow(title, valueView: Self.valueLabel(value))
    }

    private func addRow(_ title: String, valueView: NSView) {
        bodyStack.addArrangedSubview(
            IncidentDetailRowView(
                title: title,
                valueView: valueView,
                titleColumnWidth: Self.titleColumnWidth,
                valueColumnWidth: Self.valueColumnWidth,
                columnSpacing: Self.columnSpacing
            )
        )
    }

    private static func loadingRow() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: calloutWidth, height: calloutHeight))

        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isIndeterminate = true
        spinner.startAnimation(nil)
        spinner.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    fileprivate static func titleLabel(_ text: String) -> NSTextField {
        let label = label(text, font: .systemFont(ofSize: 11, weight: .semibold), color: .secondaryLabelColor)
        label.alignment = .left
        return label
    }

    private static func valueLabel(_ text: String, color: NSColor = .labelColor) -> NSTextField {
        let label = label(text, font: .systemFont(ofSize: 11), color: color)
        label.preferredMaxLayoutWidth = valueColumnWidth
        return label
    }

    private static func label(_ text: String, font: NSFont, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.preferredMaxLayoutWidth = calloutWidth - contentInset * 2
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    private static func linkLabel(_ url: URL) -> NSTextField {
        LinkTextField(url: url, preferredWidth: valueColumnWidth)
    }

    private static func urls(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.matches(in: text, range: range).compactMap(\.url)
    }

    private func resizeToFitContent() {
        setFrameSize(Self.calloutSize)

        bodyStack.layoutSubtreeIfNeeded()
        let scrollHeight = Self.calloutHeight - (headerLabel.isHidden ? 0 : headerLabel.fittingSize.height + 8)
        let contentHeight = max(bodyStack.fittingSize.height, scrollHeight)
        let contentSize = NSSize(width: Self.calloutWidth - Self.contentInset * 2, height: contentHeight)

        bodyStack.setFrameSize(contentSize)
        scrollView.documentView?.setFrameSize(contentSize)
        scrollToTop()
        invalidateIntrinsicContentSize()
    }

    private func scrollToTop() {
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private static var calloutSize: NSSize {
        NSSize(width: calloutWidth, height: calloutHeight)
    }

}

private final class FlippedStackView: NSStackView {
    override var isFlipped: Bool {
        true
    }
}

private final class IncidentDetailRowView: NSView {
    init(
        title: String,
        valueView: NSView,
        titleColumnWidth: CGFloat,
        valueColumnWidth: CGFloat,
        columnSpacing: CGFloat
    ) {
        super.init(frame: .zero)

        let titleLabel = IncidentCalloutView.titleLabel(title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        valueView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(valueView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.widthAnchor.constraint(equalToConstant: titleColumnWidth),

            valueView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: columnSpacing),
            valueView.topAnchor.constraint(equalTo: topAnchor),
            valueView.widthAnchor.constraint(equalToConstant: valueColumnWidth),
            valueView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),

            bottomAnchor.constraint(greaterThanOrEqualTo: titleLabel.bottomAnchor),
            bottomAnchor.constraint(greaterThanOrEqualTo: valueView.bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class LinkTextField: NSTextField {
    private let url: URL

    init(url: URL, preferredWidth: CGFloat) {
        self.url = url
        super.init(frame: .zero)

        isEditable = false
        isBordered = false
        drawsBackground = false
        maximumNumberOfLines = 0
        lineBreakMode = .byWordWrapping
        preferredMaxLayoutWidth = preferredWidth
        toolTip = url.absoluteString
        attributedStringValue = NSAttributedString(
            string: url.absoluteString,
            attributes: [
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .font: NSFont.systemFont(ofSize: 11)
            ]
        )
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        NSWorkspace.shared.open(url)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
