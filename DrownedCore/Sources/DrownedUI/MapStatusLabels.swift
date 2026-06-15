import SwiftUI

struct MapStatusLabels: View {
    let displayedIncidentCount: Int
    let matchingIncidentCount: Int
    let filteredIncidentCount: Int

    var body: some View {
        return HStack(spacing: 10) {
            Text(mapIncidentCountLabel)
            Text(filterIncidentCountLabel)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private var mapIncidentCountLabel: String {
        if matchingIncidentCount > displayedIncidentCount {
            return "Map: \(displayedIncidentCount.formatted()) of \(matchingIncidentCount.formatted()) visible"
        }
        return "Map: \(matchingIncidentCount.formatted()) visible"
    }

    private var filterIncidentCountLabel: String {
        return "Filters: \(filteredIncidentCount.formatted()) total"
    }
}
