import Foundation

public struct IncidentFilter: Sendable, Hashable, Codable {
    public var regions: Set<Region>
    public var routes: Set<String>
    public var startDate: Date?
    public var endDate: Date?
    public var causes: Set<String>
    public var mappableOnly: Bool

    public init(
        regions: Set<Region> = [.mediterranean],
        routes: Set<String> = [],
        startDate: Date? = nil,
        endDate: Date? = nil,
        causes: Set<String> = [],
        mappableOnly: Bool = true
    ) {
        self.regions = regions
        self.routes = routes
        self.startDate = startDate
        self.endDate = endDate
        self.causes = causes
        self.mappableOnly = mappableOnly
    }
}
