import Foundation

// MARK: - Block parser
/// Minimal block segmentation: fenced code (```lang … ```), ATX headings,
/// and paragraph runs. Streaming-safe — an unterminated fence renders as a
/// code block so output doesn't flicker between styles mid-stream.
struct MarkdownBlock: Identifiable {
    enum Kind {
        case paragraph
        case heading(Int)
        case code(String?)
    }

    let id: Int
    let kind: Kind
    let text: String

    static func parse(_ content: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var codeLines: [String] = []
        var codeLanguage: String? = nil
        var inCode = false

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

        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if inCode {
                    flushCode()
                    inCode = false
                } else {
                    flushParagraph()
                    inCode = true
                    let lang = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                    codeLanguage = lang.isEmpty ? nil : lang
                }
                continue
            }
            if inCode {
                codeLines.append(String(line))
                continue
            }
            if let level = headingLevel(trimmed) {
                flushParagraph()
                let text = trimmed.drop(while: { $0 == "#" })
                    .trimmingCharacters(in: .whitespaces)
                blocks.append(MarkdownBlock(id: blocks.count, kind: .heading(level), text: text))
                continue
            }
            if trimmed.isEmpty {
                flushParagraph()
            } else {
                paragraph.append(String(line))
            }
        }
        if inCode { flushCode() } else { flushParagraph() }
        return blocks
    }

    private static func headingLevel(_ line: String) -> Int? {
        guard line.hasPrefix("#") else { return nil }
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard hashes <= 6 else { return nil }
        let after = line.dropFirst(hashes)
        guard after.first == " " else { return nil }
        return hashes
    }
}
