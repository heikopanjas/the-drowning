import AppKit

final class FlippedStackView: NSStackView {
    override var isFlipped: Bool {
        return true
    }
}
