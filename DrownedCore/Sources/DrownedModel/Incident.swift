import Foundation

public struct Incident: Sendable, Identifiable, Hashable, Codable {
    public var id: String { return "\(webID)#\(contentHash)" }

    public let webID: String
    public let region: Region
    public let rawRegion: String
    public let reportedDate: Date
    public let numberDead: Int?
    public let numberMissing: Int?
    public let totalDeadAndMissing: Int?
    public let numberOfSurvivors: Int?
    public let numberOfFemale: Int?
    public let numberOfMale: Int?
    public let numberOfChildren: Int?
    public let causeOfDeath: String
    public let countryOfIncident: String
    public let locationDescription: String
    public let unsdGeographicGrouping: String
    public let latitude: Double?
    public let longitude: Double?
    public let migrationRoute: String?
    public let informationSource: String?
    public let sourceURL: String?
    public let sourceQuality: Int?
    public let regionOrigin: String?
    public let countryOrigin: String?
    public let contentHash: Int64

    public var coordinate: Coordinate? {
        guard let latitude else { return nil }
        guard let longitude else { return nil }
        return Coordinate(latitude: latitude, longitude: longitude)
    }

    public init(
        webID: String,
        region: Region,
        rawRegion: String? = nil,
        reportedDate: Date,
        numberDead: Int?,
        numberMissing: Int?,
        totalDeadAndMissing: Int?,
        numberOfSurvivors: Int?,
        numberOfFemale: Int?,
        numberOfMale: Int?,
        numberOfChildren: Int?,
        causeOfDeath: String,
        countryOfIncident: String,
        locationDescription: String,
        unsdGeographicGrouping: String,
        latitude: Double?,
        longitude: Double?,
        migrationRoute: String?,
        informationSource: String?,
        sourceURL: String?,
        sourceQuality: Int?,
        regionOrigin: String?,
        countryOrigin: String?,
        contentHash: Int64
    ) {
        self.webID = webID
        self.region = region
        self.rawRegion = rawRegion ?? region.rawValue
        self.reportedDate = reportedDate
        self.numberDead = numberDead
        self.numberMissing = numberMissing
        self.totalDeadAndMissing = totalDeadAndMissing
        self.numberOfSurvivors = numberOfSurvivors
        self.numberOfFemale = numberOfFemale
        self.numberOfMale = numberOfMale
        self.numberOfChildren = numberOfChildren
        self.causeOfDeath = causeOfDeath
        self.countryOfIncident = countryOfIncident
        self.locationDescription = locationDescription
        self.unsdGeographicGrouping = unsdGeographicGrouping
        self.latitude = latitude
        self.longitude = longitude
        self.migrationRoute = migrationRoute
        self.informationSource = informationSource
        self.sourceURL = sourceURL
        self.sourceQuality = sourceQuality
        self.regionOrigin = regionOrigin
        self.countryOrigin = countryOrigin
        self.contentHash = contentHash
    }
}
