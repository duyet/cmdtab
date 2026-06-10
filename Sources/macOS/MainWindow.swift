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
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.isMovableByWindowBackground = true
    }

    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return true
    }

    public override func keyDown(with event: NSEvent) {
        if let onKeyPress = onKeyPress, onKeyPress(event) {
            return
        }
        super.keyDown(with: event)
    }
}
