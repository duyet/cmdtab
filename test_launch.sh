#!/bin/bash
set -e

echo "=== Running Launch Verification Test ==="

echo "Compiling Swift source files..."
if [ -d "MinhAgent.app" ]; then
    echo "Cleaning old build..."
    rm -rf MinhAgent.app
fi
if [ -f "MinhAgent" ]; then
    rm -f MinhAgent
fi

xcrun -sdk macosx swiftc -target arm64-apple-macosx14.0 -parse-as-library -O -D DISABLE_NATIVE_LLM -o MinhAgent Sources/Shared/*.swift Sources/macOS/*.swift

echo "Creating app bundle structure..."
mkdir -p MinhAgent.app/Contents/MacOS
mkdir -p MinhAgent.app/Contents/Resources

echo "Packaging binary, Info.plist and icon..."
mv MinhAgent MinhAgent.app/Contents/MacOS/MinhAgent
cp Info.plist MinhAgent.app/Contents/Info.plist
cp Resources/PrivacyInfo.xcprivacy MinhAgent.app/Contents/Resources/PrivacyInfo.xcprivacy

echo "Compiling app icon..."
iconutil -c icns Resources/logo/AppIcon.iconset -o MinhAgent.app/Contents/Resources/AppIcon.icns
cp Resources/logo/StatusBarIconTemplate.png MinhAgent.app/Contents/Resources/StatusBarIconTemplate.png

echo "Ad-hoc signing executable and app bundle..."
codesign -s - --force MinhAgent.app/Contents/MacOS/MinhAgent
codesign -s - --force MinhAgent.app

echo "Launching MinhAgent.app..."
/usr/bin/open -n MinhAgent.app

sleep 2
APP_EXEC="$PWD/MinhAgent.app/Contents/MacOS/MinhAgent"
APP_PID=$(pgrep -nf "$APP_EXEC" || true)

if [ -n "$APP_PID" ] && kill -0 "$APP_PID" 2>/dev/null; then
    echo "✓ MinhAgent successfully launched and is running (PID: $APP_PID)"

    if plutil -p MinhAgent.app/Contents/Info.plist | grep -q LSUIElement; then
        echo "❌ Error: MinhAgent.app is still marked LSUIElement; Dock/Cmd-Tab presence is disabled."
        kill "$APP_PID"
        exit 1
    fi

    kill "$APP_PID"
    wait "$APP_PID" 2>/dev/null || true
    echo "✓ MinhAgent successfully terminated"
    echo "=== Launch Verification Passed ==="
else
    echo "❌ Error: MinhAgent process died immediately on startup!"
    exit 1
fi
