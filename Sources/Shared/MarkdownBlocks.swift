import Foundation

// MARK: - Block parser
/// Block-level markdown segmentation: fenced code, ATX headings, lists,
/// blockquotes, tables, horizontal rules, and paragraph runs.
/// Streaming-safe — an unterminated fence renders as a code block so
/// output doesn't flicker between styles mid-stream.
struct MarkdownBlock: Identifiable {
    enum Kind {
        case paragraph
        case heading(Int)
        case code(String?)
        case unorderedList
        case orderedList
        case blockquote
        case table
        case horizontalRule
    }

    let id: Int
    let kind: Kind
    /// For paragraphs/headings/blockquotes: the raw text (may contain inline markdown).
    /// For lists: individual lines joined with newline (each starts with marker).
    /// For code: the raw code content.
    /// For tables: pipe-delimited rows joined with newline.
    let text: String

    static func parse(_ content: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var codeLines: [String] = []
        var codeLanguage: String? = nil
        var inCode = false
        var listLines: [String] = []
        var isOrdered = false
        var inList = false
        var quoteLines: [String] = []
        var inQuote = false
        var tableLines: [String] = []
        var inTable = false

        func flushParagraph() {
            let text = paragraph.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(MarkdownBlock(id: blocks.count, kind: .paragraph, text: text))
            }
            paragraph = []
        }

        func flushCode() {
            blocks.append(
                MarkdownBlock(
                    id: blocks.count, kind: .code(codeLanguage),
                    text: codeLines.joined(separator: "\n")))
            codeLines = []
            codeLanguage = nil
        }

        func flushList() {
            let text = listLines.joined(separator: "\n")
            blocks.append(MarkdownBlock(
                id: blocks.count,
                kind: isOrdered ? .orderedList : .unorderedList,
                text: text))
            listLines = []
            inList = false
        }

        func flushQuote() {
            let text = quoteLines.joined(separator: "\n")
            blocks.append(MarkdownBlock(id: blocks.count, kind: .blockquote, text: text))
            quoteLines = []
            inQuote = false
        }

        func flushTable() {
            let text = tableLines.joined(separator: "\n")
            blocks.append(MarkdownBlock(id: blocks.count, kind: .table, text: text))
            tableLines = []
            inTable = false
        }

        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Inside fenced code block — only ``` closes it
            if inCode {
                if trimmed.hasPrefix("```") {
                    flushCode()
                    inCode = false
                } else {
                    codeLines.append(String(line))
                }
                continue
            }

            // Fenced code start
            if trimmed.hasPrefix("```") {
                if inList { flushList() }
                if inQuote { flushQuote() }
                if inTable { flushTable() }
                flushParagraph()
                inCode = true
                let lang = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                codeLanguage = lang.isEmpty ? nil : lang
                continue
            }

            // Horizontal rule: ---, ***, ___ (3+ chars, nothing else on line)
            if isHorizontalRule(trimmed) {
                if inList { flushList() }
                if inQuote { flushQuote() }
                if inTable { flushTable() }
                flushParagraph()
                blocks.append(MarkdownBlock(id: blocks.count, kind: .horizontalRule, text: ""))
                continue
            }

            // ATX headings
            if let level = headingLevel(trimmed) {
                if inList { flushList() }
                if inQuote { flushQuote() }
                if inTable { flushTable() }
                flushParagraph()
                let text = trimmed.drop(while: { $0 == "#" })
                    .trimmingCharacters(in: .whitespaces)
                blocks.append(MarkdownBlock(id: blocks.count, kind: .heading(level), text: text))
                continue
            }

            // Blockquote
            if trimmed.hasPrefix(">") {
                if inList { flushList() }
                if inTable { flushTable() }
                flushParagraph()
                // Strip leading "> " or ">"
                let content = trimmed.drop(while: { $0 == ">" || $0 == " " })
                    .trimmingCharacters(in: .whitespaces)
                quoteLines.append(content)
                inQuote = true
                continue
            }

            // Table row (contains | with at least one cell)
            if trimmed.hasPrefix("|"), trimmed.hasSuffix("|"), trimmed.contains("-"),
                isTableSeparator(trimmed)
            {
                // This is a separator line — skip it, we already captured the header
                if inTable { continue }
            }
            if trimmed.hasPrefix("|"), trimmed.filter({ $0 == "|" }).count >= 2 {
                if inList { flushList() }
                if inQuote { flushQuote() }
                flushParagraph()
                tableLines.append(trimmed)
                inTable = true
                continue
            }

            // Unordered list: - , *, + followed by space
            if isUnorderedListItem(trimmed) {
                if inTable { flushTable() }
                if inQuote { flushQuote() }
                flushParagraph()
                listLines.append(trimmed)
                inList = true
                isOrdered = false
                continue
            }

            // Ordered list: 1. 2. etc.
            if isOrderedListItem(trimmed) {
                if inTable { flushTable() }
                if inQuote { flushQuote() }
                flushParagraph()
                listLines.append(trimmed)
                inList = true
                isOrdered = true
                continue
            }

            // Blank line — terminate current block
            if trimmed.isEmpty {
                if inList { flushList() }
                if inQuote { flushQuote() }
                if inTable { flushTable() }
                flushParagraph()
                continue
            }

            // Regular text — flush any open block type before accumulating
            if inList { flushList() }
            if inQuote { flushQuote() }
            if inTable { flushTable() }

            paragraph.append(String(line))
        }

        // Flush remaining
        if inCode { flushCode() }
        if inList { flushList() }
        if inQuote { flushQuote() }
        if inTable { flushTable() }
        flushParagraph()
        return blocks
    }

    // MARK: - Detection helpers

    private static func headingLevel(_ line: String) -> Int? {
        guard line.hasPrefix("#") else { return nil }
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard hashes <= 6 else { return nil }
        let after = line.dropFirst(hashes)
        guard after.first == " " else { return nil }
        return hashes
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        let stripped = line.trimmingCharacters(in: .whitespaces)
        guard stripped.count >= 3 else { return false }
        // Allow spaces between dash/star/underscore
        let noSpaces = stripped.filter { $0 != " " }
        guard noSpaces.count >= 3 else { return false }
        let uniqueChars = Set(noSpaces)
        return uniqueChars.count == 1 && (uniqueChars.first == "-" || uniqueChars.first == "*" || uniqueChars.first == "_")
    }

    private static func isUnorderedListItem(_ line: String) -> Bool {
        guard line.count >= 2 else { return false }
        let first = line.first
        guard first == "-" || first == "*" || first == "+" else { return false }
        let after = line.dropFirst()
        return after.first == " "
    }

    private static func isOrderedListItem(_ line: String) -> Bool {
        // Match: digit(s) + "." + space
        let prefix = line.prefix(while: { $0.isNumber })
        guard prefix.count >= 1, prefix.count <= 3 else { return false }
        let rest = line.dropFirst(prefix.count)
        guard rest.first == "." else { return false }
        let afterDot = rest.dropFirst()
        return afterDot.first == " "
    }

    static func isTableSeparator(_ line: String) -> Bool {
        // |---|---|  or  |:---:|:---:|
        let stripped = line
            .replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespaces)
        return stripped.isEmpty
    }
}
