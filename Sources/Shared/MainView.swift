import SwiftUI

public struct MainView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var dragStartWidth: CGFloat? = nil
    #if os(macOS)
    // Distinguishes width-triggered hiding from a user's manual ⌘B toggle so
    // we only auto-restore what we auto-hid.
    @State private var sidebarAutoHidden = false
    // Hover-to-peek: hovering the toggle icon shows the sidebar as a floating
    // overlay without changing the persisted visibility state.
    @State private var isFloatingSidebarShown = false
    @State private var toggleIconHovering = false
    @State private var floatingPanelHovering = false
    #endif

    public init(viewModel: MainViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            // Base layer: sidebar + main pane always present
            #if os(macOS)
            HStack(spacing: 0) {
                if viewModel.isSidebarVisible {
                    SidebarView(viewModel: viewModel)
                        .frame(width: viewModel.sidebarWidth)
                        .transition(.move(edge: .leading).combined(with: .opacity))

                    sidebarResizeHandle
                }

                mainContentPane
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.isSidebarVisible)
            #else
            ZStack(alignment: .leading) {
                mainContentPane

                if viewModel.isSidebarVisible {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation { viewModel.isSidebarVisible = false }
                        }
                        .transition(.opacity)

                    SidebarView(viewModel: viewModel)
                        .frame(width: 300)
                        .background(Color.windowBackground)
                        .transition(.move(edge: .leading))
                        .ignoresSafeArea(edges: .vertical)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.isSidebarVisible)
            #endif

            #if os(macOS)
            // Floating sidebar peek (hover on the toggle icon while hidden)
            if isFloatingSidebarShown && !viewModel.isSidebarVisible && !viewModel.isSettingsOpen {
                floatingSidebarOverlay
            }
            #endif

            // Settings overlay — instant, full-window scrim + floating panel
            if viewModel.isSettingsOpen {
                settingsOverlay
            }
        }
        .platformFrame()
        .background(Color.creamBackground)
        .tint(.primary)
        // Every static Text in the app is mouse-selectable.
        .textSelection(.enabled)
        // Extend under the transparent title bar so the sidebar toolbar icons
        // sit on the same line as the traffic lights.
        .ignoresSafeArea(.container, edges: .top)
        #if os(macOS)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onChange(of: geo.size.width) { _, newWidth in
                        adaptSidebar(toWidth: newWidth)
                    }
                    .onAppear { adaptSidebar(toWidth: geo.size.width) }
            }
        )
        #endif
    }

    #if os(macOS)
    /// Auto-hides the sidebar when the main pane would get too cramped, and
    /// restores it (with hysteresis) once the window is wide enough again.
    private func adaptSidebar(toWidth width: CGFloat) {
        let minMainPaneWidth: CGFloat = 460
        let restoreSlack: CGFloat = 40
        if viewModel.isSidebarVisible, width < viewModel.sidebarWidth + minMainPaneWidth {
            withAnimation { viewModel.isSidebarVisible = false }
            sidebarAutoHidden = true
        } else if sidebarAutoHidden, !viewModel.isSidebarVisible,
            width >= viewModel.sidebarWidth + minMainPaneWidth + restoreSlack
        {
            withAnimation { viewModel.isSidebarVisible = true }
            sidebarAutoHidden = false
        }
    }

    // MARK: - Floating sidebar peek

    private var floatingSidebarOverlay: some View {
        HStack(spacing: 0) {
            SidebarView(viewModel: viewModel)
                .frame(width: viewModel.sidebarWidth)
                .glassCardSurface(cornerRadius: 12)
                .shadow(color: .black.opacity(0.22), radius: 18, x: 4, y: 6)
                .padding(.leading, 10)
                .padding(.top, 44)
                .padding(.bottom, 14)
            Spacer()
        }
        .transition(.move(edge: .leading).combined(with: .opacity))
        .zIndex(1)
        .onHover { hovering in
            floatingPanelHovering = hovering
            updateFloatingSidebar()
        }
    }

    private func updateFloatingSidebar() {
        guard !viewModel.isSidebarVisible else {
            isFloatingSidebarShown = false
            return
        }
        if toggleIconHovering || floatingPanelHovering {
            withAnimation(.easeOut(duration: 0.15)) { isFloatingSidebarShown = true }
        } else {
            // Grace period so the pointer can cross the gap between the icon
            // and the panel without dismissing it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if !toggleIconHovering && !floatingPanelHovering {
                    withAnimation(.easeIn(duration: 0.15)) { isFloatingSidebarShown = false }
                }
            }
        }
    }
    #endif

    #if os(macOS)
    // MARK: - Sidebar resize handle (drag the divider; width persists)
    private var sidebarResizeHandle: some View {
        Divider()
            .overlay(
                Color.clear
                    .frame(width: 8)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { value in
                                if dragStartWidth == nil { dragStartWidth = viewModel.sidebarWidth }
                                let proposed = (dragStartWidth ?? 260) + value.translation.width
                                viewModel.sidebarWidth = min(400, max(220, proposed))
                            }
                            .onEnded { _ in dragStartWidth = nil }
                    )
                    .onHover { hovering in
                        if hovering { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                    }
            )
    }
    #endif

    // MARK: - Main Content Pane (no header bar)
    private var mainContentPane: some View {
        VStack(spacing: 0) {
            // Slim top inset matching sidebar toolbar height — no header bar.
            HStack {
                if !viewModel.isSidebarVisible {
                    PlainIconButton(systemName: "sidebar.left", size: 13, help: "Show Sidebar") {
                        #if os(macOS)
                        isFloatingSidebarShown = false
                        #endif
                        withAnimation { viewModel.isSidebarVisible.toggle() }
                    }
                    .padding(.leading, 72)
                    #if os(macOS)
                    .onHover { hovering in
                        toggleIconHovering = hovering
                        updateFloatingSidebar()
                    }
                    #endif
                }
                Spacer()
            }
            .frame(height: 36)

            if hasMessages {
                chatHistoryViewport
            } else {
                emptyLandingView
            }

            ComposerView(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.creamBackground)
    }

    // MARK: - Settings Overlay (instant, scrim + floating panel)
    private var settingsOverlay: some View {
        ZStack {
            // Scrim over everything including sidebar
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            // Floating settings panel
            SettingsView(viewModel: viewModel)
                .frame(maxWidth: 640)
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
        }
        // No animation — instant appearance per spec
        .transaction { $0.animation = nil }
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
                VStack(alignment: .leading, spacing: 18) {
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
                .padding(.bottom, 16)
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

    /// Time-aware headline, personalized when a name is set in Settings.
    private var welcomeHeadline: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let salutation: String
        switch hour {
        case 5..<12: salutation = "Good morning"
        case 12..<17: salutation = "Good afternoon"
        case 17..<22: salutation = "Good evening"
        default: salutation = "Working late"
        }
        let name = viewModel.userName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "\(salutation)!" : "\(salutation), \(name)!"
    }

    // MARK: - Landing View
    private var emptyLandingView: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(spacing: 12) {
                Image(systemName: "command")
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .foregroundColor(Color.accentCoral)

                Text(welcomeHeadline)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Text("Copy something to get quick actions, or start with one of these.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(.top, 10)

            HStack(spacing: 10) {
                StarterCard(icon: "doc.on.clipboard", title: "Summarize my clipboard") {
                    viewModel.prefillComposer("Summarize this for me: ")
                }
                StarterCard(icon: "envelope", title: "Draft an email") {
                    viewModel.prefillComposer("Draft a short, friendly email about ")
                }
                StarterCard(icon: "lightbulb", title: "Explain a concept") {
                    viewModel.prefillComposer("Explain in plain language: ")
                }
            }
            .padding(.top, 22)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Starter Card (empty-state suggestion)
private struct StarterCard: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.system(size: 12.5))
                    .foregroundColor(.primary.opacity(0.85))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(isHovered ? Color.primary.opacity(0.06) : Color.cardSurface)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.hairline))
            .contentShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { isHovered = h } }
    }
}

// MARK: - Message Row — chat-bubble layout
/// User messages: right-aligned gray bubble. Assistant: left-aligned plain
/// markdown text. Small timestamp + copy icons sit below each message.
private struct MessageRow: View {
    let message: ChatMessage
    @ObservedObject var viewModel: MainViewModel
    @State private var isHovered = false
    @State private var copied = false

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if isUser {
                    markdownText
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else if message.content.isEmpty && viewModel.isStreaming {
                    Text("Thinking…")
                        .font(.system(size: 13 * viewModel.fontScale))
                        .foregroundColor(.secondary.opacity(0.7))
                } else if message.isError {
                    errorCard
                } else {
                    markdownText
                }

                // Meta row: timestamp + copy, quiet until hover
                HStack(spacing: 8) {
                    Text(message.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                    Button(action: copyMessage) {
                        Image(systemName: copied ? "checkmark" : "square.on.square")
                            .font(.system(size: 10))
                            .foregroundColor(copied ? Color.accentCoral : .secondary.opacity(0.7))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(copied ? "Copied" : "Copy message")
                    #if os(macOS)
                    .help("Copy")
                    #endif
                }
                .opacity(isHovered || copied ? 1 : 0)
            }

            if !isUser { Spacer(minLength: 60) }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
        }
    }

    /// Failed-request presentation: quiet red card with the concise provider
    /// message instead of a wall of raw JSON.
    private var errorCard: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(.red.opacity(0.85))
            Text(message.content)
                .font(.system(size: 13 * viewModel.fontScale))
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
            .font(.system(size: 13 * viewModel.fontScale))
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
