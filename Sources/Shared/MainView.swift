import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct MainView: View {
    @ObservedObject var viewModel: MainViewModel

    public init(viewModel: MainViewModel) {
        self.viewModel = viewModel
    }

    #if os(iOS)
    // Live drag translation while the user is dragging the drawer (nil = idle).
    @State private var sidebarDrag: CGFloat?

    private var drawerWidth: CGFloat { DeviceLayout.drawerWidth }

    /// Current x-offset of the drawer: -drawerWidth (hidden) … 0 (open).
    private var drawerOffset: CGFloat {
        let base: CGFloat = viewModel.isSidebarVisible ? 0 : -drawerWidth
        return min(0, max(-drawerWidth, base + (sidebarDrag ?? 0)))
    }
    /// 0 = closed, 1 = fully open. Drives scrim opacity + content peek.
    private var drawerProgress: CGFloat { (drawerOffset + drawerWidth) / drawerWidth }
    private var isDrawerInPlay: Bool { viewModel.isSidebarVisible || sidebarDrag != nil }

    public var body: some View {
        ZStack(alignment: .leading) {
            // Content "card" that shrinks + slides as the drawer comes over it.
            mainContentPane
                .scaleEffect(1 - 0.05 * drawerProgress, anchor: .trailing)
                .offset(x: drawerProgress * 12)
                .clipShape(RoundedRectangle(cornerRadius: 28 * drawerProgress, style: .continuous))
                .disabled(isDrawerInPlay)

            // Left-edge grab strip — owns the open drag while the drawer is closed.
            if !isDrawerInPlay && !viewModel.isSettingsOpen {
                Color.clear
                    .frame(width: 24)
                    .frame(maxHeight: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .gesture(drawerDragGesture)
            }

            if isDrawerInPlay {
                Color.black.opacity(0.28 * drawerProgress)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { setSidebar(false) }
                    .gesture(drawerDragGesture)

                SidebarView(viewModel: viewModel)
                    .frame(width: drawerWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.windowBackground)
                    .clipShape(
                        .rect(bottomTrailingRadius: 28, topTrailingRadius: 28, style: .continuous))
                    .shadow(color: .black.opacity(0.18 * drawerProgress), radius: 24, x: 8, y: 0)
                    .offset(x: drawerOffset)
                    .ignoresSafeArea(edges: .vertical)
                    .gesture(drawerDragGesture)
            }

            // Settings — full-screen top layer. Owns the whole frame so it
            // covers the content + keyboard and reliably captures touches.
            if viewModel.isSettingsOpen {
                SettingsView(viewModel: viewModel)
                    .background(Color.appBackground.ignoresSafeArea())
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isSettingsOpen)
        .platformFrame()
        .background(Color.creamBackground)
        .tint(.primary)
        .textSelection(.enabled)
        .onChange(of: viewModel.isSidebarVisible) { _, visible in
            if visible { dismissKeyboard() }
        }
        .onChange(of: viewModel.isSettingsOpen) { _, open in
            if open {
                viewModel.isSidebarVisible = false
                dismissKeyboard()
            }
        }
    }

    /// Resign the first responder so the software keyboard hides.
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func setSidebar(_ open: Bool) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            viewModel.isSidebarVisible = open
            sidebarDrag = nil
        }
    }

    /// Single interactive gesture: the drawer tracks the finger, then snaps
    /// open/closed on release based on distance + fling velocity.
    private var drawerDragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard !viewModel.isSettingsOpen else { return }
                if viewModel.isSidebarVisible {
                    sidebarDrag = min(0, value.translation.width)   // drag left to close
                } else {
                    sidebarDrag = max(0, value.translation.width)   // drag right to open
                }
            }
            .onEnded { value in
                guard !viewModel.isSettingsOpen else { return }
                let projected = value.translation.width + value.predictedEndTranslation.width
                let open: Bool
                if viewModel.isSidebarVisible {
                    open = projected > -drawerWidth * 0.4
                } else {
                    open = projected > drawerWidth * 0.3
                }
                if open { dismissKeyboard() }
                setSidebar(open)
            }
    }
    #else
    // macOS: MainView is not instantiated (WindowController hosts views separately).
    // This body exists only to satisfy compilation.
    public var body: some View {
        EmptyView()
    }
    #endif

    #if os(iOS)
    // MARK: - Main Content Pane
    private var mainContentPane: some View {
        VStack(spacing: 0) {
            HStack {
                if !viewModel.isSidebarVisible {
                    PlainIconButton(systemName: "sidebar.left", size: 13, help: "Show Sidebar") {
                        setSidebar(true)
                    }
                    .padding(.leading, 16)
                }
                Spacer()
            }
            .frame(height: 44)

            if viewModel.sidebarMode == "actions", let selectedPresetId = viewModel.selectedPresetIdForDetail {
                PresetDetailView(viewModel: viewModel, presetId: selectedPresetId)
            } else if hasMessages {
                chatHistoryViewport
            } else {
                emptyLandingView
            }

            if viewModel.sidebarMode != "actions" || viewModel.selectedPresetIdForDetail == nil {
                ComposerView(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.creamBackground)
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
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
                // Centered reading column — comfortable line length on iPad widths
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
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

    /// Time-aware headline, personalized when a name is set in Settings.
    private var welcomeHeadline: String {
        Greeting.headline(
            userName: viewModel.userName,
            hour: Calendar.current.component(.hour, from: Date()))
    }

    // MARK: - Landing View
    private var emptyLandingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero greeting — large, friendly, left-aligned for mobile.
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: AppFont.pt(30), weight: .semibold))
                        .foregroundColor(Color.accentCoral)
                        .padding(.bottom, 4)

                    Text(welcomeHeadline)
                        .font(.system(size: AppFont.pt(34), weight: .bold))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Copy something for instant Quick Actions, or start with one of these.")
                        .font(.system(size: AppFont.pt(16)))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 24)

                Text("QUICK ACTIONS")
                    .font(.system(size: AppFont.pt(12), weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.top, 32)
                    .padding(.bottom, 12)

                // Suggestion pills are the user's saved Quick Actions (presets).
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 130), spacing: 10)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(viewModel.presets) { preset in
                        PresetPill(name: preset.name, icon: preset.sfSymbol) {
                            viewModel.startNewConversation(title: preset.name, presetId: preset.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    #endif
}

#if os(iOS)
// MARK: - Preset Pill (mobile homepage)
/// Compact suggestion pill backed by a saved Quick Action (preset):
/// icon + name on a hairline-bordered capsule (assistant-ui style).
struct PresetPill: View {
    let name: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: AppFont.pt(14), weight: .medium))
                    .foregroundColor(Color.accentCoral)
                Text(name)
                    .font(.system(size: AppFont.pt(15), weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.cardSurface)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.hairline))
            .contentShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
#endif

// MARK: - Starter Card (empty-state suggestion)
struct StarterCard: View {
    let icon: String
    let title: String
    let action: () -> Void
    #if os(macOS)
    @State private var isHovered = false
    #endif

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: AppFont.pt(12)))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.system(size: AppFont.pt(12.5)))
                    .foregroundColor(.primary.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            #if os(macOS)
            .background(isHovered ? Color.primary.opacity(0.06) : Color.cardSurface)
            #else
            .background(Color.cardSurface)
            #endif
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.hairline))
            .contentShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
        .focusable(false)
        #if os(macOS)
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { isHovered = h } }
        #endif
    }
}

// MARK: - Message Row — chat-bubble layout
/// User messages: right-aligned gray bubble with avatar. Assistant:
/// left-aligned with avatar icon, markdown rendering, and streaming cursor.
/// Small timestamp + copy icons sit below each message.
/// On macOS: hover reveals meta. On iOS: meta always visible.
struct MessageRow: View {
    let message: ChatMessage
    @ObservedObject var viewModel: MainViewModel
    @State private var copied = false
    #if os(macOS)
    @State private var isHovered = false
    #endif

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isUser { Spacer(minLength: 48) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if isUser {
                    VStack(alignment: .leading, spacing: 6) {
                        // Quick Action header (e.g. "Summarize") when this turn
                        // came from a preset run on clipboard text.
                        if let action = message.actionLabel {
                            HStack(spacing: 5) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: AppFont.pt(9)))
                                Text(action)
                                    .font(.system(size: AppFont.pt(11), weight: .semibold))
                            }
                            .foregroundColor(Color.accentCoral)
                        }

                        if message.isQuote {
                            // Quoted text, assistant-ui style: a quote glyph +
                            // italic gray text sitting above the user's words.
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "quote.opening")
                                    .font(.system(size: AppFont.pt(12)))
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .padding(.top, 1)
                                Text(message.content)
                                    .font(.system(size: AppFont.pt(14)))
                                    .italic()
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            markdownText
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else if message.content.isEmpty && viewModel.isStreaming {
                    TypingIndicator(fontScale: viewModel.fontScale)
                } else if message.isError {
                    errorCard
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        MessageMarkdownView(
                            content: message.content, fontScale: viewModel.fontScale)
                        // Blinking cursor while streaming
                        if viewModel.isStreaming {
                            StreamingCursor()
                        }
                    }
                }

                // Meta row: timestamp + metrics + copy
                HStack(spacing: 8) {
                    Text(message.timestamp, style: .time)
                        .font(.system(size: AppFont.pt(10)))
                        .foregroundColor(.secondary.opacity(0.7))
                    if !isUser, let metrics = message.inferenceMetrics {
                        MetricsChips(metrics: metrics)
                    }
                    Button(action: copyMessage) {
                        Image(systemName: copied ? "checkmark" : "square.on.square")
                            .font(.system(size: AppFont.pt(10)))
                            .foregroundColor(copied ? Color.accentCoral : .secondary.opacity(0.7))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(copied ? "Copied" : "Copy message")
                    #if os(macOS)
                    .help("Copy")
                    #endif
                }
                #if os(macOS)
                .opacity(isHovered || copied ? 1 : 0)
                #else
                .opacity(copied ? 1 : 0.5)
                #endif
            }

            if !isUser { Spacer(minLength: 48) }
        }
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
        }
        #else
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { copyMessage() }
        #endif
    }

    /// Failed-request presentation: quiet red card with the concise provider
    /// message instead of a wall of raw JSON.
    private var errorCard: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: AppFont.pt(12)))
                .foregroundColor(.red.opacity(0.85))
            Text(message.content)
                .font(.system(size: AppFont.pt(13) * viewModel.fontScale))
                .foregroundColor(.primary.opacity(0.85))
                .textSelection(.enabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.red.opacity(0.18))
        )
    }

    /// Native markdown rendering (inline syntax: bold, italic, code, links).
    private var markdownText: some View {
        Text(attributedContent)
            .font(.system(size: AppFont.pt(13) * viewModel.fontScale))
            .foregroundColor(.primary)
            .lineSpacing(4)
            .textSelection(.enabled)
            .multilineTextAlignment(isUser ? .trailing : .leading)
    }

    private var attributedContent: AttributedString {
        if let attr = try? AttributedString(
            markdown: message.content,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace))
        {
            return attr
        }
        return AttributedString(message.content)
    }

    private func copyMessage() {
        PasteboardMonitor.shared.suppressNextEcho(text: message.content)
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(message.content, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = message.content
        #endif
        withAnimation { copied = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                withAnimation { copied = false }
            }
        }
    }
}

// MARK: - Typing Indicator
/// Three bouncing dots animated with staggered delays.
struct TypingIndicator: View {
    let fontScale: Double
    @State private var isActive = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .offset(y: isActive ? -4 : 4)
                    .animation(
                        Animation.easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: isActive
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .onAppear { isActive = true }
        .onDisappear { isActive = false }
    }
}

// MARK: - Streaming Cursor
/// Blinking vertical bar at the end of streaming assistant text.
struct StreamingCursor: View {
    @State private var isVisible = true

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.accentCoral.opacity(isVisible ? 0.8 : 0))
            .frame(width: 2, height: 14)
            .offset(y: 1)
            .animation(
                Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                value: isVisible
            )
            .onAppear { isVisible = false }
    }
}

// MARK: - Inference Metrics Chips

/// Compact metrics display shown in the assistant message meta row.
/// Shows model name, TTFT, TPS, token counts, reasoning tokens.
struct MetricsChips: View {
    let metrics: InferenceMetrics

    var body: some View {
        HStack(spacing: 6) {
            if let model = metrics.model {
                Text(shortModelName(model))
                    .font(.system(size: AppFont.pt(9), weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            if let ttft = metrics.ttftMs {
                Text("\(ttft)ms ttft")
                    .metricChipStyle()
            }
            if let tps = metrics.tps {
                Text(String(format: "%.1f t/s", tps))
                    .metricChipStyle()
            }
            if let out = metrics.outputTokens {
                Text("~\(out) tok")
                    .metricChipStyle()
            }
            if let reason = metrics.reasoningTokens, reason > 0 {
                Text("+\(reason) reason")
                    .metricChipStyle()
            }
        }
    }

    /// Strip provider prefix: "anthropic/claude-sonnet-4.6" → "claude-sonnet-4.6"
    private func shortModelName(_ id: String) -> String {
        if let slash = id.lastIndex(of: "/") {
            return String(id[id.index(after: slash)...])
        }
        return id
    }
}

private extension View {
    func metricChipStyle() -> some View {
        font(.system(size: AppFont.pt(9), design: .monospaced))
            .foregroundColor(.secondary.opacity(0.55))
    }
}

// MARK: - onChange Compatibility Helpers
extension View {
    @ViewBuilder
    func onStreamingChange(of value: Bool, perform action: @escaping (Bool) -> Void) -> some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value) { newValue in
                action(newValue)
            }
        }
    }

    @ViewBuilder
    func onConversationsChange(of value: [Conversation], perform action: @escaping () -> Void) -> some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            self.onChange(of: value) { _, _ in
                action()
            }
        } else {
            self.onChange(of: value) { _ in
                action()
            }
        }
    }
}
