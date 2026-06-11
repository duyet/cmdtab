import SwiftUI

/// macOS-only right pane: chat viewport, composer, settings inspector.
/// Hosted inside NSSplitViewController's detail item via NSHostingController.
struct DetailContentView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        ZStack {
            mainContentPane

            // Settings — right-side floating inspector panel with scrim
            if viewModel.isSettingsOpen {
                settingsInspector
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
            if hasMessages {
                chatHistoryViewport
            } else {
                emptyLandingView
            }

            ComposerView(viewModel: viewModel)
        }
    }

    // MARK: - Settings Inspector (right-side panel)
    private var settingsInspector: some View {
        HStack(spacing: 0) {
            // Scrim over content — tap to dismiss
            Color.black.opacity(0.25)
                .onTapGesture { viewModel.isSettingsOpen = false }

            // Settings panel anchored to the right edge
            SettingsView(viewModel: viewModel)
                .frame(width: 420)
                .background(Color.cardSurface)
                .overlay(Rectangle().frame(width: 1).foregroundColor(Color.hairline), alignment: .leading)
        }
        .ignoresSafeArea()
        .transition(.move(edge: .trailing))
        // Instant appearance — no animation per original spec.
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
            .padding(.top, 26)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
