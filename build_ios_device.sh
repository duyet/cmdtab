#!/bin/bash
set -e

echo "=== Building MinhAgent for iOS Device ==="

# ─── Config ──────────────────────────────────────────────────────────
# Override IDENTITY via env or argument:
#   IDENTITY="Apple Development: you@email.com (ABCD1234)" ./build_ios_device.sh
# List available: security find-identity -v -p codesigning
IDENTITY="${IDENTITY:-${1:-}}"
BUNDLE_ID="app.minhagent.ios"
APP_NAME="MinhAgent_iOS_Device"
# ─────────────────────────────────────────────────────────────────────

if [ -d "${APP_NAME}.app" ]; then
    echo "Cleaning old device build..."
    rm -rf "${APP_NAME}.app"
fi
if [ -f "${APP_NAME}" ]; then
    rm -f "${APP_NAME}"
fi

echo "Compiling for arm64-ios26.0 (device)..."
xcrun -sdk iphoneos swiftc \
  -target arm64-apple-ios26.0 \
  -parse-as-library -O \
  -o "${APP_NAME}" \
  Sources/Shared/*.swift Sources/iOS/*.swift

echo "Packaging..."
mkdir -p "${APP_NAME}.app"
mv "${APP_NAME}" "${APP_NAME}.app/MinhAgent_iOS"
cp Resources/iOS_Info.plist "${APP_NAME}.app/Info.plist"

if [ -n "$IDENTITY" ]; then
    echo "Signing with: ${IDENTITY}"
    codesign -s "$IDENTITY" --force --timestamp "${APP_NAME}.app"
else
    echo "Ad-hoc signing (no identity specified — will NOT run on device)"
    echo "  To sign for device: IDENTITY=\"Apple Development: you@...\" $0"
    codesign -s - --force "${APP_NAME}.app"
fi

echo "=== Device Build: ${APP_NAME}.app ==="

# ─── Deploy (optional) ──────────────────────────────────────────────
if [ "${2:-}" = "deploy" ] || [ "${DEPLOY:-}" = "1" ]; then
    echo ""
    echo "Looking for connected devices..."
    DEVICE_ID=$(xcrun devicectl list devices 2>/dev/null | grep -m1 "iPhone" | awk '{print $NF}' || true)

    if [ -z "$DEVICE_ID" ]; then
        echo "No iPhone found. Connect a device and try:"
        echo "  DEPLOY=1 ./build_ios_device.sh"
        exit 1
    fi

    echo "Installing on device: ${DEVICE_ID}..."
    xcrun devicectl device install app --device "$DEVICE_ID" "${APP_NAME}.app"
    echo "=== Deployed ==="
fi
