import DrownedModel
import DrownedStore
import Foundation

public actor SyncSession {
    private let store: IncidentStore
    private let defaults: UserDefaults

    public init(store: IncidentStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
    }

    public func sync() async throws -> SyncOutcome {
        let outcome = try await LocalPollingSync(store: store).sync()
        defaults.set(outcome.completedAt, forKey: DrownedDefaultsKey.lastSyncAt)
        return outcome
    }
}
