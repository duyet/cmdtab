# Release Audit — Lessons Learned (2026-06-11)

## Summary

Pre-release audit of the macOS codebase identified and fixed **6 categories** of issues across 20 files. All fixes verified with `lint.sh`, `build.sh`, `test.sh`, and `test_launch.sh`.

---

## 1. Swift 6 Concurrency Annotations

**Problem:** `HotKeyManager` and `PasteboardMonitor` were plain `final class` with no `Sendable` or `@MainActor` annotations. Static `shared` singletons triggered `mutable-global-variable` warnings. Timer/NotificationCenter callbacks called main-actor-isolated methods from nonisolated closures.

**Fix:**
- Added `@MainActor` + `@unchecked Sendable` to both classes
- Wrapped callback bodies in `MainActor.assumeIsolated { }` for Timer and NotificationCenter observers (which already fire on the main run loop)
- Removed redundant `DispatchQueue.main.async` in `MainViewModel.setupClipboardMonitor()`

**Lesson:** Even when code is *de facto* main-thread-only (Timer on main run loop, NotificationCenter with `queue: .main`), Swift 6 requires formal declaration. `@MainActor` + `@unchecked Sendable` is the pattern for singletons that are actor-isolated but have mutable state.

**Lesson:** When making a class `@MainActor`, audit all closure-based callbacks (Timer, NotificationCenter, Combine). The closures are nonisolated and need `MainActor.assumeIsolated` to call actor-isolated methods.

---

## 2. Sendable Model Types

**Problem:** `ChatMessage`, `Conversation`, and `Preset` structs crossed actor boundaries (captured in `Task { [weak self] in ... }`) without `Sendable` conformance, triggering `sending-risks-data-race`.

**Fix:** Added `Sendable` conformance to all three structs. They're value types with only `Sendable` stored properties (`UUID`, `String`, `Date`, `Bool`), so conformance is trivially safe.

**Lesson:** Any value type that crosses actor boundaries (captured in a `Task`, passed to `async` functions) needs `Sendable` conformance. For simple structs with primitive fields, just add it proactively.

---

## 3. Logging — print() vs os.Logger

**Problem:** `HotKeyManager` used `print()` for error logging. Invisible in release builds, invisible in Console.app.

**Fix:** Replaced with `os.Logger` (`Logger(subsystem: "app.cmdtab", category: "HotKey")`).

**Lesson:** `print()` is only acceptable during active debugging. For anything shipped, use `os.Logger` — it's visible in Console.app, respects log levels, and has near-zero overhead when the level is disabled.

---

## 4. Keychain Save Error Handling

**Problem:** `MainViewModel.apiKey` didSet called `KeychainHelper.shared.save(...)` but discarded the `Bool` return. If Keychain write fails, the user's API key is silently lost.

**Fix:** Check return value and log via `Self.logger.error(...)`. Also added `kSecAttrAccessibleAfterFirstUnlock` to the Keychain query so items don't require user interaction to create.

**Lesson:** Never discard Keychain operation results. Even if you can't show UI, at minimum log the failure. And `kSecAttrAccessibleAfterFirstUnlock` is the correct access level for API keys that need to be read without user presence.

---

## 5. Keychain Testing on Apple Silicon

**Problem:** `SecItemAdd` returns `errSecInteractionNotAllowed` (-25308) from CLI binaries on Apple Silicon, even when wrapped in an `.app` bundle with ad-hoc signing. The Keychain requires a proper provisioning profile or Developer ID signing.

**Fix:** Made `testKeychainCRUD()` gracefully skip when `save()` fails, with a clear `⚠` message. The Keychain path is still exercised in the real `.app` via `test_launch.sh`.

**Lesson:** Keychain CRUD can't be unit-tested from ad-hoc signed CLI binaries on Apple Silicon. Options:
1. Skip gracefully (chosen — simple, honest)
2. Mock `KeychainHelper` in tests (adds abstraction)
3. Sign test binary with real identity (requires CI secrets setup)

---

## 6. NSCursor Push/Pop Imbalance

**Problem:** `MenuTriggerHover` in `ComposerView` pushes `NSCursor.pointingHand` on hover and pops on unhover. If the view disappears while hovered (window closes), the pop never fires, leaving the cursor stack unbalanced.

**Fix:** Added `onDisappear { if isHovered { NSCursor.pop() } }` as a safety net.

**Lesson:** Any `NSCursor.push()` must have a matching `NSCursor.pop()` in all exit paths — including view disappearance. SwiftUI's `onDisappear` is the safety net for cleanup that `onHover(performing: false)` might miss.

---

## 7. Status Bar Item

**Problem:** `NSStatusItem.button.title = "⌘⌥"` renders inconsistently across macOS versions and font sizes.

**Fix:** Switched to SF Symbol: `NSImage(systemSymbolName: "command.square", accessibilityDescription: "cmdtab")`.

**Lesson:** SF Symbols are the standard for menu-bar icons. Emoji text is unreliable for small sizes and varies across system fonts.

---

## Remaining Pre-Release Items (Not Code Fixes)

| Item | Status |
|------|--------|
| `CmdTab.entitlements` file | ❌ Missing — template in docs only |
| Hardened runtime signing (`--options runtime`) | ❌ Ad-hoc only |
| Developer ID certificate | ❓ Needs setup |
| Notarization workflow automation | ❓ Docs exist, not automated |
| Localization (~100+ hardcoded strings) | ⚠️ English-only for 1.0 |
| Dead code: `Persistence.swift` (123 lines) | ⚠️ Not wired in |
| Large files: `MainViewModel.swift` (646 lines) | ⚠️ Refactoring candidate |
