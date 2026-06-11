import SwiftUI

public struct MainView: View {
    @ObservedObject var viewModel: MainViewModel

    public init(viewModel: MainViewModel) {
        self.viewModel = viewModel
    }

    #if os(iOS)
    public var body: some View {
        ZStack(alignment: .leading) {
            mainContentPane

            if viewModel.isSidebarVisible {
                // Dimming scrim — tap to dismiss sidebar
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.isSidebarVisible = false
                        }
                    }
                    .transition(.opacity)

                SidebarView(viewModel: viewModel)
                    .frame(width: DeviceLayout.sidebarWidth)
                    .transition(.move(edge: .leading))
                    .ignoresSafeArea(edges: .top)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isSidebarVisible)
        .platformFrame()
        .background(Color.creamBackground)
        .tint(.primary)
        .textSelection(.enabled)

        // Settings overlay
        if viewModel.isSettingsOpen {
            settingsOverlay
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
                        withAnimation(.easeInOut(duration: 0.25)) { viewModel.isSidebarVisible.toggle() }
                    }
                    .padding(.leading, 16)
                }
                Spacer()
            }
            .frame(height: 44)

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

    // MARK: - Settings Overlay
    private var settingsOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            SettingsView(viewModel: viewModel)
                #if os(macOS)
            .frame(maxWidth: 640)
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
                #else
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
                #endif
        }
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

            Image(systemName: "command")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundColor(Color.accentCoral)

            Text(welcomeHeadline)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.top, 16)

            Text("Copy something to get quick actions, or start with one of these.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(.top, 6)

            VStack(spacing: 8) {
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
            .padding(.horizontal, 24)
            .padding(.top, 26)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    #endif
}

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
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.system(size: 12.5))
                    .foregroundColor(.primary.opacity(0.85))
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
                    markdownText
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

                // Meta row: timestamp + copy
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
