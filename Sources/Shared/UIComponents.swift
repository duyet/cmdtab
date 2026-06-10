import SwiftUI

// MARK: - Pill Tab Bar
/// Unified tab/selector component used across the app.
/// Selected item: light-gray capsule pill + primary text.
/// Unselected: secondary text, no background. Hover: slightly darker.
struct PillTabBar<T: Hashable>: View {
    struct Item {
        let value: T
        let label: String
        let icon: String?  // optional SF Symbol name

        init(value: T, label: String, icon: String? = nil) {
            self.value = value
            self.label = label
            self.icon = icon
        }
    }

    let items: [Item]
    @Binding var selection: T
    /// Track style: items sit on a full-width gray track and the selected
    /// item gets a white (cardSurface) pill — like the Claude/Codex sidebar
    /// switcher. Non-track style renders bare pills (used in Settings).
    var track: Bool = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items.indices, id: \.self) { i in
                PillTabItem(
                    item: items[i],
                    isSelected: items[i].value == selection,
                    track: track,
                    onTap: { selection = items[i].value }
                )
                // Selected pill hugs its icon + label; unselected items share
                // the remaining track width as generous icon hit targets.
                .frame(maxWidth: track && items[i].value != selection ? .infinity : nil)
            }
        }
        .padding(track ? 3 : 0)
        .background(track ? Color.primary.opacity(0.05) : Color.clear)
        .cornerRadius(track ? 10 : 0)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct PillTabItem<T: Hashable>: View {
    let item: PillTabBar<T>.Item
    let isSelected: Bool
    var track: Bool = false
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            Group {
                if isSelected {
                    // Selected: icon + label, hugging its content
                    HStack(spacing: 5) {
                        if let icon = item.icon {
                            Image(systemName: icon)
                                .font(.system(size: 11))
                        }
                        Text(item.label)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                    }
                } else if let icon = item.icon {
                    // Unselected with icon: icon only — no wrapping
                    Image(systemName: icon)
                        .font(.system(size: 13))
                } else {
                    // Unselected, no icon: short label
                    Text(item.label)
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
            }
            .foregroundColor(isSelected ? .primary : (isHovered ? .primary.opacity(0.75) : .secondary))
            .padding(.horizontal, track ? (isSelected ? 14 : 8) : 9)
            .padding(.vertical, track ? 6 : 5)
            .frame(maxWidth: track && !isSelected ? .infinity : nil)
            .background(
                isSelected
                    ? (track ? Color.cardSurface : Color.primary.opacity(0.10))
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: track ? 8 : 12))
            .overlay(
                RoundedRectangle(cornerRadius: track ? 8 : 12)
                    .stroke(isSelected && track ? Color.hairline : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .fixedSize(horizontal: !track || isSelected, vertical: true)
        .onHover { h in withAnimation(.easeOut(duration: 0.1)) { isHovered = h } }
    }
}

// MARK: - Keycap Badge
/// Small rounded keycap showing a keyboard shortcut, e.g. "⌘T" or a number.
struct KeycapBadge: View {
    let label: String
    var emphasized: Bool = false

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.keycapFill)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.cardStroke, lineWidth: emphasized ? 1 : 0)
            )
            .cornerRadius(5)
    }
}

// MARK: - Number Keycap
/// Square rounded badge showing a single number for quick-action cards.
struct NumberKeycap: View {
    let number: Int

    var body: some View {
        Text("\(number)")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(.secondary)
            .frame(width: 20, height: 20)
            .background(Color.keycapFill)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.cardStroke, lineWidth: 1)
            )
            .cornerRadius(5)
    }
}

// MARK: - Plain Icon Button
/// A bare gray SF Symbol button used for toolbar-style affordances.
struct PlainIconButton: View {
    let systemName: String
    var size: CGFloat = 12
    var help: String = ""
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size))
                .foregroundColor(disabled ? .secondary.opacity(0.35) : .secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(disabled)
        .plainFocusEffectDisabled()
        .accessibilityLabel(help.isEmpty ? systemName : help)
        #if os(macOS)
        .help(help)
        #endif
    }
}

extension View {
    /// Removes the system focus ring on bare icon buttons, where a permanent
    /// accent-tinted focus box looks like an unintended highlight.
    @ViewBuilder
    func plainFocusEffectDisabled() -> some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            self.focusEffectDisabled()
        } else {
            self
        }
    }
}

// MARK: - Avatar Circle
/// Circular avatar with two-letter initials on a colored background.
struct AvatarCircle: View {
    let initials: String
    var diameter: CGFloat = 28
    var color: Color = .blue

    var body: some View {
        Text(initials)
            .font(.system(size: diameter * 0.42, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .frame(width: diameter, height: diameter)
            .background(color)
            .clipShape(Circle())
    }
}
