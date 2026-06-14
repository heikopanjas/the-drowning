import Foundation

public enum AppGroup {
    public static let identifier = "8J2G689FCZ.com.panjas.thedrowned"

    public static func containerURL(fileManager: FileManager = .default) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    public static func storeURL(fileManager: FileManager = .default) throws -> URL {
        if let containerURL = containerURL(fileManager: fileManager) {
            return containerURL.appendingPathComponent("drowned.sqlite")
        }

        let supportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = supportURL.appendingPathComponent("TheDrowned", isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent("drowned.sqlite")
    }
}

public enum DrownedDefaultsKey {
    public static let regionsOfInterest = "regionsOfInterest"
    public static let notifyRegions = "notifyRegions"
    public static let pollIntervalHours = "pollIntervalHours"
    public static let lastSyncAt = "lastSyncAt"
    public static let notificationsAuthorized = "notificationsAuthorized"
    public static let mapStyle = "mapStyle"
}

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
