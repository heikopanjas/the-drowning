import DrownedModel
import DrownedStore
import MapKit
import SwiftUI

public struct IncidentMapView: NSViewRepresentable {
    public typealias Coordinator = IncidentMapController

    public var incidents: [Incident]
    public var mapType: MKMapType
    public var restoredCamera: CameraState?
    public var requestedCamera: CameraState?
    public var requestedFit: MapFitRequest?
    public var fallback: MKCoordinateRegion
    public var fetchIncident: (String) async throws -> Incident?
    public var onCameraIdle: (CameraState) -> Void
    public var onVisibleRegionChange: (CoordinateBounds) -> Void

    public init(
        incidents: [Incident],
        mapType: MKMapType,
        restoredCamera: CameraState?,
        requestedCamera: CameraState?,
        requestedFit: MapFitRequest?,
        fallback: MKCoordinateRegion,
        fetchIncident: @escaping (String) async throws -> Incident?,
        onCameraIdle: @escaping (CameraState) -> Void,
        onVisibleRegionChange: @escaping (CoordinateBounds) -> Void
    ) {
        self.incidents = incidents
        self.mapType = mapType
        self.restoredCamera = restoredCamera
        self.requestedCamera = requestedCamera
        self.requestedFit = requestedFit
        self.fallback = fallback
        self.fetchIncident = fetchIncident
        self.onCameraIdle = onCameraIdle
        self.onVisibleRegionChange = onVisibleRegionChange
    }

    public func makeCoordinator() -> Coordinator {
        return IncidentMapController()
    }

    public func makeNSView(context: Context) -> MKMapView {
        let controller = context.coordinator
        controller.fetchIncident = fetchIncident
        controller.onCameraIdle = onCameraIdle
        controller.onVisibleRegionChange = onVisibleRegionChange
        if let restoredCamera {
            controller.apply(restoredCamera)
        }
        return controller.mapView
    }

    public func updateNSView(_ view: MKMapView, context: Context) -> Void {
        context.coordinator.fetchIncident = fetchIncident
        context.coordinator.onCameraIdle = onCameraIdle
        context.coordinator.onVisibleRegionChange = onVisibleRegionChange
        context.coordinator.update(mapType: mapType)
        context.coordinator.update(incidents)
        context.coordinator.applyRequestedCamera(requestedCamera)
        context.coordinator.applyRequestedFit(requestedFit)
        context.coordinator.frame(fallback: fallback)
    }
}
