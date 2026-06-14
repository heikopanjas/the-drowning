import DrownedModel
import DrownedSync
import Foundation
import Testing

struct IncidentCSVParserTests {
    @Test("Multiline quoted field does not corrupt subsequent rows")
    func multilineQuotedField() async throws {
        let incidents = try await IncidentCSVParser().parse(Self.fixture.data(using: .utf8)!)

        #expect(incidents.count == 3)
        let first = try #require(incidents.first { $0.webID == "2014.MMP00001" })
        #expect(first.locationDescription.contains("\n"))

        let second = try #require(incidents.first { $0.webID == "2014.MMP00002" })
        #expect(second.region == .southEasternAsia)
        #expect(second.totalDeadAndMissing == 3)
    }

    @Test("Leading UTF-8 BOM before quoted header is ignored")
    func leadingBOM() async throws {
        let incidents = try await IncidentCSVParser().parse(("\u{feff}" + Self.fixture).data(using: .utf8)!)

        #expect(incidents.count == 3)
    }

    @Test("Misspelled coordinate key is parsed and empty coordinates are stored as non mappable")
    func coordinateParsing() async throws {
        let incidents = try await IncidentCSVParser().parse(Self.fixture.data(using: .utf8)!)

        let mappable = try #require(incidents.first { $0.webID == "2014.MMP00001" })
        #expect(mappable.coordinate == Coordinate(latitude: 32.22804, longitude: -112.590416))

        let unmappable = try #require(incidents.first { $0.webID == "2014.MMP00003" })
        #expect(unmappable.coordinate == nil)
    }

    @Test("Exact duplicate rows are deduped but origin split web ids are preserved")
    func duplicateAndSplitRows() async throws {
        let csv = Self.fixture + Self.fixtureRow(webID: "2014.MMP00002", countryOrigin: "Myanmar")
        let incidents = try await IncidentCSVParser().parse(csv.data(using: .utf8)!)
        let splitRows = incidents.filter { $0.webID == "2014.MMP00002" }

        #expect(incidents.count == 4)
        #expect(splitRows.count == 2)
    }

    @Test("Current HDX export parses")
    func currentHDXExportParses() async throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("_docs/Missing_Migrants_Global_Figures_allData.csv")
        let data = try Data(contentsOf: url)
        let incidents = try await IncidentCSVParser().parse(data)

        #expect(incidents.count > 1_000)
    }

    @Test("Live endpoint download parses when present")
    func liveEndpointDownloadParsesWhenPresent() async throws {
        let url = URL(fileURLWithPath: "/private/tmp/iom-live.csv")
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let data = try Data(contentsOf: url)
        let incidents = try await IncidentCSVParser().parse(data)

        #expect(incidents.count > 1_000)
    }

    private static let header = """
        web_id,region,reported_date,number_dead,number_missing,total_dead_and_missing,number_of_survivors,number_of_female,number_of_male,number_of_children,cause_death,country_of_incident,location_description,unsd_geographic_grouping,location_coodinates,migration_route,information_source,url,source_quality,region_origin,country_origin
        """

    private static let fixture = header + "\n"
        + fixtureRow(webID: "2014.MMP00001", location: "\"Crossing near shore\nwith quoted newline\"", coordinates: "32.22804, -112.590416")
        + fixtureRow(webID: "2014.MMP00002", region: "South-eastern Asia", total: "", countryOrigin: "Bangladesh")
        + fixtureRow(webID: "2014.MMP00003", coordinates: "")
        + fixtureRow(webID: "2014.MMP00003", coordinates: "")

    private static func fixtureRow(
        webID: String,
        region: String = "Mediterranean",
        total: String = "3",
        location: String = "At sea",
        coordinates: String = "36.0, 17.0",
        countryOrigin: String = ""
    ) -> String {
        """
        \(webID),\(region),2024-01-02,1,2,\(total),,,,,"Drowning",Italy,\(location),Southern Europe,"\(coordinates)",Central Mediterranean,IOM,https://example.com,4,Africa,\(countryOrigin)
        """ + "\n"
    }
}
