#!/bin/bash
# Build, sign, install and launch MinhAgent on a connected physical iPhone/iPad.
#
# Unlike build_ios_device.sh (raw swiftc, simulator-style signing), this uses the
# MinhAgent.xcodeproj iOS scheme with automatic provisioning — the only path that
# produces a profile the device will actually run.
#
#   ./deploy_ios.sh            # detect device → build → install → launch
#   ./deploy_ios.sh --no-launch  # install only
#
# Requires: a wired/networked device with Developer Mode enabled, and an Apple
# Development identity whose team matches DEVELOPMENT_TEAM in the project.
set -euo pipefail
cd "$(dirname "$0")"

SCHEME="MinhAgent_iOS"
BUNDLE_ID="app.minhagent.ios"
DERIVED="build/ios-device"

# ── 1. Detect a connected physical device ────────────────────────────
echo "Detecting physical device…"
xcrun devicectl list devices --json-output /tmp/minhagent_devices.json >/dev/null 2>&1

read -r DEV_ID DEV_UDID DEV_NAME < <(/usr/bin/python3 - <<'PY'
import json
d = json.load(open("/tmp/minhagent_devices.json"))
for dev in d["result"]["devices"]:
    cp = dev.get("connectionProperties", {})
    hp = dev.get("hardwareProperties", {})
    dp = dev.get("deviceProperties", {})
    # Physical = real transport (wired/localNetwork), not a simulator (sameMachine)
    if cp.get("tunnelState") == "connected" \
       and cp.get("transportType") in ("wired", "localNetwork") \
       and hp.get("platform") == "iOS":
        print(dev["identifier"], hp["udid"], dp.get("name", "device").replace(" ", "_"))
        break
PY
)

if [ -z "${DEV_ID:-}" ]; then
    echo "✗ No physical iOS device found."
    echo "  Connect an iPhone/iPad, unlock it, trust this Mac, and enable Developer Mode."
    exit 1
fi
echo "✓ Device: ${DEV_NAME//_/ }  (udid ${DEV_UDID})"

# ── 2. Build + sign (automatic provisioning) ─────────────────────────
echo "Building ${SCHEME} for device…"
xcrun xcodebuild \
  -project MinhAgent.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "platform=iOS,id=${DEV_UDID}" \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  build

APP="${DERIVED}/Build/Products/Release-iphoneos/${SCHEME}.app"
[ -d "$APP" ] || { echo "✗ Build product not found at ${APP}"; exit 1; }

# ── 3. Install ───────────────────────────────────────────────────────
echo "Installing on device…"
xcrun devicectl device install app --device "$DEV_ID" "$APP"

# ── 4. Launch (smoke test) ───────────────────────────────────────────
if [ "${1:-}" = "--no-launch" ]; then
    echo "=== Installed (launch skipped) ==="
    exit 0
fi
echo "Launching ${BUNDLE_ID}…"
xcrun devicectl device process launch --device "$DEV_ID" "$BUNDLE_ID"
echo "=== Deployed & launched on ${DEV_NAME//_/ } ==="
