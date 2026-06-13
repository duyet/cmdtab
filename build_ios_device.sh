#!/bin/bash
# Build MinhAgent_iOS.app for a PHYSICAL iPhone and (optionally) install + launch it.
#
# Compiles for the iphoneos SDK, auto-discovers the matching provisioning profile and
# a connected device, signs with the "Apple Development" identity, then installs and
# launches via devicectl.
#
# Usage:
#   ./build_ios_device.sh           # build + sign + install + launch (default)
#   ./build_ios_device.sh build     # build + sign only, skip deploy
#
# Overrides:
#   IDENTITY="Apple Development: you@..." DEVICE_ID=<coredevice-id> ./build_ios_device.sh
set -e

# --- Configuration ---
BUNDLE_ID="app.minhagent.ios"
IDENTITY="${IDENTITY:-Apple Development: lvduit08@gmail.com (ZK9ZJ3365L)}"
PROF_DIR="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
APP_NAME="MinhAgent_iOS"
ACTION="${1:-deploy}"
ENTITLEMENTS="/tmp/minhagent_ios_device_entitlements.plist"

# Discover the provisioning profile whose application-identifier matches BUNDLE_ID.
# Xcode regenerates profiles (changing UUIDs), so match by content, not by filename.
discover_profile() {
    local decoded=/tmp/minhagent_pp_scan.plist p appid
    for p in "$PROF_DIR"/*.mobileprovision; do
        [ -f "$p" ] || continue
        security cms -D -i "$p" 2>/dev/null > "$decoded" || continue
        appid=$(plutil -extract Entitlements.application-identifier raw "$decoded" 2>/dev/null)
        case "$appid" in
            *."$BUNDLE_ID") echo "$p"; rm -f "$decoded"; return 0;;
        esac
    done
    rm -f "$decoded"
    return 1
}

# CoreDevice identifier (NOT the UDID) of the first connected, available, physical
# iPhone. Robust to device names with spaces — matches the UUID by pattern, not column.
detect_device() {
    xcrun devicectl list devices 2>/dev/null \
      | awk '/available/ && /physical/' \
      | grep -oE '[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}' \
      | head -1
}

echo "=== Building ${APP_NAME}.app for Device (iOS 26, arm64) ==="

if [ -d "${APP_NAME}.app" ]; then
    echo "Cleaning old device build..."
    rm -rf "${APP_NAME}.app"
fi
if [ -f "$APP_NAME" ]; then
    rm -f "$APP_NAME"
fi

echo "Compiling iOS source files (iphoneos)..."
xcrun -sdk iphoneos swiftc \
  -target arm64-apple-ios26.0 \
  -module-name MinhAgent_iOS \
  -parse-as-library -O \
  -o "$APP_NAME" \
  Sources/Shared/*.swift Sources/iOS/*.swift

echo "Creating iOS app bundle..."
mkdir -p "${APP_NAME}.app"
mv "$APP_NAME" "${APP_NAME}.app/$APP_NAME"
cp Resources/iOS_Info.plist "${APP_NAME}.app/Info.plist"
cp Resources/PrivacyInfo.xcprivacy "${APP_NAME}.app/PrivacyInfo.xcprivacy"

echo "Compiling app icon (iphoneos)..."
xcrun actool --compile "${APP_NAME}.app" \
    --app-icon AppIcon --output-partial-info-plist /tmp/minhagent_ios_icon_partial.plist \
    --platform iphoneos --minimum-deployment-target 26.0 \
    Assets.xcassets > /dev/null

PROFILE_PATH="$(discover_profile)" || true
if [ -z "$PROFILE_PATH" ]; then
    echo "No provisioning profile matching ${BUNDLE_ID} found in:"
    echo "  $PROF_DIR"
    echo "Open Xcode once to let it download the profile, then rerun."
    exit 1
fi
PROFILE_UUID="$(basename "$PROFILE_PATH" .mobileprovision)"
echo "Using profile: $PROFILE_UUID"

echo "Extracting entitlements from provisioning profile..."
security cms -D -i "$PROFILE_PATH" 2>/dev/null > "$ENTITLEMENTS.tmp"
plutil -extract Entitlements xml1 -o "$ENTITLEMENTS" "$ENTITLEMENTS.tmp"
rm -f "$ENTITLEMENTS.tmp"

echo "Embedding provisioning profile..."
cp "$PROFILE_PATH" "${APP_NAME}.app/embedded.mobileprovision"

echo "Signing with development identity..."
codesign -f -s "$IDENTITY" \
  --entitlements "$ENTITLEMENTS" \
  "${APP_NAME}.app"

echo "=== Device Build Successful: ${APP_NAME}.app created ==="

if [ "$ACTION" = "build" ]; then
    echo "Skipping deploy. Run with no arg (or 'deploy') to install + launch."
    exit 0
fi

DEVICE_ID="${DEVICE_ID:-$(detect_device)}"
if [ -z "$DEVICE_ID" ]; then
    echo "No available physical iPhone found."
    echo "Connect one (unlock it, tap Trust this Mac), then rerun — or set DEVICE_ID explicitly."
    exit 1
fi

echo "Installing on device ($DEVICE_ID)..."
xcrun devicectl device install app --device "$DEVICE_ID" "${APP_NAME}.app"

echo "Launching $BUNDLE_ID..."
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"

echo "=== Done: installed and launched on device ==="
