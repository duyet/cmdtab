import SwiftUI

/// Floating command-palette search overlay (Spotlight / Cmd+K style).
/// Centered on screen with a dimmed backdrop, filters conversations by title,
/// and navigates on selection.
struct SearchPaletteView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var searchText = ""
    @State private var selectedConversationId: UUID?
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { viewModel.hideSearchPalette() }

            // Palette card
            VStack(spacing: 0) {
                // Search field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: AppFont.pt(14)))
                        .foregroundColor(.secondary)
                    TextField("Search conversations…", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: AppFont.pt(14)))
                        .focused($searchFocused)
                        .onSubmit(selectFirstResult)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                // Results
                if filteredGroups.isEmpty {
                    VStack(spacing: 8) {
                        Spacer().frame(height: 8)
                        Text(searchText.isEmpty ? "Start typing to search…" : "No results")
                            .font(.system(size: AppFont.pt(13)))
                            .foregroundColor(.secondary)
                        Spacer().frame(height: 8)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredGroups, id: \.0) { group, conversations in
                                // Group header
                                Text(group)
                                    .font(.system(size: AppFont.pt(11), weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)

                                ForEach(conversations) { conv in
                                    paletteRow(conv)
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .frame(maxHeight: 320)
                }
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 24)
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(UIColor.secondarySystemBackground))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.2), radius: 24, y: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            searchFocused = true
            selectFirstIfNeeded()
        }
        .onChange(of: searchText) { _, _ in selectFirstResultId() }
        #if os(macOS)
        .onExitCommand { viewModel.hideSearchPalette() }
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        #endif
    }

    // MARK: - Row

    @ViewBuilder
    private func paletteRow(_ conv: Conversation) -> some View {
        let isSelected = conv.id == viewModel.selectedConversationId
        let isKeyboardSelected = conv.id == selectedConversationId
        Button {
            viewModel.selectedConversationId = conv.id
            viewModel.hideSearchPalette()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left")
                    .font(.system(size: AppFont.pt(11)))
                    .foregroundColor(.secondary.opacity(0.6))
                    .frame(width: 16)
                Text(conv.title)
                    .font(.system(size: AppFont.pt(13)))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: AppFont.pt(10)))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isKeyboardSelected ? Color.primary.opacity(0.07) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityHint(isKeyboardSelected ? "Keyboard selected" : "")
        .accessibilityAddTraits(isKeyboardSelected ? .isSelected : [])
    }

    // MARK: - Filtering

    private var filteredGroups: [(String, [Conversation])] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let groups = groupedConversations
        guard !query.isEmpty else { return groups }
        return groups.compactMap { group, conversations in
            let matches = conversations.filter {
                $0.title.localizedCaseInsensitiveContains(query)
            }
            return matches.isEmpty ? nil : (group, matches)
        }
    }

    private var flatResults: [Conversation] {
        filteredGroups.flatMap { $0.1 }
    }

    /// Reuses the same time-bucketing as SidebarView.
    private var groupedConversations: [(String, [Conversation])] {
        let calendar = Calendar.current
        let now = Date()
        var buckets: [String: [Conversation]] = [:]
        for conv in viewModel.conversations {
            let isActive = conv.id == viewModel.selectedConversationId
            guard !conv.messages.isEmpty || isActive else { continue }
            let days =
                calendar.dateComponents(
                    [.day], from: calendar.startOfDay(for: conv.timestamp), to: calendar.startOfDay(for: now)
                ).day ?? 0
            let key: String
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

    // MARK: - Actions

    private func selectFirstResult() {
        guard let selected = flatResults.first(where: { $0.id == selectedConversationId }) ?? flatResults.first else {
            return
        }
        viewModel.selectedConversationId = selected.id
        viewModel.hideSearchPalette()
    }

    private func selectFirstIfNeeded() {
        if selectedConversationId == nil {
            selectFirstResultId()
        }
    }

    private func selectFirstResultId() {
        selectedConversationId = flatResults.first?.id
    }

    private func moveSelection(by delta: Int) {
        let results = flatResults
        guard !results.isEmpty else {
            selectedConversationId = nil
            return
        }
        let currentIndex = results.firstIndex { $0.id == selectedConversationId } ?? 0
        let nextIndex = min(max(currentIndex + delta, 0), results.count - 1)
        selectedConversationId = results[nextIndex].id
    }
}
