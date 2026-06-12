# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

**MinhAgent** — native macOS/iOS SwiftUI app: conversation workspace with clipboard Quick Actions and dual LLM inference (on-device FoundationModels + cloud SSE).

## Build & Test

No SPM, no Xcode project checked in. Everything is raw `xcrun swiftc` via shell scripts.

| Command | Purpose |
|---------|---------|
| `./build.sh` | Build macOS app → `MinhAgent.app` (ad-hoc signed) |
| `./build_ios.sh` | Build iOS Simulator target → `MinhAgent_iOS.app` |
| `./test.sh` | Run unit tests (custom runner, not XCTest) |
| `./test_launch.sh` | Build + launch app for 2s to verify no startup crash |
| `./test_ui.sh` | UI smoke test via macOS Accessibility API |

Always run `./test.sh` and `./test_launch.sh` after changes.

## Platform & API Guidelines

- SwiftUI throughout. Follow Apple Human Interface Guidelines.
- Target latest macOS — no backward compatibility constraint.
- Swift 6.2+ — must compile **warning-free**.
- Use async/await and Swift concurrency wherever applicable.

## Key Architecture

- **MVVM**: `MainViewModel` (`@MainActor`) is the single source of truth.
- **Conversation persistence**: Saved locally via SwiftData (SQLite database) or a fallback JSON file under Application Support.
- **Dual inference**: Cloud via `APIClient.swift` (SSE streaming). Local via `LocalModelClient.swift`, guarded `#available(macOS 26, iOS 26, *)`.
- **Platform split**: `Sources/Shared/` (cross-platform), `Sources/macOS/`, `Sources/iOS/`.
- **Semantic colors**: `Color.textBackground`, `Color.windowBackground` from `Theme.swift`.

## Critical Gotchas

- **No `Package.swift` builds**: never run `swift build` or `swift test`.
- **FoundationModels availability-guarded**: real on-device path is behind `#available(macOS 26, *)` and auto-weak-linked. `-D DISABLE_NATIVE_LLM` is an opt-out used in `test.sh` and `build_ios.sh`.
- **Custom test runner**: `Tests/main.swift` uses hand-rolled asserts — not XCTest. Only links `KeychainHelper.swift` and a few non-UI sources.
- **Clipboard echo loop**: after copying app output, call `PasteboardMonitor.shared.suppressNextEcho(text:)`.
- **Keychain only**: API keys go through `KeychainHelper.swift`, service `"minhagent.app"` — never `UserDefaults`.
- **SwiftUI compiler limits**: `MainView.swift` is large. Extract subviews aggressively.
- **Regular macOS app**: Dock + Cmd-Tab presence. Launch tests must open the `.app` bundle, not the raw executable.

## Full Reference

@AGENTS.md
