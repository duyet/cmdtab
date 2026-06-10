import SwiftUI

// MARK: - Block-level markdown for chat messages
/// Renders assistant/user message content as markdown blocks: fenced code
/// blocks become monospaced cards with a copy affordance, `#` headings get
/// heading type sizes, and everything else uses Apple's inline markdown
/// parser (bold, italic, code spans, links) with whitespace preserved.
struct MessageMarkdownView: View {
    let content: String
    let fontScale: Double
    var alignment: TextAlignment = .leading

    /// Parse once in init so body re-evaluations don't re-parse.
    private let blocks: [MarkdownBlock]

    init(content: String, fontScale: Double, alignment: TextAlignment = .leading) {
        self.content = content
        self.fontScale = fontScale
        self.alignment = alignment
        self.blocks = MarkdownBlock.parse(content)
    }

    var body: some View {
        VStack(alignment: alignment == .trailing ? .trailing : .leading, spacing: 8) {
            ForEach(blocks) { block in
                blockView(block)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block.kind {
        case .code(let language):
            CodeBlockView(code: block.text, language: language, fontScale: fontScale)
        case .heading(let level):
            Text(inline(block.text))
                .font(.system(size: headingSize(level) * fontScale, weight: .semibold))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .multilineTextAlignment(alignment)
        case .paragraph:
            Text(inline(block.text))
                .font(.system(size: 13 * fontScale))
                .foregroundColor(.primary)
                .lineSpacing(4)
                .textSelection(.enabled)
                .multilineTextAlignment(alignment)
        }
    }

    private func headingSize(_ level: Int) -> Double {
        switch level {
        case 1: return 19
        case 2: return 16.5
        default: return 14.5
        }
    }

    private func inline(_ text: String) -> AttributedString {
        if let attr = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace))
        {
            return attr
        }
        return AttributedString(text)
    }
}

// MARK: - Code block card
private struct CodeBlockView: View {
    let code: String
    let language: String?
    let fontScale: Double
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language?.isEmpty == false ? language! : "code")
                    .font(.system(size: 10 * fontScale, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: copyCode) {
                    Image(systemName: copied ? "checkmark" : "square.on.square")
                        .font(.system(size: 10))
                        .foregroundColor(copied ? Color.accentCoral : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(copied ? "Copied" : "Copy code")
                #if os(macOS)
                .help("Copy code")
                #endif
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.04))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 12 * fontScale, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(minHeight: 20, alignment: .top)
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.hairline))
    }

    private func copyCode() {
        PasteboardMonitor.shared.suppressNextEcho(text: code)
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(code, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = code
        #endif
        withAnimation { copied = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { copied = false }
        }
    }
}
