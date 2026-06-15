import SwiftUI

struct FilterToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        return HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .frame(width: 38, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
