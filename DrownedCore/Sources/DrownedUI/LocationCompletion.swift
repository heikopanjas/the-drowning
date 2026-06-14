import DrownedStore
import MapKit
import Observation

struct LocationCompletion: Sendable, Hashable, Identifiable {
    var id: String { return "\(title)\n\(subtitle)" }
    let title: String
    let subtitle: String
}
