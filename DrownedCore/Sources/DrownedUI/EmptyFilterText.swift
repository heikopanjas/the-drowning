import SwiftUI

struct EmptyFilterText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        return Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
