# Agent Instructions: MinhAgent

This file is for agentic coding systems modifying this codebase. See `@CLAUDE.md` for the quick-reference guide.

---

## 1. Architecture

**MVVM**: `MainViewModel` (`@MainActor`) owns all state. Conversations are persisted locally via SwiftData (SQLite database) or a fallback JSON file under Application Support, triggered on key lifecycle events (creation, deletion, rename, and stream completion).

**Dual inference**:
- Cloud: `APIClient.swift` streams SSE using OpenAI-compatible chat completion format.
- Local: `LocalModelClient.swift` wraps FoundationModels behind `#available(macOS 26, iOS 26, *)`. Auto-weak-linked — the binary runs cleanly on macOS 14+.

**Build flags**:
- `-D DISABLE_NATIVE_LLM` compiles out the local path. Used in `test.sh` and `build_ios.sh`.
- The real on-device path ships in `build.sh` (no flag) via `#available` runtime guard.

**Platform split**: `Sources/Shared/` for cross-platform code; `Sources/macOS/` and `Sources/iOS/` for target-specific code. Use `#if os(macOS)` / `#if os(iOS)` in Shared files when needed.

**SwiftUI compiler limits**: `MainView.swift` is large. Always extract subviews into separate properties/structs to avoid type-checking timeouts.

---

## 2. Security Rules

- API keys → `KeychainHelper.swift` only. Service identifier: `"minhagent.app"`, account: `"token"`.
- Never use `UserDefaults` or any file for secrets.
- After copying app output to clipboard: call `PasteboardMonitor.shared.suppressNextEcho(text:)` to prevent the clipboard monitor from re-triggering a Quick Action banner.

---

## 3. Verification Protocol

Before concluding any change:

```bash
./test.sh          # unit tests (custom runner, not XCTest)
./test_launch.sh   # build + launch + verify no startup crash
codesign -d -v MinhAgent.app  # check ad-hoc signature
```

Optionally (if Xcode is installed):
```bash
./build_ios.sh     # verify iOS simulator compilation
```

All changes must be **warning-free** under Swift 6.2+.

---

## 4. Internal Docs

- [multiplatform.md](docs/multiplatform.md) — architecture, platform adaptations, build commands
- [anyrouter.md](docs/anyrouter.md) — API integration, keychain security, SSE transport
- [ci_cd.md](docs/ci_cd.md) — GitHub Actions pipeline, release automation
- [distribution.md](docs/distribution.md) — code signing, notarization, App Review justifications
