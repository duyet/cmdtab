import SwiftUI

// MARK: - Adaptive surfaces

/// Plain sidebar surface matching the Codex app: solid, quiet, and readable.
struct SidebarSurface: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Color.windowBackground)
    }
}

/// Raised card surface: solid system surface, hairline border, and a small shadow.
struct PlainCardSurface: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(Color.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.hairline, lineWidth: 1)
            )
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
            .shadow(color: Color.black.opacity(0.09), radius: 18, y: 8)
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
