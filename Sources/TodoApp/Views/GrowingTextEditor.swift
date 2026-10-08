import SwiftUI
import AppKit

/// A multi-line text input backed by AppKit's NSTextView.
///
/// Unlike SwiftUI's `TextEditor`, the text view lives inside a real `NSScrollView`,
/// so long input scrolls inside the bar instead of overflowing it. The wrapped
/// content height is reported through `onHeightChange` so the container can grow
/// smoothly between `minHeight` and `maxHeight`.
struct GrowingTextEditor: NSViewRepresentable {
    @Binding var text: String

    var minHeight: CGFloat
    var maxHeight: CGFloat
    var focusRequest: Bool = false
    var onSubmit: () -> Void = {}
    var onHeightChange: (CGFloat) -> Void = { _ in }
    var onFocusChange: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = MeasuringScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = InputTextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 14)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.textContainer?.lineFragmentPadding = 0
        textView.autoresizingMask = [.width]
        textView.string = text

        let coordinator = context.coordinator
        coordinator.textView = textView
        textView.onFocusChange = { [weak coordinator] focused in
            coordinator?.parent.onFocusChange(focused)
        }

        scrollView.documentView = textView
        scrollView.onLayout = { [weak coordinator] in
            // `layout()` always runs on the main thread, so it is safe to
            // re-measure the text right here without hopping actors.
            MainActor.assumeIsolated {
                coordinator?.reportHeight()
            }
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let textView = coordinator.textView else { return }

        // Only push external changes; never clobber in-progress IME composition.
        if textView.string != text && !textView.hasMarkedText() {
            textView.string = text
        }

        // Apply focus changes exactly once per change to avoid feedback loops.
        if coordinator.appliedFocus != focusRequest {
            coordinator.appliedFocus = focusRequest
            if focusRequest {
                scrollView.window?.makeFirstResponder(textView)
            } else if textView.window?.firstResponder === textView {
                scrollView.window?.makeFirstResponder(nil)
            }
        }

        coordinator.reportHeight()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: GrowingTextEditor
        weak var textView: InputTextView?
        var appliedFocus: Bool = false
        private var lastReportedHeight: CGFloat = 0

        init(_ parent: GrowingTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            parent.text = textView.string
            reportHeight()
            // Follow the caret once the editor starts scrolling
            textView.scrollRangeToVisible(NSRange(location: textView.string.utf16.count, length: 0))
        }

        func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString string: String?
        ) -> Bool {
            // Plain Enter submits; Shift+Return inserts a line break.
            if string == "\n", !NSEvent.modifierFlags.contains(.shift) {
                parent.onSubmit()
                return false
            }
            return true
        }

        func reportHeight() {
            guard let textView = textView,
                  let layoutManager = textView.layoutManager,
                  let container = textView.textContainer else { return }

            layoutManager.ensureLayout(for: container)
            let contentHeight = layoutManager.usedRect(for: container).height
                + textView.textContainerInset.height * 2

            let clamped = min(parent.maxHeight, max(parent.minHeight, contentHeight.rounded(.up)))
            guard abs(clamped - lastReportedHeight) > 0.5 else { return }
            lastReportedHeight = clamped
            parent.onHeightChange(clamped)
        }
    }
}

/// Reports layout passes so the text height is re-measured whenever the
/// window (and therefore the wrapping width) changes.
final class MeasuringScrollView: NSScrollView {
    var onLayout: (() -> Void)?

    override func layout() {
        super.layout()
        onLayout?()
    }
}

/// NSTextView that reports first-responder changes so the SwiftUI focus
/// state (border highlight, ⌘N, dictation hand-off) stays in sync.
final class InputTextView: NSTextView {
    var onFocusChange: ((Bool) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocusChange?(true) }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { onFocusChange?(false) }
        return accepted
    }
}
