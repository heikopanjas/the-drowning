import CoreLocation
import DrownedModel
import MapKit

enum DisplayCoordinateSpread {
    static func coordinates(for incidents: [Incident]) -> [String: CLLocationCoordinate2D] {
        let groups = Dictionary(grouping: incidents) { incident in
            return DisplayCoordinateKey(incident.coordinate)
        }

        var coordinates: [String: CLLocationCoordinate2D] = [:]
        for (_, incidents) in groups {
            let incidents = incidents.sorted { lhs, rhs in
                return lhs.id < rhs.id
            }
            guard incidents.count > 1 else { continue }
            for (index, incident) in incidents.enumerated() {
                guard let coordinate = incident.coordinate else { continue }
                coordinates[incident.id] = spread(
                    CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
                    index: index,
                    count: incidents.count
                )
            }
        }

        return coordinates
    }

    private static func spread(_ coordinate: CLLocationCoordinate2D, index: Int, count: Int) -> CLLocationCoordinate2D {
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
