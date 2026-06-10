import SwiftUI

// MARK: - Sidebar
/// Flat, minimal sidebar (Codex-style): toolbar icons on the traffic-light line,
/// pill mode tabs, plain hover rows, Recents list, Settings pinned bottom-left.
/// No shadows, no card borders — native SF type and quiet grays only.
struct SidebarView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: 0) {
            topToolbarRow

            PillTabBar(
                items: [
                    PillTabBar.Item(value: "chat", label: "Chat", icon: "bubble.left.and.bubble.right"),
                    PillTabBar.Item(value: "actions", label: "Actions", icon: "bolt"),
                    PillTabBar.Item(value: "automations", label: "Automations", icon: "wand.and.stars"),
                ],
                selection: $viewModel.sidebarMode,
                track: true
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            switch viewModel.sidebarMode {
            case "actions":
                ActionsPane(viewModel: viewModel)
            case "automations":
                placeholderPane(
                    icon: "wand.and.stars",
                    title: "Automations",
                    description: "Run actions automatically on rules and schedules."
                )
            default:
                chatBody
            }

            footerRow
        }
        .frame(maxHeight: .infinity)
        .sidebarSurface()
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

    // MARK: Top toolbar — centered on the traffic-light line (~18pt from top).
    private var topToolbarRow: some View {
        HStack(spacing: 6) {
            #if os(macOS)
            Spacer().frame(width: 64)
            #endif

            PlainIconButton(systemName: "sidebar.left", size: 13, help: "Toggle Sidebar") {
                withAnimation { viewModel.isSidebarVisible.toggle() }
            }

            PlainIconButton(systemName: "magnifyingglass", size: 13, help: "Search") {}

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
                        ForEach(groupedConversations, id: \.0) { group, conversations in
                            Text(group)
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.8))
                                .padding(.horizontal, 12)
                                .padding(.top, 16)
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
            let days = calendar.dateComponents(
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

    // MARK: Footer — Settings bottom-left; download icon only when an update exists.
    private var footerRow: some View {
        HStack(spacing: 4) {
            PlainIconButton(systemName: "gearshape", size: 14, help: "Settings") {
                viewModel.toggleSettings()
            }

            if viewModel.isUpdateAvailable {
                PlainIconButton(systemName: "arrow.down.circle", size: 13, help: "Update available") {}
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
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
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                Text(label)
                    .font(.body)
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
            .padding(.vertical, compact ? 6 : 7)
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
                        .font(.body)
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
