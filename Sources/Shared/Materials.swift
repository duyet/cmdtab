import SwiftUI

#if os(macOS)
import AppKit

// MARK: - AppKit vibrancy bridge
/// Smallest possible AppKit bridge (see appkit-interop): a bare
/// NSVisualEffectView for behind-window vibrancy. SwiftUI stays the source of
/// truth; this view holds no state and exposes nothing back.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}
#endif

// MARK: - Adaptive surfaces

/// Sidebar surface: real vibrancy on macOS, solid color when the user enables
/// Reduce Transparency (HIG rule 9.5) and on iOS.
struct SidebarSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        #if os(macOS)
        if reduceTransparency {
            content.background(Color.windowBackground)
        } else {
            content.background(VisualEffectBackground(material: .sidebar))
        }
        #else
        content.background(Color.windowBackground)
        #endif
    }
}

/// Floating card surface: Liquid Glass on macOS 26+, classic card styling
/// (solid surface + hairline + shadow) everywhere else.
struct GlassCardSurface: ViewModifier {
    var cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if #available(macOS 26.0, iOS 26.0, *), !reduceTransparency {
            content
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
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
}

extension View {
    func sidebarSurface() -> some View {
        modifier(SidebarSurface())
    }

    func glassCardSurface(cornerRadius: CGFloat) -> some View {
        modifier(GlassCardSurface(cornerRadius: cornerRadius))
    }
}
