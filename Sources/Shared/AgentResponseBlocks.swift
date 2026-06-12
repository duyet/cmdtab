import Foundation

/// Typed display blocks derived from an assistant markdown response.
///
/// Persisted messages stay as plain `ChatMessage.content`; this parser is a
/// rendering boundary so older conversations remain valid while the UI can
/// present tool activity, charts, images, and text as separate agent outputs.
public struct AgentResponseBlock: Codable, Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable {
        case text
        case tool
        case chart
        case image
    }

    public let id: Int
    public let kind: Kind
    public let content: String
    public let language: String?
    public let title: String?
    public let metadata: [String: String]
    public let imageAlt: String?
    public let imageURL: String?

    public init(
        id: Int,
        kind: Kind,
        content: String,
        language: String? = nil,
        title: String? = nil,
        metadata: [String: String] = [:],
        imageAlt: String? = nil,
        imageURL: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.content = content
        self.language = language
        self.title = title
        self.metadata = metadata
        self.imageAlt = imageAlt
        self.imageURL = imageURL
    }

    public static func parse(_ markdown: String) -> [AgentResponseBlock] {
        var blocks: [AgentResponseBlock] = []
        var textParts: [String] = []

        func flushText() {
            let text = textParts.joined(separator: "\n\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            blocks.append(
                AgentResponseBlock(
                    id: blocks.count,
                    kind: .text,
                    content: text
                ))
            textParts = []
        }

        for block in MarkdownBlock.parse(markdown) {
            switch block.kind {
            case .image:
                flushText()
                let parts = MarkdownBlock.imageParts(block.text)
                blocks.append(
                    AgentResponseBlock(
                        id: blocks.count,
                        kind: .image,
                        content: block.text,
                        title: parts?.alt,
                        imageAlt: parts?.alt,
                        imageURL: parts?.url
                    ))
            case .code(let language):
                let normalized = normalizedLanguage(language)
                if isToolLanguage(normalized) {
                    flushText()
                    blocks.append(
                        AgentResponseBlock(
                            id: blocks.count,
                            kind: .tool,
                            content: block.text,
                            language: normalized,
                            title: toolTitle(from: block.text, language: normalized),
                            metadata: keyValueMetadata(from: block.text)
                        ))
                } else if isChartLanguage(normalized) {
                    flushText()
                    blocks.append(
                        AgentResponseBlock(
                            id: blocks.count,
                            kind: .chart,
                            content: block.text,
                            language: normalized,
                            title: chartTitle(from: block.text)
                        ))
                } else {
                    textParts.append(markdownText(for: block))
                }
            default:
                textParts.append(markdownText(for: block))
            }
        }

        flushText()
        return blocks
    }

    private static func normalizedLanguage(_ language: String?) -> String? {
        language?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func isToolLanguage(_ language: String?) -> Bool {
        guard let language else { return false }
        return [
            "tool",
            "tools",
            "tool-call",
            "tool-use",
            "tool-result",
            "function",
            "function-call",
            "calculator",
            "system_clock",
            "system-clock",
            "clock",
        ].contains(language)
    }

    private static func isChartLanguage(_ language: String?) -> Bool {
        guard let language else { return false }
        return [
            "chart",
            "bar-chart",
            "barchart",
            "mermaid",
            "vega",
            "vega-lite",
        ].contains(language)
    }

    private static func keyValueMetadata(from text: String) -> [String: String] {
        var metadata: [String: String] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let value = line[line.index(after: colon)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty, !value.isEmpty {
                metadata[key] = value
            }
        }
        return metadata
    }

    private static func toolTitle(from text: String, language: String?) -> String {
        let metadata = keyValueMetadata(from: text)
        if let name = metadata["name"] ?? metadata["tool"] {
            return name
        }
        if let language, !["tool", "tools", "tool-call", "tool-use", "tool-result"].contains(language) {
            return language.replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        }
        return "Tool"
    }

    private static func chartTitle(from text: String) -> String {
        let metadata = keyValueMetadata(from: text)
        return metadata["title"] ?? "Chart"
    }

    private static func markdownText(for block: MarkdownBlock) -> String {
        switch block.kind {
        case .paragraph:
            return block.text
        case .heading(let level):
            return String(repeating: "#", count: level) + " " + block.text
        case .code(let language):
            let info = language.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
            return "```\(info)\n\(block.text)\n```"
        case .unorderedList, .orderedList, .blockquote, .table:
            return block.text
        case .horizontalRule:
            return "---"
        case .math:
            return "$$\n\(block.text)\n$$"
        case .image:
            return block.text
        }
    }
}
