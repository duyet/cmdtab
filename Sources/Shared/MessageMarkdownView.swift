import SwiftUI

/// Render a single line/run of text through Apple's inline markdown parser
/// (bold, italic, code spans, links) with whitespace preserved. Falls back to
/// plain text if parsing fails. Shared by every block view in this file.
private func inlineMarkdown(_ text: String) -> AttributedString {
    if let attr = try? AttributedString(
        markdown: text,
        options: AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace))
    {
        return attr
    }
    return AttributedString(text)
}

// MARK: - Block-level markdown for chat messages
/// Renders assistant/user message content as markdown blocks: fenced code
/// blocks become monospaced cards with a copy affordance, `#` headings get
/// heading type sizes, lists render with proper markers, blockquotes get an
/// accent bar, tables render as grids, and everything else uses Apple's
/// inline markdown parser (bold, italic, code spans, links).
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
            Text(inlineMarkdown(block.text))
                .font(.system(size: headingSize(level) * fontScale, weight: .semibold))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .multilineTextAlignment(alignment)
        case .paragraph:
            Text(inlineMarkdown(block.text))
                .font(.system(size: 13 * fontScale))
                .foregroundColor(.primary)
                .lineSpacing(4)
                .textSelection(.enabled)
                .multilineTextAlignment(alignment)
        case .unorderedList:
            UnorderedListView(text: block.text, fontScale: fontScale)
        case .orderedList:
            OrderedListView(text: block.text, fontScale: fontScale)
        case .blockquote:
            BlockquoteView(text: block.text, fontScale: fontScale)
        case .table:
            TableView(text: block.text, fontScale: fontScale)
        case .horizontalRule:
            HorizontalRuleView()
        }
    }

    private func headingSize(_ level: Int) -> Double {
        switch level {
        case 1: return 19
        case 2: return 16.5
        default: return 14.5
        }
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

// MARK: - Unordered list
private struct UnorderedListView: View {
    let text: String
    let fontScale: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .font(.system(size: 13 * fontScale))
                        .foregroundColor(.secondary)
                        .frame(width: 12, alignment: .leading)
                    Text(inlineMarkdown(item))
                        .font(.system(size: 13 * fontScale))
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var items: [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            // Strip leading "- ", "* ", "+ "
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") { return String(trimmed.dropFirst(2)) }
            if trimmed.hasPrefix("* ") { return String(trimmed.dropFirst(2)) }
            if trimmed.hasPrefix("+ ") { return String(trimmed.dropFirst(2)) }
            return String(trimmed)
        }
    }
}

// MARK: - Ordered list
private struct OrderedListView: View {
    let text: String
    let fontScale: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.system(size: 13 * fontScale, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .trailing)
                    Text(inlineMarkdown(item))
                        .font(.system(size: 13 * fontScale))
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var items: [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Strip leading "1. ", "2. ", etc.
            let digits = trimmed.prefix(while: { $0.isNumber })
            let rest = trimmed.dropFirst(digits.count)
            if rest.hasPrefix(". ") { return String(rest.dropFirst(2)) }
            return String(trimmed)
        }
    }
}

// MARK: - Blockquote
private struct BlockquoteView: View {
    let text: String
    let fontScale: Double

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentCoral.opacity(0.6))
                .frame(width: 3)

            Text(inlineMarkdown(text))
                .font(.system(size: 13 * fontScale))
                .foregroundColor(.primary.opacity(0.85))
                .lineSpacing(4)
                .textSelection(.enabled)
                .padding(.leading, 12)
                .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Table
private struct TableView: View {
    let text: String
    let fontScale: Double

    private var rows: [[String]] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !MarkdownBlock.isTableSeparator(String($0)) }
            .map { line in
                line.split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header = rows.first {
                // Header row
                HStack(spacing: 0) {
                    ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
                        Text(cell)
                            .font(.system(size: 11 * fontScale, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    }
                }
                .background(Color.primary.opacity(0.05))

                // Data rows
                ForEach(Array(rows.dropFirst().enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(inlineMarkdown(cell))
                                .font(.system(size: 12 * fontScale))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                        }
                    }
                    .background(Color.cardSurface)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.hairline))
    }
}

// MARK: - Horizontal rule
private struct HorizontalRuleView: View {
    var body: some View {
        Rectangle()
            .fill(Color.hairline)
            .frame(height: 1)
            .padding(.vertical, 4)
    }
}
