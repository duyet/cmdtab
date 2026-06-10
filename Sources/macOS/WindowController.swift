import AppKit
import SwiftUI

@MainActor
final class WindowController: NSWindowController {
    let viewModel: MainViewModel
    let splitViewController: SplitViewController

    init(viewModel: MainViewModel) {
        self.viewModel = viewModel

        // Default size — compact utility window
        let windowWidth: CGFloat = 800
        let windowHeight: CGFloat = 560
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
        window.minSize = NSSize(width: 680, height: 480)
        window.setFrameAutosaveName("CmdTabMainWindow")

        let splitVC = SplitViewController(viewModel: viewModel)
        self.splitViewController = splitVC

        super.init(window: window)

        window.contentViewController = splitVC
        window.delegate = self

        // NSToolbar — automatic Liquid Glass on macOS 26
        let toolbar = MainWindowToolbar.create(viewModel: viewModel, windowController: self)
        window.toolbar = toolbar

        // Wire key events through MainWindow
        window.onKeyPress = { [weak self] event in
            guard let self else { return false }
            return self.handleKeyPress(event)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Key Handling
    // Moved from AppDelegate — all keyboard shortcuts live here now.
    private func handleKeyPress(_ event: NSEvent) -> Bool {
        let vm = viewModel

        // 1. Escape → Hide window
        if event.keyCode == 53 {
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
                if vm.isClipboardBannerVisible && !vm.detectedClipboardText.isEmpty {
                    vm.runPresetWithClipboard(index: num - 1)
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

        // 6. ⌘K → Clear conversation
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "k" {
            if !vm.isSettingsOpen && vm.selectedConversationId != nil {
                vm.clearConversation()
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
