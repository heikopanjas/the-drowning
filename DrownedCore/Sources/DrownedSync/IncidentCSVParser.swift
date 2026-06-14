import DrownedModel
import Foundation

public struct IncidentCSVParser: Sendable {
    public init() {}

    @concurrent
    public func parse(_ data: Data) async throws -> [Incident] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw IncidentCSVParserError.invalidUTF8
        }

        let rows = try RFC4180Parser().parse(text.strippingByteOrderMark())
        guard let header = rows.first else { return [] }

        let columns = Dictionary(
            header.enumerated().map { item in
                return (Self.normalizedHeader(item.element), item.offset)
            },
            uniquingKeysWith: { first, _ in
                return first
            }
        )
        try [CSVColumn.webID, .region, .reportedDate].forEach { column in
            guard column.index(in: columns) != nil else {
                throw IncidentCSVParserError.missingColumn(column.aliases[0])
            }
        }

        var seenRows = Set<String>()
        var incidents: [Incident] = []
        incidents.reserveCapacity(max(rows.count - 1, 0))

        for row in rows.dropFirst()
        where row.allSatisfy({ field in
            return field.isEmpty == true
        }) == false {
            let fields = CSVIncidentFields(row: row, columns: columns)
            let incident = try fields.incident()
            let rowFingerprint = fields.rowFingerprint
            guard seenRows.insert(rowFingerprint).inserted == true else { continue }
            incidents.append(incident)
        }

        return incidents
    }

    private static func normalizedHeader(_ header: String) -> String {
        return
            header
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{feff}", with: "")
            .lowercased()
    }
}

public enum IncidentCSVParserError: Error, Equatable, Sendable, CustomStringConvertible, LocalizedError {
    case invalidUTF8
    case missingColumn(String)
    case invalidDate(String)
    case invalidInteger(column: String, value: String)
    case malformedCSV(String = "")

    public var description: String {
        switch self {
            case .invalidUTF8:
                return "CSV data is not valid UTF-8."
            case .missingColumn(let column):
                return "CSV is missing required column '\(column)'."
            case .invalidDate(let value):
                return "CSV contains invalid reported_date '\(value)'."
            case .invalidInteger(let column, let value):
                return "CSV contains invalid integer '\(value)' in column '\(column)'."
            case .malformedCSV(let context):
                return context.isEmpty ? "CSV is malformed." : "CSV is malformed: \(context)"
        }
    }

    public var errorDescription: String? { return description }
}

private enum CSVColumn: CaseIterable {
    case webID
    case region
    case reportedDate
    case numberDead
    case numberMissing
    case totalDeadAndMissing
    case numberOfSurvivors
    case numberOfFemale
    case numberOfMale
    case numberOfChildren
    case causeDeath
    case countryOfIncident
    case locationDescription
    case unsdGeographicGrouping
    case locationCoordinates
    case migrationRoute
    case informationSource
    case url
    case sourceQuality
    case regionOrigin
    case countryOrigin

    var aliases: [String] {
        switch self {
            case .webID:
                return ["web_id", "Main ID", "Incident ID"]
            case .region:
                return ["region", "Region of Incident", "Region"]
            case .reportedDate:
                return ["reported_date", "Incident Date"]
            case .numberDead:
                return ["number_dead", "Number Dead", "Number of Dead"]
            case .numberMissing:
                return ["number_missing", "Minimum Estimated Number of Missing"]
            case .totalDeadAndMissing:
                return ["total_dead_and_missing", "Total Number of Dead and Missing"]
            case .numberOfSurvivors:
                return ["number_of_survivors", "Number of Survivors", "Number Survivors"]
            case .numberOfFemale:
                return ["number_of_female", "Number of Females", "Number Females"]
            case .numberOfMale:
                return ["number_of_male", "Number of Males", "Number Males"]
            case .numberOfChildren:
                return ["number_of_children", "Number of Children", "Number Children"]
            case .causeDeath:
                return ["cause_death", "Cause of Death"]
            case .countryOfIncident:
                return ["country_of_incident", "Country of Incident"]
            case .locationDescription:
                return ["location_description", "Location of Incident", "Location of death"]
            case .unsdGeographicGrouping:
                return ["unsd_geographic_grouping", "UNSD Geographical Grouping"]
            case .locationCoordinates:
                return ["location_coodinates", "Coordinates"]
            case .migrationRoute:
                return ["migration_route", "Migration Route", "Migration route"]
            case .informationSource:
                return ["information_source", "Information Source"]
            case .url:
                return ["url", "URL"]
            case .sourceQuality:
                return ["source_quality", "Source Quality"]
            case .regionOrigin:
                return ["region_origin", "Region of Origin", "Region Origin"]
            case .countryOrigin:
                return ["country_origin", "Country of Origin", "Country Origin"]
        }
    }

    func index(in columns: [String: Int]) -> Int? {
        return aliases.lazy
            .map {
                return $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\u{feff}", with: "")
                    .lowercased()
            }
            .compactMap { key in
                return columns[key]
            }
            .first
    }
}

private struct CSVIncidentFields {
    let row: [String]
    let columns: [String: Int]

    var rowFingerprint: String {
        return CSVColumn.allCases
            .map { column in
                return value(column)
            }
            .joined(separator: "\u{1F}")
    }

    func incident() throws -> Incident {
        let rawRegion = trimmed(.region)
        let coordinate = Coordinate(field: trimmed(.locationCoordinates))
        let contentFields = CSVColumn.allCases
            .filter { column in
                return column != .webID
            }
            .map { column in
                return value(column).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        let numberDead = try optionalInt(.numberDead)
        let numberMissing = try optionalInt(.numberMissing)

        return Incident(
            webID: trimmed(.webID),
            region: Region(source: rawRegion),
            rawRegion: rawRegion,
            reportedDate: try date(.reportedDate),
            numberDead: numberDead,
            numberMissing: numberMissing,
            totalDeadAndMissing: try optionalInt(.totalDeadAndMissing) ?? Self.sum(numberDead, numberMissing),
            numberOfSurvivors: try optionalInt(.numberOfSurvivors),
            numberOfFemale: try optionalInt(.numberOfFemale),
            numberOfMale: try optionalInt(.numberOfMale),
            numberOfChildren: try optionalInt(.numberOfChildren),
            causeOfDeath: trimmed(.causeDeath),
            countryOfIncident: optionalString(.countryOfIncident) ?? "",
            locationDescription: trimmed(.locationDescription),
            unsdGeographicGrouping: trimmed(.unsdGeographicGrouping),
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude,
            migrationRoute: optionalString(.migrationRoute),
            informationSource: optionalString(.informationSource),
            sourceURL: optionalString(.url),
            sourceQuality: try optionalInt(.sourceQuality),
            regionOrigin: optionalString(.regionOrigin),
            countryOrigin: optionalString(.countryOrigin),
            contentHash: StableHasher.hash(contentFields)
        )
    }

    private static func sum(_ lhs: Int?, _ rhs: Int?) -> Int? {
        if lhs == nil {
            if rhs == nil {
                return nil
            }
        }
        return (lhs ?? 0) + (rhs ?? 0)
    }

    private func value(_ column: CSVColumn) -> String {
        guard let index = column.index(in: columns) else { return "" }
        guard row.indices.contains(index) == true else { return "" }
        return row[index]
    }

    private func trimmed(_ column: CSVColumn) -> String {
        return value(column).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func optionalString(_ column: CSVColumn) -> String? {
        let value = trimmed(column)
        return value.isEmpty ? nil : value
    }

    private func optionalInt(_ column: CSVColumn) throws -> Int? {
        let value = trimmed(column)
        guard value.isEmpty == false else { return nil }
        if column == .sourceQuality,
            let firstValue = value.split(separator: ",").first.flatMap({ value in
                return Int(value)
            })
        {
            return firstValue
        }
        if column == .sourceQuality {
            return nil
        }
        let normalized = value.replacingOccurrences(of: ",", with: "")
        guard let integer = Int(normalized) else {
            throw IncidentCSVParserError.invalidInteger(column: column.aliases[0], value: value)
        }
        return integer
    }

    private func date(_ column: CSVColumn) throws -> Date {
        let value = trimmed(column)
        for formatter in DateFormatter.missingMigrantsDateFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        throw IncidentCSVParserError.invalidDate(value)
    }
}

private struct RFC4180Parser {
    func parse(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var index = text.startIndex
        var isQuoted = false
        var justClosedQuote = false

        while index < text.endIndex {
            let character = text[index]
            let nextIndex = text.index(after: index)

            if isQuoted == true {
                if character == "\"" {
                    if nextIndex < text.endIndex {
                        if text[nextIndex] == "\"" {
                            field.append("\"")
                            index = text.index(after: nextIndex)
                        }
                        else {
                            isQuoted = false
                            justClosedQuote = true
                            index = nextIndex
                        }
                    }
                    else {
                        isQuoted = false
                        justClosedQuote = true
                        index = nextIndex
                    }
                }
                else {
                    field.append(character)
                    index = nextIndex
                }
                continue
            }

            switch character {
                case "\"":
                    guard field.isEmpty == true else {
                        throw IncidentCSVParserError.malformedCSV("Unexpected quote after field text near: \(field.suffix(80))")
                    }
                    guard justClosedQuote == false else {
                        throw IncidentCSVParserError.malformedCSV("Unexpected quote after field text near: \(field.suffix(80))")
                    }
                    isQuoted = true
                    index = nextIndex
                case ",":
                    row.append(field)
                    field.removeAll(keepingCapacity: true)
                    justClosedQuote = false
                    index = nextIndex
                case "\n":
                    row.append(field)
                    rows.append(row)
                    row.removeAll(keepingCapacity: true)
                    field.removeAll(keepingCapacity: true)
                    justClosedQuote = false
                    index = nextIndex
                case "\r\n":
                    row.append(field)
                    rows.append(row)
                    row.removeAll(keepingCapacity: true)
                    field.removeAll(keepingCapacity: true)
                    justClosedQuote = false
                    index = nextIndex
                case "\r":
                    row.append(field)
                    rows.append(row)
                    row.removeAll(keepingCapacity: true)
                    field.removeAll(keepingCapacity: true)
                    justClosedQuote = false
                    if nextIndex < text.endIndex {
                        if text[nextIndex] == "\n" {
                            index = text.index(after: nextIndex)
                        }
                        else {
                            index = nextIndex
                        }
                    }
                    else {
                        index = nextIndex
                    }
                default:
                    if justClosedQuote == true {
                        if character.isWhitespace == false {
                            let nearby = String(text[index...].prefix(120))
                            throw IncidentCSVParserError.malformedCSV(
                                "Unexpected character '\(character)' after closing quote near: \(nearby)"
                            )
                        }
                    }
                    field.append(character)
                    index = nextIndex
            }
        }

        guard isQuoted == false else { throw IncidentCSVParserError.malformedCSV("Unclosed quoted field") }
        if field.isEmpty == false {
            row.append(field)
            rows.append(row)
        }
        else if row.isEmpty == false {
            row.append(field)
            rows.append(row)
        }
        else if text.last == "," {
            row.append(field)
            rows.append(row)
        }

        return rows
    }
}

private enum StableHasher {
    static func hash(_ values: [String]) -> Int64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for value in values {
            for byte in value.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 0x100_0000_01b3
            }
            hash ^= 0x1f
            hash = hash &* 0x100_0000_01b3
        }
        return Int64(bitPattern: hash)
    }
}

extension DateFormatter {
    fileprivate static let missingMigrantsDateFormatters: [DateFormatter] = [
        makeMissingMigrantsDateFormatter("yyyy-MM-dd"),
        makeMissingMigrantsDateFormatter("EEE, MM/dd/yyyy - HH:mm")
    ]

    fileprivate static func makeMissingMigrantsDateFormatter(_ dateFormat: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = dateFormat
        return formatter
    }
}

extension String {
    fileprivate func strippingByteOrderMark() -> String {
        return hasPrefix("\u{feff}") ? String(dropFirst()) : self
    }
}
