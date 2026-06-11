import AppKit
import SwiftUI

@MainActor
final class MainWindowToolbar: NSObject, NSToolbarDelegate {
    private let viewModel: MainViewModel
    private weak var windowController: WindowController?

    private static let sidebarToggleID = NSToolbarItem.Identifier("sidebarToggle")
    private static let searchID = NSToolbarItem.Identifier("searchChats")

    static func create(viewModel: MainViewModel, windowController: WindowController) -> NSToolbar {
        let toolbar = NSToolbar(identifier: "MinhAgentMainWindowToolbar")
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

    func toolbar(
        _ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case Self.sidebarToggleID:
            return makeSidebarToggle()
        case Self.searchID:
            return makeSearch()
        case .flexibleSpace:
            return NSToolbarItem(itemIdentifier: .flexibleSpace)
        default:
            return nil
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.sidebarToggleID, Self.searchID, .flexibleSpace]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    // MARK: - Item Builders

    /// One shared symbol configuration so every toolbar glyph renders at the
    /// exact same size regardless of the symbol's intrinsic proportions.
    private static let iconConfiguration = NSImage.SymbolConfiguration(
        pointSize: 13, weight: .regular)

    private static func icon(_ name: String, description: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: description)?
            .withSymbolConfiguration(iconConfiguration)
    }

    private func makeSidebarToggle() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: Self.sidebarToggleID)
        item.label = "Toggle Sidebar"
        item.paletteLabel = "Toggle Sidebar"
        item.toolTip = "Toggle Sidebar (⌘B)"
        item.image = Self.icon("sidebar.left", description: "Toggle Sidebar")
        item.target = self
        item.action = #selector(toggleSidebar)
        // Plain glyph — no bordered (glass) capsule behind toolbar icons.
        item.isBordered = false
        return item
    }

    private func makeSearch() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: Self.searchID)
        item.label = "Search Chats"
        item.paletteLabel = "Search Chats"
        item.toolTip = "Search Chats"
        item.image = Self.icon("magnifyingglass", description: "Search Chats")
        item.target = self
        item.action = #selector(searchChats)
        item.isBordered = false
        return item
    }

    // MARK: - Actions

    @objc private func toggleSidebar() {
        if !viewModel.isSettingsOpen {
            viewModel.isSidebarVisible.toggle()
        }
    }

    @objc private func searchChats() {
        if !viewModel.isSettingsOpen {
            viewModel.toggleSidebarSearch()
        }
    }
}
