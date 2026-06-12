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
            if language?.lowercased() == "mermaid", !block.text.isEmpty {
                MermaidView(source: block.text, fontScale: fontScale)
            } else if ["math", "latex", "tex", "katex"].contains(language?.lowercased() ?? ""),
                !block.text.isEmpty
            {
                MathView(source: block.text, fontScale: fontScale)
            } else {
                CodeBlockView(code: block.text, language: language, fontScale: fontScale)
            }
        case .heading(let level):
            Text(inlineMarkdown(block.text))
                .font(.system(size: headingSize(level), weight: .semibold))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .multilineTextAlignment(alignment)
        case .paragraph:
            Text(inlineMarkdown(block.text))
                .font(.system(size: AppFont.pt(13)))
                .foregroundColor(.primary)
                .lineSpacing(4)
                .textSelection(.enabled)
                .multilineTextAlignment(alignment)
        case .unorderedList, .orderedList:
            ListBlockView(text: block.text, fontScale: fontScale)
        case .blockquote:
            BlockquoteView(text: block.text, fontScale: fontScale)
        case .table:
            TableView(text: block.text, fontScale: fontScale)
        case .horizontalRule:
            HorizontalRuleView()
        case .math:
            MathView(source: block.text, fontScale: fontScale)
        case .image:
            MarkdownImageView(line: block.text, fontScale: fontScale)
        }
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return AppFont.pt(19)
        case 2: return AppFont.pt(16.5)
        default: return AppFont.pt(14.5)
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
                    .font(.system(size: AppFont.pt(10), weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: copyCode) {
                    Image(systemName: copied ? "checkmark" : "square.on.square")
                        .font(.system(size: AppFont.pt(10)))
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
                    .font(.system(size: AppFont.pt(12), design: .monospaced))
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

// MARK: - List block (nested, ordered/unordered/task items mixed)
/// Renders each list line with its own marker: real source numbers for
/// ordered items, level-aware bullets (• ◦ ▪) for unordered, and SF-symbol
/// checkboxes for task items (- [ ] / - [x]). Indentation in the source
/// (2 spaces per level) becomes visual nesting.
private struct ListBlockView: View {
    let text: String
    let fontScale: Double

    private struct Item {
        let level: Int
        let marker: Marker
        let content: String

        enum Marker {
            case bullet
            case number(String)
            case checkbox(checked: Bool)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    markerView(item)
                    Text(inlineMarkdown(item.content))
                        .font(.system(size: AppFont.pt(13)))
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                }
                .padding(.leading, CGFloat(item.level) * 16)
            }
        }
    }

    @ViewBuilder
    private func markerView(_ item: Item) -> some View {
        switch item.marker {
        case .bullet:
            Text(bulletSymbol(for: item.level))
                .font(.system(size: AppFont.pt(13)))
                .foregroundColor(.secondary)
                .frame(width: 14, alignment: .center)
        case .number(let n):
            Text("\(n).")
                .font(.system(size: AppFont.pt(13), weight: .medium))
                .foregroundColor(.secondary)
                .frame(minWidth: 20, alignment: .trailing)
        case .checkbox(let checked):
            Image(systemName: checked ? "checkmark.square.fill" : "square")
                .font(.system(size: AppFont.pt(12)))
                .foregroundColor(checked ? Color.accentCoral : .secondary)
                .frame(width: 14, alignment: .center)
                .padding(.top, 1)
        }
    }

    private func bulletSymbol(for level: Int) -> String {
        switch level {
        case 0: return "•"
        case 1: return "◦"
        default: return "▪"
        }
    }

    private var items: [Item] {
        text.split(separator: "\n", omittingEmptySubsequences: true).map { line in
            let leadingSpaces = line.prefix(while: { $0 == " " }).count
            let level = min(leadingSpaces / 2, 3)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Unordered marker
            for prefix in ["- ", "* ", "+ "] where trimmed.hasPrefix(prefix) {
                var rest = String(trimmed.dropFirst(prefix.count))
                // Task item: [ ] / [x] / [X]
                if rest.hasPrefix("[ ] ") {
                    rest = String(rest.dropFirst(4))
                    return Item(level: level, marker: .checkbox(checked: false), content: rest)
                }
                if rest.hasPrefix("[x] ") || rest.hasPrefix("[X] ") {
                    rest = String(rest.dropFirst(4))
                    return Item(level: level, marker: .checkbox(checked: true), content: rest)
                }
                return Item(level: level, marker: .bullet, content: rest)
            }

            // Ordered marker — keep the source's own number
            let digits = trimmed.prefix(while: { $0.isNumber })
            if !digits.isEmpty, trimmed.dropFirst(digits.count).hasPrefix(". ") {
                let rest = String(trimmed.dropFirst(digits.count + 2))
                return Item(level: level, marker: .number(String(digits)), content: rest)
            }

            return Item(level: level, marker: .bullet, content: String(trimmed))
        }
    }
}

// MARK: - Image block
/// Renders a standalone `![alt](url)` line. Remote images load async with a
/// progress placeholder; failures fall back to a quiet alt-text card.
private struct MarkdownImageView: View {
    let line: String
    let fontScale: Double

    var body: some View {
        if let parts = MarkdownBlock.imageParts(line), let url = URL(string: parts.url) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.hairline))
                case .failure:
                    fallbackCard(parts.alt)
                default:
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Color.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .accessibilityLabel(parts.alt.isEmpty ? "Image" : parts.alt)
        } else {
            Text(line)
                .font(.system(size: AppFont.pt(13)))
                .foregroundColor(.primary)
        }
    }

    private func fallbackCard(_ alt: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "photo")
                .font(.system(size: AppFont.pt(11)))
                .foregroundColor(.secondary)
            Text(alt.isEmpty ? "Image unavailable" : alt)
                .font(.system(size: AppFont.pt(12)))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.hairline))
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
                .font(.system(size: AppFont.pt(13)))
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
                            .font(.system(size: AppFont.pt(11), weight: .semibold))
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
                                .font(.system(size: AppFont.pt(12)))
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
