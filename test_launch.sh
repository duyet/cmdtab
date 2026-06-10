#!/bin/bash
set -e

echo "=== Running Launch Verification Test ==="

# 1. Compile and build the app first
./build.sh

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
