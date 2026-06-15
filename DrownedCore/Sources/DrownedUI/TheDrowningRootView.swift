import AppKit
import DrownedModel
import DrownedStore
import DrownedSync
import MapKit
import SwiftUI

public struct TheDrowningRootView: View {
    @State private var model: MapModel
    @State private var searchModel = SearchModel()
    @State private var syncError: String?
    @State private var isSyncing = false

    private let store: IncidentStore

    public init(store: IncidentStore) {
        self.store = store
        _model = State(wrappedValue: MapModel(store: store))
    }

    public var body: some View {
        @Bindable var model = model

        return MapScreen(
            model: model,
            searchModel: searchModel,
            isSyncing: isSyncing,
            syncError: syncError,
            fetchIncident: { id in
                return try await store.fetchIncident(id: id)
            },
            sync: sync
        )
        .frame(minWidth: 980, minHeight: 680)
        .task(id: model.queryKey) {
            await model.observe()
        }
        .task {
            await sync()
        }
    }

    private func sync() async -> Void {
        guard isSyncing == false else { return }
        isSyncing = true
        syncError = nil
        do {
            let outcome = try await SyncSession(store: store).sync()
            model.syncCompleted(at: outcome.completedAt)
        }
        catch {
            syncError = error.localizedDescription
        }
        isSyncing = false
    }
}

private struct MapScreen: View {
    @Bindable var model: MapModel
    @Bindable var searchModel: SearchModel
    let isSyncing: Bool
    let syncError: String?
    let fetchIncident: (String) async throws -> Incident?
    let sync: () async -> Void

    @State private var isFilterPresented = false
    @AppStorage(DrownedDefaultsKey.mapStyle) private var mapStyleRawValue = MapStyle.standard.rawValue

    var body: some View {
        return VStack(spacing: 0) {
            toolbar
            ZStack(alignment: .top) {
                IncidentMapView(
                    incidents: model.incidents,
                    mapType: mapStyle.mapType,
                    restoredCamera: model.restoredCamera,
                    requestedCamera: model.requestedCamera,
                    requestedFit: model.requestedFit,
                    fallback: model.filter.fallbackRegion,
                    fetchIncident: fetchIncident,
                    onCameraIdle: model.save(camera:),
                    onVisibleRegionChange: model.updateVisibleBounds(_:)
                )

                if model.isLoading == true {
                    if model.incidents.isEmpty == true {
                        ProgressView()
                            .controlSize(.large)
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding(.top, 24)
                    }
                }
                else if model.incidents.isEmpty == true {
                    ContentUnavailableView("No incidents match these filters", systemImage: "map")
                        .padding(.top, 40)
                }

                if let message = syncError ?? model.errorMessage {
                    Text(message)
                        .font(.callout)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 16)
                }

                if searchModel.completions.isEmpty == false {
                    LocationPreview(completions: searchModel.completions) { completion in
                        searchModel.select(completion)
                        select(completion)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                    .padding(.top, 4)
                    .zIndex(10)
                }
            }
            AttributionBar()
        }
    }

    private var toolbar: some View {
        let search = searchModel
        return HStack(alignment: .center, spacing: 10) {
            ToolbarIconButton(systemName: "line.3.horizontal.decrease.circle", label: "Filters") {
                isFilterPresented.toggle()
            }
            .popover(isPresented: $isFilterPresented, arrowEdge: .bottom) {
                FilterPopoverContent(model: model, searchModel: searchModel)
            }

            SearchField(searchModel: search)
                .frame(height: Self.toolbarControlSize, alignment: .center)
            ToolbarIconButton(systemName: "globe", label: "Fit Selected Regions") {
                searchModel.clear()
                Task {
                    await model.fitSelectedRegions()
                }
            }
            ToolbarIconButton(systemName: "map", label: "Map Style: \(mapStyle.title)") {
                toggleMapStyle()
            }
            Spacer()
            MapStatusLabels(
                displayedIncidentCount: model.incidents.count,
                matchingIncidentCount: model.matchingIncidentCount,
                filteredIncidentCount: model.filteredIncidentCount
            )
            ToolbarIconButton(systemName: "arrow.clockwise", label: "Refresh") {
                Task { await sync() }
            }
            .disabled(isSyncing)
        }
        .frame(height: Self.toolbarControlSize, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private static let toolbarControlSize = ToolbarIconButton.size

    private func select(_ completion: LocationCompletion) -> Void {
        let search = searchModel
        Task {
            if let camera = try? await search.camera(for: completion) {
                model.moveCamera(to: camera)
            }
        }
    }

    private var mapStyle: MapStyle {
        return MapStyle(rawValue: mapStyleRawValue) ?? .standard
    }

    private func toggleMapStyle() -> Void {
        mapStyleRawValue = mapStyle == .standard ? MapStyle.hybrid.rawValue : MapStyle.standard.rawValue
    }
}
