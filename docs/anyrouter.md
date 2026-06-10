# AnyRouter Integration & Key Security

`cmdtab` supports seamless integration with **AnyRouter** (and other OpenAI-compatible endpoints) as its default cloud completion provider. This document explains the secure configuration, Keychain-backed credential storage, and network transport details.

---

## 1. Credentials Security Model

### 1.1 The Security Risk
Most developer utilities store API keys in plaintext files (like `.env`, JSON configs, or standard user preferences), which makes them vulnerable to exfiltration by malware, scripts, or backups.

### 1.2 The Solution: Apple Keychain Services
`cmdtab` stores all API tokens directly in the macOS Keychain using **System Keychain Services**.
- **Keychain Storage**: API tokens are encrypted using OS-level AES encryption managed by the Secure Enclave.
- **Volatile in Memory**: During runtime, the API token is loaded from the Keychain only when starting a new completion stream, and is never logged to stdout or saved to local disk configuration caches.

### 1.3 Key Operations Code
In `Sources/KeychainHelper.swift`, the API token is managed using Apple's Security Framework:
```swift
// Save or update key
KeychainHelper.shared.save(apiKey, service: "cmdtab.app", account: "token")

// Read key when completing requests
KeychainHelper.shared.read(service: "cmdtab.app", account: "token")

// Delete key when user resets settings
KeychainHelper.shared.delete(service: "cmdtab.app", account: "token")
```

---

## 2. API Configuration Settings

API configuration can be edited inside the settings screen (`Cmd + ,`):

- **API Provider**: `AnyRouter` (Default)
- **Endpoint URL**: `https://anyrouter.dev/api/v1`
- **Model Name**: `meta-llama/llama-3-8b-instruct:free`
- **API Key**: Enter your AnyRouter API token.

*Note: You can switch to other endpoints like OpenRouter, OpenAI, local Ollama instances, or Google Gemini by selecting them in the dropdown, which updates the base URL and default model accordingly.*

---

## 3. Secure Transport & Streaming (SSE)

Completed requests are processed directly from the application to the API gateway using secure HTTPS connections.

### 3.1 Network Stack
- **Direct Connection**: No intermediate proxy or telemetry server is operated by `cmdtab`. Outgoing calls are sent directly from your Mac to `anyrouter.dev` (or your custom host).
- **Server-Sent Events (SSE)**: Completion tokens are streamed using HTTP chunked transfer-encoding.
- **Completion Client**: Implementation details are located in `Sources/APIClient.swift`, which decodes streaming bytes and extracts delta content values.

### 3.2 Request Format
The payload matches the standard OpenAI Chat Completion specification:
```json
{
  "model": "meta-llama/llama-3-8b-instruct:free",
  "messages": [
    {"role": "system", "content": "System Instructions..."},
    {"role": "user", "content": "Sanitized clipboard text..."}
  ],
  "stream": true
}
```
The request header sets `"Authorization": "Bearer YOUR_ANYROUTER_TOKEN"`, fetched directly from the secure Keychain at transmission time.
