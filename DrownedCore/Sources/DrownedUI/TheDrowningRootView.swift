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
            let outcome = try await LocalPollingSync(store: store).sync()
            UserDefaults.standard.set(outcome.completedAt, forKey: DrownedDefaultsKey.lastSyncAt)
            model.syncCompleted(at: outcome.completedAt)
        }
        catch {
            syncError = error.localizedDescription
        }
        isSyncing = false
    }
}

private struct FilterPopoverContent: View {
    @Bindable var model: MapModel
    @Bindable var searchModel: SearchModel

    @State private var expandedSections: Set<FilterSection> = [.regions]

    var body: some View {
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                filterSection(.regions, title: "Regions") {
                    ForEach(
                        Region.allCases.filter { region in
                            return region != .unknown
                        }.sorted()
                    ) { region in
                        filterToggle(region.rawValue, isOn: binding(for: region))
                    }
                }

                filterSection(.routes, title: "Routes") {
                    if model.routes.isEmpty == true {
                        emptyFilterText("No routes loaded")
                    }
                    else {
                        ForEach(model.routes, id: \.self) { route in
                            filterToggle(route, isOn: setBinding(route, keyPath: \.routes))
                        }
                    }
                }

                filterSection(.causes, title: "Causes") {
                    if model.causes.isEmpty == true {
                        emptyFilterText("No causes loaded")
                    }
                    else {
                        ForEach(model.causes, id: \.self) { cause in
                            filterToggle(cause, isOn: setBinding(cause, keyPath: \.causes))
                        }
                    }
                }

                filterSection(.map, title: "Map") {
                    filterToggle("Mappable incidents only", isOn: $model.filter.mappableOnly)
                    Button("Reset Filters", systemImage: "arrow.counterclockwise") {
                        searchModel.clear()
                        model.resetFilter()
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(width: 340, height: 520)
    }

    private func filterSection<Content: View>(
        _ section: FilterSection,
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        return DisclosureGroup(isExpanded: expansionBinding(for: section)) {
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(.top, 6)
            .padding(.bottom, 8)
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func filterToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        return HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .frame(width: 38, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func emptyFilterText(_ text: String) -> some View {
        return Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func expansionBinding(for section: FilterSection) -> Binding<Bool> {
        return Binding {
            return expandedSections.contains(section)
        } set: { isExpanded in
            if isExpanded == true {
                expandedSections.insert(section)
            }
            else {
                expandedSections.remove(section)
            }
        }
    }

    private func binding(for region: Region) -> Binding<Bool> {
        return Binding {
            return model.filter.regions.contains(region)
        } set: { isSelected in
            guard model.filter.regions.contains(region) != isSelected else {
                return
            }
            searchModel.clear()
            Task {
                await model.updateRegionSelection(region, isSelected: isSelected)
            }
        }
    }

    private func setBinding(_ value: String, keyPath: WritableKeyPath<IncidentFilter, Set<String>>) -> Binding<Bool> {
        return Binding {
            return model.filter[keyPath: keyPath].contains(value)
        } set: { isSelected in
            if isSelected == true {
                model.filter[keyPath: keyPath].insert(value)
            }
            else {
                model.filter[keyPath: keyPath].remove(value)
            }
        }
    }
}

private enum FilterSection: Hashable {
    case regions
    case routes
    case causes
    case map
}

private struct MapScreen: View {
    @Bindable var model: MapModel
    @Bindable var searchModel: SearchModel
    let isSyncing: Bool
    let syncError: String?
    let fetchIncident: (String) async throws -> Incident?
    let sync: () async -> Void
    private static let iomURL: URL = {
        guard let url = URL(string: "https://missingmigrants.iom.int") else {
            fatalError("Invalid IOM URL constant")
        }
        return url
    }()

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
                    locationPreview
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 12)
                        .padding(.top, 4)
                        .zIndex(10)
                }
            }
            attribution
        }
    }

    private var toolbar: some View {
        let search = searchModel
        return HStack(alignment: .center, spacing: 10) {
            Button {
                isFilterPresented.toggle()
            } label: {
                toolbarIcon("line.3.horizontal.decrease.circle")
            }
            .buttonStyle(.plain)
            .help("Filters")
            .accessibilityLabel("Filters")
            .frame(width: Self.toolbarControlSize, height: Self.toolbarControlSize)
            .popover(isPresented: $isFilterPresented, arrowEdge: .bottom) {
                FilterPopoverContent(model: model, searchModel: searchModel)
            }

            SearchField(searchModel: search)
                .frame(height: Self.toolbarControlSize, alignment: .center)
            Button {
                searchModel.clear()
                Task {
                    await model.fitSelectedRegions()
                }
            } label: {
                toolbarIcon("globe")
            }
            .buttonStyle(.plain)
            .help("Fit Selected Regions")
            .accessibilityLabel("Fit Selected Regions")
            .frame(width: Self.toolbarControlSize, height: Self.toolbarControlSize)
            Button {
                toggleMapStyle()
            } label: {
                toolbarIcon("map")
            }
            .buttonStyle(.plain)
            .help("Map Style: \(mapStyle.title)")
            .accessibilityLabel("Map Style: \(mapStyle.title)")
            .frame(width: Self.toolbarControlSize, height: Self.toolbarControlSize)
            Spacer()
            statusLabels
            Button {
                Task { await sync() }
            } label: {
                toolbarIcon("arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh")
            .accessibilityLabel("Refresh")
            .frame(width: Self.toolbarControlSize, height: Self.toolbarControlSize)
            .disabled(isSyncing)
        }
        .frame(height: Self.toolbarControlSize, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private static let toolbarControlSize: CGFloat = 28

    private func toolbarIcon(_ systemName: String) -> some View {
        return Image(systemName: systemName)
            .font(.system(size: 18, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(width: Self.toolbarControlSize, height: Self.toolbarControlSize)
            .contentShape(Rectangle())
    }

    private var locationPreview: some View {
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(searchModel.completions.prefix(8))) { completion in
                Button {
                    searchModel.select(completion)
                    select(completion)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(completion.title)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if completion.subtitle.isEmpty == false {
                            Text(completion.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.plain)

                if completion.id != searchModel.completions.prefix(8).last?.id {
                    Divider()
                }
            }
        }
        .frame(width: 360, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 1)
        }
        .shadow(radius: 8, y: 4)
    }

    private func select(_ completion: LocationCompletion) -> Void {
        let search = searchModel
        Task {
            if let camera = try? await search.camera(for: completion) {
                model.moveCamera(to: camera)
            }
        }
    }

    private var statusLabels: some View {
        return HStack(spacing: 10) {
            Text(mapIncidentCountLabel)
            Text(filterIncidentCountLabel)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private var mapIncidentCountLabel: String {
        if model.isAnnotationLimited == true {
            return "Map: \(model.incidents.count.formatted()) of \(model.matchingIncidentCount.formatted()) visible"
        }
        return "Map: \(model.matchingIncidentCount.formatted()) visible"
    }

    private var filterIncidentCountLabel: String {
        return "Filters: \(model.filteredIncidentCount.formatted()) total"
    }

    private var mapStyle: MapStyle {
        return MapStyle(rawValue: mapStyleRawValue) ?? .standard
    }

    private func toggleMapStyle() -> Void {
        mapStyleRawValue = mapStyle == .standard ? MapStyle.hybrid.rawValue : MapStyle.standard.rawValue
    }

    private var attribution: some View {
        return HStack(spacing: 4) {
            Link("Data: IOM Missing Migrants Project", destination: Self.iomURL)
            Text("CC BY 4.0. Figures are minimum estimates; locations are approximate.")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

private struct SearchField: View {
    @Bindable var searchModel: SearchModel

    var body: some View {
        return MacSearchField(
            text: $searchModel.query,
            placeholder: "Search location",
            onTextChange: searchModel.updateQuery
        )
        .frame(width: 360, height: 28, alignment: .center)
    }
}

private enum MapStyle: String {
    case standard
    case hybrid

    var title: String {
        switch self {
            case .standard:
                return "Standard"
            case .hybrid:
                return "Hybrid"
        }
    }

    var mapType: MKMapType {
        switch self {
            case .standard:
                return .standard
            case .hybrid:
                return .hybrid
        }
    }
}

private struct MacSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onTextChange: (String) -> Void

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.sendsSearchStringImmediately = true
        field.focusRingType = .default
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) -> Void {
        context.coordinator.text = $text
        context.coordinator.onTextChange = onTextChange
        if field.stringValue != text {
            field.stringValue = text
        }
        field.placeholderString = placeholder
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text, onTextChange: onTextChange)
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>
        var onTextChange: (String) -> Void

        init(text: Binding<String>, onTextChange: @escaping (String) -> Void) {
            self.text = text
            self.onTextChange = onTextChange
        }

        func controlTextDidChange(_ notification: Notification) -> Void {
            guard let field = notification.object as? NSSearchField else { return }
            text.wrappedValue = field.stringValue
            onTextChange(field.stringValue)
        }
    }
}
