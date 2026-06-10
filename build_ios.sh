#!/bin/bash
set -e

echo "=== Building CmdTab_iOS.app for Simulator ==="

# 1. Clean previous build if it exists
if [ -d "CmdTab_iOS.app" ]; then
    echo "Cleaning old iOS build..."
    rm -rf CmdTab_iOS.app
fi
if [ -f "CmdTab_iOS" ]; then
    rm -f CmdTab_iOS
fi

# 2. Compile iOS Swift sources using iphonesimulator SDK
echo "Compiling iOS source files..."
xcrun -sdk iphonesimulator swiftc \
  -target arm64-apple-ios17.0-simulator \
  -D DISABLE_NATIVE_LLM \
  -parse-as-library -O \
  -o CmdTab_iOS \
  Sources/Shared/*.swift Sources/iOS/*.swift

# 3. Create .app bundle structure for iOS
echo "Creating iOS app bundle structure..."
mkdir -p CmdTab_iOS.app

# 4. Move binary and copy Info.plist
echo "Packaging binary and Info.plist..."
mv CmdTab_iOS CmdTab_iOS.app/CmdTab_iOS
cp Resources/iOS_Info.plist CmdTab_iOS.app/Info.plist

# 5. Ad-hoc code-sign (required for Apple Silicon Simulator runtime)
echo "Ad-hoc signing executable and iOS app bundle..."
codesign -s - --force CmdTab_iOS.app/CmdTab_iOS
codesign -s - --force CmdTab_iOS.app

echo "=== iOS Build Successful: CmdTab_iOS.app created ==="
