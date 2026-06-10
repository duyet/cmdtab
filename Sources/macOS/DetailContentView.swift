import SwiftUI

/// macOS-only right pane: chat viewport, composer, floating sidebar peek, settings overlay.
/// Hosted inside NSSplitViewController's detail item via NSHostingController.
struct DetailContentView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var isFloatingSidebarShown = false
    @State private var toggleIconHovering = false
    @State private var floatingPanelHovering = false

    var body: some View {
        ZStack {
            mainContentPane

            // Floating sidebar peek (hover on toggle icon while hidden)
            if isFloatingSidebarShown && !viewModel.isSidebarVisible && !viewModel.isSettingsOpen {
                floatingSidebarOverlay
            }

            // Settings overlay — instant, full-window scrim + floating panel
            if viewModel.isSettingsOpen {
                settingsOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.creamBackground)
        .tint(.primary)
        .textSelection(.enabled)
    }

    // MARK: - Main Content Pane
    private var mainContentPane: some View {
        VStack(spacing: 0) {
            // Top bar — sidebar toggle icon when hidden
            HStack {
                if !viewModel.isSidebarVisible {
                    PlainIconButton(systemName: "sidebar.left", size: 13, help: "Show Sidebar") {
                        isFloatingSidebarShown = false
                        withAnimation(.easeInOut(duration: 0.25)) { viewModel.isSidebarVisible.toggle() }
                    }
                    .padding(.leading, 16)
                    .onHover { hovering in
                        toggleIconHovering = hovering
                        updateFloatingSidebar()
                    }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if !toggleIconHovering && !floatingPanelHovering {
                    withAnimation(.easeIn(duration: 0.15)) { isFloatingSidebarShown = false }
                }
            }
        }
    }

    // MARK: - Settings Overlay (instant, scrim + floating panel)
    private var settingsOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            SettingsView(viewModel: viewModel)
                .frame(maxWidth: 640)
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
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

    // MARK: - Landing View
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
