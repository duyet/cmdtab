import AppKit
import SwiftUI

@MainActor
final class WindowController: NSWindowController {
    let viewModel: MainViewModel
    private let defaultFrame: NSRect

    init(viewModel: MainViewModel) {
        self.viewModel = viewModel

        // Default size — compact utility window, wider than tall
        let windowWidth: CGFloat = 780
        let windowHeight: CGFloat = 460
        let screenFrame =
            NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let rect = NSRect(
            x: screenFrame.origin.x + (screenFrame.width - windowWidth) / 2,
            y: screenFrame.origin.y + (screenFrame.height - windowHeight) * 0.65,
            width: windowWidth,
            height: windowHeight
        )

        let window = MainWindow(contentRect: rect)
        self.defaultFrame = window.frame
        window.minSize = NSSize(width: 680, height: 420)

        let rootHC = NSHostingController(
            rootView: MacRootView(viewModel: viewModel)
        )
        rootHC.sizingOptions = []

        super.init(window: window)

        window.contentViewController = rootHC
        window.contentMinSize = NSSize(width: 680, height: 420)
        window.setContentSize(NSSize(width: 780, height: 460))
        ensureUsableFrame()
        DispatchQueue.main.async { [weak self] in
            self?.ensureUsableFrame()
        }
        // Layer-backed content so opaque pane backgrounds clip to the
        // window's rounded corners instead of drawing square edges.
        window.contentView?.wantsLayer = true
        window.delegate = self

        // Toolbar removed — sidebar toggle + search live inline in the sidebar
        // next to the traffic lights (Claude Code style).
        window.toolbar = nil

        // Add header buttons to titlebar container next to traffic lights
        if let titlebarContainer = window.standardWindowButton(.closeButton)?.superview {
            let buttonsView = WindowHeaderButtonsView(viewModel: viewModel)
            let hostingView = NSHostingView(rootView: buttonsView)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            titlebarContainer.addSubview(hostingView)

            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: titlebarContainer.leadingAnchor, constant: 76),
                hostingView.centerYAnchor.constraint(equalTo: titlebarContainer.centerYAnchor),
                hostingView.heightAnchor.constraint(equalToConstant: 24),
                hostingView.widthAnchor.constraint(equalToConstant: 92)
            ])
        }

        // Wire key events through MainWindow
        window.onKeyPress = { [weak self] event in
            guard let self else { return false }
            return self.handleKeyPress(event)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func ensureUsableFrame() {
        guard let window else { return }
        let frame = window.frame
        let minSize = window.minSize
        let isTooSmall = frame.width < minSize.width || frame.height < minSize.height
        let isVisibleOnScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
        if isTooSmall || !isVisibleOnScreen {
            window.setFrame(defaultFrame, display: true)
        }
    }

    func resetToDefaultFrame() {
        window?.setFrame(defaultFrame, display: true)
    }

    // MARK: - Key Handling
    // Moved from AppDelegate — all keyboard shortcuts live here now.
    private func handleKeyPress(_ event: NSEvent) -> Bool {
        let vm = viewModel

        // 1. Escape → close transient UI first, then hide the window.
        if event.keyCode == 53 {
            if vm.isSearchPaletteVisible {
                vm.hideSearchPalette()
                return true
            }
            window?.orderOut(nil)
            return true
        }

        // 2. ⌘B / ⌘\ → Toggle sidebar
        if event.modifierFlags.contains(.command),
            event.charactersIgnoringModifiers == "b" || event.charactersIgnoringModifiers == "\\"
        {
            if !vm.isSettingsOpen {
                vm.isSidebarVisible.toggle()
                return true
            }
        }

        // 3. ⌘T / ⌘N → New conversation
        if event.modifierFlags.contains(.command),
            event.charactersIgnoringModifiers == "t" || event.charactersIgnoringModifiers == "n"
        {
            if !vm.isSettingsOpen {
                vm.startNewConversation(title: "New Chat")
                return true
            }
        }

        // 4. ⌥1-9 / ⌘1-9 → Run preset with clipboard
        let hasCommand = event.modifierFlags.contains(.command)
        let hasOption = event.modifierFlags.contains(.option)
        if (hasCommand || hasOption) && !event.modifierFlags.contains(.control) {
            if let chars = event.charactersIgnoringModifiers,
                chars.count == 1,
                let firstChar = chars.first,
                let num = Int(String(firstChar)),
                num >= 1 && num <= 9
            {
                if !vm.isSettingsOpen && num - 1 < vm.presets.count {
                    vm.pickPreset(index: num - 1)
                    return true
                }
            }
        }

        // 5. ⌘C → Copy streaming output (only if no text selected)
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "c" {
            let hasTextSelection =
                (window?.firstResponder as? NSTextView)?.selectedRange.length ?? 0 > 0
            if !hasTextSelection && !vm.isSettingsOpen && vm.selectedConversationId != nil {
                vm.copyOutputToClipboard()
                return true
            }
            return false
        }

        // 6. ⌘K → Open search palette
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "k" {
            if !vm.isSettingsOpen {
                vm.showSearchPalette()
                return true
            }
        }

        // 7. ⌘, → Toggle settings
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "," {
            vm.toggleSettings()
            return true
        }

        // 8. ⌘W → Hide window
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
            window?.orderOut(nil)
            return true
        }

        // 9. Delete → Delete selected conversation
        if event.keyCode == 51
            && event.modifierFlags.intersection([.command, .option, .control]).isEmpty
        {
            let editingText =
                window?.firstResponder is NSTextView || window?.firstResponder is NSTextField
            if !editingText && !vm.isSettingsOpen && vm.isSidebarVisible,
                let selectedId = vm.selectedConversationId
            {
                vm.deleteConversation(id: selectedId)
                return true
            }
        }

        return false
    }
}

// MARK: - NSWindowDelegate
extension WindowController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}

private struct MacRootView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        ZStack {
            HSplitView {
                if viewModel.isSidebarVisible {
                    SidebarView(viewModel: viewModel)
                        .frame(minWidth: 180, idealWidth: viewModel.sidebarWidth, maxWidth: 480)
                }

                DetailContentView(viewModel: viewModel)
                    .frame(minWidth: 500)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if viewModel.isSearchPaletteVisible {
                SearchPaletteView(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .frame(minWidth: 680, minHeight: 420)
        .background(Color.creamBackground)
    }
}

// MARK: - Window Header Buttons View
/// A single, window-level set of buttons next to the traffic lights.
struct WindowHeaderButtonsView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        HStack(spacing: 2) {
            headerButton(systemName: "sidebar.left", help: "Toggle Sidebar (⌘B)") {
                withAnimation { viewModel.isSidebarVisible.toggle() }
            }
            headerButton(systemName: "magnifyingglass", help: "Search Conversations (⌘K)") {
                viewModel.showSearchPalette()
            }
            headerButton(
                systemName: "info.circle",
                help: "Show Raw Request / System Prompt",
                disabled: viewModel.selectedConversationId == nil
            ) {
                viewModel.isRawRequestInfoVisible = true
            }
        }
        .frame(width: 92, height: 24, alignment: .leading)
    }

    private func headerButton(
        systemName: String,
        help: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Image(systemName: systemName)
            .font(.system(size: AppFont.pt(12), weight: .medium))
            .foregroundColor(disabled ? .secondary.opacity(0.3) : .secondary)
            .frame(width: 28, height: 22)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
        .plainFocusEffectDisabled()
        .accessibilityLabel(help)
        .accessibilityAddTraits(.isButton)
        .help(help)
    }
}
