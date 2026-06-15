import SwiftUI

struct ToolbarIconButton: View {
    static let size: CGFloat = 28

    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        return Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: Self.size, height: Self.size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .frame(width: Self.size, height: Self.size)
    }
}
