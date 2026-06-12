# MinhAgent

Native macOS/iOS AI chat workspace with clipboard Quick Actions and dual inference (on-device Apple Intelligence + cloud APIs).

---

## Features

- **Clipboard Quick Actions** — copy any text, MinhAgent offers instant AI presets (⌥1–⌥9)
- **Dual Inference** — on-device via FoundationModels (macOS 26+) or cloud via AnyRouter / OpenAI / Gemini / Ollama
- **Sidebar workspace** — collapsible sidebar with chat history, preset management, and settings navigation
- **Local persistence** — conversations are stored in a local SQLite database (via SwiftData) or fallback JSON file under Application Support
- **Keychain-only secrets** — API keys in macOS Keychain, never plaintext

---

## Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `⌥Space` | Toggle window |
| `Esc` | Hide window |
| `⌘B` | Toggle sidebar |
| `⌥1`–`⌥9` | Run Quick Action preset |
| `⌘T` | New chat |
| `⌘C` | Copy last assistant output |
| `⌘K` | Clear chat |
| `⌘,` | Open Settings |

---

## Build & Run

```bash
./build.sh            # → MinhAgent.app
./build_ios.sh        # → iOS Simulator build
./test.sh             # unit tests
./test_launch.sh      # build + launch regression
```

No SPM — everything is raw `xcrun swiftc` via shell scripts.

---

## Architecture

```
Sources/
├── Shared/           Views, ViewModel, API client, keychain, theme
├── macOS/            App delegate, window, split view, toolbar
└── iOS/              UIKit lifecycle + drawer sidebar

Resources/
├── logo/             App icons
└── Info.plist        Bundle config
```

**MVVM** — `MainViewModel` (`@MainActor`) is the single source of truth.
**No `Package.swift`** — use `./build.sh`, not `swift build`.

---

## API Configuration

Settings → Cloud Model (`⌘,`). Keys stored in macOS Keychain under `minhagent.app`. Default provider: **AnyRouter**.
