#if os(macOS)
import SwiftUI
import AppKit
#if canImport(SwiftData)
import SwiftData
#endif

@main
struct MinhAgentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public var statusItem: NSStatusItem?
    var windowController: WindowController?
    public var viewModel: MainViewModel?
    private var hasPositionedOnce = false
    #if canImport(SwiftData)
    private var modelContainer: ModelContainer?
    #endif

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // .regular: normal windowed app with Dock icon + Cmd+Tab presence.
        NSApp.setActivationPolicy(.regular)

        let vm = MainViewModel()
        self.viewModel = vm

        #if canImport(SwiftData)
        do {
            let container = try ModelContainer(for: PersistedConversation.self, PersistedMessage.self)
            self.modelContainer = container
            vm.configurePersistence(container.mainContext)
        } catch {
            print("Failed to initialize SwiftData: \(error)")
        }
        #endif

        // Apply persisted appearance preference before the window appears.
        vm.applyAppearance()

        let wc = WindowController(viewModel: vm)
        self.windowController = wc

        setupMainMenu()
        setupStatusItem()
        setupGlobalHotKey()
        setupActivationObserver()
        DispatchQueue.main.async { [weak self] in
            self?.showWindow()
            self?.runSnapshotModeIfRequested()
        }
    }

    // MARK: - Snapshot mode (UI verification harness)
    /// When MINHAGENT_SNAPSHOT_DIR is set, renders the live window through a
    /// sequence of UI states to PNG files and exits. In-process rendering —
    /// no Screen Recording permission needed. Dev/test harness only.
    private func runSnapshotModeIfRequested() {
        guard let dir = ProcessInfo.processInfo.environment["MINHAGENT_SNAPSHOT_DIR"],
            let window = windowController?.window, let vm = viewModel
        else { return }
        let outDir = URL(fileURLWithPath: dir, isDirectory: true)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        func snap(_ name: String) {
            // The frame view (contentView's superview) includes the title bar.
            guard let frameView = window.contentView?.superview,
                let rep = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds)
            else { return }
            frameView.cacheDisplay(in: frameView.bounds, to: rep)
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: outDir.appendingPathComponent("\(name).png"))
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            snap("01-main")
            vm.isSidebarVisible = false
            try? await Task.sleep(for: .milliseconds(700))
            snap("02-sidebar-hidden")
            vm.isSidebarVisible = true
            try? await Task.sleep(for: .milliseconds(700))
            snap("03-sidebar-restored")
            vm.showSearchPalette()
            try? await Task.sleep(for: .milliseconds(500))
            snap("04-search-palette")
            vm.hideSearchPalette()
            try? await Task.sleep(for: .milliseconds(300))
            vm.isSettingsOpen = true
            vm.settingsTab = "general"
            try? await Task.sleep(for: .milliseconds(700))
            snap("05-settings-general")
            vm.settingsTab = "cloudmodel"
            try? await Task.sleep(for: .milliseconds(500))
            snap("06-settings-cloudmodel")
            vm.isSettingsOpen = false
            try? await Task.sleep(for: .milliseconds(300))
            NSApp.terminate(nil)
        }
    }

    // MARK: - Main Menu

        /// A programmatic main menu restores standard Edit shortcuts
        /// (⌘C/⌘V/⌘X/⌘A/⌘Z) inside text fields and makes commands discoverable.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "About MinhAgent",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide MinhAgent", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(
            withTitle: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(
            withTitle: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit MinhAgent", action: #selector(quitApp), keyEquivalent: "q")

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
        let searchItem = viewMenu.addItem(
            withTitle: "Search Conversations", action: #selector(showSearchPalette), keyEquivalent: "k")
        searchItem.keyEquivalentModifierMask = .command

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

    @objc private func showSearchPalette() {
        if viewModel?.isSettingsOpen != true {
            viewModel?.showSearchPalette()
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

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appDidBecomeActive() {
        viewModel?.handleActivation()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            let icon = NSImage(contentsOf: Bundle.main.url(forResource: "StatusBarIconTemplate", withExtension: "png")!)
                ?? NSImage(systemSymbolName: "command.square", accessibilityDescription: "MinhAgent")!
            icon.size = NSSize(width: 16, height: 16)
            icon.isTemplate = true
            button.image = icon
        }

        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: "Toggle Window (⌥Space)", action: #selector(toggleWindow), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit MinhAgent", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem?.menu = menu
    }

    private func setupGlobalHotKey() {
        HotKeyManager.shared.onHotKeyPressed = { [weak self] in
            self?.toggleWindow()
        }
        HotKeyManager.shared.registerGlobalHotKey()
    }

    @objc public func toggleWindow() {
        guard let window = windowController?.window else { return }
        // Only hide if the window is visible AND the app is frontmost.
        // If the window is behind other apps (visible but app inactive),
        // bring it to front instead.
        if window.isVisible && window.isKeyWindow && NSApp.isActive {
            hideWindow()
        } else {
            showWindow()
        }
    }

    @objc public func openSettings() {
        showWindow()
        viewModel?.isSettingsOpen = true
        viewModel?.loadApiKeyIfNeeded()
    }

    private func showWindow() {
        guard let window = windowController?.window else { return }
        let fallbackSize = NSSize(width: 780, height: 460)
        if !hasPositionedOnce {
            windowController?.resetToDefaultFrame()
        }
        let contentSize = window.contentRect(forFrameRect: window.frame).size
        window.setContentSize(
            NSSize(
                width: max(contentSize.width, fallbackSize.width),
                height: max(contentSize.height, fallbackSize.height)
            )
        )
        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        // Check for new clipboard content via PasteboardMonitor (respects echo suppression)
        if let newText = PasteboardMonitor.shared.detectNewContent() {
            if newText != viewModel?.detectedClipboardText {
                viewModel?.detectedClipboardText = newText
                viewModel?.isClipboardBannerVisible = true
            }
        }

        // Only center the window on the first show; after that, respect the
        // user's manual placement (setFrameAutosaveName restores it).
        if !hasPositionedOnce {
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
                window.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: windowSize), display: true)
            }
            hasPositionedOnce = true
        }

        windowController?.showWindow(nil)
        window.makeMain()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        windowController?.ensureUsableFrame()
        activateApplication()
    }

    private func activateApplication() {
        NSApp.activate(ignoringOtherApps: true)
        let currentApp = NSRunningApplication.current
        if #available(macOS 14.0, *),
            let frontmostApp = NSWorkspace.shared.frontmostApplication,
            frontmostApp.processIdentifier != currentApp.processIdentifier
        {
            currentApp.activate(from: frontmostApp, options: [.activateAllWindows])
        } else {
            currentApp.activate(options: [.activateAllWindows])
        }
    }

    private func hideWindow() {
        windowController?.window?.orderOut(nil)
    }

    // MARK: - Dock Reopen
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    /// Quit when the last window is closed — no background mode.
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc public func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
#endif
