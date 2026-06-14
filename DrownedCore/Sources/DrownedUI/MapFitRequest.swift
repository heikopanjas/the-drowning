import DrownedModel
import Foundation

public struct MapFitRequest: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let bounds: CoordinateBounds

    public init(bounds: CoordinateBounds, id: UUID = UUID()) {
        self.id = id
        self.bounds = bounds
    }
}
