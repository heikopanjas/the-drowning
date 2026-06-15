import DrownedModel
import Foundation

enum IncidentTestFactory {
    static func temporaryDatabaseURL() -> URL {
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("drowned.sqlite")
    }

    static func incident(
        webID: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        totalDeadAndMissing: Int = 1
    ) -> Incident {
        return Incident(
            webID: webID,
            region: .mediterranean,
            reportedDate: Date(timeIntervalSince1970: 1_704_153_600),
            numberDead: 1,
            numberMissing: nil,
            totalDeadAndMissing: totalDeadAndMissing,
            numberOfSurvivors: nil,
            numberOfFemale: nil,
            numberOfMale: nil,
            numberOfChildren: nil,
            causeOfDeath: "Drowning",
            countryOfIncident: "Italy",
            locationDescription: "At sea",
            unsdGeographicGrouping: "Southern Europe",
            latitude: latitude,
            longitude: longitude,
            migrationRoute: "Central Mediterranean",
            informationSource: "IOM",
            sourceURL: nil,
            sourceQuality: 4,
            regionOrigin: "Africa",
            countryOrigin: nil,
            contentHash: stableHashValue(webID)
        )
    }

    private static func stableHashValue(_ string: String) -> Int64 {
        return string.unicodeScalars.reduce(Int64(0)) { hash, scalar in
            return hash &* 31 &+ Int64(scalar.value)
        }
    }
}
