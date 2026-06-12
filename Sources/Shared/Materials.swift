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
        content
            .background(Color.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.hairline, lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
    }
}

extension View {
    func sidebarSurface() -> some View {
        modifier(SidebarSurface())
    }

    func plainCardSurface(cornerRadius: CGFloat) -> some View {
        modifier(PlainCardSurface(cornerRadius: cornerRadius))
    }
}
