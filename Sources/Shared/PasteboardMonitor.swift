import Foundation

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

@MainActor
public final class PasteboardMonitor: @unchecked Sendable {
    public static let shared = PasteboardMonitor()

    #if os(macOS)
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    #endif

    private var lastCopiedText: String = ""
    private var timer: Timer?

    public var onClipboardChanged: ((String) -> Void)?

    private init() {
        #if os(macOS)
        self.lastChangeCount = pasteboard.changeCount
        #endif
    }

    #if os(iOS)
    private var activeObserver: NSObjectProtocol?
    #endif

    public func startMonitoring(interval: TimeInterval = 0.25) {
        #if os(macOS)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkPasteboard() }
        }
        #elseif os(iOS)
        activeObserver = NotificationCenter.default.addObserver(
            forName: UIPasteboard.changedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkPasteboard() }
        }
        // Seed lastCopiedText so the current clipboard content doesn't
        // trigger a spurious banner on first launch.
        lastCopiedText = UIPasteboard.general.string ?? ""
        #endif
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        #if os(iOS)
        if let observer = activeObserver {
            NotificationCenter.default.removeObserver(observer)
            activeObserver = nil
        }
        #endif
    }

    public func suppressNextEcho(text: String) {
        lastCopiedText = text
    }

    public func copyToClipboard(_ text: String) {
        suppressNextEcho(text: text)
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = text
        #endif
    }

    private func checkPasteboard() {
        #if os(macOS)
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let items = pasteboard.pasteboardItems,
            let firstItem = items.first,
            let text = firstItem.string(forType: .string)
        else {
            return
        }
        #elseif os(iOS)
        guard let text = UIPasteboard.general.string else { return }
        #endif

        let sanitized = sanitizeText(text)
        guard !sanitized.isEmpty else { return }

        if sanitized == sanitizeText(lastCopiedText) {
            lastCopiedText = ""  // Allow future external copies of same text
            return
        }

        onClipboardChanged?(sanitized)
    }

    /// Check for new clipboard content respecting echo suppression.
    /// Used by showWindow() instead of reading NSPasteboard directly.
    public func detectNewContent() -> String? {
        #if os(macOS)
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return nil }

        guard let items = pasteboard.pasteboardItems,
            let firstItem = items.first,
            let text = firstItem.string(forType: .string)
        else {
            return nil
        }
        #elseif os(iOS)
        guard let text = UIPasteboard.general.string else { return nil }
        #endif

        let sanitized = sanitizeText(text)
        guard !sanitized.isEmpty else { return nil }

        if sanitized == sanitizeText(lastCopiedText) {
            lastCopiedText = ""
            return nil
        }

        return sanitized
    }

    private func sanitizeText(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
