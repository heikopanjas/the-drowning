import MapKit

enum MapStyle: String {
    case standard
    case hybrid

    var title: String {
        switch self {
            case .standard:
                return "Standard"
            case .hybrid:
                return "Hybrid"
        }
    }

    var mapType: MKMapType {
        switch self {
            case .standard:
                return .standard
            case .hybrid:
                return .hybrid
        }
    }
}
