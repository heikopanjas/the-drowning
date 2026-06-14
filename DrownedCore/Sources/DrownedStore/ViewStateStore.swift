import DrownedModel
import Foundation

@MainActor
public struct ViewStateStore {
    public static let standard = ViewStateStore(defaults: .standard)

    private let defaults: UserDefaults
    private let filterKey = "viewState.filter"
    private let cameraKey = "viewState.camera"

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func save(filter: IncidentFilter) {
        defaults.set(try? JSONEncoder().encode(filter), forKey: filterKey)
    }

    public func save(camera: CameraState) {
        defaults.set(try? JSONEncoder().encode(camera), forKey: cameraKey)
    }

    public func loadFilter() -> IncidentFilter? {
        defaults.data(forKey: filterKey).flatMap {
            try? JSONDecoder().decode(IncidentFilter.self, from: $0)
        }
    }

    public func loadCamera() -> CameraState? {
        defaults.data(forKey: cameraKey).flatMap {
            try? JSONDecoder().decode(CameraState.self, from: $0)
        }
    }
}

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
