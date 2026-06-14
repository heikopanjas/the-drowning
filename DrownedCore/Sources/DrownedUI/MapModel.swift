import DrownedModel
import DrownedStore
import Foundation
import GRDB
import MapKit
import Observation

@Observable
@MainActor
public final class MapModel {
    public private(set) var incidents: [Incident] = []
    public private(set) var matchingIncidentCount = 0
    public private(set) var filteredIncidentCount = 0
    public private(set) var routes: [String] = []
    public private(set) var causes: [String] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    public private(set) var lastSyncAt: Date?
    public private(set) var visibleBounds: CoordinateBounds?

    public var filter: IncidentFilter
    public var restoredCamera: CameraState?
    public var requestedCamera: CameraState?
    public var requestedFit: MapFitRequest?

    private let store: IncidentStore
    private let viewState: ViewStateStore
    private let defaults: UserDefaults
    private static let mapAnnotationLimit = 1_000

    public var isAnnotationLimited: Bool {
        matchingIncidentCount > incidents.count
    }

    var queryKey: MapQueryKey {
        MapQueryKey(filter: filter, bounds: visibleBounds)
    }

    public init(
        store: IncidentStore,
        viewState: ViewStateStore = .standard,
        defaults: UserDefaults = .standard,
        defaultRegions: Set<Region> = [.mediterranean]
    ) {
        self.store = store
        self.viewState = viewState
        self.defaults = defaults
        filter = viewState.loadFilter() ?? IncidentFilter(regions: defaultRegions)
        restoredCamera = viewState.loadCamera()
        lastSyncAt = defaults.object(forKey: DrownedDefaultsKey.lastSyncAt) as? Date
    }

    public func observe() async -> Void {
        isLoading = true
        errorMessage = nil
        viewState.save(filter: filter)

        do {
            try await refreshMetadata()
            let filter = self.filter
            let bounds = visibleBounds ?? CoordinateBounds(region: filter.fallbackRegion)
            let mapAnnotationLimit = Self.mapAnnotationLimit
            let observation = ValueObservation.tracking { db in
                try IncidentSnapshot(
                    incidents: filter.fetchMapAnnotations(db, limit: mapAnnotationLimit, bounds: bounds),
                    visibleCount: filter.count(db, bounds: bounds),
                    filteredCount: filter.count(db)
                )
            }

            for try await snapshot in observation.values(in: store.dbPool) {
                incidents = snapshot.incidents
                matchingIncidentCount = snapshot.visibleCount
                filteredIncidentCount = snapshot.filteredCount
                isLoading = false
            }
        }
        catch is CancellationError {
            isLoading = false
        }
        catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    public func refreshMetadata() async throws {
        routes = try await store.availableRoutes(regions: filter.regions)
        causes = try await store.availableCauses(regions: filter.regions)
    }

    public func resetFilter() -> Void {
        filter = IncidentFilter()
    }

    public func updateRegionSelection(_ region: Region, isSelected: Bool) async -> Void {
        if isSelected == true {
            filter.regions.insert(region)
        }
        else {
            filter.regions.remove(region)
        }

        await fitSelectedRegions()
    }

    public func fitSelectedRegions() async -> Void {
        visibleBounds = nil

        do {
            var fitFilter = filter
            fitFilter.mappableOnly = true
            let incidents = try await store.fetchIncidents(filter: fitFilter)
            guard let bounds = CoordinateBounds(incidents: incidents, trimsOutliers: true) else { return }
            visibleBounds = bounds
            requestedFit = MapFitRequest(bounds: bounds)
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    public func save(camera: CameraState) -> Void {
        viewState.save(camera: camera)
    }

    public func updateVisibleBounds(_ bounds: CoordinateBounds) -> Void {
        guard visibleBounds?.shouldRefreshMapAnnotations(for: bounds) != false else { return }
        visibleBounds = bounds
    }

    public func moveCamera(to state: CameraState) -> Void {
        requestedCamera = state
    }

    public func syncCompleted(at date: Date) -> Void {
        lastSyncAt = date
    }
}

private struct IncidentSnapshot: Sendable {
    let incidents: [Incident]
    let visibleCount: Int
    let filteredCount: Int
}

extension CoordinateBounds {
    fileprivate func shouldRefreshMapAnnotations(for bounds: CoordinateBounds) -> Bool {
        let latitudeSpan = max(maximumLatitude - minimumLatitude, 0.000001)
        let longitudeSpan = max(maximumLongitude - minimumLongitude, 0.000001)
        let latitudeCenterDelta = abs(bounds.centerLatitude - centerLatitude) / latitudeSpan
        let longitudeCenterDelta = abs(bounds.centerLongitude - centerLongitude) / longitudeSpan
        let latitudeSpanDelta = abs(bounds.latitudeSpan - latitudeSpan) / latitudeSpan
        let longitudeSpanDelta = abs(bounds.longitudeSpan - longitudeSpan) / longitudeSpan

        return latitudeCenterDelta > 0.12
            || longitudeCenterDelta > 0.12
            || latitudeSpanDelta > 0.08
            || longitudeSpanDelta > 0.08
    }

    fileprivate var centerLatitude: Double {
        (minimumLatitude + maximumLatitude) / 2
    }

    fileprivate var centerLongitude: Double {
        (minimumLongitude + maximumLongitude) / 2
    }

    fileprivate var latitudeSpan: Double {
        maximumLatitude - minimumLatitude
    }

    fileprivate var longitudeSpan: Double {
        maximumLongitude - minimumLongitude
    }
}

extension CoordinateBounds {
    init?(incidents: [Incident], trimsOutliers: Bool = false) {
        let coordinates = incidents.compactMap(\.coordinate)
        guard let first = coordinates.first else { return nil }
        guard trimsOutliers else {
            let initial = (
                minimumLatitude: first.latitude,
                maximumLatitude: first.latitude,
                minimumLongitude: first.longitude,
                maximumLongitude: first.longitude
            )
            let bounds = coordinates.dropFirst().reduce(initial) { bounds, coordinate in
                (
                    minimumLatitude: min(bounds.minimumLatitude, coordinate.latitude),
                    maximumLatitude: max(bounds.maximumLatitude, coordinate.latitude),
                    minimumLongitude: min(bounds.minimumLongitude, coordinate.longitude),
                    maximumLongitude: max(bounds.maximumLongitude, coordinate.longitude)
                )
            }

            self.init(
                minimumLatitude: bounds.minimumLatitude,
                maximumLatitude: bounds.maximumLatitude,
                minimumLongitude: bounds.minimumLongitude,
                maximumLongitude: bounds.maximumLongitude
            )
            return
        }

        let latitudes = coordinates.map(\.latitude).sorted()
        let longitudes = coordinates.map(\.longitude).sorted()
        let trimCount = Self.outlierTrimCount(for: coordinates.count)

        self.init(
            minimumLatitude: latitudes[trimCount],
            maximumLatitude: latitudes[latitudes.count - 1 - trimCount],
            minimumLongitude: longitudes[trimCount],
            maximumLongitude: longitudes[longitudes.count - 1 - trimCount]
        )
    }

    private static func outlierTrimCount(for count: Int) -> Int {
        guard count >= 200 else { return 0 }
        return min(count / 20, max(1, count / 400))
    }

    init(region: MKCoordinateRegion) {
        let halfLatitude = region.span.latitudeDelta / 2
        let halfLongitude = region.span.longitudeDelta / 2
        self.init(
            minimumLatitude: max(-90, region.center.latitude - halfLatitude),
            maximumLatitude: min(90, region.center.latitude + halfLatitude),
            minimumLongitude: max(-180, region.center.longitude - halfLongitude),
            maximumLongitude: min(180, region.center.longitude + halfLongitude)
        )
    }
}
