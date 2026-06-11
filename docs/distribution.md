# macOS App Distribution Guide

## 1. Certificates

- **Direct distribution**: `Developer ID Application` certificate.
- **App Store**: `Apple Distribution` certificate.

### Entitlements (`MinhAgent.entitlements`)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)minhagent.app</string>
    </array>
</dict>
</plist>
```

## 2. Code Sign & Package

```bash
codesign --force --options runtime \
  --sign "Developer ID Application: Your Name (TeamID)" \
  --entitlements MinhAgent.entitlements \
  MinhAgent.app/Contents/MacOS/MinhAgent

codesign --force --sign "Developer ID Application: Your Name (TeamID)" MinhAgent.app

ditto -c -k --keepParent MinhAgent.app MinhAgent.zip
```

## 3. Notarize

```bash
xcrun notarytool store-credentials "notary-profile" \
  --apple-id "developer@email.com" --team-id "TEAMID123" --password "abcd-efgh-ijkl-mnop"

xcrun notarytool submit MinhAgent.zip --keychain-profile "notary-profile" --wait

xcrun stapler staple MinhAgent.app

spctl --assess -vv --type execute MinhAgent.app
```

## 4. App Review Justifications

**Pasteboard**: MinhAgent monitors clipboard to surface Quick Actions for copied content. Content is processed in-memory only; never written to disk or transmitted without user interaction.

**Global hotkey (`⌥Space`)**: Single hotkey combo to toggle the window. No other keystrokes are monitored.

**Keychain**: API credentials are stored in the system Keychain under `minhagent.app` — never in plaintext files.
