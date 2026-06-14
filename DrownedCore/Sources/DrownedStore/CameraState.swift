import Foundation

public struct CameraState: Sendable, Codable, Hashable {
    public var latitude: Double
    public var longitude: Double
    public var distance: Double
    public var pitch: Double
    public var heading: Double

    public init(latitude: Double, longitude: Double, distance: Double, pitch: Double, heading: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.distance = distance
        self.pitch = pitch
        self.heading = heading
    }
}
