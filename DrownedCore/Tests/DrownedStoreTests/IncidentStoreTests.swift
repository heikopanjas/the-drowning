import DrownedModel
import DrownedStore
import Foundation
import Testing

struct IncidentStoreTests {
    @Test("replaceAll dedupes identical incident identities and filters mappable rows")
    func replaceAllAndFilter() async throws -> Void {
        let store = try IncidentStore(url: IncidentTestFactory.temporaryDatabaseURL())
        let incidents = [
            IncidentTestFactory.incident(webID: "a", latitude: 1, longitude: 2),
            IncidentTestFactory.incident(webID: "a", latitude: 1, longitude: 2),
            IncidentTestFactory.incident(webID: "b")
        ]

        try await store.replaceAll(incidents)

        let all = try await store.fetchIncidents(filter: IncidentFilter(regions: [], mappableOnly: false))
        let mappable = try await store.fetchIncidents(filter: IncidentFilter(regions: [], mappableOnly: true))

        #expect(all.count == 2)
        #expect(mappable.map(\.webID) == ["a"])
    }

    @Test("map annotation fetch is limited while count remains complete")
    func limitedMapAnnotationFetch() async throws -> Void {
        let store = try IncidentStore(url: IncidentTestFactory.temporaryDatabaseURL())
        try await store.replaceAll([
            IncidentTestFactory.incident(webID: "a", latitude: 1, longitude: 2),
            IncidentTestFactory.incident(webID: "b", latitude: 3, longitude: 4),
            IncidentTestFactory.incident(webID: "c", latitude: 5, longitude: 6)
        ])

        let filter = IncidentFilter(regions: [], mappableOnly: true)
        let displayed = try await store.dbPool.read { db in
            return try filter.fetchMapAnnotations(db, limit: 2, bounds: nil)
        }
        let count = try await store.count(filter: filter)

        #expect(displayed.count == 2)
        #expect(count == 3)
    }

    @Test("map annotation fetch can be constrained to visible coordinate bounds")
    func boundedMapAnnotationFetch() async throws -> Void {
        let store = try IncidentStore(url: IncidentTestFactory.temporaryDatabaseURL())
        try await store.replaceAll([
            IncidentTestFactory.incident(webID: "a", latitude: 1, longitude: 2),
            IncidentTestFactory.incident(webID: "b", latitude: 40, longitude: 4),
            IncidentTestFactory.incident(webID: "c", latitude: 5, longitude: 80)
        ])

        let filter = IncidentFilter(regions: [], mappableOnly: true)
        let bounds = CoordinateBounds(
            minimumLatitude: 0,
            maximumLatitude: 10,
            minimumLongitude: 0,
            maximumLongitude: 10
        )
        let displayed = try await store.dbPool.read { db in
            return try filter.fetchMapAnnotations(db, limit: 10, bounds: bounds)
        }
        let count = try await store.dbPool.read { db in
            return try filter.count(db, bounds: bounds)
        }

        #expect(displayed.map(\.webID) == ["a"])
        #expect(count == 1)
    }

    @Test("limited map annotation fetch keeps the deadliest visible incidents")
    func limitedMapAnnotationFetchKeepsDeadliestIncidents() async throws -> Void {
        let store = try IncidentStore(url: IncidentTestFactory.temporaryDatabaseURL())
        try await store.replaceAll([
            IncidentTestFactory.incident(webID: "low", latitude: 1, longitude: 1, totalDeadAndMissing: 2),
            IncidentTestFactory.incident(webID: "high", latitude: 2, longitude: 2, totalDeadAndMissing: 30),
            IncidentTestFactory.incident(webID: "medium", latitude: 3, longitude: 3, totalDeadAndMissing: 12),
            IncidentTestFactory.incident(webID: "outside", latitude: 40, longitude: 40, totalDeadAndMissing: 200)
        ])

        let filter = IncidentFilter(regions: [], mappableOnly: true)
        let bounds = CoordinateBounds(
            minimumLatitude: 0,
            maximumLatitude: 10,
            minimumLongitude: 0,
            maximumLongitude: 10
        )
        let displayed = try await store.dbPool.read { db in
            return try filter.fetchMapAnnotations(db, limit: 2, bounds: bounds)
        }

        #expect(displayed.map(\.webID) == ["high", "medium"])
    }

    @Test("seen web ids survive a full replace")
    func seenIDsSurviveReplace() async throws -> Void {
        let store = try IncidentStore(url: IncidentTestFactory.temporaryDatabaseURL())
        try await store.markSeen(["a"])
        try await store.replaceAll([IncidentTestFactory.incident(webID: "b")])

        #expect(try await store.seenWebIDs() == ["a"])
    }

    @Test("fetch incident resolves full record by compound id")
    func fetchIncidentByID() async throws -> Void {
        let store = try IncidentStore(url: IncidentTestFactory.temporaryDatabaseURL())
        let expected = IncidentTestFactory.incident(webID: "a", latitude: 1, longitude: 2)
        try await store.replaceAll([expected, IncidentTestFactory.incident(webID: "b")])

        let fetched = try await store.fetchIncident(id: expected.id)

        #expect(fetched == expected)
        #expect(try await store.fetchIncident(id: "not-a-valid-id") == nil)
    }
}
