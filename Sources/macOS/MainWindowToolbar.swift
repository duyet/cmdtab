import AppKit
import SwiftUI

@MainActor
final class MainWindowToolbar: NSObject, NSToolbarDelegate {
    private let viewModel: MainViewModel
    private weak var windowController: WindowController?

    private static let sidebarToggleID = NSToolbarItem.Identifier("sidebarToggle")
    private static let newChatID = NSToolbarItem.Identifier("newChat")

    static func create(viewModel: MainViewModel, windowController: WindowController) -> NSToolbar {
        let toolbar = NSToolbar(identifier: "CmdTabMainWindowToolbar")
        let delegate = MainWindowToolbar(viewModel: viewModel, windowController: windowController)
        toolbar.delegate = delegate
        toolbar.displayMode = .iconOnly
        toolbar.showsBaselineSeparator = false
        // Retain delegate strongly (toolbar's delegate is weak)
        objc_setAssociatedObject(toolbar, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        return toolbar
    }

    private init(viewModel: MainViewModel, windowController: WindowController) {
        self.viewModel = viewModel
        self.windowController = windowController
    }

    // MARK: - NSToolbarDelegate

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem?
    {
        switch itemIdentifier {
        case Self.sidebarToggleID:
            return makeSidebarToggle()
        case Self.newChatID:
            return makeNewChat()
        case .flexibleSpace:
            return NSToolbarItem(itemIdentifier: .flexibleSpace)
        default:
            return nil
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.sidebarToggleID, Self.newChatID, .flexibleSpace]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    // MARK: - Item Builders

    private func makeSidebarToggle() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: Self.sidebarToggleID)
        item.label = "Toggle Sidebar"
        item.paletteLabel = "Toggle Sidebar"
        item.toolTip = "Toggle Sidebar (⌘B)"
        item.image = NSImage(systemSymbolName: "sidebar.left",
                             accessibilityDescription: "Toggle Sidebar")
        item.target = self
        item.action = #selector(toggleSidebar)
        item.isBordered = true
        return item
    }

    private func makeNewChat() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: Self.newChatID)
        item.label = "New Chat"
        item.paletteLabel = "New Chat"
        item.toolTip = "New Chat (⌘T)"
        item.image = NSImage(systemSymbolName: "square.and.pencil",
                             accessibilityDescription: "New Chat")
        item.target = self
        item.action = #selector(newChat)
        item.isBordered = true
        return item
    }

    // MARK: - Actions

    @objc private func toggleSidebar() {
        if !viewModel.isSettingsOpen {
            viewModel.isSidebarVisible.toggle()
        }
    }

    @objc private func newChat() {
        if !viewModel.isSettingsOpen {
            viewModel.startNewConversation(title: "New Chat")
        }
    }
}
