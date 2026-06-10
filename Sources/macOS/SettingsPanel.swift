import AppKit
import SwiftUI

@MainActor
final class SettingsPanel: NSPanel {
    let viewModel: MainViewModel

    init(viewModel: MainViewModel, parentWindow: NSWindow) {
        self.viewModel = viewModel

        let settingsView = SettingsView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: settingsView)

        let panelRect = NSRect(x: 0, y: 0, width: 640, height: 520)

        super.init(
            contentRect: panelRect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.contentViewController = hostingController
        self.isFloatingPanel = true
        self.level = .floating
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true

        // Center over parent window
        if let parentFrame = parentWindow.screen?.visibleFrame {
            let x = parentFrame.origin.x + (parentFrame.width - panelRect.width) / 2
            let y = parentFrame.origin.y + (parentFrame.height - panelRect.height) / 2
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
