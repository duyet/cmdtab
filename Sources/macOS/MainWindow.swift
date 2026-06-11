import Cocoa

public final class MainWindow: NSWindow {
    public var onKeyPress: ((NSEvent) -> Bool)?  // Returns true if handled/consumed

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.backgroundColor = .windowBackgroundColor
        self.isOpaque = true
        self.hasShadow = true
        // Drag only via the title bar area — body drags would fight text
        // selection and slider/drag interactions in the content.
        self.isMovableByWindowBackground = false
    }

    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return true
    }

    // Menu key equivalents are matched before keyDown would ever fire, so the
    // interceptor must also run here — otherwise the Edit menu's ⌘C would
    // swallow the "copy streaming output" behavior, ⌘K, ⌘B, etc.
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let onKeyPress = onKeyPress, onKeyPress(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    public override func keyDown(with event: NSEvent) {
        if let onKeyPress = onKeyPress, onKeyPress(event) {
            return
        }
        super.keyDown(with: event)
    }
}
