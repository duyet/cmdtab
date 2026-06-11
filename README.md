# MinhAgent

A native macOS + iOS conversation workspace for developers. Clipboard-aware Quick Actions, dual inference (on-device Apple Intelligence + cloud APIs), and zero disk persistence.

---

## Features

- **Clipboard Quick Actions** — copy any text, activate MinhAgent, and a banner surfaces with 9 instant AI presets (⌥1–⌥9)
- **Dual Inference** — on-device via `FoundationModels` (Apple Silicon, macOS 26+) or cloud via AnyRouter / OpenAI / Gemini / Ollama
- **Double-pane workspace** — collapsible sidebar, native window controls, Dock + Cmd-Tab presence
- **Zero disk leakage** — all conversations live in RAM; quit to purge
- **Keychain-only secrets** — API keys stored in macOS Keychain, never in plaintext files

---

## Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `⌥Space` | Toggle window |
| `Esc` | Hide window |
| `⌘\` / `⌘B` | Toggle sidebar |
| `⌥1`–`⌥9` / `⌘1`–`⌘9` | Run Quick Action preset |
| `⌘C` | Copy last assistant output |
| `⌘K` | Clear chat |
| `⌘,` | Open Settings |

---

## Quick Action Presets

Nine presets, fully editable in Settings → Presets:

1. Fix English & Tone
2. Explain Logic
3. Summarize to Bullets
4. Generate Python/Rust Workaround
5. Refactor Code
6. Translate to SQL
7. Generate JSON Schema
8. Format JSON/XML
9. Draft Slack Update

---

## Requirements

- macOS 14.0 Sonoma+ (macOS 26+ for on-device Apple Intelligence)
- Apple Silicon recommended; Intel supported for cloud-only mode
- Xcode 15+ / Swift 6.0+ toolchain

---

## Build & Run

### Xcode (recommended)

```bash
python3 gen_xcodeproj.py   # generates MinhAgent.xcodeproj
open MinhAgent.xcodeproj
```

Targets:

| Target | Platform | Min OS | Sources |
| :--- | :--- | :--- | :--- |
| `MinhAgent` | macOS | 14.0 | `Sources/Shared` + `Sources/macOS` |
| `MinhAgent_iOS` | iOS | 26.0 | `Sources/Shared` + `Sources/iOS` |

Press `⌘R` to build and run. Regenerate the project after adding/removing source files.

### Command line

```bash
./build.sh            # → MinhAgent.app
open MinhAgent.app    # status bar icon ⌘⌥ — press ⌥Space to activate

./build_ios.sh        # → MinhAgent_iOS.app (Simulator)
./test.sh             # unit tests
./test_launch.sh      # launch regression (no crash on startup)
```

---

## Architecture

```
Sources/
├── Shared/         # Cross-platform: views, view model, API, keychain
├── macOS/          # App delegate, window, global hotkey
└── iOS/            # UIKit lifecycle + scene delegate

Resources/
├── logo/           # App icon (Icon.icon bundle + PNGs)
├── Info.plist      # macOS bundle config
└── iOS_Info.plist  # iOS bundle config
```

**MVVM**: `MainViewModel` (`@MainActor`) is the single source of truth.
**Dual inference**: cloud via `APIClient.swift` (SSE), local via `LocalModelClient.swift` (`#available(macOS 26, *)`).
**No `Package.swift` builds**: use `./build.sh`, not `swift build`.

---

## API Configuration

Enter your API key in Settings (`⌘,`). Keys are stored in macOS Keychain under service `minhagent.app`. Default provider: **AnyRouter** at `https://anyrouter.dev/api/v1`.

---

## Security

- Clipboard content is processed in-memory only — never written to disk
- API keys never touch `UserDefaults` or config files
- No telemetry; requests go directly from your device to the API host
