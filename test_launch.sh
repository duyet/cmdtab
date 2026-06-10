#!/bin/bash
set -e

echo "=== Running Launch Verification Test ==="

# 1. Compile and build the app first with DISABLE_NATIVE_LLM for CI compatibility
# (FoundationModels is only available on macOS 26+; CI runs on macOS 14)
echo "Compiling Swift source files..."
if [ -d "CmdTab.app" ]; then
    echo "Cleaning old build..."
    rm -rf CmdTab.app
fi
if [ -f "CmdTab" ]; then
    rm -f CmdTab
fi

xcrun -sdk macosx swiftc -target arm64-apple-macosx14.0 -parse-as-library -O -D DISABLE_NATIVE_LLM -o CmdTab Sources/Shared/*.swift Sources/macOS/*.swift

echo "Creating app bundle structure..."
mkdir -p CmdTab.app/Contents/MacOS
mkdir -p CmdTab.app/Contents/Resources

echo "Packaging binary, Info.plist and icon..."
mv CmdTab CmdTab.app/Contents/MacOS/CmdTab
cp Info.plist CmdTab.app/Contents/Info.plist

echo "Compiling app icon..."
xcrun actool --compile CmdTab.app/Contents/Resources \
    --app-icon Icon --output-partial-info-plist /tmp/cmdtab_icon_partial.plist \
    --platform macosx --minimum-deployment-target 14.0 \
    Resources/logo/Icon.icon > /dev/null

echo "Ad-hoc signing executable and app bundle..."
codesign -s - --force CmdTab.app/Contents/MacOS/CmdTab
codesign -s - --force CmdTab.app

# 2. Launch the app binary in the background
echo "Launching CmdTab executable..."
./CmdTab.app/Contents/MacOS/CmdTab &
APP_PID=$!

# 3. Wait a moment for it to initialize
sleep 2

# 4. Check if the process is still running
if kill -0 $APP_PID 2>/dev/null; then
    echo "✓ CmdTab successfully launched and is running (PID: $APP_PID)"
    
    # Clean up and kill the background process
    kill $APP_PID
    wait $APP_PID 2>/dev/null || true
    echo "✓ CmdTab successfully terminated"
    echo "=== Launch Verification Passed ==="
else
    echo "❌ Error: CmdTab process died immediately on startup!"
    exit 1
fi
