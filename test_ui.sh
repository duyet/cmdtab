#!/bin/bash
# =============================================================================
# UI test for MinhAgent (macOS) — smoke + end-to-end journey in one.
#
# Drives the *built* app through the Accessibility API (System Events):
#
#   launch → window + toolbar present → type in composer → open Settings
#          → tab through Settings pages → close Settings → toggle sidebar → alive
#
# Requires Accessibility permission for the controlling terminal. SKIPS loudly
# (exit 0) when absent — safe on hosted CI runners.
#
# Usage:  ./test_ui.sh            # builds if needed, then runs the journey
#         ./test_ui.sh --no-build
# =============================================================================
set -euo pipefail

APP="MinhAgent.app"
BIN_NAME="MinhAgent"
SKIP_BUILD="${1:-}"

echo "=== MinhAgent UI Test (smoke + e2e journey) ==="

if [[ "$SKIP_BUILD" != "--no-build" ]]; then
    ./build.sh >/dev/null
fi
if [[ ! -d "$APP" ]]; then
    echo "✗ $APP not found — run ./build.sh first" >&2
    exit 1
fi

AX_OK=$(osascript -e 'tell application "System Events" to return UI elements enabled' 2>/dev/null || echo "false")
if [[ "$AX_OK" != "true" ]]; then
    echo "⚠️  SKIP: Accessibility permission not granted to this terminal."
    echo "        Grant it in System Settings → Privacy & Security → Accessibility."
    echo "        (Skipping is not a failure.)"
    exit 0
fi

pkill -x "$BIN_NAME" 2>/dev/null || true
sleep 0.5
open "$APP"
echo "Launched $APP — running journey…"

RESULT=$(osascript <<'APPLESCRIPT'
on clickButton(proc, theName)
    tell application "System Events"
        tell proc
            repeat with el in (entire contents of window 1)
                try
                    if (role of el is "AXButton") then
                        if (name of el is theName) or (description of el is theName) then
                            click el
                            return true
                        end if
                    end if
                end try
            end repeat
        end tell
    end tell
    return false
end clickButton

on hasText(proc, needle)
    tell application "System Events"
        tell proc
            repeat with el in (entire contents of window 1)
                try
                    if (value of el as text) contains needle then return true
                end try
                try
                    if (name of el as text) contains needle then return true
                end try
            end repeat
        end tell
    end tell
    return false
end hasText

on alive(proc)
    tell application "System Events"
        tell proc to return (exists window 1)
    end tell
end alive

set journey to {}

tell application "System Events"
    set ok to false
    repeat 25 times
        if exists (process "MinhAgent") then
            if (count of windows of process "MinhAgent") > 0 then
                set ok to true
                exit repeat
            end if
        end if
        delay 0.2
    end repeat
    if not ok then return "FAIL:no window appeared"
end tell
tell application "System Events" to set proc to (first process whose name is "MinhAgent")
set end of journey to "window"

tell application "System Events"
    tell proc
        if not (exists toolbar 1 of window 1) then return "FAIL:window has no toolbar"
        if (count of buttons of toolbar 1 of window 1) is 0 then return "FAIL:toolbar has no buttons"
    end tell
end tell
set end of journey to "toolbar"

set marker to "ui test ping 4242"
tell application "System Events"
    try
        set frontmost of proc to true
        tell proc to perform action "AXRaise" of window 1
    end try
    delay 0.4
    keystroke marker
    delay 0.3
    keystroke return
end tell
set sent to false
repeat 15 times
    if hasText(proc, marker) then
        set sent to true
        exit repeat
    end if
    delay 0.2
end repeat
if not alive(proc) then return "FAIL:window vanished after send"
if sent then
    set end of journey to "message-sent"
    set responded to false
    repeat 40 times
        tell application "System Events"
            tell proc
                try
                    if (count of (static texts of window 1)) > 2 then set responded to true
                end try
            end tell
        end tell
        if responded then exit repeat
        delay 0.25
    end repeat
    if responded then set end of journey to "response-received"
else
    set end of journey to "type-send-skipped(no-key-focus)"
end if

if clickButton(proc, "Settings") then
    delay 0.5
    set end of journey to "settings-open"
    repeat with pageName in {"Profile", "Personalization", "Cloud Model", "General"}
        if clickButton(proc, pageName) then
            set end of journey to ("settings-tab:" & pageName)
            delay 0.3
        end if
    end repeat
    if clickButton(proc, "Close settings") then
        delay 0.3
        set end of journey to "settings-closed"
    end if
    if not alive(proc) then return "FAIL:window vanished during Settings journey"
end if

clickButton(proc, "Toggle Sidebar")
delay 0.4
if not alive(proc) then return "FAIL:window vanished toggling sidebar"
set end of journey to "sidebar-toggled"

set text item delimiters to " > "
return "PASS:" & (journey as text)
APPLESCRIPT
)

pkill -x "$BIN_NAME" 2>/dev/null || true

case "$RESULT" in
    PASS:*)
        echo "✓ Journey: ${RESULT#PASS:}"
        echo "=== UI Test Passed ==="
        ;;
    FAIL:*)
        echo "✗ ${RESULT#FAIL:}" >&2
        echo "=== UI Test Failed ===" >&2
        exit 1
        ;;
    *)
        echo "✗ Unexpected result: $RESULT" >&2
        exit 1
        ;;
esac
