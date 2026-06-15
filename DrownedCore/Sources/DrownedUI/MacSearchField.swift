import AppKit
import SwiftUI

struct MacSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onTextChange: (String) -> Void

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.sendsSearchStringImmediately = true
        field.focusRingType = .default
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) -> Void {
        context.coordinator.text = $text
        context.coordinator.onTextChange = onTextChange
        if field.stringValue != text {
            field.stringValue = text
        }
        field.placeholderString = placeholder
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text, onTextChange: onTextChange)
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>
        var onTextChange: (String) -> Void

        init(text: Binding<String>, onTextChange: @escaping (String) -> Void) {
            self.text = text
            self.onTextChange = onTextChange
        }

        func controlTextDidChange(_ notification: Notification) -> Void {
            guard let field = notification.object as? NSSearchField else { return }
            text.wrappedValue = field.stringValue
            onTextChange(field.stringValue)
        }
    }
}
