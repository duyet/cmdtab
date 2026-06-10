# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**cmdtab** (⌘⌥) — native macOS/iOS SwiftUI app: a conversation workspace with clipboard detection, Quick Actions, and dual LLM inference (on-device FoundationModels + cloud SSE).

## Build & Test

No SPM, no Xcode project. Everything is raw `xcrun swiftc` via shell scripts.

| Command | Purpose |
|---------|---------|
| `./build.sh` | Build macOS app → `CmdTab.app` (ad-hoc signed) |
| `./build_ios.sh` | Build iOS Simulator target |
| `./test.sh` | Run unit tests (custom runner, **not XCTest**) |
| `./test_launch.sh` | Build + launch app for 2s to verify no crash |

Always run `./test.sh` and `./test_launch.sh` after changes. Use `/cmdtab-verify` for the full loop.

## Key Architecture

- **MVVM**: `MainViewModel` (`@MainActor`) is the single source of truth. All state flows through it.
- **Volatile conversations**: RAM only — never persist to disk (no plist, UserDefaults, files).
- **Dual inference**: Cloud via `APIClient.swift` (SSE streaming). Local via Apple FoundationModels, **but compiled out** with `-D DISABLE_NATIVE_LLM` flag.
- **Platform split**: `Sources/Shared/` (cross-platform), `Sources/macOS/`, `Sources/iOS/`.

## Critical Gotchas

- **No `Package.swift`**: Do not use `swift build`, `swift test`, or `swift package` commands.
- **FoundationModels is availability-guarded, not compiled out**: `build.sh` ships the real on-device path behind `#available(macOS 26, *)` runtime guards (auto-weak-linked, still runs on macOS 14+). `-D DISABLE_NATIVE_LLM` remains supported as an opt-out and stays on in `test.sh`/`build_ios.sh`.
- **Custom test runner**: Tests in `Tests/main.swift` use a hand-rolled `assert()` — not XCTest. Tests only link `KeychainHelper.swift`, so they cannot import view models or views.
- **Clipboard echo loop**: When copying app output to clipboard, always call `PasteboardMonitor.shared.suppressNextEcho(text:)` to prevent the monitor from re-triggering.
- **Keychain only for secrets**: API keys must go through `KeychainHelper.swift` — never `UserDefaults` or plaintext.
- **SwiftUI compiler limits**: `MainView.swift` is large (~32k). Extract subviews aggressively to avoid type-checking timeouts.
- **LSUIElement app**: Runs as menu-bar agent (no Dock icon). Affects how you test launch.

## Code Style

- Swift 6.2+ — must compile **warning-free**.
- Semantic color tokens via `Theme.swift` (`Color.textBackground`, `Color.windowBackground`).
- Platform conditionals: `#if os(macOS)` / `#if os(iOS)` in shared files.

## Full Reference

For architecture details, security rules, and verification protocols: @AGENTS.md
