import DrownedModel
import DrownedNotify
import DrownedStore
import DrownedSync
import Foundation
import UserNotifications

@main
enum TheDrownedAgent {
    static func main() async {
        do {
            let store = try IncidentStore()
            let outcome = try await LocalPollingSync(store: store).sync()
            UserDefaults.standard.set(outcome.completedAt, forKey: DrownedDefaultsKey.lastSyncAt)

            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            }

            let notifyRegions = SettingsReader.notifyRegions()
            try await NotificationCoordinator().post(outcome, notifyRegions: notifyRegions)
        } catch {
            FileHandle.standardError.write(Data("TheDrownedAgent failed: \(error)\n".utf8))
        }
    }
}

private enum SettingsReader {
    static func notifyRegions() -> Set<Region> {
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        let values = defaults.stringArray(forKey: DrownedDefaultsKey.notifyRegions)
        let regions = values?.map(Region.init(source:)).filter { $0 != .unknown } ?? []
        return regions.isEmpty ? [.mediterranean] : Set(regions)
    }
}
