import DrownedModel
import DrownedStore
import Foundation

public actor LocalPollingSync: SyncEngine {
    public static let defaultEndpoint: URL = {
        guard
            let url = URL(
                string:
                    "https://data.humdata.org/dataset/fc59785a-31d2-4018-aac7-6b9f619ae8ec/resource/99078436-9c4a-473b-a073-428304a9cf8a/download/iom-missing-migrants-project-data.csv"
            )
        else {
            fatalError("Invalid default sync endpoint URL constant")
        }
        return url
    }()

    private let endpoint: URL
    private let store: IncidentStore
    private let parser: IncidentCSVParser
    private let session: URLSession

    public init(
        endpoint: URL = LocalPollingSync.defaultEndpoint,
        store: IncidentStore,
        parser: IncidentCSVParser = IncidentCSVParser(),
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.store = store
        self.parser = parser
        self.session = session
    }

    public func sync() async throws -> SyncOutcome {
        try Task.checkCancellation()
        let (data, _) = try await session.data(from: endpoint)
        let incidents = try await parser.parse(data)
        try Task.checkCancellation()

        let seen = try await store.seenWebIDs()
        let incomingIDs = Set(incidents.map(\.webID))
        let newIDs = incomingIDs.subtracting(seen)
        let suppressNotifications = seen.isEmpty

        try await store.replaceAll(incidents)
        try await store.markSeen(incomingIDs)

        let newIncidents =
            suppressNotifications
            ? []
            : incidents.filter { incident in
                return newIDs.contains(incident.webID)
            }
        return SyncOutcome(
            newWebIDs: suppressNotifications ? [] : newIDs,
            newIncidents: newIncidents,
            totalRows: incidents.count,
            completedAt: Date(),
            suppressNotifications: suppressNotifications
        )
    }
}
