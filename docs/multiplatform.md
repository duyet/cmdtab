# Multiplatform Architecture: Shared Codebase for macOS & iOS

This document outlines the architectural guidelines, code structure, styling, and build configurations for **cmdtab** as a single codebase that targets both a native macOS window app and a native iOS application.

---

## 1. Directory Structure

The project separates platform-agnostic business logic from target-specific entry points:

```
cmdtab/
├── Sources/
│   ├── Shared/                # Cross-platform business logic & SwiftUI views
│   │   ├── APIClient.swift    # SSE completions streaming client
│   │   ├── KeychainHelper.swift # Key storage via Security framework
│   │   ├── MainView.swift     # Shared SwiftUI View layout
│   │   ├── MainViewModel.swift # Single source of truth state manager
│   │   ├── PasteboardMonitor.swift # Clipboard abstraction
│   │   ├── SettingsView.swift # Redesigned, theme-adaptive Settings panel
│   │   └── Theme.swift        # Color aliases & adaptive platform layout
│   │
│   ├── macOS/                 # macOS target entry & Window controllers
│   │   ├── App_macOS.swift    # App delegate & status item configuration
│   │   ├── HotKeyManager.swift # Carbon global hotkey listener
│   │   └── MainWindow.swift   # Custom NSWindow style
│   │
│   └── iOS/                   # iOS target entry
│       └── App_iOS.swift      # SwiftUI App structure targeting mobile
│
├── Resources/
│   └── iOS_Info.plist         # iOS bundler configurations
├── Info.plist                 # macOS bundler configurations
├── build.sh                   # Compiles and packages macOS app
├── build_ios.sh               # Compiles and packages iOS simulator app
├── test.sh                    # Runs unit tests
└── test_launch.sh             # Verifies macOS background startup safety
```

---

## 2. Platform Adaptations

### 2.1 Theme & Layout Abstraction (`Theme.swift`)
To prevent macOS-specific classes (like `NSColor`) and frame sizes from breaking iOS targets, compile-safe wrappers are defined:
- **Semantic Colors:** `Color.textBackground` and `Color.windowBackground` adapt dynamically to System Light and Dark appearance.
- **Adaptive Frames:** The `.platformFrame()` modifier enforces minimum window sizing constraints on macOS (`minWidth: 700`, `minHeight: 450`) while letting the viewport scale to fill mobile screens on iOS.

### 2.2 Clipboard Monitoring (`PasteboardMonitor.swift`)
The clipboard monitor abstracts the platform pasteboard:
- **macOS:** Polls `NSPasteboard.general` change count every `0.25` seconds in a background timer.
- **iOS:** Listens to `UIPasteboard.changedNotification` for event-driven updates.
- **Unified Output:** Exposes a unified `copyToClipboard(_:)` method to safely copy data and suppress self-echo loops on both platforms.

### 2.3 iOS Navigation Drawer
On iOS, standard split-pane windows do not fit mobile viewports. The shared layout automatically displays the conversation list as a slide-out overlay drawer on iOS, completed with a dimming backdrop that dismisses the sidebar when tapped.

---

## 3. UI/UX & Feature Configuration

### 3.1 Redesigned Settings Panel (`SettingsView.swift`)
The Settings panel is rendered in-app without spawning external dialogs. It has been redesigned to conform with the solid background theme, utilizing:
- Subtle borders and lighter field backgrounds (`Color.primary.opacity(0.04)`).
- **Preferred Language Picker:** Supports selecting English, Spanish, French, German, Chinese, Japanese, Korean, and Vietnamese. The selected language is appended to the LLM system instructions (`"All responses must be in [Language]."`).
- **Preset Action Editing & Reset:** Enables customizing the name and prompt instructions for all 9 Quick Action presets. A **Reset to Defaults** button instantly restores the default preset prompt configurations.

### 3.2 Local LLM Availability Protection
To prevent runtime crashes and dynamic link errors, the application performs safety checks:
- `isLocalModelSupported` checks if the local model has been stubbed out at compile-time (via `DISABLE_NATIVE_LLM` flag) or if the host OS doesn't support the `FoundationModels` framework.
- If unsupported, the **Local LLM** selector is grayed out, disabled, and the app is locked to the **Cloud API** gateway.

---

## 4. CLI Build Workflows

### 4.1 Building macOS App (`build.sh`)
```bash
xcrun -sdk macosx swiftc \
  -target arm64-apple-macosx27.0 \
  -D DISABLE_NATIVE_LLM \
  -parse-as-library -O \
  -o CmdTab \
  Sources/Shared/*.swift Sources/macOS/*.swift
```

### 4.2 Building iOS App for Simulator (`build_ios.sh`)
```bash
xcrun -sdk iphonesimulator swiftc \
  -target arm64-apple-ios17.0-simulator \
  -D DISABLE_NATIVE_LLM \
  -parse-as-library -O \
  -o CmdTab_iOS \
  Sources/Shared/*.swift Sources/iOS/*.swift
```
*Note: iOS simulator compilation requires a full Xcode installation with active SDK configurations (run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` to switch).*

---

## 5. Plist Versioning Best Practices

The bundle specifications (`Info.plist` and `Resources/iOS_Info.plist`) are tracked under version control (Git). Version numbers should follow this structure:
- **`CFBundleShortVersionString` (Marketing Version):** Configured manually when launching new release tags (e.g. `1.0.0`).
- **`CFBundleVersion` (Build Version):** Dynamic integer representing compile number (e.g. `1`, `24`).

### Automated Versioning
To automate build numbers in CI/CD pipelines (such as GitHub Actions), modify the plist files before running compilation using `plutil`:
```bash
# Replace build version dynamically
plutil -replace CFBundleVersion -string "${GITHUB_RUN_NUMBER}" Info.plist
plutil -replace CFBundleVersion -string "${GITHUB_RUN_NUMBER}" Resources/iOS_Info.plist
```
