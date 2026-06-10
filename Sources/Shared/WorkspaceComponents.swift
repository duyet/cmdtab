import SwiftUI

// MARK: - Clipboard Quote Card
/// Hero landing card: shows clipboard content as a quote when text is detected.
/// Rounded cardSurface card with 3-line monospaced preview, type badge, coral dot.
struct ClipboardQuoteCard: View {
    @ObservedObject var viewModel: MainViewModel

    private var trimmedText: String {
        viewModel.detectedClipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var contentType: String {
        let text = trimmedText
        if text.hasPrefix("{") || text.hasPrefix("[") { return "json" }
        if text.lowercased().hasPrefix("select") || text.lowercased().hasPrefix("with ") { return "sql" }
        if text.contains("func ") || text.contains("def ") || text.contains("=>") { return "code" }
        if text.hasPrefix("http://") || text.hasPrefix("https://") { return "url" }
        return "text"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Badge row
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.accentCoral)
                    .frame(width: 7, height: 7)
                Text(contentType)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                Text("·")
                    .foregroundColor(.secondary)
                Text("\(trimmedText.count) chars")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
                Spacer()
                Button(action: { viewModel.dismissClipboardBanner() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Dismiss clipboard")
            }

            // Preview text
            Text(trimmedText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary.opacity(0.75))
                .lineLimit(3)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .black, location: 0.0),
                            .init(color: .black, location: 0.72),
                            .init(color: .clear, location: 1.0),
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .padding(14)
        .background(Color.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.hairline, lineWidth: 1)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }
}

// MARK: - Clipboard Detection Card (used in chat view above chat history)
/// Compact top-of-chat banner version of the clipboard card.
struct ClipboardDetectionCard: View {
    @ObservedObject var viewModel: MainViewModel

    private var trimmedText: String {
        viewModel.detectedClipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var contentType: String {
        let text = trimmedText
        if text.hasPrefix("{") || text.hasPrefix("[") { return "json" }
        if text.lowercased().hasPrefix("select") || text.lowercased().hasPrefix("with ") { return "sql" }
        if text.contains("func ") || text.contains("def ") || text.contains("=>") { return "code" }
        if text.hasPrefix("http://") || text.hasPrefix("https://") { return "url" }
        return "text"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("Clipboard detected")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Circle()
                    .fill(Color.accentCoral)
                    .frame(width: 6, height: 6)
                Text(contentType)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                Text("\(trimmedText.count) chars")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
                Button(action: { viewModel.dismissClipboardBanner() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Dismiss clipboard")
            }
            Text(trimmedText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .black, location: 0.0),
                            .init(color: .black, location: 0.7),
                            .init(color: .clear, location: 1.0),
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .padding(14)
        .background(Color.subtleFill)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.hairline, lineWidth: 1)
        )
        .cornerRadius(10)
        .padding(.horizontal, 20)
    }
}

// MARK: - Preset Chips
/// Bottom row of pill-shaped preset action buttons, wrapping into 1-2 rows.
/// Replaces the 2-column QuickActionsGrid on the landing screen.
struct PresetChips: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        ChipsFlowLayout(spacing: 8) {
            ForEach(Array(viewModel.presets.prefix(9).enumerated()), id: \.offset) { index, preset in
                PresetChip(
                    number: index + 1,
                    title: preset.name,
                    icon: preset.sfSymbol,
                    action: { viewModel.runPresetWithClipboard(index: index) }
                )
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Preset Chip
private struct PresetChip: View {
    let number: Int
    let title: String
    let icon: String
    let action: () -> Void
    #if os(macOS)
    @State private var isHovered = false
    #endif

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    #if os(macOS)
                .foregroundColor(isHovered ? Color.accentCoral : .secondary)
                    #else
                .foregroundColor(.secondary)
                    #endif
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.cardSurface)
            .overlay(
                Capsule()
                    #if os(macOS)
                .stroke(isHovered ? Color.accentCoral.opacity(0.4) : Color.hairline, lineWidth: 1)
                    #else
                .stroke(Color.hairline, lineWidth: 1)
                    #endif
            )
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) { isHovered = hovering }
        }
        #endif
    }
}

// MARK: - Flow layout for chips
/// A simple wrapping HStack layout for pill chips.
private struct ChipsFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 400
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        var rowViews: [(subview: LayoutSubview, size: CGSize)] = []

        func flushRow() {
            let totalWidth = rowViews.reduce(0) { $0 + $1.size.width } + CGFloat(max(0, rowViews.count - 1)) * spacing
            var rx = bounds.minX + (maxWidth - totalWidth) / 2  // center rows
            for (sub, size) in rowViews {
                sub.place(at: CGPoint(x: rx, y: y), proposal: ProposedViewSize(size))
                rx += size.width + spacing
            }
            rowViews = []
        }

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && !rowViews.isEmpty {
                flushRow()
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowViews.append((subview, size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        flushRow()
    }
}
