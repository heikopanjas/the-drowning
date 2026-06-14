import Foundation

public struct SyncOutcome: Sendable, Hashable {
    public let newWebIDs: Set<String>
    public let newIncidents: [Incident]
    public let totalRows: Int
    public let completedAt: Date
    public let suppressNotifications: Bool

    public init(
        newWebIDs: Set<String>,
        newIncidents: [Incident],
        totalRows: Int,
        completedAt: Date,
        suppressNotifications: Bool
    ) {
        self.newWebIDs = newWebIDs
        self.newIncidents = newIncidents
        self.totalRows = totalRows
        self.completedAt = completedAt
        self.suppressNotifications = suppressNotifications
    }
}
