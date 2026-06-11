#!/bin/bash
set -e

echo "=== Building MinhAgent.app ==="

if [ -d "MinhAgent.app" ]; then
    echo "Cleaning old build..."
    rm -rf MinhAgent.app
fi
if [ -f "MinhAgent" ]; then
    rm -f MinhAgent
fi

echo "Compiling Swift source files..."
xcrun -sdk macosx swiftc -target arm64-apple-macosx14.0 -parse-as-library -O -o MinhAgent Sources/Shared/*.swift Sources/macOS/*.swift

echo "Creating app bundle structure..."
mkdir -p MinhAgent.app/Contents/MacOS
mkdir -p MinhAgent.app/Contents/Resources

echo "Packaging binary, Info.plist and icon..."
mv MinhAgent MinhAgent.app/Contents/MacOS/MinhAgent
cp Info.plist MinhAgent.app/Contents/Info.plist
cp Resources/PrivacyInfo.xcprivacy MinhAgent.app/Contents/Resources/PrivacyInfo.xcprivacy

echo "Compiling app icon..."
xcrun actool --compile MinhAgent.app/Contents/Resources \
    --app-icon Icon --output-partial-info-plist /tmp/minhagent_icon_partial.plist \
    --platform macosx --minimum-deployment-target 14.0 \
    Resources/logo/Icon.icon > /dev/null

echo "Ad-hoc signing executable and app bundle..."
codesign -s - --force MinhAgent.app/Contents/MacOS/MinhAgent
codesign -s - --force MinhAgent.app

echo "=== Build Successful: MinhAgent.app created ==="
