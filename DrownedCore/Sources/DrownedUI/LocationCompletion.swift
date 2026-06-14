import DrownedStore
import MapKit
import Observation

struct LocationCompletion: Sendable, Hashable, Identifiable {
    var id: String { "\(title)\n\(subtitle)" }
    let title: String
    let subtitle: String
}
