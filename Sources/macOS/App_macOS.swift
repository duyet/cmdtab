#if os(macOS)
import SwiftUI
import AppKit

@main
struct CmdTabApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    public var statusItem: NSStatusItem?
    public var window: MainWindow?
    public var viewModel: MainViewModel?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        let vm = MainViewModel()
        self.viewModel = vm

        // Apply persisted appearance preference before the window appears.
        vm.applyAppearance()

        // Default size — compact utility window (Claude desktop mini feel)
        let windowWidth: CGFloat = 800
        let windowHeight: CGFloat = 560

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let rect = NSRect(
            x: screenFrame.origin.x + (screenFrame.width - windowWidth) / 2,
            y: screenFrame.origin.y + (screenFrame.height - windowHeight) * 0.65,
            width: windowWidth,
            height: windowHeight
        )

        let mainWindow = MainWindow(contentRect: rect)
        mainWindow.minSize = NSSize(width: 680, height: 480)
        // Restores any previously saved frame and persists future moves/resizes.
        mainWindow.setFrameAutosaveName("CmdTabMainWindow")

        let contentView = MainView(viewModel: vm)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)

        mainWindow.contentView = hostingView
        mainWindow.delegate = self
        self.window = mainWindow

        // Configure key down interceptor
        mainWindow.onKeyPress = { [weak self] event in
            guard let self = self, let vm = self.viewModel else { return false }

            // 1. Escape key -> Hide Window
            if event.keyCode == 53 {
                self.hideWindow()
                return true
            }

            // 2. Command + B or Command + \ -> Toggle sidebar
            if event.modifierFlags.contains(.command)
                && (event.charactersIgnoringModifiers == "b" || event.charactersIgnoringModifiers == "\\")
            {
                if !vm.isSettingsOpen {
                    vm.isSidebarVisible.toggle()
                    return true
                }
            }

            // 2b. Command + T or Command + N -> New conversation
            // (⌘T = New Tab muscle memory; ⌘N = HIG-standard New, undocumented in UI)
            if event.modifierFlags.contains(.command),
                event.charactersIgnoringModifiers == "t" || event.charactersIgnoringModifiers == "n"
            {
                if !vm.isSettingsOpen {
                    vm.startNewConversation(title: "New Chat")
                    return true
                }
            }

            // 3. Option + [1-9] or Command + [1-9] -> Run preset with clipboard
            let hasCommand = event.modifierFlags.contains(.command)
            let hasOption = event.modifierFlags.contains(.option)
            if (hasCommand || hasOption) && !event.modifierFlags.contains(.control) {
                if let chars = event.charactersIgnoringModifiers,
                    chars.count == 1,
                    let firstChar = chars.first,
                    let num = Int(String(firstChar)),
                    num >= 1 && num <= 9
                {
                    if vm.isClipboardBannerVisible && !vm.detectedClipboardText.isEmpty {
                        vm.runPresetWithClipboard(index: num - 1)
                        return true
                    }
                }
            }

            // 4. Command + C -> Copy streaming output to clipboard (only if no text selected)
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "c" {
                let hasTextSelection = (self.window?.firstResponder as? NSTextView)?.selectedRange.length ?? 0 > 0
                if !hasTextSelection && !vm.isSettingsOpen && vm.selectedConversationId != nil {
                    vm.copyOutputToClipboard()
                    return true
                }
                return false  // Let system handle normal copy
            }

            // 5. Command + K -> Clear conversation
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "k" {
                if !vm.isSettingsOpen && vm.selectedConversationId != nil {
                    vm.clearConversation()
                    return true
                }
            }

            // 6. Command + , -> Toggle settings
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "," {
                vm.toggleSettings()
                return true
            }

            // 7. Command + W -> Hide window (HIG: Close Window)
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
                self.hideWindow()
                return true
            }

            // 8. Delete key -> Delete selected conversation (only when not editing text)
            if event.keyCode == 51 && event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
                let editingText =
                    self.window?.firstResponder is NSTextView || self.window?.firstResponder is NSTextField
                if !editingText && !vm.isSettingsOpen && vm.isSidebarVisible,
                    let selectedId = vm.selectedConversationId
                {
                    vm.deleteConversation(id: selectedId)
                    return true
                }
            }

            return false
        }

        setupMainMenu()
        setupStatusItem()
        setupGlobalHotKey()
        setupActivationObserver()
        showWindow()
    }

    // MARK: - Main Menu

    /// LSUIElement apps get no menu bar by default, which also disables the
    /// standard Edit shortcuts (⌘C/⌘V/⌘X/⌘A/⌘Z) inside text fields. Since we
    /// switch to `.regular` activation at launch, a real main menu restores
    /// those via the responder chain and makes commands discoverable.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "About cmdtab",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide cmdtab", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(
            withTitle: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(
            withTitle: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit cmdtab", action: #selector(quitApp), keyEquivalent: "q")

        // File menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "New Chat", action: #selector(newChat), keyEquivalent: "n")
        let newChatTab = fileMenu.addItem(withTitle: "New Chat", action: #selector(newChat), keyEquivalent: "t")
        newChatTab.isAlternate = true
        newChatTab.keyEquivalentModifierMask = .command
        fileMenu.addItem(.separator())
        fileMenu.addItem(
            withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        // Edit menu — standard selectors resolve through the responder chain.
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        // View menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        let sidebarItem = viewMenu.addItem(
            withTitle: "Toggle Sidebar", action: #selector(toggleSidebarVisibility), keyEquivalent: "b")
        sidebarItem.keyEquivalentModifierMask = .command
        let clearItem = viewMenu.addItem(
            withTitle: "Clear Conversation", action: #selector(clearConversation), keyEquivalent: "k")
        clearItem.keyEquivalentModifierMask = .command

        // Window menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(
            withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu

        // Help menu
        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "Help")
        helpMenuItem.submenu = helpMenu
        NSApp.helpMenu = helpMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func newChat() {
        showWindow()
        if viewModel?.isSettingsOpen != true {
            viewModel?.startNewConversation(title: "New Chat")
        }
    }

    @objc private func toggleSidebarVisibility() {
        if viewModel?.isSettingsOpen != true {
            viewModel?.isSidebarVisible.toggle()
        }
    }

    @objc private func clearConversation() {
        if viewModel?.isSettingsOpen != true && viewModel?.selectedConversationId != nil {
            viewModel?.clearConversation()
        }
    }

    private func setupActivationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        viewModel?.handleActivation()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "⌘⌥"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Window (⌥Space)", action: #selector(toggleWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit cmdtab", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    private func setupGlobalHotKey() {
        HotKeyManager.shared.onHotKeyPressed = { [weak self] in
            DispatchQueue.main.async {
                self?.toggleWindow()
            }
        }
        HotKeyManager.shared.registerGlobalHotKey()
    }

    @objc public func toggleWindow() {
        guard let window = window else { return }
        if window.isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

    @objc public func openSettings() {
        showWindow()
        viewModel?.isSettingsOpen = true
    }

    private func showWindow() {
        guard let window = window else { return }

        // Check for new clipboard content via PasteboardMonitor (respects echo suppression)
        if let newText = PasteboardMonitor.shared.detectNewContent() {
            if newText != viewModel?.detectedClipboardText {
                viewModel?.detectedClipboardText = newText
                viewModel?.isClipboardBannerVisible = true
            }
        }

        // Position on the screen containing mouse pointer
        var screen = NSScreen.main
        let mouseLocation = NSEvent.mouseLocation
        for s in NSScreen.screens {
            if NSMouseInRect(mouseLocation, s.frame, false) {
                screen = s
                break
            }
        }

        if let screen = screen {
            let screenRect = screen.visibleFrame
            let windowSize = window.frame.size
            let x = screenRect.origin.x + (screenRect.size.width - windowSize.width) / 2
            let y = screenRect.origin.y + (screenRect.size.height - windowSize.height) * 0.65
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hideWindow() {
        window?.orderOut(nil)
    }

    // MARK: - NSWindowDelegate & Dock Reopen
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showWindow()
        }
        return true
    }

    @objc public func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
#endif
