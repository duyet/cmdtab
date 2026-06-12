import SwiftUI

/// Renders typed agent output blocks derived from markdown content.
struct AgentResponseView: View {
    let content: String
    let fontScale: Double

    private let blocks: [AgentResponseBlock]

    init(content: String, renderBlocks: [AgentResponseBlock]? = nil, fontScale: Double) {
        self.content = content
        self.fontScale = fontScale
        self.blocks = renderBlocks ?? AgentResponseBlock.parse(content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(blocks) { block in
                blockView(block)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: AgentResponseBlock) -> some View {
        switch block.kind {
        case .text:
            MessageMarkdownView(content: block.content, fontScale: fontScale)
        case .image:
            MessageMarkdownView(content: block.content, fontScale: fontScale)
        case .tool:
            ToolBlockCard(block: block)
        case .chart:
            ChartBlockCard(block: block, fontScale: fontScale)
        }
    }
}

private struct ToolBlockCard: View {
    let block: AgentResponseBlock

    private var status: String {
        block.metadata["status"] ?? block.metadata["state"] ?? "completed"
    }

    private var toolName: String {
        block.metadata["name"] ?? block.metadata["tool"] ?? block.title ?? "Tool"
    }

    private var input: String? { block.metadata["input"] ?? block.metadata["arguments"] }
    private var output: String? { block.metadata["output"] ?? block.metadata["result"] }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .font(.system(size: AppFont.pt(13), weight: .semibold))
                    .foregroundColor(statusColor)
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(toolName)
                        .font(.system(size: AppFont.pt(12.5), weight: .semibold))
                        .foregroundColor(.primary)
                    Text(status.capitalized)
                        .font(.system(size: AppFont.pt(10.5)))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }

            if let input {
                fieldRow("Input", input)
            }
            if let output {
                fieldRow("Result", output)
            }
            if input == nil && output == nil {
                Text(block.content)
                    .font(.system(size: AppFont.pt(11.5), design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.hairline))
    }

    private func fieldRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: AppFont.pt(9.5), weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: AppFont.pt(11.5), design: .monospaced))
                .foregroundColor(.primary.opacity(0.85))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusIcon: String {
        let lower = status.lowercased()
        if lower.contains("fail") || lower.contains("error") {
            return "exclamationmark.triangle.fill"
        }
        if lower.contains("running") || lower.contains("start") {
            return "arrow.triangle.2.circlepath"
        }
        return "checkmark.circle.fill"
    }

    private var statusColor: Color {
        let lower = status.lowercased()
        if lower.contains("fail") || lower.contains("error") {
            return .red
        }
        if lower.contains("running") || lower.contains("start") {
            return .secondary
        }
        return .green
    }
}

private struct ChartBlockCard: View {
    let block: AgentResponseBlock
    let fontScale: Double

    private struct DataPoint: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
    }

    private var points: [DataPoint] {
        Self.parsePoints(from: block.content)
    }

    var body: some View {
        if block.language == "mermaid" {
            MermaidView(source: block.content, fontScale: fontScale)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: AppFont.pt(13), weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 18, height: 18)
                    Text(block.title ?? "Chart")
                        .font(.system(size: AppFont.pt(12.5), weight: .semibold))
                    Spacer(minLength: 0)
                }

                if points.isEmpty {
                    Text(block.content)
                        .font(.system(size: AppFont.pt(11.5), design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    barChart(points)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.hairline))
        }
    }

    private func barChart(_ points: [DataPoint]) -> some View {
        let maxValue = max(points.map(\.value).max() ?? 1, 1)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(points.prefix(8)) { point in
                VStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.72))
                        .frame(height: max(4, CGFloat(point.value / maxValue) * 88))
                    Text(point.label)
                        .font(.system(size: AppFont.pt(9.5)))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 48)
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(point.label): \(point.value)")
            }
        }
        .frame(height: 124)
        .padding(.top, 2)
    }

    private static func parsePoints(from text: String) -> [DataPoint] {
        if let jsonPoints = parseJSONPoints(from: text), !jsonPoints.isEmpty {
            return jsonPoints
        }

        return text.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let separator = trimmed.firstIndex(where: { $0 == ":" || $0 == "," }) else {
                return nil
            }
            let label = trimmed[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawValue = trimmed[trimmed.index(after: separator)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty, let value = Double(rawValue) else { return nil }
            return DataPoint(label: label, value: value)
        }
    }

    private static func parseJSONPoints(from text: String) -> [DataPoint]? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        let rows: [[String: Any]]
        if let array = object as? [[String: Any]] {
            rows = array
        } else if let dictionary = object as? [String: Any],
                  let array = dictionary["data"] as? [[String: Any]] {
            rows = array
        } else {
            return nil
        }

        return rows.compactMap { row in
            let label = (row["label"] ?? row["name"] ?? row["x"]).map { "\($0)" } ?? ""
            let rawValue = row["value"] ?? row["y"]
            let value: Double?
            if let double = rawValue as? Double {
                value = double
            } else if let int = rawValue as? Int {
                value = Double(int)
            } else if let string = rawValue as? String {
                value = Double(string)
            } else {
                value = nil
            }
            guard !label.isEmpty, let value else { return nil }
            return DataPoint(label: label, value: value)
        }
    }
}
