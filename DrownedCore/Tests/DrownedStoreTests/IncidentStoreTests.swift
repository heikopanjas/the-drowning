import DrownedModel
import DrownedStore
import Foundation
import Testing

struct IncidentStoreTests {
    @Test("replaceAll dedupes identical incident identities and filters mappable rows")
    func replaceAllAndFilter() async throws {
        let store = try IncidentStore(url: temporaryDatabaseURL())
        let incidents = [incident(webID: "a", latitude: 1, longitude: 2), incident(webID: "a", latitude: 1, longitude: 2), incident(webID: "b")]

        try await store.replaceAll(incidents)

        let all = try await store.fetchIncidents(filter: IncidentFilter(regions: [], mappableOnly: false))
        let mappable = try await store.fetchIncidents(filter: IncidentFilter(regions: [], mappableOnly: true))

        #expect(all.count == 2)
        #expect(mappable.map(\.webID) == ["a"])
    }

    @Test("map annotation fetch is limited while count remains complete")
    func limitedMapAnnotationFetch() async throws {
        let store = try IncidentStore(url: temporaryDatabaseURL())
        try await store.replaceAll([
            incident(webID: "a", latitude: 1, longitude: 2),
            incident(webID: "b", latitude: 3, longitude: 4),
            incident(webID: "c", latitude: 5, longitude: 6),
        ])

        let filter = IncidentFilter(regions: [], mappableOnly: true)
        let displayed = try await store.dbPool.read { db in
            try filter.fetchMapAnnotations(db, limit: 2, bounds: nil)
        }
        let count = try await store.count(filter: filter)

        #expect(displayed.count == 2)
        #expect(count == 3)
    }

    @Test("map annotation fetch can be constrained to visible coordinate bounds")
    func boundedMapAnnotationFetch() async throws {
        let store = try IncidentStore(url: temporaryDatabaseURL())
        try await store.replaceAll([
            incident(webID: "a", latitude: 1, longitude: 2),
            incident(webID: "b", latitude: 40, longitude: 4),
            incident(webID: "c", latitude: 5, longitude: 80),
        ])

        let filter = IncidentFilter(regions: [], mappableOnly: true)
        let bounds = CoordinateBounds(
            minimumLatitude: 0,
            maximumLatitude: 10,
            minimumLongitude: 0,
            maximumLongitude: 10
        )
        let displayed = try await store.dbPool.read { db in
            try filter.fetchMapAnnotations(db, limit: 10, bounds: bounds)
        }
        let count = try await store.dbPool.read { db in
            try filter.count(db, bounds: bounds)
        }

        #expect(displayed.map(\.webID) == ["a"])
        #expect(count == 1)
    }

    @Test("limited map annotation fetch keeps the deadliest visible incidents")
    func limitedMapAnnotationFetchKeepsDeadliestIncidents() async throws {
        let store = try IncidentStore(url: temporaryDatabaseURL())
        try await store.replaceAll([
            incident(webID: "low", latitude: 1, longitude: 1, totalDeadAndMissing: 2),
            incident(webID: "high", latitude: 2, longitude: 2, totalDeadAndMissing: 30),
            incident(webID: "medium", latitude: 3, longitude: 3, totalDeadAndMissing: 12),
            incident(webID: "outside", latitude: 40, longitude: 40, totalDeadAndMissing: 200),
        ])

        let filter = IncidentFilter(regions: [], mappableOnly: true)
        let bounds = CoordinateBounds(
            minimumLatitude: 0,
            maximumLatitude: 10,
            minimumLongitude: 0,
            maximumLongitude: 10
        )
        let displayed = try await store.dbPool.read { db in
            try filter.fetchMapAnnotations(db, limit: 2, bounds: bounds)
        }

        #expect(displayed.map(\.webID) == ["high", "medium"])
    }

    @Test("seen web ids survive a full replace")
    func seenIDsSurviveReplace() async throws {
        let store = try IncidentStore(url: temporaryDatabaseURL())
        try await store.markSeen(["a"])
        try await store.replaceAll([incident(webID: "b")])

        #expect(try await store.seenWebIDs() == ["a"])
    }

    @Test("fetch incident resolves full record by compound id")
    func fetchIncidentByID() async throws {
        let store = try IncidentStore(url: temporaryDatabaseURL())
        let expected = incident(webID: "a", latitude: 1, longitude: 2)
        try await store.replaceAll([expected, incident(webID: "b")])

        let fetched = try await store.fetchIncident(id: expected.id)

        #expect(fetched == expected)
        #expect(try await store.fetchIncident(id: "not-a-valid-id") == nil)
    }

    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("drowned.sqlite")
    }

    private func incident(
        webID: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        totalDeadAndMissing: Int = 1
    ) -> Incident {
        Incident(
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
            contentHash: webID.stableHashValue
        )
    }
}

private extension String {
    var stableHashValue: Int64 {
        unicodeScalars.reduce(Int64(0)) { hash, scalar in
            hash &* 31 &+ Int64(scalar.value)
        }
    }
}
