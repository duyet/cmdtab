# cmdtab ⌘⌥

`cmdtab` is a sleek, multiplatform application designed for developers and power users. Supporting both native **macOS** and **iOS** platforms from a single shared codebase, it offers a Codex-inspired conversation workspace, automated clipboard detection with Quick Action transformations, and dual-inference support—switching seamlessly between a local on-device LLM (via Apple's `FoundationModels` framework) and cloud APIs (via AnyRouter, OpenAI, Gemini, etc.), while securely storing your API credentials in the system Keychain.

---

## Key Features

- **Double-Pane Workspace**: A transparent, blurred backdrop window using standard macOS controls (close, minimize, resize). It behaves as a regular application—it does not float on top by default, integrates with the Dock, and launches directly on startup.
- **Collapsible Sidebar**: List your active, volatile in-memory conversations. Toggle the sidebar using `Cmd+\` or `Cmd+B` to maximize screen workspace, and create new chats with the `+` button.
- **Auto-Detect Clipboard & Quick Actions**: Copy any block of code or text from any application, activate `cmdtab`, and it will immediately display a banner with the copied content and a grid of **Quick Action Presets (1-9)**.
- **Instant Preset Shortcuts**: Press `⌥1` to `⌥9` (or `Cmd+1` to `Cmd+9`) to instantly send your clipboard text to the LLM with a specific pre-defined system prompt.
- **Dual Inference Engine**:
  - **Local Model**: On-device native completion using the Apple Intelligence model (`FoundationModels.framework` on compatible M-series Macs running macOS Sequoia+).
  - **Cloud Model**: Secure streaming completion from AnyRouter, OpenRouter, OpenAI, Ollama, or Google Gemini.
- **Zero Disk Leakage (Privacy First)**: In compliance with strict privacy guidelines, all conversations, messages, and processed text reside exclusively in volatile RAM. Quitting `cmdtab` purges all conversations.
- **Secure Key Storage**: API tokens are secured directly in the macOS Keychain using System Keychain Services. No credentials or keys are ever saved to plain-text configuration files or disk.

---

## Keyboard Shortcuts

The app is designed to be fully keyboard-navigable for maximum efficiency:

| Shortcut | Action | Description |
| :--- | :--- | :--- |
| `⌥Space` | **Toggle HUD Window** | Globally show or hide the overlay window on the active monitor. |
| `Esc` | **Hide HUD** | Instantly dismiss the overlay window. |
| `Cmd + \` or `Cmd + B` | **Toggle Sidebar** | Expand/collapse the conversation list sidebar (persisted in preferences). |
| `⌥1` – `⌥9` or `⌘1` – `⌘9` | **Run Quick Action** | Executes preset 1-9 on the detected clipboard content. |
| `Cmd + C` | **Copy Last Output** | Copies the most recent assistant message directly back to the clipboard. |
| `Cmd + K` | **Clear Chat** | Clears the message history of the current conversation. |
| `Cmd + ,` | **Settings Panel** | Open/close the configuration screen for API endpoints, keys, and presets. |

---

## Quick Action Presets (1-9)

The application ships with 9 default presets that can be customized in the Presets tab under Settings:

1. **Fix English & Tone**: Fixes spelling, grammar, and tone to make it professional and clear.
2. **Explain Logic**: Explains the technical logic, algorithms, or operations of the input text or code.
3. **Summarize to Bullets**: Summarizes the input into a high-density, bulleted markdown list.
4. **Generate Python/Rust Workaround**: Writes a complete, functional Python/Rust script resolving the problem.
5. **Refactor Code**: Refactors the input code to improve performance, readability, and design.
6. **Translate to SQL**: Writes high-performance ClickHouse or PostgreSQL queries satisfying the prompt.
7. **Generate JSON Schema**: Parses the input data and outputs a valid JSON Schema (Draft-07).
8. **Format JSON/XML**: Formats the input block with 2-space indentation.
9. **Draft Slack Update**: Converts engineering notes into a clean Slack bullet-point update.

---

## Requirements & Compatibility

- **Hardware**: Optimized for Apple Silicon M-series Macs (M1, M2, M3, M4, etc.) for local execution. Intel Macs are supported for cloud API completion.
- **Operating System**: macOS 14.0 Sonoma or later. (macOS 15.0+ Sequoia required for native local Apple Intelligence models).
- **Toolchain**: Xcode Command Line Tools or Xcode 15+ (Swift 6.0 compatibility).

---

## How to Build & Run

### 1. Build the macOS App Bundle
Run the build script in the root directory. This compiles the Swift source files, packages them into a native `CmdTab.app` bundle, and signs it with an ad-hoc signature:
```bash
./build.sh
```

### 2. Launch the macOS App
To open the compiled app bundle, you can double-click it or launch it from the terminal:
```bash
open CmdTab.app
```
*Note: A small menu bar icon `⌘⌥` will appear in the top-right corner. You can activate the window by pressing `⌥Space` or clicking the menu bar icon.*

### 3. Build the iOS App for Simulator
To compile the iOS version for the iOS Simulator:
```bash
./build_ios.sh
```
*Note: Compiling the iOS app requires a full installation of Xcode with the `iphonesimulator` SDK configured via `xcode-select`.*

### 4. Run Automated Tests
We maintain two test suites:
- **Unit Tests**: Verifies pasteboard sanitization, keychain storage security, and data model operations.
  ```bash
  ./test.sh
  ```
- **Launch Verification Test**: Rebuilds the app and performs background execution tests to ensure the binary loads dynamic frameworks and runs without startup crashes on macOS.
  ```bash
  ./test_launch.sh
  ```

---

## Secure API Integration

To prevent key leakage, `cmdtab` never writes API tokens to config files, logs, or defaults.
- Any API keys entered in **Settings** (under `Cmd + ,`) are immediately transferred to the secure macOS Keychain via:
  - Service: `cmdtab.app`
  - Account: `token`
- Network completed requests are streamed securely via SSE using [APIClient.swift](Sources/APIClient.swift) directly to your chosen provider (e.g. AnyRouter) using secure HTTPS transport.
- You can clear your API key at any time by clearing the field in Settings.

---

## Architecture

```
cmdtab/
├── Sources/
│   ├── Shared/                # Cross-platform business logic & SwiftUI views
│   │   ├── APIClient.swift    # HTTP SSE client for cloud inference streaming
│   │   ├── KeychainHelper.swift # Secure OS Keychain interface (no key disk-writes)
│   │   ├── MainView.swift     # Main SwiftUI viewport (with iOS adaptive drawer)
│   │   ├── MainViewModel.swift # State manager: handles conversations & inference
│   │   ├── PasteboardMonitor.swift # Clipboard monitor (abstracted for both OSes)
│   │   ├── SettingsView.swift # Settings panel for endpoints, keys, and presets
│   │   └── Theme.swift        # Color and layout style semantic abstractions
│   │
│   ├── macOS/                 # macOS-specific classes and delegate setup
│   │   ├── App_macOS.swift    # macOS entry point and AppDelegate window lifecycle
│   │   ├── HotKeyManager.swift # Carbon/CoreGraphics global key down listener
│   │   └── MainWindow.swift   # Resizable native macOS NSWindow configuration
│   │
│   └── iOS/                   # iOS-specific views and app scene entry
│       └── App_iOS.swift      # iOS entry point using SwiftUI App lifecycle
│
├── Resources/
│   └── iOS_Info.plist         # iOS bundler specifications and orientation rules
├── Tests/
│   └── main.swift             # Unit test runner
├── build.sh                   # Builds and signs CmdTab.app (macOS)
├── build_ios.sh               # Builds and signs CmdTab_iOS.app (iOS Simulator)
├── test.sh                    # Runs unit tests
└── test_launch.sh             # Performs macOS launch regression verification
```
