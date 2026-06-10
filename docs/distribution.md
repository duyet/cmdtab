# macOS App Distribution & Apple Developer Submission Guide

To distribute `cmdtab` to end-users on macOS, the application must be signed with a valid Apple Developer Certificate and notarized by Apple's Notarization Service (for direct distribution) or submitted to the Mac App Store.

---

## 1. Preparing Certificates & Entitlements

To sign the app, you need a valid Apple Developer Account and the following certificate types installed in your macOS Keychain:
- **For Direct Distribution (Website/GitHub Releases)**: `Developer ID Application` Certificate.
- **For Mac App Store Distribution**: `Apple Distribution` Certificate.

### Entitlements (`CmdTab.entitlements`)
When compiling for production or App Store with Sandbox enabled, create an entitlements file:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Enable App Sandboxing for App Store -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- Allow Outgoing HTTPS Requests to API Gateways -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- Access Secure Keychain Services -->
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)cmdtab.app</string>
    </array>
</dict>
</plist>
```

---

## 2. Hardened Runtime, Code Signing & Packaging

To pass Apple's notarization checks, the binary must be built with the **Hardened Runtime** enabled.

### 2.1 Code-Sign the Executable & Bundle
Replace `"Developer ID Application: Your Name (TeamID)"` with your actual Apple Developer certificate common name:
```bash
# 1. Sign the inner executable with hardened runtime enabled
codesign --force --options runtime --sign "Developer ID Application: Your Name (TeamID)" --entitlements CmdTab.entitlements CmdTab.app/Contents/MacOS/CmdTab

# 2. Sign the outer application bundle
codesign --force --sign "Developer ID Application: Your Name (TeamID)" CmdTab.app
```

### 2.2 Package the App Bundle
Compress the application bundle into a ZIP archive or create a DMG installer:
```bash
# Compress using ditto to preserve file permissions and resource forks
ditto -c -k --keepParent CmdTab.app CmdTab.zip
```

---

## 3. Apple Notarization Workflow

Send the ZIP archive to Apple's notarization server. You must set up a keychain profile using your Apple ID and an App-Specific Password:
```bash
# 1. Store credentials in notarytool (one-time setup)
xcrun notarytool store-credentials "notary-profile" \
  --apple-id "developer@email.com" \
  --team-id "TEAMID123" \
  --password "abcd-efgh-ijkl-mnop"

# 2. Submit the archive for notarization and wait for response
xcrun notarytool submit CmdTab.zip --keychain-profile "notary-profile" --wait

# 3. Staple the notarization ticket to the app bundle (so it runs offline)
xcrun stapler staple CmdTab.app

# 4. Verify that notarization and stapling succeeded
spctl --assess -vv --type execute CmdTab.app
```

---

## 4. Apple Review & Distribution Justifications

When submitting to the App Store, you must justify the use of specific APIs. Use the following templates for the Apple Review team:

### 4.1 Justification for Pasteboard (Clipboard) Access
> **Purpose**: `cmdtab` features a keyboard-triggered overlay that helps developers transform code snippets and texts using AI models. To facilitate a seamless user workflow, the app monitors the local system pasteboard changes.
> **Privacy Safeguard**: The clipboard content is processed strictly in-memory and remains volatile. Text is never serialized, written to disk, or transmitted to any remote servers without explicit user interaction (e.g., opening the window and clicking a transformation preset).

### 4.2 Justification for Global Hotkey (`CGEvent` Monitor)
> **Purpose**: The application is a keyboard-driven utility designed to be summoned instantly from anywhere within macOS. It listens for a system-wide hotkey (`⌥Space`) to toggle the visibility of the overlay window.
> **Privacy Safeguard**: Keyboard listening is restricted strictly to the global hotkey combo (`⌥Space`). No other keystrokes or input text are logged or inspected outside the application's focused window boundaries.

### 4.3 Justification for Keychain Services Access
> **Purpose**: To interact with cloud APIs, users configure their personal endpoint credentials (e.g., AnyRouter). The app stores these tokens in the secure system Keychain to protect credentials from storage in plaintext.
