import DrownedModel
import Foundation
@preconcurrency import UserNotifications

public protocol NotificationPosting: Sendable {
    func add(_ request: UNNotificationRequest) async throws -> Void
}

public struct UserNotificationPoster: NotificationPosting {
    public init() {}

    public func add(_ request: UNNotificationRequest) async throws -> Void {
        try await UNUserNotificationCenter.current().add(request)
    }
}

public struct NotificationCoordinator: Sendable {
    private let poster: any NotificationPosting

    public init(poster: any NotificationPosting = UserNotificationPoster()) {
        self.poster = poster
    }

    public func post(_ outcome: SyncOutcome, notifyRegions: Set<Region>) async throws -> Void {
        guard outcome.suppressNotifications == false else { return }

        let relevant = outcome.newIncidents.filter { notifyRegions.contains($0.region) }
        guard relevant.isEmpty == false else { return }

        let grouped = Dictionary(grouping: relevant, by: \.region)
        for region in grouped.keys.sorted() {
            guard let incidents = grouped[region] else { continue }
            let distinctCount = Set(incidents.map(\.webID)).count
            let deadOrMissing = incidents.compactMap(\.totalDeadAndMissing).reduce(0, +)

            let content = UNMutableNotificationContent()
            content.title = region.rawValue
            content.body = Self.body(distinctCount: distinctCount, deadOrMissing: deadOrMissing)
            content.threadIdentifier = "region.\(region.rawValue)"
            content.userInfo = ["region": region.rawValue]

            let request = UNNotificationRequest(
                identifier: "region.\(region.rawValue).\(outcome.completedAt.timeIntervalSince1970)",
                content: content,
                trigger: nil
            )
            try await poster.add(request)
        }
    }

    public static func body(distinctCount: Int, deadOrMissing: Int) -> String {
        let incidentWord = distinctCount == 1 ? "incident" : "incidents"
        return "\(distinctCount) newly recorded \(incidentWord) - \(deadOrMissing) dead or missing"
    }
}

public enum NotificationAuthorization {
    public static func request() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }
}
