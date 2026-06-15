import AppKit

final class LinkTextField: NSTextField {
    private let url: URL

    init(url: URL, preferredWidth: CGFloat) {
        self.url = url
        super.init(frame: .zero)

        isEditable = false
        isBordered = false
        drawsBackground = false
        maximumNumberOfLines = 0
        lineBreakMode = .byWordWrapping
        preferredMaxLayoutWidth = preferredWidth
        toolTip = url.absoluteString
        attributedStringValue = NSAttributedString(
            string: url.absoluteString,
            attributes: [
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .font: NSFont.systemFont(ofSize: 11)
            ]
        )
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) -> Void {
        NSWorkspace.shared.open(url)
    }

    override func resetCursorRects() -> Void {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
