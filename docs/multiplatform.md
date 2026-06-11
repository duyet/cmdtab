# Multiplatform Architecture

MinhAgent targets macOS 14+ and iOS 26+ from a single shared Swift codebase.

## Directory Structure

```
Sources/
├── Shared/          # Cross-platform business logic & SwiftUI views
│   ├── APIClient.swift          # SSE streaming cloud inference
│   ├── KeychainHelper.swift     # Keychain credential storage
│   ├── MainView.swift           # Shared SwiftUI layout
│   ├── MainViewModel.swift      # @MainActor state source of truth
│   ├── PasteboardMonitor.swift  # Clipboard abstraction (macOS + iOS)
│   ├── SettingsView.swift       # Settings panel
│   └── Theme.swift              # Semantic colors + adaptive layout
│
├── macOS/           # macOS-only: app delegate, window, hotkey
│   ├── App_macOS.swift          # AppDelegate, status item, main menu
│   ├── HotKeyManager.swift      # Carbon global ⌥Space listener
│   └── MainWindow.swift         # NSWindow configuration
│
└── iOS/             # iOS-only: UIKit lifecycle + scene delegate
    └── App_iOS.swift
```

## Platform Adaptations

**Theme** (`Theme.swift`): `Color.textBackground` / `Color.windowBackground` adapt to Light/Dark. `.platformFrame()` sets min size on macOS; fills screen on iOS.

**Clipboard** (`PasteboardMonitor.swift`): macOS polls `NSPasteboard.general` every 0.25s; iOS uses `UIPasteboard.changedNotification`. Both platforms share `copyToClipboard(_:)` with echo suppression.

**Sidebar**: Split-pane on macOS; slide-out overlay drawer on iOS.

**FoundationModels**: guarded with `#available(macOS 26, iOS 26, *)` — auto-weak-linked, safe on older OS.

## Build Commands

```bash
./build.sh           # macOS: MinhAgent.app
./build_ios.sh       # iOS Simulator: MinhAgent_iOS.app
./build_ios_device.sh  # iOS Device (requires signing identity)
```

## Plist Versioning

`CFBundleShortVersionString` — marketing version (e.g. `1.0.0`), set manually per release.
`CFBundleVersion` — build number, automated via CI: `plutil -replace CFBundleVersion -string "${GITHUB_RUN_NUMBER}" Info.plist`.
