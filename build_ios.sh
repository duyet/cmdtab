#!/bin/bash
set -e

echo "=== Building MinhAgent_iOS.app for Simulator (iOS 26) ==="

if [ -d "MinhAgent_iOS.app" ]; then
    echo "Cleaning old iOS build..."
    rm -rf MinhAgent_iOS.app
fi
if [ -f "MinhAgent_iOS" ]; then
    rm -f MinhAgent_iOS
fi

echo "Compiling iOS source files..."
xcrun -sdk iphonesimulator swiftc \
  -target arm64-apple-ios26.0-simulator \
  -parse-as-library -O \
  -o MinhAgent_iOS \
  Sources/Shared/*.swift Sources/iOS/*.swift

echo "Creating iOS app bundle structure..."
mkdir -p MinhAgent_iOS.app

echo "Packaging binary and Info.plist..."
mv MinhAgent_iOS MinhAgent_iOS.app/MinhAgent_iOS
cp Resources/iOS_Info.plist MinhAgent_iOS.app/Info.plist
cp Resources/PrivacyInfo.xcprivacy MinhAgent_iOS.app/PrivacyInfo.xcprivacy

echo "Ad-hoc signing executable and iOS app bundle..."
codesign -s - --force MinhAgent_iOS.app/MinhAgent_iOS
codesign -s - --force MinhAgent_iOS.app

echo "=== iOS Build Successful: MinhAgent_iOS.app created ==="
