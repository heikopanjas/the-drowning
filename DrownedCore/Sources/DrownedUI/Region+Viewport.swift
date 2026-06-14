import DrownedModel
import MapKit

extension Region {
    var defaultRegion: MKCoordinateRegion {
        switch self {
            case .mediterranean:
                return region(center: (36.0, 17.0), span: (18.0, 42.0))
            case .northAmerica:
                return region(center: (39.0, -102.0), span: (40.0, 70.0))
            case .centralAmerica:
                return Self.centralAmericaCaribbeanRegion
            case .caribbean:
                return Self.centralAmericaCaribbeanRegion
            case .southAmerica:
                return region(center: (-15.0, -60.0), span: (55.0, 50.0))
            case .northernAfrica:
                return Self.africaRegion
            case .westernAfrica:
                return Self.africaRegion
            case .middleAfrica:
                return Self.africaRegion
            case .easternAfrica:
                return Self.africaRegion
            case .southernAfrica:
                return Self.africaRegion
            case .westernAsia:
                return Self.asiaRegion
            case .centralAsia:
                return Self.asiaRegion
            case .southernAsia:
                return Self.asiaRegion
            case .southEasternAsia:
                return Self.asiaRegion
            case .easternAsia:
                return Self.asiaRegion
            case .europe:
                return region(center: (52.0, 15.0), span: (35.0, 60.0))
            case .oceania:
                return region(center: (-22.0, 140.0), span: (50.0, 70.0))
            case .unknown:
                return region(center: (20.0, 0.0), span: (120.0, 180.0))
        }
    }

    private static let centralAmericaCaribbeanRegion = region(
        center: (15.0, -80.0),
        span: (25.0, 45.0)
    )

    private static let africaRegion = region(
        center: (5.0, 20.0),
        span: (70.0, 75.0)
    )

    private static let asiaRegion = region(
        center: (28.0, 78.0),
        span: (60.0, 110.0)
    )

    private static func region(center: (Double, Double), span: (Double, Double)) -> MKCoordinateRegion {
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: center.0, longitude: center.1),
            span: MKCoordinateSpan(latitudeDelta: span.0, longitudeDelta: span.1)
        )
    }

    private func region(center: (Double, Double), span: (Double, Double)) -> MKCoordinateRegion {
        return Self.region(center: center, span: span)
    }
}

extension IncidentFilter {
    var fallbackRegion: MKCoordinateRegion {
        let selected =
            regions.isEmpty == true
            ? Set(
                Region.allCases.filter { region in
                    return region != .unknown
                })
            : regions
        guard selected.count != 1 else {
            return selected.first?.defaultRegion ?? Region.mediterranean.defaultRegion
        }
        return Region.mediterranean.defaultRegion
    }
}
