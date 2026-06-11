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
            #endif

            // When settings is open, sidebar shows settings navigation.
            if viewModel.isSettingsOpen {
                settingsNavigation
                    #if os(macOS)
                    .padding(.top, 12)
                    #endif
            } else {
                primaryNavigation
                    #if os(macOS)
                .padding(.top, 12)
                    #endif

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
        .background(
            Color.windowBackground.ignoresSafeArea(.container, edges: .top)
        )
        .overlay(alignment: .trailing) {
            Color.hairline
                .frame(width: 1)
                .ignoresSafeArea(.container, edges: .vertical)
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
    private var primaryNavigation: some View {
        HStack(spacing: 2) {
            tabButton(mode: "chat", icon: "bubble.left", label: "Chat")
            tabButton(mode: "actions", icon: "bolt", label: "Preset")
            tabButton(mode: "automations", icon: "gearshape", label: "Auto")
        }
        .padding(3)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    private func tabButton(mode: String, icon: String, label: String) -> some View {
        let isSelected = viewModel.sidebarMode == mode
        return Button {
            viewModel.sidebarMode = mode
            if mode != "chat" { viewModel.isSidebarSearchVisible = false }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: AppFont.pt(10)))
                if isSelected {
                    Text(label)
                        .font(.system(size: AppFont.pt(11)))
                        .lineLimit(1)
                }
            }
            .foregroundColor(isSelected ? .primary : .secondary.opacity(0.7))
            .frame(maxWidth: isSelected ? .infinity : nil)
            .padding(.horizontal, isSelected ? 8 : 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.appBackground : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.hairline : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
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
        .cornerRadius(8)
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
                viewModel.isSidebarSearchVisible.toggle()
            }
            .padding(.horizontal, 10)
            #endif

            if !viewModel.conversations.isEmpty {
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
                        .font(.system(size: AppFont.pt(22)))
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
                        onDelete: { viewModel.deletePreset(id: preset.id) },
                        onPromptEdit: { viewModel.setPresetPrompt(id: preset.id, prompt: $0) }
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
    let onPromptEdit: (String) -> Void
    @State private var name: String = ""
    @State private var prompt: String = ""
    @State private var isExpanded: Bool = false
    @FocusState private var nameFocused: Bool
    @FocusState private var promptFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row: icon + name + chevron
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
                        .font(.system(size: AppFont.pt(12)))
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()

                TextField("Action name", text: $name)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.body)
                    .focused($nameFocused)
                    .onSubmit { onRename(name) }
                    .onChange(of: nameFocused) { _, focused in
                        if !focused { onRename(name) }
                    }

                Spacer(minLength: 0)

                // Chevron to indicate expandability
                Image(systemName: "chevron.right")
                    .font(.system(size: AppFont.pt(9), weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            }

            // Expanded: prompt editor
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PROMPT")
                        .font(.system(size: AppFont.pt(9), weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.7))

                    TextEditor(text: $prompt)
                        .font(.system(size: AppFont.pt(11.5)))
                        .frame(height: 80)
                        .padding(6)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.hairline.opacity(0.5), lineWidth: 1)
                        )
                        .focused($promptFocused)
                        .onChange(of: promptFocused) { _, focused in
                            if !focused { onPromptEdit(prompt) }
                        }
                        .onChange(of: isExpanded) { _, expanded in
                            if expanded { promptFocused = true }
                        }
                }
                .padding(.leading, 30)
                .padding(.top, 6)
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            name = preset.name
            prompt = preset.systemPrompt
        }
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
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(8)
            } else {
                Button(action: {
                    #if os(macOS)
                    isSelected ? beginEditing() : onSelect()
                    #else
                    onSelect()
                    #endif
                }) {
                    Text(title)
                        .font(.system(size: AppFont.pt(12)))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(rowBackground)
                        .cornerRadius(8)
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
