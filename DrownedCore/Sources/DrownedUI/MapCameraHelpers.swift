import DrownedModel
import DrownedStore
import MapKit

enum ClusteringMode {
    case grouped
    case individual
}

extension CoordinateBounds {
    var rectangleCoordinates: [CLLocationCoordinate2D] {
        return [
            CLLocationCoordinate2D(latitude: minimumLatitude, longitude: minimumLongitude),
            CLLocationCoordinate2D(latitude: minimumLatitude, longitude: maximumLongitude),
            CLLocationCoordinate2D(latitude: maximumLatitude, longitude: maximumLongitude),
            CLLocationCoordinate2D(latitude: maximumLatitude, longitude: minimumLongitude)
        ]
    }
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
        return MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            fromDistance: distance,
            pitch: 0,
            heading: heading
        )
    }
}
