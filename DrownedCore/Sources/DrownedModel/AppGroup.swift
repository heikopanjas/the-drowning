import Foundation

public enum AppGroup {
    public static let identifier = "8J2G689FCZ.com.panjas.thedrowning"

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
        let directoryURL = supportURL.appendingPathComponent("TheDrowning", isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent("drowned.sqlite")
    }
}
