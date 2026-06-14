import DrownedModel

struct MapQueryKey: Hashable {
    let filter: IncidentFilter
    let bounds: CoordinateBounds?
}
