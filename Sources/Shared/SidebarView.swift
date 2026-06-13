import SwiftUI

// MARK: - Sidebar
/// Flat, minimal sidebar (Codex-style): toolbar icons on the traffic-light line,
/// pill mode tabs, plain hover rows, Recents list, Settings pinned bottom-left.
/// No shadows, no card borders — native SF type and quiet grays only.
struct SidebarView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var showHelp = false
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            topToolbarRow
            #else
            // macOS: content starts below the opaque title bar; small
            // breathing room before the mode tabs.
            Color.clear.frame(height: 4)
            #endif

            // When settings is open, sidebar shows settings navigation.
            if viewModel.isSettingsOpen {
                settingsNavigation
            } else {
                primaryNavigation

                if viewModel.isSidebarSearchVisible && viewModel.sidebarMode == "chat" {
                    searchField
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                }

                contentPane
            }

            footerRow
        }
        .frame(maxHeight: .infinity)
        #if os(macOS)
        .background(Color.windowBackground)
        // Trailing hairline to separate from main content
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.hairline)
                .frame(width: 1)
        }
        .onChange(of: viewModel.isSidebarSearchVisible) { _, visible in
            if visible { searchFocused = true } else { searchText = "" }
        }
        #else
        .background(Color.windowBackground)
        #endif
    }

    // MARK: Settings navigation (replaces main sidebar content)
    private var settingsNavigation: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.system(size: AppFont.pt(11), weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            VStack(spacing: 1) {
                settingsNavItem("general", title: "General", icon: "gearshape")
                settingsNavItem("profile", title: "Profile", icon: "person.circle")
                settingsNavItem("personalization", title: "Personalization", icon: "slider.horizontal.3")
                settingsNavItem("cloudmodel", title: "Cloud Model", icon: "cloud")
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 0)
        }
    }

    private func settingsNavItem(_ value: String, title: String, icon: String) -> some View {
        let isSelected = viewModel.settingsTab == value
        return Button {
            viewModel.settingsTab = value
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: AppFont.pt(11)))
                    .foregroundColor(.secondary)
                    .frame(width: 14)
                Text(title)
                    .font(.system(size: AppFont.pt(12)))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? Color.primary.opacity(0.06) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: Primary navigation — segmented pill tabs
    @ViewBuilder
    private var primaryNavigation: some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                primaryNavigationTabs
            }
        } else {
            primaryNavigationTabs
        }
        #else
        primaryNavigationTabs
        #endif
    }

    private var primaryNavigationTabs: some View {
        HStack(spacing: 2) {
            tabButton(mode: "chat", icon: "bubble.left", label: "Chat")
            tabButton(mode: "actions", icon: "bolt", label: "Preset")
            #if os(macOS)
            tabButton(mode: "automations", icon: "clock", label: "Auto")
            #endif
        }
        .padding(4)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 10)
        .padding(.top, 8) // move tabs down a bit
        .padding(.bottom, 6)
        .animation(.easeOut(duration: 0.1), value: viewModel.sidebarMode)
    }

    private func tabButton(mode: String, icon: String, label: String) -> some View {
        let isSelected = viewModel.sidebarMode == mode
        return Button {
            withAnimation(.easeOut(duration: 0.1)) {
                viewModel.sidebarMode = mode
            }
            if mode != "chat" { viewModel.isSidebarSearchVisible = false }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: AppFont.pt(11)))
                if isSelected {
                    Text(label)
                        .font(.system(size: AppFont.pt(12)))
                        .lineLimit(1)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.9)), removal: .opacity))
                }
            }
            .foregroundColor(isSelected ? .primary : .secondary.opacity(0.7))
            .frame(maxWidth: .infinity, minHeight: 26)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.appBackground : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .iOSGlassControlSurface(cornerRadius: 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .focusable(false)
        .accessibilityLabel(label)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: AppFont.pt(13)))
                .foregroundColor(.secondary)
            TextField("Search chats", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: AppFont.pt(13)))
                .focused($searchFocused)
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(Color.primary.opacity(0.05))
        .clipShape(.rect(cornerRadius: 8))
        .padding(.horizontal, 10)
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

    // MARK: Top header — serif wordmark + profile avatar (Claude-style).
    private var topToolbarRow: some View {
        HStack(spacing: 10) {
            Text("MinhAgent")
                .font(.system(size: AppFont.pt(24), weight: .semibold, design: .serif))
                .foregroundColor(.primary)
            Spacer()
            AvatarCircle(initials: sidebarInitials, diameter: 34, color: Color.accentCoral)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    private var sidebarInitials: String {
        let parts = viewModel.userName.split(separator: " ").prefix(2)
        let initials = parts.compactMap { $0.first.map(String.init) }.joined()
        return initials.isEmpty ? "M" : initials.uppercased()
    }

    // MARK: Chat tab body
    /// Every row (New chat, history rows) shares the same metrics: 10pt outer
    /// gutter, 8pt inner horizontal padding, 6pt vertical, radius 8.
    private var chatBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            SidebarRow(icon: "plus", label: "New chat", keycap: "⌘T") {
                viewModel.startNewConversation(title: "New Chat")
            }
            .padding(.horizontal, 10)

            #if os(iOS)
            SidebarRow(icon: "magnifyingglass", label: "Search", compact: true) {
                viewModel.showSearchPalette()
                withAnimation {
                    viewModel.isSidebarVisible = false
                }
            }
            .padding(.horizontal, 10)
            #endif

            if !viewModel.conversations.isEmpty {
                // Batch delete bar when multi-selected
                if viewModel.isMultiSelect {
                    batchDeleteBar
                        .padding(.horizontal, 10)
                        .padding(.bottom, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(filteredGroupedConversations, id: \.0) { group, conversations in
                            Text(group)
                                .font(.system(size: AppFont.pt(10.5), weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.top, 12)
                                .padding(.bottom, 4)

                            ForEach(conversations) { conv in
                                ConversationRow(
                                    title: conv.title,
                                    isSelected: viewModel.selectedConversationIds.contains(conv.id),
                                    isInMultiSelect: viewModel.isMultiSelect,
                                    onSelect: { shift, cmd in
                                        viewModel.selectConversation(id: conv.id, shift: shift, cmd: cmd)
                                    },
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
                        .font(.system(size: AppFont.pt(22)))
                        .foregroundColor(.secondary.opacity(0.35))
                    Text("Your chats live here.\nThey stay local on this device.")
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

    /// Batch action bar shown when multiple conversations are selected.
    private var batchDeleteBar: some View {
        HStack(spacing: 8) {
            Text("\(viewModel.selectedConversationIds.count) selected")
                .font(.system(size: AppFont.pt(11)))
                .foregroundColor(.secondary)

            Spacer(minLength: 0)

            Button {
                viewModel.deleteSelectedConversations()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: AppFont.pt(10)))
                    Text("Delete")
                        .font(.system(size: AppFont.pt(11)))
                }
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(PlainButtonStyle())

            Button {
                viewModel.selectedConversationIds = []
                if let id = viewModel.selectedConversationId {
                    viewModel.selectedConversationIds = [id]
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: AppFont.pt(9)))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// History buckets in display order. Only non-empty groups are returned;
    /// conversations with no messages are hidden UNLESS they are the currently
    /// selected conversation (shown as a temporary "New chat" row).
    private var groupedConversations: [(String, [Conversation])] {
        let calendar = Calendar.current
        let now = Date()
        var buckets: [String: [Conversation]] = [:]
        for conv in viewModel.conversations {
            let isActive = conv.id == viewModel.selectedConversationId
            guard !conv.messages.isEmpty || isActive else { continue }
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
                key = "Last 7 days"
            } else if days < 30 {
                key = "Last 30 days"
            } else {
                key = "Older"
            }
            buckets[key, default: []].append(conv)
        }
        return ["Today", "Yesterday", "Last 7 days", "Last 30 days", "Older"]
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
                .font(.system(size: AppFont.pt(28)))
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

    // MARK: Footer — settings pinned bottom-left, help on the right.
    private var footerRow: some View {
        HStack(spacing: 8) {
            PlainIconButton(systemName: "gearshape", size: 12, help: "Settings") {
                viewModel.toggleSettings()
            }

            Spacer(minLength: 0)

            PlainIconButton(systemName: "questionmark.circle", size: 12, help: "How to use") {
                showHelp.toggle()
            }
            .popover(isPresented: $showHelp, arrowEdge: .top) {
                HelpGuide()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
                        .font(.system(size: AppFont.pt(14)))
                        .foregroundColor(.accentColor)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tip.title)
                            .font(.system(size: AppFont.pt(12.5), weight: .semibold))
                        Text(tip.detail)
                            .font(.system(size: AppFont.pt(11.5)))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(18)
        .frame(width: 300)
        .frame(maxHeight: 400)
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
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: AppFont.pt(11)))
                    .foregroundColor(.secondary)
                    .frame(width: 14)
                Text(label)
                    .font(.system(size: AppFont.pt(12)))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                if let keycap {
                    Text(keycap)
                        .font(.system(size: AppFont.pt(11), weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                        #if os(macOS)
                    .opacity(isHovered ? 1 : 0)
                        #else
                    .opacity(0)
                        #endif
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        #if os(macOS)
        .onHover { h in isHovered = h }
        #endif
    }

    private var rowBackground: Color {
        #if os(macOS)
        return isHovered ? Color.primary.opacity(0.04) : Color.clear
        #else
        return Color.clear
        #endif
    }
}

// MARK: - Actions Pane (prompt actions shown on clipboard detection)
/// Editable list of prompt actions: drag to reorder, rename inline,
/// pick an icon, add and delete. These are the chips offered in the
/// composer whenever clipboard content is detected.
private struct ActionsPane: View {
    @ObservedObject var viewModel: MainViewModel

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
                        isSelected: viewModel.selectedPresetIdForDetail == preset.id,
                        onSelect: {
                            viewModel.selectedPresetIdForDetail = preset.id
                            #if os(iOS)
                            withAnimation {
                                viewModel.isSidebarVisible = false
                            }
                            #endif
                        },
                        onDelete: { viewModel.deletePreset(id: preset.id) }
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 1, leading: 10, bottom: 1, trailing: 10))
                }
                .onMove { viewModel.movePresets(from: $0, to: $1) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            SidebarRow(icon: "plus", label: "Add action") {
                viewModel.addPreset()
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 4)
        }
    }
}

private struct ActionRow: View {
    let preset: Preset
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    #if os(macOS)
    @State private var isHovered = false
    #endif

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: preset.sfSymbol)
                    .font(.system(size: AppFont.pt(11)))
                    .foregroundColor(.secondary)
                    .frame(width: 14)
                Text(preset.name)
                    .font(.system(size: AppFont.pt(12)))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: AppFont.pt(9), weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        #if os(macOS)
        .onHover { h in isHovered = h }
        #endif
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var rowBackground: Color {
        if isSelected { return Color.primary.opacity(0.06) }
        #if os(macOS)
        return isHovered ? Color.primary.opacity(0.04) : Color.clear
        #else
        return Color.clear
        #endif
    }
}

// MARK: - Conversation Row
/// Click selects; clicking the already-selected row (or Rename in the context
/// menu) starts inline renaming. Shift/Cmd click for multi-select on macOS.
/// Enter commits, Esc cancels.
private struct ConversationRow: View {
    let title: String
    let isSelected: Bool
    let isInMultiSelect: Bool
    let onSelect: (Bool, Bool) -> Void  // (shift, cmd)
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
                    .background(Color.primary.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 8))
            } else {
                Button(action: {
                    #if os(macOS)
                    isSelected && !isInMultiSelect ? beginEditing() : onSelect(false, false)
                    #else
                    onSelect(false, false)
                    #endif
                }) {
                    HStack(spacing: 6) {
                        #if os(macOS)
                        if isInMultiSelect {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: AppFont.pt(10)))
                                .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.4))
                        }
                        #endif
                        Text(title)
                            .font(.system(size: AppFont.pt(12)))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    #if os(macOS)
                    .padding(.trailing, 22)
                    #endif
                    .background(rowBackground)
                    .clipShape(.rect(cornerRadius: 8))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                #if os(macOS)
                .overlay(alignment: .trailing) {
                    if isHovered || isSelected {
                        rowMenu
                            .padding(.trailing, 4)
                            .transition(.opacity)
                    }
                }
                .onHover { h in isHovered = h }
                .onTapGesture {
                    // handled by Button
                }
                .simultaneousGesture(
                    TapGesture().modifiers(.shift).onEnded { _ in
                        onSelect(true, false)
                    }
                )
                .simultaneousGesture(
                    TapGesture().modifiers(.command).onEnded { _ in
                        onSelect(false, true)
                    }
                )
                #endif
                .contextMenu {
                    menuItems
                }
            }
        }
    }

    @ViewBuilder
    private var menuItems: some View {
        Button(action: beginEditing) {
            Label("Rename", systemImage: "pencil")
        }
        .accessibilityHint("Rename this conversation")
        Button(role: .destructive, action: onDelete) {
            Label("Delete", systemImage: "trash")
        }
        .accessibilityHint("Delete this conversation")
    }

    #if os(macOS)
    private var rowMenu: some View {
        Menu {
            menuItems
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: AppFont.pt(11), weight: .semibold))
                .foregroundColor(.secondary.opacity(0.75))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Conversation options")
    }
    #endif

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
        if isSelected { return Color.primary.opacity(0.06) }
        #if os(macOS)
        return isHovered ? Color.primary.opacity(0.04) : Color.clear
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
