import DrownedModel
import MapKit

final class IncidentAnnotation: NSObject, MKAnnotation {
    let incidentID: String
    let coordinate: CLLocationCoordinate2D

    var title: String? { return nil }

    init?(_ incident: Incident, displayCoordinate: CLLocationCoordinate2D? = nil) {
        guard let coordinate = incident.coordinate else { return nil }
        incidentID = incident.id
        self.coordinate =
            displayCoordinate
            ?? CLLocationCoordinate2D(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        super.init()
    }
}

final class IncidentAnnotationView: MKAnnotationView {
    private let symbolView = NSImageView()

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var annotation: MKAnnotation? {
        didSet {
            guard annotation is IncidentAnnotation else { return }
            frame.size = NSSize(width: MapAnnotationMetrics.incidentDiameter, height: MapAnnotationMetrics.incidentDiameter)
            centerOffset = MapAnnotationMetrics.incidentCenterOffset
            collisionMode = .circle
            displayPriority = .defaultHigh
            canShowCallout = false
            detailCalloutAccessoryView = nil
        }
    }

    override func layout() -> Void {
        super.layout()
        layer?.cornerRadius = bounds.width / 2
        symbolView.frame = NSRect(
            x: (bounds.width - MapAnnotationMetrics.incidentSymbolSize) / 2,
            y: (bounds.height - MapAnnotationMetrics.incidentSymbolSize) / 2,
            width: MapAnnotationMetrics.incidentSymbolSize,
            height: MapAnnotationMetrics.incidentSymbolSize
        )
    }

    private func configure() -> Void {
        frame.size = NSSize(width: MapAnnotationMetrics.incidentDiameter, height: MapAnnotationMetrics.incidentDiameter)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.cornerRadius = MapAnnotationMetrics.incidentDiameter / 2
        layer?.masksToBounds = true

        symbolView.image = NSImage(
            systemSymbolName: "person.fill",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(.init(pointSize: MapAnnotationMetrics.incidentSymbolSize, weight: .semibold))
        symbolView.contentTintColor = .white
        symbolView.imageScaling = .scaleProportionallyDown
        addSubview(symbolView)
    }
}

final class IncidentClusterAnnotationView: MKAnnotationView {
    override var annotation: MKAnnotation? {
        didSet {
            updateImage()
        }
    }

    override func prepareForDisplay() -> Void {
        super.prepareForDisplay()
        updateImage()
    }

    private func updateImage() -> Void {
        guard let cluster = annotation as? MKClusterAnnotation else { return }
        let incidentCount = cluster.memberAnnotations.compactMap { annotation in
            return annotation as? IncidentAnnotation
        }.count
        image = MapAnnotationImage.circle(diameter: MapAnnotationMetrics.clusterDiameter, text: incidentCount.formatted())
        centerOffset = MapAnnotationMetrics.clusterCenterOffset
        collisionMode = .circle
        displayPriority = .required
        canShowCallout = false
    }
}

private enum MapAnnotationImage {
    static func circle(diameter: CGFloat, text: String? = nil) -> NSImage {
        let image = NSImage(size: NSSize(width: diameter, height: diameter))
        image.lockFocus()

        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: diameter, height: diameter)).fill()

        if let text {
            draw(text, in: NSRect(x: 0, y: 0, width: diameter, height: diameter))
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func draw(_ text: String, in rect: NSRect) -> Void {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedText.size()
        let textRect = NSRect(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        attributedText.draw(in: textRect)
    }
}
