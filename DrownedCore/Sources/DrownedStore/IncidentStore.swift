import DrownedModel
import Foundation
import GRDB

public actor IncidentStore {
    public nonisolated let dbPool: DatabasePool

    public init(url: URL? = nil) throws {
        let storeURL = try url ?? AppGroup.storeURL()
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        dbPool = try DatabasePool(path: storeURL.path, configuration: configuration)
        try Self.makeMigrator().migrate(dbPool)
    }

    public func replaceAll(_ incidents: [Incident]) throws -> Void {
        try dbPool.write { db in
            var inserted = Set<String>()
            try db.execute(sql: "DELETE FROM incident")

            for incident in incidents where inserted.insert(incident.id).inserted == true {
                try db.execute(sql: Self.insertSQL, arguments: incident.persistenceArguments())
            }
        }
    }

    public func seenWebIDs() throws -> Set<String> {
        return try dbPool.read { db in
            let ids = try String.fetchAll(db, sql: "SELECT webID FROM seen_web_id")
            return Set(ids)
        }
    }

    public func markSeen(_ webIDs: Set<String>) throws -> Void {
        guard webIDs.isEmpty == false else { return }
        try dbPool.write { db in
            for webID in webIDs {
                try db.execute(
                    sql: "INSERT OR IGNORE INTO seen_web_id (webID) VALUES (?)",
                    arguments: [webID]
                )
            }
        }
    }

    public func fetchIncidents(filter: IncidentFilter) throws -> [Incident] {
        return try dbPool.read { db in
            return try filter.fetchAll(db)
        }
    }

    public func fetchIncident(id: String) throws -> Incident? {
        guard let identity = IncidentIdentity(id: id) else { return nil }
        return try dbPool.read { db in
            return try Incident.fetchOne(
                db,
                sql: "SELECT * FROM incident WHERE webID = ? AND contentHash = ? LIMIT 1",
                arguments: [identity.webID, identity.contentHash]
            )
        }
    }

    public func count(filter: IncidentFilter = IncidentFilter(regions: [], mappableOnly: false)) throws -> Int {
        return try dbPool.read { db in
            return try filter.count(db)
        }
    }

    public func availableRegions() throws -> [Region] {
        return try dbPool.read { db in
            let rawRegions = try String.fetchAll(
                db,
                sql: "SELECT DISTINCT rawRegion FROM incident ORDER BY rawRegion ASC"
            )
            return rawRegions.map(Region.init(source:))
        }
    }

    public func availableRoutes(regions: Set<Region>) throws -> [String] {
        return try dbPool.read { db in
            var sql = "SELECT DISTINCT migrationRoute FROM incident WHERE migrationRoute IS NOT NULL AND migrationRoute != ''"
            var arguments = StatementArguments()
            if regions.isEmpty == false {
                sql += " AND rawRegion IN (" + Array(repeating: "?", count: regions.count).joined(separator: ", ") + ")"
                regions.sorted().forEach { arguments += [$0.rawValue] }
            }
            sql += " ORDER BY migrationRoute ASC"
            return try String.fetchAll(db, sql: sql, arguments: arguments)
        }
    }

    public func availableCauses(regions: Set<Region>) throws -> [String] {
        return try dbPool.read { db in
            var sql = "SELECT DISTINCT causeOfDeath FROM incident WHERE causeOfDeath != ''"
            var arguments = StatementArguments()
            if regions.isEmpty == false {
                sql += " AND rawRegion IN (" + Array(repeating: "?", count: regions.count).joined(separator: ", ") + ")"
                regions.sorted().forEach { arguments += [$0.rawValue] }
            }
            sql += " ORDER BY causeOfDeath ASC"
            return try String.fetchAll(db, sql: sql, arguments: arguments)
        }
    }

    public static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "incident") { table in
                table.autoIncrementedPrimaryKey("rowID")
                table.column("webID", .text).notNull().indexed()
                table.column("rawRegion", .text).notNull().indexed()
                table.column("reportedDate", .text).notNull().indexed()
                table.column("numberDead", .integer)
                table.column("numberMissing", .integer)
                table.column("totalDeadAndMissing", .integer)
                table.column("numberOfSurvivors", .integer)
                table.column("numberOfFemale", .integer)
                table.column("numberOfMale", .integer)
                table.column("numberOfChildren", .integer)
                table.column("causeOfDeath", .text).notNull().indexed()
                table.column("countryOfIncident", .text).notNull()
                table.column("locationDescription", .text).notNull()
                table.column("unsdGeographicGrouping", .text).notNull()
                table.column("latitude", .double)
                table.column("longitude", .double)
                table.column("migrationRoute", .text).indexed()
                table.column("informationSource", .text)
                table.column("sourceURL", .text)
                table.column("sourceQuality", .integer)
                table.column("regionOrigin", .text)
                table.column("countryOrigin", .text)
                table.column("contentHash", .integer).notNull()
            }

            try db.create(index: "incident_region_date", on: "incident", columns: ["rawRegion", "reportedDate"])
            try db.create(index: "incident_identity", on: "incident", columns: ["webID", "contentHash"])

            try db.create(table: "seen_web_id") { table in
                table.column("webID", .text).notNull().primaryKey()
            }
        }
        return migrator
    }

    private static let insertSQL = """
        INSERT INTO incident (
            webID, rawRegion, reportedDate, numberDead, numberMissing, totalDeadAndMissing,
            numberOfSurvivors, numberOfFemale, numberOfMale, numberOfChildren, causeOfDeath,
            countryOfIncident, locationDescription, unsdGeographicGrouping, latitude, longitude,
            migrationRoute, informationSource, sourceURL, sourceQuality, regionOrigin, countryOrigin,
            contentHash
        ) VALUES (
            :webID, :rawRegion, :reportedDate, :numberDead, :numberMissing, :totalDeadAndMissing,
            :numberOfSurvivors, :numberOfFemale, :numberOfMale, :numberOfChildren, :causeOfDeath,
            :countryOfIncident, :locationDescription, :unsdGeographicGrouping, :latitude, :longitude,
            :migrationRoute, :informationSource, :sourceURL, :sourceQuality, :regionOrigin, :countryOrigin,
            :contentHash
        )
        """
}

private struct IncidentIdentity {
    let webID: String
    let contentHash: Int64

    init?(id: String) {
        guard let separator = id.lastIndex(of: "#") else { return nil }
        guard let contentHash = Int64(id[id.index(after: separator)...]) else { return nil }
        webID = String(id[..<separator])
        self.contentHash = contentHash
    }
}
