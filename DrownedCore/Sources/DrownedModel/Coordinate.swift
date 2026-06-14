import Foundation

public struct Coordinate: Sendable, Hashable, Codable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public init?(field: String) {
        let trimmed = field.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let parts = trimmed.split(separator: ",", omittingEmptySubsequences: false).map {
            return $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard parts.count == 2 else { return nil }
        guard let latitude = Double(parts[0]) else { return nil }
        guard let longitude = Double(parts[1]) else { return nil }
        guard (-90 ... 90).contains(latitude) else { return nil }
        guard (-180 ... 180).contains(longitude) else { return nil }

        self.latitude = latitude
        self.longitude = longitude
    }
}
