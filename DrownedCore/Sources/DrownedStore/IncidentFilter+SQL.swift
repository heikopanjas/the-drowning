import DrownedModel
import Foundation
import GRDB

extension IncidentFilter {
    public func fetchAll(_ db: Database) throws -> [Incident] {
        return try Incident.fetchAll(db, sql: sql.orderByDateDescending, arguments: sql.arguments)
    }

    public func fetchMapAnnotations(_ db: Database, limit: Int, bounds: CoordinateBounds?) throws -> [Incident] {
        guard limit > 0 else { return [] }
        let sql = sql(bounds: bounds)
        var arguments = sql.arguments
        arguments += [limit]
        return try Incident.fetchAll(db, sql: sql.orderByDeadliest + " LIMIT ?", arguments: arguments)
    }

    public func count(_ db: Database, bounds: CoordinateBounds? = nil) throws -> Int {
        let sql = sql(bounds: bounds)
        return try Int.fetchOne(db, sql: sql.count, arguments: sql.arguments) ?? 0
    }
}

extension IncidentFilter {
    var sql: IncidentSQL {
        return sql(bounds: nil)
    }

    func sql(bounds: CoordinateBounds?) -> IncidentSQL {
        var predicates: [String] = []
        var arguments = StatementArguments()

        let concreteRegions = regions.filter { region in
            return region != .unknown
        }
        if concreteRegions.isEmpty == false {
            predicates.append("rawRegion IN \(Self.placeholders(concreteRegions.count))")
            concreteRegions.sorted().forEach { arguments += [$0.rawValue] }
        }
        else if regions == [.unknown] {
            predicates.append("rawRegion = ?")
            arguments += [Region.unknown.rawValue]
        }

        if routes.isEmpty == false {
            predicates.append("migrationRoute IN \(Self.placeholders(routes.count))")
            routes.sorted().forEach { arguments += [$0] }
        }

        if let startDate {
            predicates.append("reportedDate >= ?")
            arguments += [startDate.missingMigrantsDateString]
        }

        if let endDate {
            predicates.append("reportedDate <= ?")
            arguments += [endDate.missingMigrantsDateString]
        }

        if causes.isEmpty == false {
            predicates.append("causeOfDeath IN \(Self.placeholders(causes.count))")
            causes.sorted().forEach { arguments += [$0] }
        }

        if mappableOnly == true {
            predicates.append("latitude IS NOT NULL AND longitude IS NOT NULL")
        }

        if let bounds {
            predicates.append("latitude BETWEEN ? AND ?")
            arguments += [bounds.minimumLatitude, bounds.maximumLatitude]
            if bounds.minimumLongitude <= bounds.maximumLongitude {
                predicates.append("longitude BETWEEN ? AND ?")
                arguments += [bounds.minimumLongitude, bounds.maximumLongitude]
            }
            else {
                predicates.append("(longitude >= ? OR longitude <= ?)")
                arguments += [bounds.minimumLongitude, bounds.maximumLongitude]
            }
        }

        let whereClause = predicates.isEmpty == true ? "" : " WHERE " + predicates.joined(separator: " AND ")
        return IncidentSQL(whereClause: whereClause, arguments: arguments)
    }

    private static func placeholders(_ count: Int) -> String {
        return "(" + Array(repeating: "?", count: count).joined(separator: ", ") + ")"
    }
}

struct IncidentSQL {
    let whereClause: String
    let arguments: StatementArguments

    var orderByDateDescending: String {
        return "SELECT * FROM incident\(whereClause) ORDER BY reportedDate DESC, webID ASC, contentHash ASC"
    }

    var orderByDeadliest: String {
        return """
            SELECT * FROM incident\(whereClause)
            ORDER BY COALESCE(totalDeadAndMissing, numberDead, 0) DESC, reportedDate DESC, webID ASC, contentHash ASC
            """
    }

    var count: String {
        return "SELECT COUNT(*) FROM incident\(whereClause)"
    }
}
