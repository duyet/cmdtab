import SwiftUI

// MARK: - Adaptive surfaces

/// Plain sidebar surface matching the Codex app: solid, quiet, and readable.
struct SidebarSurface: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Color.windowBackground)
    }
}

/// Raised card surface: solid system surface, light hairline border, minimal shadow.
/// Flat style matching Claude Code desktop — cards feel integrated, not floating.
struct PlainCardSurface: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            content
                .background(Color.cardSurface.opacity(0.18))
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                .clipShape(.rect(cornerRadius: cornerRadius))
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background(Color.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.hairline, lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.01), radius: 1, y: 1)
    }
}

extension View {
    func sidebarSurface() -> some View {
        modifier(SidebarSurface())
    }

    func plainCardSurface(cornerRadius: CGFloat) -> some View {
        modifier(PlainCardSurface(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    func iOSGlassIconSurface() -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .circle)
        } else {
            self.background(Color.primary.opacity(0.06), in: Circle())
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func iOSGlassControlSurface(cornerRadius: CGFloat) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(Color.primary.opacity(0.06), in: .rect(cornerRadius: cornerRadius))
        }
        #else
        self
        #endif
    }

    /// Liquid Glass button styling on iOS 26+, falling back to standard
    /// bordered styles elsewhere (and on macOS). `prominent` maps to
    /// `.glassProminent` / `.borderedProminent`.
    @ViewBuilder
    func liquidGlassButton(prominent: Bool = false) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            if prominent {
                self.buttonStyle(.borderedProminent)
            } else {
                self.buttonStyle(.bordered)
            }
        }
        #else
        if prominent {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(.bordered)
        }
        #endif
    }
}
