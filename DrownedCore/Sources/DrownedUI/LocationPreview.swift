import SwiftUI

struct LocationPreview: View {
    let completions: [LocationCompletion]
    let select: (LocationCompletion) -> Void

    private var visibleCompletions: [LocationCompletion] {
        return Array(completions.prefix(8))
    }

    var body: some View {
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(visibleCompletions) { completion in
                Button {
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

                if completion.id != visibleCompletions.last?.id {
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
}
