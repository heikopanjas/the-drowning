import DrownedModel

public protocol SyncEngine: Sendable {
    func sync() async throws -> SyncOutcome
}
