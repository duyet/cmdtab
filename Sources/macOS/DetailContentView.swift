import SwiftUI

/// macOS-only right pane: chat viewport, composer, settings inspector.
/// Hosted inside NSSplitViewController's detail item via NSHostingController.
struct DetailContentView: View {
    @ObservedObject var viewModel: MainViewModel

    /// Floating sidebar shown when the docked sidebar is hidden and the
    /// pointer rests on the window's left edge (Claude-app style).
    @State private var isHoverSidebarVisible = false

    var body: some View {
        // Settings presents as a window-modal sheet — slides over the chat
        // without replacing the main window content.
        ZStack(alignment: .topLeading) {
            if viewModel.isSettingsOpen {
                // Settings content in the detail pane; navigation lives in
                // the main sidebar (which swapped to settings nav items).
                SettingsView(viewModel: viewModel).settingsContentPane
                    .transition(.opacity)
            } else {
                mainContentPane
            }

            if !viewModel.isSidebarVisible && !viewModel.isSettingsOpen {
                // Invisible 10pt strip along the left edge that summons the
                // floating sidebar on hover.
                Color.clear
                    .frame(width: 10)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering {
                            withAnimation(.easeOut(duration: 0.18)) {
                                isHoverSidebarVisible = true
                            }
                        }
                    }

                if isHoverSidebarVisible {
                    // SidebarView styles itself as a floating card; only add
                    // the heavier hover shadow here.
                    SidebarView(viewModel: viewModel)
                        .frame(width: 280)
                        .shadow(color: .black.opacity(0.16), radius: 18, x: 4, y: 6)
                        .padding(.vertical, 2)
                        .onHover { hovering in
                            if !hovering {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    isHoverSidebarVisible = false
                                }
                            }
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
        }
        .onChange(of: viewModel.isSidebarVisible) { _, _ in
            isHoverSidebarVisible = false
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.isSettingsOpen)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.creamBackground)
        .tint(.primary)
        .textSelection(.enabled)
    }

    // MARK: - Main Content Pane
    private var mainContentPane: some View {
        VStack(spacing: 0) {
            if hasMessages {
                chatHistoryViewport
            } else {
                emptyLandingView
            }

            ComposerView(viewModel: viewModel)

        }
    }

    private var hasMessages: Bool {
        if let activeId = viewModel.selectedConversationId,
            let activeConv = viewModel.conversations.first(where: { $0.id == activeId })
        {
            return !activeConv.messages.isEmpty
        }
        return false
    }

    // MARK: - Chat History Viewport
    private var chatHistoryViewport: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let activeId = viewModel.selectedConversationId,
                        let activeConv = viewModel.conversations.first(where: { $0.id == activeId })
                    {
                        ForEach(activeConv.messages) { message in
                            MessageRow(message: message, viewModel: viewModel)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 16)
                // Centered reading column — keeps lines comfortable on wide windows
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .onStreamingChange(of: viewModel.isStreaming) { _ in
                scrollToLast(proxy)
            }
            .onConversationsChange(of: viewModel.conversations) {
                scrollToLast(proxy)
            }
        }
    }

    private func scrollToLast(_ proxy: ScrollViewProxy) {
        if let activeId = viewModel.selectedConversationId,
            let activeConv = viewModel.conversations.first(where: { $0.id == activeId }),
            let lastMsg = activeConv.messages.last
        {
            withAnimation {
                proxy.scrollTo(lastMsg.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Landing View
    private var welcomeHeadline: String {
        Greeting.headline(
            userName: viewModel.userName,
            hour: Calendar.current.component(.hour, from: Date()))
    }

    private var emptyLandingView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Inline logo + greeting, left-aligned at the top
            // ("What's up next, Duyet?" layout in Claude desktop).
            HStack(spacing: 12) {
                Image(systemName: "command")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.accentCoral)
                Text(welcomeHeadline)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Text("Copy something to get quick actions, or start with one of these.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(.top, 8)

            // Session summary — quiet stats card (Claude desktop style).
            summaryCard
                .padding(.top, 28)

            // Suggestion pills are the user's Quick Action presets.
            HStack(spacing: 8) {
                ForEach(Array(viewModel.presets.prefix(4).enumerated()), id: \.offset) { index, preset in
                    StarterCard(icon: preset.sfSymbol, title: preset.name) {
                        viewModel.pickPreset(index: index)
                    }
                }
            }
            .padding(.top, 16)

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Summary card — lifetime usage stats + activity calendar
    // (Claude desktop "Overview" style). Backed by per-day counters in
    // UsageStats; only numbers persist, never conversation content.

    private var usageTotals: (sessions: Int, messages: Int, tokens: Int, activeDays: Int) {
        var s = 0, m = 0, t = 0, a = 0
        for day in viewModel.usageByDay.values {
            s += day.sessions
            m += day.messages
            t += day.tokens
            if day.messages > 0 || day.sessions > 0 { a += 1 }
        }
        return (s, m, t, a)
    }

    private func compactNumber(_ n: Int) -> String {
        switch n {
        case 1_000_000...: return String(format: "%.1fM", Double(n) / 1_000_000)
        case 1_000...: return String(format: "%.1fK", Double(n) / 1_000)
        default: return "\(n)"
        }
    }

    private var summaryCard: some View {
        let totals = usageTotals
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 0) {
                summaryStat(value: compactNumber(totals.sessions), label: "Sessions")
                summaryDivider
                summaryStat(value: compactNumber(totals.messages), label: "Messages")
                summaryDivider
                summaryStat(value: compactNumber(totals.tokens), label: "Total tokens")
                summaryDivider
                summaryStat(value: "\(totals.activeDays)", label: "Active days")
            }

            ActivityCalendarView(usageByDay: viewModel.usageByDay)
        }
        .padding(14)
        .frame(maxWidth: 560, alignment: .leading)
        .background(Color.primary.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.hairline.opacity(0.7))
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(Color.hairline.opacity(0.7))
            .frame(width: 1, height: 24)
    }

    private func summaryStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: AppFont.pt(10)))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: AppFont.pt(15), weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }
}

// MARK: - Activity Calendar
/// GitHub-style contribution grid: one column per week, one cell per day,
/// shaded by that day's message count.
private struct ActivityCalendarView: View {
    let usageByDay: [String: DayUsage]

    private static let weeksShown = 17
    private let cell: CGFloat = 9
    private let gap: CGFloat = 2.5

    /// Day-grid as week columns, oldest → newest. `nil` marks future days
    /// in the current (partial) week.
    private var weeks: [[Date?]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)  // 1 = Sunday
        var columns: [[Date?]] = []
        for w in (0..<Self.weeksShown).reversed() {
            var column: [Date?] = []
            for d in 0..<7 {
                let offset = -(w * 7) - (weekday - 1) + d
                let date = cal.date(byAdding: .day, value: offset, to: today)!
                column.append(date > today ? nil : date)
            }
            columns.append(column)
        }
        return columns
    }

    var body: some View {
        HStack(alignment: .top, spacing: gap) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                VStack(spacing: gap) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color(for: day))
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .accessibilityLabel("Activity calendar")
    }

    private func color(for day: Date?) -> Color {
        guard let day else { return Color.clear }
        let messages = usageByDay[UsageStats.dayKey(for: day)]?.messages ?? 0
        switch messages {
        case 0: return Color.primary.opacity(0.05)
        case 1...4: return Color.accentCoral.opacity(0.25)
        case 5...14: return Color.accentCoral.opacity(0.5)
        case 15...39: return Color.accentCoral.opacity(0.75)
        default: return Color.accentCoral
        }
    }
}
