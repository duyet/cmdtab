import SwiftUI

// MARK: - Sidebar
/// Flat, minimal sidebar (Codex-style): toolbar icons on the traffic-light line,
/// pill mode tabs, plain hover rows, Recents list, Settings pinned bottom-left.
/// No shadows, no card borders — native SF type and quiet grays only.
struct SidebarView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var showHelp = false
    @State private var isSearchVisible = false
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            topToolbarRow
            #endif

            primaryNavigation
                #if os(macOS)
            .padding(.top, 12)
                #endif

            if isSearchVisible && viewModel.sidebarMode == "chat" {
                searchField
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }

            contentPane

            footerRow
        }
        .frame(maxHeight: .infinity)
        .background(Color.windowBackground)
        #if os(iOS)
        // Swipe left to dismiss sidebar on iOS
        .highPriorityGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width < -50 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.isSidebarVisible = false
                        }
                    }
                }
        )
        #endif
    }

    // MARK: Primary navigation
    private var primaryNavigation: some View {
        VStack(spacing: 4) {
            SidebarNavRow(icon: "square.and.pencil", label: "New chat") {
                viewModel.startNewConversation(title: "New Chat")
            }

            SidebarNavRow(
                icon: "magnifyingglass",
                label: "Search",
                isSelected: isSearchVisible && viewModel.sidebarMode == "chat"
            ) {
                viewModel.sidebarMode = "chat"
                isSearchVisible.toggle()
            }

            SidebarNavRow(
                icon: "puzzlepiece.extension",
                label: "Plugins",
                isSelected: viewModel.sidebarMode == "actions"
            ) {
                viewModel.sidebarMode = "actions"
                isSearchVisible = false
            }

            SidebarNavRow(
                icon: "clock",
                label: "Automations",
                isSelected: viewModel.sidebarMode == "automations"
            ) {
                viewModel.sidebarMode = "automations"
                isSearchVisible = false
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 12)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            TextField("Search chats", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 14))
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var contentPane: some View {
        switch viewModel.sidebarMode {
        case "actions":
            ActionsPane(viewModel: viewModel)
        case "automations":
            placeholderPane(
                icon: "clock",
                title: "Automations",
                description: "Scheduled actions will appear here."
            )
        default:
            chatBody
        }
    }

    // MARK: Top toolbar — centered on the traffic-light line (~18pt from top).
    private var topToolbarRow: some View {
        HStack(spacing: 6) {
            #if os(macOS)
            Spacer().frame(width: 64)
            #endif

            PlainIconButton(systemName: "sidebar.left", size: 13, help: "Toggle Sidebar") {
                withAnimation { viewModel.isSidebarVisible.toggle() }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .padding(.bottom, 10)
    }

    // MARK: Chat tab body
    private var chatBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            SidebarRow(icon: "square.and.pencil", label: "New chat", keycap: "⌘T") {
                viewModel.startNewConversation(title: "New Chat")
            }

            if !viewModel.conversations.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(filteredGroupedConversations, id: \.0) { group, conversations in
                            HStack(spacing: 8) {
                                Image(systemName: "folder")
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary.opacity(0.82))
                                    .frame(width: 18)
                                Text(group)
                                    .font(.system(size: 15.5))
                                    .foregroundColor(.primary)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                                .padding(.top, 16)
                                .padding(.bottom, 6)

                            ForEach(conversations) { conv in
                                ConversationRow(
                                    title: conv.title,
                                    isSelected: viewModel.selectedConversationId == conv.id,
                                    onSelect: { viewModel.selectConversation(id: conv.id) },
                                    onRename: { viewModel.renameConversation(id: conv.id, to: $0) },
                                    onDelete: { viewModel.deleteConversation(id: conv.id) }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary.opacity(0.35))
                    Text("Your chats live here.\nThey stay in memory and never touch disk.")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 0)
    }

    /// History buckets in display order. Only non-empty groups are returned;
    /// conversations stay in their existing (most-recent-first) order.
    private var groupedConversations: [(String, [Conversation])] {
        let calendar = Calendar.current
        let now = Date()
        var buckets: [String: [Conversation]] = [:]
        for conv in viewModel.conversations {
            let key: String
            let days =
                calendar.dateComponents(
                    [.day], from: calendar.startOfDay(for: conv.timestamp), to: calendar.startOfDay(for: now)
                ).day ?? 0
            if calendar.isDateInToday(conv.timestamp) {
                key = "Today"
            } else if calendar.isDateInYesterday(conv.timestamp) {
                key = "Yesterday"
            } else if days < 7 {
                key = "Previous 7 Days"
            } else if days < 30 {
                key = "Previous 30 Days"
            } else {
                key = "Older"
            }
            buckets[key, default: []].append(conv)
        }
        return ["Today", "Yesterday", "Previous 7 Days", "Previous 30 Days", "Older"]
            .compactMap { key in buckets[key].map { (key, $0) } }
    }

    private var filteredGroupedConversations: [(String, [Conversation])] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return groupedConversations }
        return groupedConversations.compactMap { group, conversations in
            let matches = conversations.filter { conversation in
                conversation.title.localizedCaseInsensitiveContains(query)
            }
            return matches.isEmpty ? nil : (group, matches)
        }
    }

    // MARK: Placeholder pane for stubbed tabs
    private func placeholderPane(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.45))
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Footer — Settings + Help bottom-left.
    private var footerRow: some View {
        HStack(spacing: 4) {
            SidebarNavRow(icon: "gearshape", label: "Settings") {
                viewModel.toggleSettings()
            }

            PlainIconButton(systemName: "questionmark.circle", size: 14, help: "How to use") {
                showHelp.toggle()
            }
            .popover(isPresented: $showHelp, arrowEdge: .top) {
                HelpGuide()
            }

        }
        .padding(.leading, 10)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
    }
}

// MARK: - Sidebar Navigation Row
private struct SidebarNavRow: View {
    let icon: String
    let label: String
    var badge: String? = nil
    var isSelected: Bool = false
    let action: () -> Void
    #if os(macOS)
    @State private var isHovered = false
    #endif

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.primary.opacity(0.84))
                    .frame(width: 20)

                Text(label)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let badge {
                    Text(badge)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.75))
                        .frame(minWidth: 26, minHeight: 24)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .frame(height: 36)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .background(rowBackground)
            .cornerRadius(9)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
        #if os(macOS)
        .onHover { isHovered = $0 }
        #endif
    }

    private var rowBackground: Color {
        if isSelected { return Color.primary.opacity(0.08) }
        #if os(macOS)
        return isHovered ? Color.primary.opacity(0.05) : Color.clear
        #else
        return Color.clear
        #endif
    }
}

// MARK: - Help Guide
/// Concise getting-started guide. Plain native type — teaches the four things
/// that make this app click: clipboard actions, asking, modes, shortcuts.
private struct HelpGuide: View {
    private struct Tip: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private let tips: [Tip] = [
        Tip(
            icon: "doc.on.clipboard",
            title: "Copy anything",
            detail: "Copy text in any app and MinhAgent offers instant Quick Actions for it."),
        Tip(
            icon: "text.bubble",
            title: "Just ask",
            detail: "Type a question in the box and press Return. Replies stream in live."),
        Tip(
            icon: "cpu",
            title: "Cloud or on-device",
            detail:
                "Switch between a cloud model and Apple's on-device model with the mode menu."),
        Tip(
            icon: "command",
            title: "Shortcuts",
            detail: "⌘T new chat · ⌘B toggle sidebar · ⌥-Space to summon the window."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How to use MinhAgent")
                .font(.headline)

            ForEach(tips) { tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: tip.icon)
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tip.title)
                            .font(.system(size: 12.5, weight: .semibold))
                        Text(tip.detail)
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(18)
        .frame(width: 300)
    }
}

// MARK: - Sidebar Row (plain icon + label, hover highlight on macOS)
private struct SidebarRow: View {
    let icon: String
    let label: String
    var compact: Bool = false
    var keycap: String? = nil
    let action: () -> Void
    #if os(macOS)
    @State private var isHovered = false
    #endif

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 15.5))
                    .foregroundColor(.primary)
                Spacer(minLength: 0)
                if let keycap {
                    Text(keycap)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.8))
                        #if os(macOS)
                    .opacity(isHovered ? 1 : 0)
                        #else
                    .opacity(0)
                        #endif
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, compact ? 6 : 8)
            #if os(macOS)
            .background(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            #else
            .background(Color.clear)
            #endif
            .cornerRadius(7)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        #if os(macOS)
        .onHover { h in isHovered = h }
        #endif
        .padding(.horizontal, compact ? 0 : 10)
    }
}

// MARK: - Actions Pane (prompt actions shown on clipboard detection)
/// Editable list of prompt actions: drag to reorder, rename inline,
/// pick an icon, add and delete. These are the chips offered in the
/// composer whenever clipboard content is detected.
private struct ActionsPane: View {
    @ObservedObject var viewModel: MainViewModel

    private static let iconChoices = [
        "sparkles", "bolt", "list.bullet", "globe", "lightbulb",
        "textformat.abc", "checklist", "pencil.and.scribble",
        "chevron.left.forwardslash.chevron.right", "doc.text",
        "envelope", "quote.bubble", "tag", "wand.and.rays",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Shown when clipboard text is detected. Drag to reorder.")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.horizontal, 22)
                .padding(.bottom, 8)
                .fixedSize(horizontal: false, vertical: true)

            List {
                ForEach(viewModel.presets) { preset in
                    ActionRow(
                        preset: preset,
                        iconChoices: Self.iconChoices,
                        onRename: { viewModel.renamePreset(id: preset.id, to: $0) },
                        onIcon: { viewModel.setPresetIcon(id: preset.id, sfSymbol: $0) },
                        onDelete: { viewModel.deletePreset(id: preset.id) }
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onMove { viewModel.movePresets(from: $0, to: $1) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            SidebarRow(icon: "plus", label: "Add action") {
                viewModel.addPreset()
            }
            .padding(.bottom, 4)
        }
    }
}

private struct ActionRow: View {
    let preset: Preset
    let iconChoices: [String]
    let onRename: (String) -> Void
    let onIcon: (String) -> Void
    let onDelete: () -> Void
    @State private var name: String = ""

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(iconChoices, id: \.self) { symbol in
                    Button {
                        onIcon(symbol)
                    } label: {
                        Label(symbol, systemImage: symbol)
                    }
                }
            } label: {
                Image(systemName: preset.sfSymbol)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 22)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            TextField("Action name", text: $name)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.body)
                .onSubmit { onRename(name) }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .onAppear { name = preset.name }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Conversation Row
/// Click selects; clicking the already-selected row (or Rename in the context
/// menu) starts inline renaming. Enter commits, Esc cancels.
private struct ConversationRow: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void
    #if os(macOS)
    @State private var isHovered = false
    #endif
    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        Group {
            if isEditing {
                renameField
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.08))
                    .cornerRadius(7)
            } else {
                Button(action: {
                    #if os(macOS)
                    isSelected ? beginEditing() : onSelect()
                    #else
                    onSelect()
                    #endif
                }) {
                    Text(title)
                        .font(.system(size: 15.5))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(rowBackground)
                        .cornerRadius(7)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                #if os(macOS)
                .onHover { h in isHovered = h }
                #endif
                .contextMenu {
                    Button(action: beginEditing) {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var renameField: some View {
        let field = TextField("Conversation name", text: $draft)
            .textFieldStyle(PlainTextFieldStyle())
            .font(.body)
            .focused($fieldFocused)
            .onSubmit { commit() }
            .onChange(of: fieldFocused) { _, focused in
                if !focused { commit() }
            }
        #if os(macOS)
        return field.onExitCommand { isEditing = false }
        #else
        return field
        #endif
    }

    private var rowBackground: Color {
        if isSelected { return Color.primary.opacity(0.08) }
        #if os(macOS)
        return isHovered ? Color.primary.opacity(0.045) : Color.clear
        #else
        return Color.clear
        #endif
    }

    private func beginEditing() {
        draft = title
        isEditing = true
        fieldFocused = true
    }

    private func commit() {
        if isEditing {
            isEditing = false
            onRename(draft)
        }
    }
}
