public struct CoordinateBounds: Sendable, Hashable, Codable {
    public let minimumLatitude: Double
    public let maximumLatitude: Double
    public let minimumLongitude: Double
    public let maximumLongitude: Double

    public init(
        minimumLatitude: Double,
        maximumLatitude: Double,
        minimumLongitude: Double,
        maximumLongitude: Double
    ) {
        self.minimumLatitude = minimumLatitude
        self.maximumLatitude = maximumLatitude
        self.minimumLongitude = minimumLongitude
        self.maximumLongitude = maximumLongitude
    }
}
