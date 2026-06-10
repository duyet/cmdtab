#!/bin/bash
set -e

echo "=== Building cmdtab.app ==="

# 1. Clean previous build if it exists
if [ -d "CmdTab.app" ]; then
    echo "Cleaning old build..."
    rm -rf CmdTab.app
fi
if [ -f "CmdTab" ]; then
    rm -f CmdTab
fi

# 2. Compile Swift sources
echo "Compiling Swift source files..."
# FoundationModels is availability-guarded (#available macOS 26+) and
# auto-weak-linked, so the real on-device path ships while the app still
# runs on macOS 14+. Add -D DISABLE_NATIVE_LLM to compile it out if needed.
xcrun -sdk macosx swiftc -target arm64-apple-macosx14.0 -parse-as-library -O -o CmdTab Sources/Shared/*.swift Sources/macOS/*.swift

# 3. Create .app bundle structure
echo "Creating app bundle structure..."
mkdir -p CmdTab.app/Contents/MacOS
mkdir -p CmdTab.app/Contents/Resources

# 4. Move binary, copy Info.plist and app icon
echo "Packaging binary, Info.plist and icon..."
mv CmdTab CmdTab.app/Contents/MacOS/CmdTab
cp Info.plist CmdTab.app/Contents/Info.plist

# Compile the Icon Composer bundle (Resources/logo/Icon.icon) into the app
echo "Compiling app icon..."
xcrun actool --compile CmdTab.app/Contents/Resources \
    --app-icon Icon --output-partial-info-plist /tmp/cmdtab_icon_partial.plist \
    --platform macosx --minimum-deployment-target 14.0 \
    Resources/logo/Icon.icon > /dev/null

# 5. Ad-hoc code-sign (required for Apple Silicon macOS)
echo "Ad-hoc signing executable and app bundle..."
codesign -s - --force CmdTab.app/Contents/MacOS/CmdTab
codesign -s - --force CmdTab.app

echo "=== Build Successful: CmdTab.app created ==="
