# AnyRouter Integration & Key Security

MinhAgent supports AnyRouter and any OpenAI-compatible endpoint as its cloud completion provider.

## Keychain Credential Storage

API keys are stored in the macOS Keychain — never in plaintext files.

```swift
KeychainHelper.shared.save(apiKey, service: "minhagent.app", account: "token")
KeychainHelper.shared.read(service: "minhagent.app", account: "token")
KeychainHelper.shared.delete(service: "minhagent.app", account: "token")
```

Keys are loaded lazily (only when starting a completion stream) and never logged.

## API Configuration (`Cmd + ,`)

| Field | Default |
| :--- | :--- |
| Provider | AnyRouter |
| Endpoint | `https://anyrouter.dev/api/v1` |
| Model | `meta-llama/llama-3-8b-instruct:free` |
| API Key | entered by user → Keychain |

Other providers (OpenRouter, OpenAI, Ollama, Gemini) are available via the dropdown.

## Streaming Transport

Completions use HTTP SSE (chunked transfer) directly from the device to the API host. No intermediate proxy. Implementation: `Sources/Shared/APIClient.swift`.

Request format:
```json
{
  "model": "...",
  "messages": [{"role": "system", "content": "..."}, {"role": "user", "content": "..."}],
  "stream": true
}
```

`Authorization: Bearer <key-from-keychain>` is set at request time.
