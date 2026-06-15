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
    private static let mapIdleDelay: UInt64 = 650_000_000

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

    func apply(_ state: CameraState) -> Void {
        mapView.camera = state.mkCamera
        cameraRestored = true
    }

    func applyRequestedCamera(_ state: CameraState?) -> Void {
        guard let state else { return }
        guard state != lastRequestedCamera else { return }
        lastRequestedCamera = state
        cameraRestored = true
        needsFrame = false
        mapView.setCamera(state.mkCamera, animated: true)
    }

    func applyRequestedFit(_ request: MapFitRequest?) -> Void {
        guard let request else { return }
        guard request.id != lastRequestedFitID else { return }
        lastRequestedFitID = request.id
        cameraRestored = true
        needsFrame = false
        mapView.setVisibleMapRect(
            mapRect(for: request.bounds),
            edgePadding: NSEdgeInsets(top: 48, left: 48, bottom: 48, right: 48),
            animated: true
        )
    }

    func update(mapType: MKMapType) -> Void {
        guard mapView.mapType != mapType else { return }
        mapView.mapType = mapType
    }

    func update(_ incidents: [Incident]) -> Void {
        var shouldFrameInitialAnnotations = false
        if shown.isEmpty == true {
            if incidents.isEmpty == false {
                shouldFrameInitialAnnotations = true
            }
        }
        let incoming = Set(
            incidents.map { incident in
                return incident.id
            })
        let displayCoordinates = DisplayCoordinateSpread.coordinates(for: incidents)
        incidentDetails = Dictionary(
            uniqueKeysWithValues: incidents.map { incident in
                return (incident.id, incident)
            })
        guard incoming != Set(shown.keys) else { return }

        let toRemove = shown.keys.filter { id in
            return incoming.contains(id) == false
        }
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

    func frame(fallback: MKCoordinateRegion) -> Void {
        guard cameraRestored == false else {
            cameraRestored = false
            needsFrame = false
            return
        }
        guard needsFrame == true else { return }

        if mapView.annotations.isEmpty == true {
            mapView.setRegion(fallback, animated: false)
        }
        else {
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
        let view =
            mapView.dequeueReusableAnnotationView(
                withIdentifier: "incident",
                for: annotation
            ) as? IncidentAnnotationView
        view?.clusteringIdentifier = clusteringIdentifier(for: incidentAnnotation, mode: clusteringMode)
        return view
    }

    public func mapView(_ mapView: MKMapView, didSelect annotationView: MKAnnotationView) -> Void {
        guard let annotation = annotationView.annotation as? IncidentAnnotation else { return }
        guard let incident = incidentDetails[annotation.incidentID] else { return }
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
            guard let self else { return }
            guard let fetchIncident else { return }

            do {
                guard let fullIncident = try await fetchIncident(annotation.incidentID) else { return }
                guard Task.isCancelled == false else { return }
                guard
                    mapView?.selectedAnnotations.contains(where: { selected in
                        return (selected as? IncidentAnnotation)?.incidentID == annotation.incidentID
                    }) == true
                else {
                    return
                }
                guard annotationView?.annotation === annotation else { return }

                callout?.update(incident: fullIncident, state: .loaded)
            }
            catch is CancellationError {
                return
            }
            catch {
                callout?.update(incident: incident, state: .failed(error.localizedDescription))
            }
        }
    }

    public func mapView(_ mapView: MKMapView, didDeselect annotationView: MKAnnotationView) -> Void {
        detailTask?.cancel()
        detailTask = nil
        detailPopover?.close()
        detailPopover = nil
    }

    public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) -> Void {
        scheduleMapIdleUpdate(for: mapView)
    }

    private func scheduleMapIdleUpdate(for mapView: MKMapView) -> Void {
        mapIdleTask?.cancel()
        mapIdleTask = Task { @MainActor [weak self, weak mapView] in
            do {
                try await Task.sleep(nanoseconds: Self.mapIdleDelay)
            }
            catch {
                return
            }

            guard let self else { return }
            guard let mapView else { return }
            updateClustering(for: mapView)
            onCameraIdle?(CameraState(mapView.camera))
            onVisibleRegionChange?(CoordinateBounds(region: mapView.region))
        }
    }

    private func updateClustering(for mapView: MKMapView) -> Void {
        let mode = clusteringMode(for: mapView)
        guard mode != clusteringMode else { return }
        let annotations = Array(shown.values)
        mapView.removeAnnotations(annotations)
        clusteringMode = mode
        mapView.addAnnotations(annotations)
    }

    private func clusteringMode(for mapView: MKMapView) -> ClusteringMode {
        return mapView.camera.centerCoordinateDistance < 50_000 ? .individual : .grouped
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
            return rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
        }
        let minimumSize: Double = 20_000
        let horizontalInset = max(0, minimumSize - baseRect.width) / 2
        let verticalInset = max(0, minimumSize - baseRect.height) / 2
        return baseRect.insetBy(dx: -horizontalInset, dy: -verticalInset)
    }
}
