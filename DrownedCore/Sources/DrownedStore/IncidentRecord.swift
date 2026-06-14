import DrownedModel
import Foundation
import GRDB

extension Incident: FetchableRecord {
    public init(row: Row) throws {
        let rawRegion: String = row["rawRegion"]
        let latitude: Double? = row["latitude"]
        let longitude: Double? = row["longitude"]

        self.init(
            webID: row["webID"],
            region: Region(source: rawRegion),
            rawRegion: rawRegion,
            reportedDate: try Date.missingMigrantsDate(row["reportedDate"]),
            numberDead: row["numberDead"],
            numberMissing: row["numberMissing"],
            totalDeadAndMissing: row["totalDeadAndMissing"],
            numberOfSurvivors: row["numberOfSurvivors"],
            numberOfFemale: row["numberOfFemale"],
            numberOfMale: row["numberOfMale"],
            numberOfChildren: row["numberOfChildren"],
            causeOfDeath: row["causeOfDeath"],
            countryOfIncident: row["countryOfIncident"],
            locationDescription: row["locationDescription"],
            unsdGeographicGrouping: row["unsdGeographicGrouping"],
            latitude: latitude,
            longitude: longitude,
            migrationRoute: row["migrationRoute"],
            informationSource: row["informationSource"],
            sourceURL: row["sourceURL"],
            sourceQuality: row["sourceQuality"],
            regionOrigin: row["regionOrigin"],
            countryOrigin: row["countryOrigin"],
            contentHash: row["contentHash"]
        )
    }
}

extension Incident {
    static let databaseTableName = "incident"

    func persistenceArguments() -> StatementArguments {
        return [
            "webID": webID,
            "rawRegion": rawRegion,
            "reportedDate": reportedDate.missingMigrantsDateString,
            "numberDead": numberDead,
            "numberMissing": numberMissing,
            "totalDeadAndMissing": totalDeadAndMissing,
            "numberOfSurvivors": numberOfSurvivors,
            "numberOfFemale": numberOfFemale,
            "numberOfMale": numberOfMale,
            "numberOfChildren": numberOfChildren,
            "causeOfDeath": causeOfDeath,
            "countryOfIncident": countryOfIncident,
            "locationDescription": locationDescription,
            "unsdGeographicGrouping": unsdGeographicGrouping,
            "latitude": latitude,
            "longitude": longitude,
            "migrationRoute": migrationRoute,
            "informationSource": informationSource,
            "sourceURL": sourceURL,
            "sourceQuality": sourceQuality,
            "regionOrigin": regionOrigin,
            "countryOrigin": countryOrigin,
            "contentHash": contentHash
        ]
    }
}

extension Date {
    static func missingMigrantsDate(_ string: String) throws -> Date {
        guard let date = formatter.date(from: string) else {
            throw DatabaseError(message: "Invalid stored reportedDate: \(string)")
        }
        return date
    }

    var missingMigrantsDateString: String {
        return Self.formatter.string(from: self)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
