import SwiftUI

// MARK: - Segmented Tab Bar
/// Native segmented selector used across the app. Renders as the system
/// segmented control (`Picker(.segmented)`) so it matches stock macOS/iOS.
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
    /// Retained for source compatibility; the native segmented control owns its
    /// own appearance, so this no longer changes styling.
    var track: Bool = false

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(items.indices, id: \.self) { i in
                let item = items[i]
                if let icon = item.icon {
                    Label(item.label, systemImage: icon).tag(item.value)
                } else {
                    Text(item.label).tag(item.value)
                }
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
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
        .buttonStyle(.borderless)
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
