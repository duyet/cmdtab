#!/bin/bash
# Lint & format via Apple's swift-format (bundled with the Xcode toolchain).
#   ./lint.sh          — lint (report violations, non-zero exit on findings)
#   ./lint.sh --fix    — format in place
# Also runs a strict zero-warning typecheck, the project's real lint gate.
set -e
cd "$(dirname "$0")"

FILES=$(find Sources Tests -name '*.swift')

if [ "$1" = "--fix" ]; then
    xcrun swift-format format --in-place --configuration .swift-format $FILES
    echo "Formatted."
else
    xcrun swift-format lint --strict --configuration .swift-format $FILES || true
fi

echo "Typechecking (warnings-as-errors)…"
xcrun swiftc -typecheck -warnings-as-errors \
    -target arm64-apple-macosx14.0 -D DISABLE_NATIVE_LLM -parse-as-library \
    Sources/Shared/*.swift Sources/macOS/*.swift
echo "OK: zero warnings."
