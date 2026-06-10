# Coding Agent Instructions: cmdtab ⌘⌥

This document is dedicated to agentic coding systems (e.g., Antigravity, Claude, etc.) and core maintainers modifying this codebase. It outlines the architectural principles, compile-time rules, testing constraints, and safety guidelines of `cmdtab`.

For complete details on the shared multiplatform architecture, styling adapters, and build/release targets, refer to the internal documentation:
- [multiplatform.md](file:///Users/duet/project/cmdtab/docs/multiplatform.md)

---

## 1. Core Architecture Principles

### 1.1 Model-View-ViewModel (MVVM)
- **State Source**: `MainViewModel` is the single source of truth for app state. It is isolated to `@MainActor` to prevent concurrency warnings or race conditions on UI threads.
- **Vols & In-Memory Constraints**: Conversation history is stored in the `@Published public var conversations` array. **Do not write conversations to disk** (e.g., in plist, UserDefaults, or temp files). Keep conversations strictly volatile in RAM.
- **Sidebar Integration**: The sidebar toggle `isSidebarVisible` is defined on `MainViewModel` and persisted in `UserDefaults` (as it's UI state, not user chat data). This allows external handlers (like key-down interceptors in `AppDelegate`) to easily change its value.

### 1.2 Layout & Resizing
- **Fluid Layout**: The root view in `MainView.swift` utilizes `.platformFrame()` to support fluid window resizing on macOS while scaling adaptively on iOS device screens.
- **Solid Theme Colors**: Backdrop and sidebar colors use semantic abstractions (`Color.textBackground` and `Color.windowBackground` defined in `Theme.swift`) to adapt to system Light/Dark appearance changes.

### 1.3 SwiftUI Compiler Performance
- **Avoid Complex Expressions**: The SwiftUI compiler can fail with type-checking timeouts if views contain too many nested layers and conditions (e.g. `LazyVGrid` inside `ScrollViewReader` inside `ScrollView` inside `VStack`).
- **Subview Extraction**: Always extract sub-layouts (like the empty landing screens or grids) into separate helper properties or views (e.g., `emptyLandingView`, `clipboardQuickActionsGrid`, `defaultEmptyStateView`) to keep compile times short.

---

## 2. Compile-Time Configurations & Dual Inference

### 2.1 The Native LLM Compatibility Bug
- **History**: Compiling against macOS 28.0+ SDK headers once caused a launch crash on macOS 27 (`Symbol not found` for newer `FoundationModels` symbols), so the local LLM was stubbed out with `-D DISABLE_NATIVE_LLM`.
- **Current solution (2026-06)**: `LocalModelClient` guards every FoundationModels usage with `#available(macOS 26.0, iOS 26.0, *)`, which makes the linker weak-link the framework automatically. `build.sh` therefore ships the REAL on-device path while still targeting macOS 14. Verified empirically: the real-path binary launches cleanly on this macOS 27 host, and availability reports `appleIntelligenceNotEnabled` (framework loads fine).
- **Build Flag**: `-D DISABLE_NATIVE_LLM` remains supported as an opt-out and is still passed in `test.sh` (the unit tests exercise the compiled-out path) and `build_ios.sh`. Do not add launch-time Keychain reads (see lazy `loadApiKeyIfNeeded`) — ad-hoc re-signing changes code identity and triggers a prompt per rebuild.
- **Cloud Routing**: Cloud completion is handled in `APIClient.swift` by streaming Server-Sent Events (SSE). It parses standard OpenAI-compatible completions payloads.

---

## 3. Security & Keychain Guardrails

- **Token Storage**: Never store API keys in `UserDefaults` or standard configuration files. Always route keys through `KeychainHelper.swift`.
- **Suppressing Echoes**: When copying output back to the system clipboard, call `PasteboardMonitor.shared.suppressNextEcho(text: output)` to prevent the clipboard monitor from triggering a new quick-action banner with the app's own response.

---

## 4. Verification Protocols for Agents

Before concluding any code changes, agents must run the following check loop:

1. **Unit Testing**:
   Run `./test.sh` to compile the lightweight unit tests.
   ```bash
   ./test.sh
   ```
2. **Launch & Regression Testing (macOS)**:
   Run `./test_launch.sh` to compile the app bundle with the default compiler parameters and launch it in the background to verify dynamic link stability.
   ```bash
   ./test_launch.sh
   ```
3. **Check Code Signatures**:
   Verify the ad-hoc signature on the generated bundle:
   ```bash
   codesign -d -v CmdTab.app
   ```
4. **Compile iOS Simulator Build** (If iOS SDK is available):
   If Xcode is installed and active, run `./build_ios.sh` to verify iOS target compilation:
   ```bash
   ./build_ios.sh
   ```
5. **Clean Code Requirements**:
   Ensure all changes are warning-free under Swift 6.2+.
