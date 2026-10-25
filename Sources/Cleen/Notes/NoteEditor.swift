import AppKit
import SwiftUI

/// The Markdown editor for SwiftUI: binds the note's text both ways and reports focus, so
/// the panel can stay open while someone writes.
struct NoteEditor: NSViewRepresentable {
    @Binding var text: String
    var baseSize: CGFloat = 13
    /// Bumped to put the cursor in the editor.
    var focusRequest = 0
    var onFocusChange: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = MarkdownTextView(baseSize: baseSize)
        textView.delegate = context.coordinator
        textView.string = text
        textView.restyle()
        textView.onFocusChange = onFocusChange
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        scroll.documentView = textView
        context.coordinator.focusRequest = focusRequest
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? MarkdownTextView else { return }
        context.coordinator.text = $text
        textView.onFocusChange = onFocusChange
        // Another note was picked, or the same note changed somewhere else (the widget).
        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            textView.restyle()
            textView.setSelectedRange(NSRange(location: min(selection.location, (text as NSString).length), length: 0))
        }
        if context.coordinator.focusRequest != focusRequest {
            context.coordinator.focusRequest = focusRequest
            DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var focusRequest = 0

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, text.wrappedValue != textView.string else { return }
            text.wrappedValue = textView.string
        }
    }
}
