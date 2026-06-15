import DrownedModel
import SwiftUI

struct FilterPopoverContent: View {
    @Bindable var model: MapModel
    @Bindable var searchModel: SearchModel

    @State private var expandedSections: Set<FilterSection> = [.regions]

    var body: some View {
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                FilterSectionView(title: "Regions", isExpanded: expansionBinding(for: .regions)) {
                    ForEach(
                        Region.allCases.filter { region in
                            return region != .unknown
                        }.sorted()
                    ) { region in
                        FilterToggleRow(title: region.rawValue, isOn: binding(for: region))
                    }
                }

                FilterSectionView(title: "Routes", isExpanded: expansionBinding(for: .routes)) {
                    if model.routes.isEmpty == true {
                        EmptyFilterText("No routes loaded")
                    }
                    else {
                        ForEach(model.routes, id: \.self) { route in
                            FilterToggleRow(title: route, isOn: setBinding(route, keyPath: \.routes))
                        }
                    }
                }

                FilterSectionView(title: "Causes", isExpanded: expansionBinding(for: .causes)) {
                    if model.causes.isEmpty == true {
                        EmptyFilterText("No causes loaded")
                    }
                    else {
                        ForEach(model.causes, id: \.self) { cause in
                            FilterToggleRow(title: cause, isOn: setBinding(cause, keyPath: \.causes))
                        }
                    }
                }

                FilterSectionView(title: "Map", isExpanded: expansionBinding(for: .map)) {
                    FilterToggleRow(title: "Mappable incidents only", isOn: $model.filter.mappableOnly)
                    Button("Reset Filters", systemImage: "arrow.counterclockwise", action: resetFilters)
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(width: 340, height: 520)
    }

    private func resetFilters() -> Void {
        searchModel.clear()
        model.resetFilter()
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
