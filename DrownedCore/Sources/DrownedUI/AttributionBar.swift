import SwiftUI

struct AttributionBar: View {
    private static let iomURL: URL = {
        guard let url = URL(string: "https://missingmigrants.iom.int") else {
            fatalError("Invalid IOM URL constant")
        }
        return url
    }()

    var body: some View {
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
