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
        .background(Color.windowBackground)
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
                Text("Recents")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 6)

                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(viewModel.conversations) { conv in
                            ConversationRow(
                                title: conv.title,
                                isSelected: viewModel.selectedConversationId == conv.id,
                                onSelect: { viewModel.selectConversation(id: conv.id) },
                                onDelete: { viewModel.deleteConversation(id: conv.id) }
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 0)
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
            SidebarRow(icon: "gearshape", label: "Settings", compact: true) {
                viewModel.toggleSettings()
            }
            .frame(width: 110)

            if viewModel.isUpdateAvailable {
                PlainIconButton(systemName: "arrow.down.circle", size: 13, help: "Update available") {}
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

// MARK: - Sidebar Row (plain icon + label, hover highlight)
private struct SidebarRow: View {
    let icon: String
    let label: String
    var compact: Bool = false
    var keycap: String? = nil
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
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
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, compact ? 6 : 7)
            .background(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            .cornerRadius(7)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { h in isHovered = h }
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
private struct ConversationRow: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? Color.primary.opacity(0.08)
                        : (isHovered ? Color.primary.opacity(0.045) : Color.clear)
                )
                .cornerRadius(7)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { h in isHovered = h }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
