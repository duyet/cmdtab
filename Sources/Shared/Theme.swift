import SwiftUI

#if os(macOS)
import AppKit
public typealias PlatformColor = NSColor

extension NSColor {
    // System-native surfaces — adapt to Light/Dark and the user's accent
    // automatically. No custom brand palette (fully stock macOS appearance).
    static var appContentBackground: NSColor { .textBackgroundColor }
    static var appWindowBackground: NSColor { .windowBackgroundColor }
    static var appCardSurface: NSColor { .controlBackgroundColor }
    static var appHairline: NSColor { .separatorColor }
    static var appSubtleFill: NSColor { .controlColor }
}
#else
import UIKit
public typealias PlatformColor = UIColor

extension UIColor {
    // System-native surfaces (fully stock iOS appearance).
    static var appContentBackground: UIColor { .systemBackground }
    static var appWindowBackground: UIColor { .secondarySystemBackground }
    static var appCardSurface: UIColor { .secondarySystemBackground }
    static var appHairline: UIColor { .separator }
    static var appSubtleFill: UIColor { .tertiarySystemFill }
}
#endif

extension Color {
    // MARK: - Semantic tokens (system-native)

    /// Main content background — system content surface.
    public static var appBackground: Color { Color(PlatformColor.appContentBackground) }

    /// Raised card/control surface — system control background.
    public static var cardSurface: Color { Color(PlatformColor.appCardSurface) }

    /// Accent — follows the user's system accent colour.
    public static var accentCoral: Color { Color.accentColor }

    /// Hairline separator — system separator colour.
    public static var hairline: Color { Color(PlatformColor.appHairline) }

    // MARK: - Legacy aliases (keep callers compiling)
    public static var creamBackground: Color { appBackground }
    public static var textBackground: Color { appBackground }
    public static var windowBackground: Color { Color(PlatformColor.appWindowBackground) }
    public static var windowChrome: Color { appBackground }
    public static var cardBackground: Color { cardSurface }
    public static var subtleFill: Color { Color(PlatformColor.appSubtleFill) }
    public static var cardStroke: Color { hairline }
    public static var keycapFill: Color { Color(PlatformColor.appSubtleFill) }
}

extension View {
    @ViewBuilder
    public func platformFrame() -> some View {
        #if os(macOS)
        self.frame(minWidth: 680, maxWidth: .infinity, minHeight: 480, maxHeight: .infinity)
        #else
        self.frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }
}

#if os(iOS)
/// iOS-specific layout constants that adapt to device size.
/// Uses window-scene-based screen queries (UIScreen.main deprecated in iOS 26).
enum DeviceLayout {
    /// Sidebar width: narrower on compact devices (iPhone SE), wider on Plus/Max.
    static var sidebarWidth: CGFloat {
        let screen = screenBounds.width
        if screen < 375 { return 260 }  // iPhone SE / compact
        if screen < 414 { return 280 }  // Standard iPhone
        return 300  // Plus / Max / Pro Max
    }

    /// Whether the device has a home indicator (no physical home button).
    static var hasHomeIndicator: Bool {
        let bottom = screenBounds.height - (activeWindowScene?.windows.first?.safeAreaInsets.bottom ?? 0)
        return bottom > 0
    }

    // MARK: - Private helpers

    private static var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
    }

    private static var screenBounds: CGRect {
        if let scene = activeWindowScene {
            return scene.screen.bounds
        }
        // Fallback when no scene is connected yet (early launch)
        return CGRect(x: 0, y: 0, width: 393, height: 852)
    }
}
#endif
