import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif

// MARK: - Composer View
/// Hero rounded card: optional clipboard quote block + preset chips row (when clipboard
/// present), multiline text field, "+" button, model picker, Local|Cloud toggle, coral send.
struct ComposerView: View {
    @ObservedObject var viewModel: MainViewModel
    // Composer-local state: keystrokes re-render ONLY this view, never the
    // whole window — keeps typing latency imperceptible.
    @State private var inputMessageText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var showLocalHelp: Bool = false
    #if os(iOS)
    @State private var photoItem: PhotosPickerItem?
    @State private var hasPhoto: Bool = false
    #endif

    private var modelOptions: [(id: String, label: String, icon: String)] {
        ModelCatalog.entries.map { (id: $0.id, label: $0.displayName, icon: $0.sfSymbol) }
    }

    private var hasClipboard: Bool {
        viewModel.isClipboardBannerVisible && !viewModel.detectedClipboardText.isEmpty
    }

    var body: some View {
        VStack(spacing: 8) {
            // 1. Clipboard/preset context — its OWN card floating above the
            //    input (Claude desktop style). Tapping a preset chip sends
            //    the quoted clipboard text immediately.
            if let sel = viewModel.selectedPresetIndex, sel < viewModel.presets.count {
                selectedPresetBlock(viewModel.presets[sel])
                    .plainCardSurface(cornerRadius: 12)
            } else if hasClipboard {
                VStack(spacing: 0) {
                    clipboardQuoteBlock
                    presetList
                }
                .plainCardSurface(cornerRadius: 12)
            }

            // 2. Input card: text field on top, controls docked inside at the
            //    bottom ("+", model badge, send).
            VStack(spacing: 0) {
                #if os(iOS)
                attachmentRow
                #endif

                textField

                // Local-model availability notice (Apple Foundation Models)
                if viewModel.isLocalModelSelected && !viewModel.isLocalModelSupported {
                    localUnavailableNotice
                }

                // Missing API key CTA (cloud mode, key checked lazily)
                if !viewModel.isLocalModelSelected && viewModel.hasLoadedApiKey && viewModel.apiKey.isEmpty {
                    missingKeyNotice
                }

                controlsRow
            }
            .plainCardSurface(cornerRadius: 12)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .onAppear { isInputFocused = true }
        .onFocusTick(of: viewModel.composerFocusTick) {
            if !viewModel.composerPrefill.isEmpty {
                inputMessageText = viewModel.composerPrefill
                viewModel.composerPrefill = ""
            }
            isInputFocused = true
        }
    }

    // MARK: Clipboard quote — single-line preview with quote glyph.
    private var clipboardQuoteBlock: some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.system(size: AppFont.pt(11)))
                .foregroundColor(.secondary.opacity(0.5))

            Text(viewModel.detectedClipboardText.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: AppFont.pt(12)))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { viewModel.dismissClipboardBanner() }) {
                Image(systemName: "xmark")
                    .font(.system(size: AppFont.pt(10)))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Dismiss clipboard")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: Selected preset header — small line above the text input
    private func selectedPresetBlock(_ preset: Preset) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: AppFont.pt(9)))
                Text(preset.name)
                    .font(.system(size: AppFont.pt(11), weight: .semibold))
                Spacer()
                Button(action: { viewModel.selectedPresetIndex = nil }) {
                    Image(systemName: "xmark")
                        .font(.system(size: AppFont.pt(9)))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Clear selected action")
            }
            .foregroundColor(Color.accentCoral)

            // Quoted clipboard line — only when clipboard text is the input.
            if hasClipboard {
                HStack(alignment: .top, spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentCoral.opacity(0.6))
                        .frame(width: 3)
                    Text(viewModel.detectedClipboardText.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: AppFont.pt(12)))
                        .foregroundColor(.primary.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04))
    }

    // MARK: Preset chips — horizontal scrolling row above the text input.
    private var presetList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(viewModel.presets.enumerated()), id: \.offset) { index, preset in
                    // Tapping a preset runs it against the clipboard right away.
                    Button { viewModel.runPresetWithClipboard(index: index) } label: {
                        HStack(spacing: 5) {
                            Image(systemName: preset.sfSymbol)
                                .font(.system(size: AppFont.pt(10)))
                            Text(preset.name)
                                .font(.system(size: AppFont.pt(12)))
                                .lineLimit(1)
                        }
                        .foregroundColor(.primary.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 10)
        }
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    #if os(iOS)
    // MARK: Attachment row — photo attach affordance above the input box.
    // NOTE: UI surface only; the cloud SSE path is text-only, so attached
    // photos are not yet sent to the model (pending vision support).
    private var attachmentRow: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                Image(systemName: "paperclip")
                    .font(.system(size: AppFont.pt(15), weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Attach photo")

            if hasPhoto {
                HStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: AppFont.pt(12)))
                    Text("Photo attached")
                        .font(.system(size: AppFont.pt(12)))
                    Button {
                        photoItem = nil
                        hasPhoto = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: AppFont.pt(10)))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Remove photo")
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.05))
                .clipShape(Capsule())
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .onChange(of: photoItem) { _, item in hasPhoto = (item != nil) }
    }
    #endif

    // MARK: Text field — multiline, reserves two lines of height so the
    // composer reads as a roomy input box (Claude desktop style).
    private var textField: some View {
        TextField("How can I help you today?", text: $inputMessageText, axis: .vertical)
            .font(.system(size: AppFont.pt(13.5)))
            .lineLimit(2...6)
            .textFieldStyle(PlainTextFieldStyle())
            .foregroundColor(.primary)
            .focused($isInputFocused)
            .onSubmit(send)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)
    }

    // MARK: Controls row — "+" quick actions, model badge, send. Docked
    // INSIDE the input card along its bottom edge.
    private var controlsRow: some View {
        HStack(spacing: 10) {
            plusButton
            Spacer()
            modelBadge
            sendButton
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .padding(.top, 2)
    }

    // MARK: Plus button — quick access to saved Quick Actions.
    private var plusButton: some View {
        Menu {
            ForEach(Array(viewModel.presets.enumerated()), id: \.offset) { index, preset in
                Button {
                    viewModel.selectedPresetIndex = index
                } label: {
                    Label(preset.name, systemImage: preset.sfSymbol)
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: AppFont.pt(9), weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 17, height: 17)
                .background(Color.primary.opacity(0.05))
                .clipShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Quick actions")
        #if os(macOS)
        .help("Quick Actions")
        #endif
    }

    // MARK: Model badge — compact icon menu combining cloud/local + model + reasoning.
    private var modelBadge: some View {
        Menu {
            Section {
                Picker("Inference", selection: $viewModel.isLocalModelSelected) {
                    Label("Cloud", systemImage: "cloud").tag(false)
                    Label(
                        viewModel.isLocalModelSupported ? "Local · On-device" : "Local · Unavailable",
                        systemImage: "cpu"
                    ).tag(true)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            if !viewModel.isLocalModelSelected {
                Section {
                    Picker("Model", selection: $viewModel.modelName) {
                        ForEach(modelOptions, id: \.id) { option in
                            Label(option.label, systemImage: option.icon).tag(option.id)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                if viewModel.modelSupportsReasoning {
                    Section {
                        Picker("Reasoning", selection: $viewModel.reasoningEffort) {
                            ForEach(ModelCatalog.reasoningEfforts, id: \.self) { effort in
                                Text(effort.capitalized).tag(effort)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.isLocalModelSelected ? "cpu" : "cloud")
                    .font(.system(size: AppFont.pt(9)))
                    .foregroundColor(.secondary)
                if !viewModel.isLocalModelSelected {
                    Text(currentModelLabel)
                        .font(.system(size: AppFont.pt(10)))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .buttonStyle(PlainButtonStyle())
        #if os(macOS)
        .help(
            viewModel.isLocalModelSelected
                ? "On-device Apple Intelligence"
                : "\(currentModelLabel) · \(URL(string: viewModel.endpointUrl)?.host ?? "cloud")"
        )
        #endif
    }

    // MARK: Model label helpers (used by modelBadge)
    private var currentModelLabel: String {
        modelOptions.first(where: { $0.id == viewModel.modelName })?.label
            ?? (viewModel.modelName.isEmpty ? "Model" : viewModel.modelName)
    }

    private var currentModelIcon: String {
        modelOptions.first(where: { $0.id == viewModel.modelName })?.icon ?? "cloud"
    }

    // MARK: Send button — coral when active
    private var sendButton: some View {
        Button(action: send) {
            Image(systemName: "arrow.up")
                .font(.system(size: AppFont.pt(10), weight: .bold))
                .foregroundColor(canSend ? .white : .secondary.opacity(0.4))
                .frame(width: 24, height: 24)
                .background(canSend ? Color.accentCoral : Color.primary.opacity(0.07))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Send message")
        .disabled(!canSend)
        #if os(iOS)
        // Haptic feedback on send for iOS
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.isStreaming)
        #endif
    }

    // MARK: Local availability notice — small, quiet, with one-click fallback
    private var localUnavailableNotice: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: AppFont.pt(10)))
                .foregroundColor(.orange)
            Text(LocalModelClient.shared.availability.unavailableReason ?? "On-device model unavailable.")
                .font(.system(size: AppFont.pt(11)))
                .foregroundColor(.secondary)
                .lineLimit(1)
            Spacer()
            Button("Learn more") { showLocalHelp = true }
                .buttonStyle(PlainButtonStyle())
                .font(.system(size: AppFont.pt(11)))
                .foregroundColor(.secondary)
                .popover(isPresented: $showLocalHelp, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("On-device model (Apple Foundation Models)")
                            .font(.headline)

                        // Live readiness audit with one-click fixes.
                        AppleIntelligenceAuditView(compact: true)

                        Text("Until on-device inference is ready, MinhAgent uses your configured cloud API.")
                            .font(.system(size: AppFont.pt(11)))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(width: 360)
                }

            Button("Use Cloud") {
                viewModel.isLocalModelSelected = false
            }
            .buttonStyle(PlainButtonStyle())
            .font(.system(size: AppFont.pt(11), weight: .semibold))
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
                .font(.system(size: AppFont.pt(10)))
                .foregroundColor(.secondary)
            Text("Add your API key to use cloud models.")
                .font(.system(size: AppFont.pt(11)))
                .foregroundColor(.secondary)
            Spacer()
            Button("Add API key") {
                viewModel.openSettings(tab: "cloudmodel")
            }
            .buttonStyle(PlainButtonStyle())
            .font(.system(size: AppFont.pt(11), weight: .semibold))
            .foregroundColor(Color.accentCoral)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.03))
    }

    private var canSend: Bool {
        guard !viewModel.isStreaming else { return false }
        if viewModel.selectedPresetIndex != nil && hasClipboard { return true }
        return !inputMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        guard canSend else { return }
        // A picked Quick Action runs against the clipboard text on send,
        // or against the typed text when there is no clipboard.
        if let sel = viewModel.selectedPresetIndex {
            if hasClipboard {
                viewModel.runPresetWithClipboard(index: sel)
            } else {
                viewModel.runPresetWithInput(index: sel, content: inputMessageText)
            }
            inputMessageText = ""
            return
        }
        viewModel.sendMessage(content: inputMessageText)
        inputMessageText = ""
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
