import SwiftUI

// MARK: - Composer View
/// Hero rounded card: optional clipboard quote block + preset chips row (when clipboard
/// present), multiline text field, "+" button, model picker, Local|Cloud toggle, coral send.
struct ComposerView: View {
    @ObservedObject var viewModel: MainViewModel
    // Composer-local state: keystrokes re-render ONLY this view, never the
    // whole window — keeps typing latency imperceptible.
    @State private var inputMessageText: String = ""
    @State private var pulseOpacity: Double = 0.3
    @FocusState private var isInputFocused: Bool
    @State private var showLocalHelp: Bool = false
    @State private var isQuoteExpanded: Bool = false

    private var modelOptions: [(id: String, label: String)] {
        ModelCatalog.entries.map { (id: $0.id, label: $0.displayName) }
    }

    private var hasClipboard: Bool {
        viewModel.isClipboardBannerVisible && !viewModel.detectedClipboardText.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            streamingIndicator

            // 1. Quote block (clipboard present)
            if hasClipboard {
                clipboardQuoteBlock
                presetChipsRow
                Divider()
                    .background(Color.hairline)
            }

            // 2. Text input
            textField

            // 3. Bottom controls row
            controlsRow

            // 4. Local-model availability notice (Apple Foundation Models)
            if viewModel.isLocalModelSelected && !viewModel.isLocalModelSupported {
                localUnavailableNotice
            }

            // 5. Missing API key CTA (cloud mode, key checked lazily)
            if !viewModel.isLocalModelSelected && viewModel.hasLoadedApiKey && viewModel.apiKey.isEmpty {
                missingKeyNotice
            }
        }
        .background(Color.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.hairline, lineWidth: 1)
        )
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .onAppear { isInputFocused = true }
        .onFocusTick(of: viewModel.composerFocusTick) {
            isInputFocused = true
        }
    }

    // MARK: Streaming indicator (thin coral stripe at top)
    @ViewBuilder
    private var streamingIndicator: some View {
        if viewModel.isStreaming {
            Rectangle()
                .fill(Color.accentCoral.opacity(0.7))
                .frame(height: 2)
                .cornerRadius(2)
                .opacity(pulseOpacity)
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        pulseOpacity = 0.9
                    }
                }
                .onDisappear { pulseOpacity = 0.3 }
        }
    }

    // MARK: Clipboard quote block (inside card, darker inset)
    private var clipboardQuoteBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("Text from your clipboard")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Image(systemName: isQuoteExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
                Spacer()
                Button(action: { viewModel.dismissClipboardBanner() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
            // Preview: one line collapsed; click to expand with scrollbar.
            if isQuoteExpanded {
                ScrollView {
                    Text(viewModel.detectedClipboardText.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
            } else {
                Text(viewModel.detectedClipboardText.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.15)) { isQuoteExpanded.toggle() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(16, corners: [.topLeft, .topRight])
    }

    // MARK: Preset chips row (horizontal scrolling, inside card)
    private var presetChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(viewModel.presets.prefix(9).enumerated()), id: \.offset) { index, preset in
                    InlinePresetChip(
                        title: preset.name,
                        icon: preset.sfSymbol,
                        action: { viewModel.runPresetWithClipboard(index: index) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: Text field
    private var textField: some View {
        TextField("How can I help you today?", text: $inputMessageText, onCommit: send)
            .font(.system(size: 15))
            .textFieldStyle(PlainTextFieldStyle())
            .foregroundColor(.primary)
            .focused($isInputFocused)
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 10)
    }

    // MARK: Bottom controls row
    private var controlsRow: some View {
        HStack(spacing: 8) {
            // "+" placeholder
            Button(action: {}) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            #if os(macOS)
            .help("Attach")
            #endif

            Spacer()

            localCloudToggle

            if !viewModel.isLocalModelSelected {
                modelPicker
            }

            sendButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Cloud / Local dropdown (Codex-style "Start in" menu)
    private var localCloudToggle: some View {
        Menu {
            Button {
                viewModel.isLocalModelSelected = false
            } label: {
                Label("Cloud", systemImage: viewModel.isLocalModelSelected ? "cloud" : "checkmark")
            }
            Button {
                viewModel.isLocalModelSelected = true
            } label: {
                Label(
                    viewModel.isLocalModelSupported ? "Local · On-device" : "Local · Unavailable",
                    systemImage: viewModel.isLocalModelSelected ? "checkmark" : "cpu")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.isLocalModelSelected ? "cpu" : "cloud")
                    .font(.system(size: 10))
                Text(viewModel.isLocalModelSelected ? "Local" : "Cloud")
                    .font(.system(size: 12))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundColor(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        #if os(macOS)
        .help(
            viewModel.isLocalModelSelected
                ? "Using on-device Apple Intelligence (Foundation Models)"
                : "Using \(URL(string: viewModel.endpointUrl)?.host ?? "cloud") · \(currentModelLabel)"
        )
        #endif
    }

    // MARK: Model picker — borderless text menu (no popup chrome)
    private var currentModelLabel: String {
        modelOptions.first(where: { $0.id == viewModel.modelName })?.label
            ?? (viewModel.modelName.isEmpty ? "Model" : viewModel.modelName)
    }

    private var modelPicker: some View {
        Menu {
            ForEach(modelOptions, id: \.id) { option in
                Button(option.label) { viewModel.modelName = option.id }
            }
        } label: {
            HStack(spacing: 3) {
                Text(currentModelLabel)
                    .font(.system(size: 12))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundColor(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // MARK: Send button — coral when active
    private var sendButton: some View {
        Button(action: send) {
            Image(systemName: "arrow.up")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(canSend ? .white : .secondary.opacity(0.4))
                .frame(width: 30, height: 30)
                .background(canSend ? Color.accentCoral : Color.primary.opacity(0.07))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!canSend)
    }

    // MARK: Local availability notice — small, quiet, with one-click fallback
    private var localUnavailableNotice: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 10))
                .foregroundColor(.orange)
            Text(LocalModelClient.shared.availability.unavailableReason ?? "On-device model unavailable.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
            Spacer()
            Button("Learn more") { showLocalHelp = true }
                .buttonStyle(PlainButtonStyle())
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .popover(isPresented: $showLocalHelp, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("On-device model (Apple Foundation Models)")
                            .font(.headline)
                        Text(
                            """
                            Local inference uses Apple Intelligence and requires:
                            • An Apple Silicon Mac eligible for Apple Intelligence
                            • Apple Intelligence enabled in System Settings
                            • The on-device model downloaded and ready

                            \(LocalModelClient.shared.availability.unavailableReason ?? "")

                            Until then, cmdtab uses your configured cloud API.
                            """
                        )
                        .font(.callout)
                        .foregroundColor(.secondary)

                        #if os(macOS)
                        Button("Open System Settings…") {
                            // Apple Intelligence & Siri pane
                            if let url = URL(
                                string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")
                            {
                                NSWorkspace.shared.open(url)
                            }
                            showLocalHelp = false
                        }
                        .controlSize(.small)
                        #endif
                    }
                    .padding(16)
                    .frame(width: 340)
                }

            Button("Use Cloud") {
                viewModel.isLocalModelSelected = false
            }
            .buttonStyle(PlainButtonStyle())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color.accentCoral)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color.orange.opacity(0.06))
    }

    // MARK: Missing API key notice — routes to Settings → Cloud Model
    private var missingKeyNotice: some View {
        HStack(spacing: 6) {
            Image(systemName: "key")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text("Add your API key to use cloud models.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Button("Add API key") {
                viewModel.openSettings(tab: "cloudmodel")
            }
            .buttonStyle(PlainButtonStyle())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color.accentCoral)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.03))
    }

    private var canSend: Bool {
        !inputMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isStreaming
    }

    private func send() {
        viewModel.sendMessage(content: inputMessageText)
        inputMessageText = ""
    }
}

// MARK: - Inline Preset Chip (inside composer)
private struct InlinePresetChip: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(isHovered ? Color.accentCoral : .secondary)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(isHovered ? 0.08 : 0.05))
            .overlay(
                Capsule()
                    .stroke(Color.hairline, lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { h in withAnimation(.easeOut(duration: 0.1)) { isHovered = h } }
    }
}

// MARK: - Corner radius helper
extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

struct RectCorner: OptionSet {
    let rawValue: Int
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    static let all: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

private struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: RectCorner

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tl = corners.contains(.topLeft) ? radius : 0
        let tr = corners.contains(.topRight) ? radius : 0
        let bl = corners.contains(.bottomLeft) ? radius : 0
        let br = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        if tr > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90),
                endAngle: .degrees(0), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        if br > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0),
                endAngle: .degrees(90), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        if bl > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90),
                endAngle: .degrees(180), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        if tl > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180),
                endAngle: .degrees(270), clockwise: false)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Focus-tick modifier
extension View {
    @ViewBuilder
    func onFocusTick(of value: Int, perform action: @escaping () -> Void) -> some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            self.onChange(of: value) { _, _ in action() }
        } else {
            self.onChange(of: value) { _ in action() }
        }
    }
}
