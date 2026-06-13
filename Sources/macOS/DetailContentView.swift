import SwiftUI

/// macOS-only right pane: chat viewport, composer, settings inspector.
/// Hosted inside NSSplitViewController's detail item via NSHostingController.
struct DetailContentView: View {
    @ObservedObject var viewModel: MainViewModel

    @State private var showRequestInfoDialog = false
    @State private var dashboardTab: DashboardTab = .overview

    private enum DashboardTab: String, CaseIterable, Identifiable {
        case overview
        case calendar
        case actions

        var id: String { rawValue }

        var title: String {
            switch self {
            case .overview: return "Overview"
            case .calendar: return "Calendar"
            case .actions: return "Actions"
            }
        }
    }

    var body: some View {
        // Settings presents as a window-modal sheet — slides over the chat
        // without replacing the main window content.
        ZStack(alignment: .topLeading) {
            if viewModel.isSettingsOpen {
                // Settings content in the detail pane; navigation lives in
                // the main sidebar (which swapped to settings nav items).
                SettingsView(viewModel: viewModel).settingsContentPane
                    .transition(.opacity)
            } else if viewModel.sidebarMode == "actions", let selectedPresetId = viewModel.selectedPresetIdForDetail {
                PresetDetailView(viewModel: viewModel, presetId: selectedPresetId)
                    .transition(.opacity)
            } else {
                mainContentPane
            }

        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.isSettingsOpen)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.creamBackground)
        .tint(.primary)
        .textSelection(.enabled)

        // Overlay info button at the top-right of the chat (in the title bar)
        .overlay(alignment: .topTrailing) {
            if !viewModel.isSettingsOpen && viewModel.selectedConversationId != nil {
                PlainIconButton(systemName: "info.circle", size: 13, help: "Show Raw Request / System Prompt") {
                    showRequestInfoDialog = true
                }
                .padding(.trailing, 16)
                .padding(.top, 4)
            }
        }
        // Sheet modal for Raw Request details
        .sheet(isPresented: $showRequestInfoDialog) {
            RawRequestSheet(viewModel: viewModel, isPresented: $showRequestInfoDialog)
        }
    }

    // MARK: - Main Content Pane
    private var mainContentPane: some View {
        VStack(spacing: 0) {
            Group {
                if hasMessages {
                    chatHistoryViewport
                } else {
                    emptyLandingView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            ComposerView(viewModel: viewModel)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(10)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        ScrollView {
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
                    ForEach(Array(viewModel.presets.prefix(4).enumerated()), id: \.element.id) { index, preset in
                        StarterCard(icon: preset.sfSymbol, title: preset.name) {
                            viewModel.pickPreset(index: index)
                        }
                    }
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 28)
            .padding(.top, 36)
            .padding(.bottom, 24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
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
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workspace")
                        .font(.system(size: AppFont.pt(13), weight: .semibold))
                    Text("Usage, activity, and saved quick actions")
                        .font(.system(size: AppFont.pt(11)))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 12)
                Picker("", selection: $dashboardTab) {
                    ForEach(DashboardTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 244)
            }

            Group {
                switch dashboardTab {
                case .overview:
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 0) {
                            summaryStat(value: compactNumber(totals.sessions), label: "Sessions")
                            summaryDivider
                            summaryStat(value: compactNumber(totals.messages), label: "Messages")
                            summaryDivider
                            summaryStat(value: compactNumber(totals.tokens), label: "Total tokens")
                            summaryDivider
                            summaryStat(value: "\(totals.activeDays)", label: "Active days")
                        }
                        ActivityCalendarView(usageByDay: viewModel.usageByDay, prominence: .compact)
                    }
                    .transition(.opacity)
                case .calendar:
                    ActivityCalendarView(usageByDay: viewModel.usageByDay, prominence: .expanded)
                        .transition(.opacity)
                case .actions:
                    quickActionsDashboard
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: dashboardTab)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var quickActionsDashboard: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(Array(viewModel.presets.prefix(8).enumerated()), id: \.element.id) { index, preset in
                StarterCard(icon: preset.sfSymbol, title: preset.name) {
                    viewModel.pickPreset(index: index)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Activity Calendar
/// GitHub-style contribution grid with month labels, day-of-week labels,
/// and a colour legend. One column per week, one cell per day, shaded by
/// that day's message count.
private struct ActivityCalendarView: View {
    let usageByDay: [String: DayUsage]
    var prominence: Prominence = .compact

    enum Prominence {
        case compact
        case expanded
    }

    private struct CalendarLayout {
        let weeksShown: Int
        let cellSize: CGFloat
        let gap: CGFloat
        let monthSpacing: CGFloat
        let showDayLabels: Bool
    }

    private let dayLabels = ["Mon", "", "Wed", "", "Fri", "", ""]

    /// Day-grid as week columns, oldest → newest. Future months are `nil`.
    private func weeks(shown weeksShown: Int) -> [[Date?]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        
        // Find the last day of the current month to show the full month
        guard let range = cal.range(of: .day, in: .month, for: today),
              let lastDayOfCurrentMonth = cal.date(bySetting: .day, value: range.count, of: today) else {
            return []
        }
        let endOfCurrentMonth = cal.startOfDay(for: lastDayOfCurrentMonth)
        
        // Adjust so columns start on Monday (weekday 2) relative to the end of the month
        let weekday = cal.component(.weekday, from: endOfCurrentMonth)
        let mondayOffset = weekday == 1 ? 6 : weekday - 2  // Sun→6, Mon→0, Tue→1, …
        
        var columns: [[Date?]] = []
        for w in (0..<weeksShown).reversed() {
            var column: [Date?] = []
            for d in 0..<7 {
                let offset = -(w * 7) - mondayOffset + d
                let date = cal.date(byAdding: .day, value: offset, to: endOfCurrentMonth)!
                
                // Keep the date if it is in the past/today, or belongs to the current month (for future days in this month)
                let isCurrentMonth = cal.isDate(date, equalTo: today, toGranularity: .month)
                if date <= today || isCurrentMonth {
                    column.append(date)
                } else {
                    column.append(nil) // future months are transparent
                }
            }
            columns.append(column)
        }
        return columns
    }

    private struct MonthGroup: Identifiable {
        let id = UUID()
        let name: String
        let weeks: [[Date?]]
    }

    private func monthGroups(for weeks: [[Date?]]) -> [MonthGroup] {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        
        var groups: [MonthGroup] = []
        var currentWeeks: [[Date?]] = []
        var currentMonthName: String = ""
        
        for week in weeks {
            if let firstDay = week.compactMap({ $0 }).first {
                let monthName = fmt.string(from: firstDay)
                if monthName != currentMonthName {
                    if !currentWeeks.isEmpty {
                        groups.append(MonthGroup(name: currentMonthName, weeks: currentWeeks))
                    }
                    currentWeeks = [week]
                    currentMonthName = monthName
                } else {
                    currentWeeks.append(week)
                }
            } else {
                currentWeeks.append(week)
            }
        }
        if !currentWeeks.isEmpty {
            groups.append(MonthGroup(name: currentMonthName, weeks: currentWeeks))
        }
        return groups
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            calendarGrid(layout: wideLayout)
            calendarGrid(layout: mediumLayout)
            calendarGrid(layout: compactLayout)
            ScrollView(.horizontal, showsIndicators: false) {
                calendarGrid(layout: compactLayout)
            }
        }
        .accessibilityLabel("Activity calendar")
    }

    private var wideLayout: CalendarLayout {
        switch prominence {
        case .compact:
            return CalendarLayout(weeksShown: 17, cellSize: 11, gap: 2, monthSpacing: 10, showDayLabels: true)
        case .expanded:
            return CalendarLayout(weeksShown: 26, cellSize: 11, gap: 2, monthSpacing: 10, showDayLabels: true)
        }
    }

    private var mediumLayout: CalendarLayout {
        CalendarLayout(weeksShown: prominence == .compact ? 14 : 20, cellSize: 10, gap: 2, monthSpacing: 8, showDayLabels: true)
    }

    private var compactLayout: CalendarLayout {
        CalendarLayout(weeksShown: prominence == .compact ? 10 : 14, cellSize: 9, gap: 2, monthSpacing: 6, showDayLabels: false)
    }

    private func calendarGrid(layout: CalendarLayout) -> some View {
        let columns = weeks(shown: layout.weeksShown)
        let groups = monthGroups(for: columns)
        return VStack(alignment: .leading, spacing: 4) {
            // Main grid: day labels + segmented months
            HStack(alignment: .top, spacing: 8) {
                // Day-of-week labels
                if layout.showDayLabels {
                    VStack(alignment: .trailing, spacing: layout.gap) {
                        Spacer()
                            .frame(height: 14)

                        ForEach(0..<7, id: \.self) { row in
                            Text(dayLabels[row])
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.6))
                                .frame(height: layout.cellSize, alignment: .center)
                        }
                    }
                    .frame(width: dayLabelWidth)
                }

                // Segmented months grid
                HStack(alignment: .top, spacing: layout.monthSpacing) {
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 2) {
                            // Month label
                            Text(group.name)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.6))
                                .frame(height: 12)
                            
                            // Week columns
                            HStack(alignment: .top, spacing: layout.gap) {
                                ForEach(0..<group.weeks.count, id: \.self) { wIdx in
                                    VStack(spacing: layout.gap) {
                                        ForEach(Array(group.weeks[wIdx].enumerated()), id: \.offset) { _, day in
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(color(for: day))
                                                .frame(width: layout.cellSize, height: layout.cellSize)
                                                .accessibilityLabel(accessibilityLabel(for: day))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            // Legend
            HStack(spacing: 4) {
                Spacer()
                Text("Less")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))
                ForEach(legendColors, id: \.self) { c in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(c)
                        .frame(width: layout.cellSize, height: layout.cellSize)
                }
                Text("More")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.top, 2)
        }
    }

    private var dayLabelWidth: CGFloat { 28 }

    private var legendColors: [Color] {
        [Color.gray.opacity(0.2), accentColor(0.25), accentColor(0.5), accentColor(0.75), accentColor(1.0)]
    }

    private func accentColor(_ opacity: CGFloat) -> Color {
        Color.accentColor.opacity(opacity)
    }

    private func color(for day: Date?) -> Color {
        guard let day else {
            return Color.clear
        }
        let key = UsageStats.dayKey(for: day)
        let messages = usageByDay[key]?.messages ?? 0
        
        switch messages {
        case 0: return Color.gray.opacity(0.2)
        case 1...4: return accentColor(0.25)
        case 5...14: return accentColor(0.5)
        case 15...39: return accentColor(0.75)
        default: return accentColor(1.0)
        }
    }

    private func accessibilityLabel(for day: Date?) -> String {
        guard let day else { return "" }
        let key = UsageStats.dayKey(for: day)
        let messages = usageByDay[key]?.messages ?? 0
        let formattedDate = Self.accessibilityDateFormatter.string(from: day)
        let unit = messages == 1 ? "message" : "messages"
        return "\(formattedDate), \(messages) \(unit)"
    }

    private static let accessibilityDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

// MARK: - Raw Request Sheet
/// Displays the full request payload sent to the model, with structured
/// JSON sections for system instructions, tools, parameters, and messages.
private struct RawRequestSheet: View {
    @ObservedObject var viewModel: MainViewModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Raw Model Request Details")
                    .font(.headline)
                Spacer()
                Button("Close") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.bottom, 12)

            // JSON content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(prettyJSON)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.subtleFill)
                .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding(16)
        .frame(width: 560, height: 520)
    }

    private var prettyJSON: String {
        let raw = viewModel.getRawRequestDetails()
        // Re-format with sorted keys for consistency
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(
                withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: formatted, encoding: .utf8) else {
            return raw
        }
        return str
    }
}
