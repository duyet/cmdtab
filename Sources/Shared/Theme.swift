import SwiftUI

#if os(macOS)
import AppKit
public typealias PlatformColor = NSColor

extension NSColor {
    // MARK: - App background (light: pure white, dark: #262624)
    public static var adaptiveAppBackground: NSColor {
        return NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(red: 0.149, green: 0.149, blue: 0.141, alpha: 1.0)  // #262624
            } else {
                return NSColor.white  // #FFFFFF
            }
        }
    }

    // MARK: - Sidebar (light: #F5F5F7 neutral gray, dark: #1F1E1D)
    public static var adaptiveSidebar: NSColor {
        return NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(red: 0.106, green: 0.102, blue: 0.098, alpha: 1.0)  // #1B1A19
            } else {
                return NSColor(red: 0.941, green: 0.941, blue: 0.949, alpha: 1.0)  // #F0F0F2
            }
        }
    }

    // MARK: - Card surface (light: white, dark: #30302E)
    public static var adaptiveCardSurface: NSColor {
        return NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(red: 0.188, green: 0.188, blue: 0.180, alpha: 1.0)  // #30302E
            } else {
                return NSColor.white
            }
        }
    }

    // Backward compat aliases
    public static var adaptiveTextBackground: NSColor { adaptiveAppBackground }
    public static var adaptiveWindowChrome: NSColor { adaptiveAppBackground }
    public static var adaptiveCardBackground: NSColor { adaptiveCardSurface }
    public static var adaptiveSubtleFill: NSColor {
        return NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(white: 0.22, alpha: 1.0)
            } else {
                return NSColor(red: 0.961, green: 0.961, blue: 0.969, alpha: 1.0)
            }
        }
    }
}
#else
import UIKit
public typealias PlatformColor = UIColor

extension UIColor {
    public static var adaptiveAppBackground: UIColor {
        return UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.149, green: 0.149, blue: 0.141, alpha: 1.0)
            } else {
                return UIColor.white
            }
        }
    }
    public static var adaptiveCardSurface: UIColor {
        return UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.188, green: 0.188, blue: 0.180, alpha: 1.0)
            } else {
                return UIColor.white
            }
        }
    }
    public static var adaptiveSidebar: UIColor {
        return UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.122, green: 0.118, blue: 0.114, alpha: 1.0)
            } else {
                return UIColor(red: 0.961, green: 0.961, blue: 0.969, alpha: 1.0)
            }
        }
    }
    public static var adaptiveTextBackground: UIColor { adaptiveAppBackground }
    public static var adaptiveWindowChrome: UIColor { adaptiveAppBackground }
    public static var adaptiveCardBackground: UIColor { adaptiveCardSurface }
    public static var adaptiveSubtleFill: UIColor {
        return UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(white: 0.22, alpha: 1.0)
            } else {
                return UIColor(red: 0.961, green: 0.961, blue: 0.969, alpha: 1.0)
            }
        }
    }
}
#endif

extension Color {
    // MARK: - Semantic tokens

    /// Main app background: white in light mode, dark gray in dark mode.
    public static var appBackground: Color {
        return Color(PlatformColor.adaptiveAppBackground)
    }

    /// White card surface in light mode; warm dark gray (#30302E) in dark mode.
    public static var cardSurface: Color {
        return Color(PlatformColor.adaptiveCardSurface)
    }

    /// Coral brand accent (#D97757).
    public static var accentCoral: Color {
        return Color(red: 0.851, green: 0.467, blue: 0.341)
    }

    /// Hairline separator: #E5E5E7 in light, subtle in dark.
    public static var hairline: Color {
        return Color.primary.opacity(0.10)
    }

    // MARK: - Legacy aliases (keep callers compiling)
    public static var creamBackground: Color { appBackground }
    public static var textBackground: Color { appBackground }
    public static var windowBackground: Color { Color(PlatformColor.adaptiveSidebar) }
    public static var windowChrome: Color { appBackground }
    public static var cardBackground: Color { cardSurface }
    public static var subtleFill: Color { Color(PlatformColor.adaptiveSubtleFill) }
    public static var cardStroke: Color { hairline }
    public static var keycapFill: Color { Color.primary.opacity(0.05) }
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
