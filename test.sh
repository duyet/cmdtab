#!/bin/bash
set -e

echo "=== Running cmdtab.app Unit Tests ==="

# Compile the TestRunner by linking main.swift with the Foundation-only service layer.
# These sources import only Foundation/Security (no SwiftUI), so they link cleanly
# into the headless runner. -D DISABLE_NATIVE_LLM mirrors the app build so the
# compiled-out on-device path is what we exercise (see AGENTS.md §2.1).
xcrun -sdk macosx swiftc -target arm64-apple-macosx14.0 -D DISABLE_NATIVE_LLM -o TestRunner \
  Tests/main.swift \
  Sources/Shared/KeychainHelper.swift \
  Sources/Shared/Models.swift \
  Sources/Shared/APIClient.swift \
  Sources/Shared/EnvFile.swift \
  Sources/Shared/MarkdownBlocks.swift \
  Sources/Shared/LocalModelClient.swift \
  Sources/Shared/InferenceAdapter.swift \
  Sources/Shared/ModelCatalog.swift

# Execute the compiled tests
./TestRunner

# Clean up test binary
rm -f TestRunner

echo "=== All Tests Passed ==="
