#!/bin/bash
set -e

echo "=== Running MinhAgent Unit Tests ==="

xcrun -sdk macosx swiftc -target arm64-apple-macosx14.0 -D DISABLE_NATIVE_LLM -o TestRunner \
  Tests/main.swift \
  Sources/Shared/KeychainHelper.swift \
  Sources/Shared/Models.swift \
  Sources/Shared/APIClient.swift \
  Sources/Shared/EnvFile.swift \
  Sources/Shared/MarkdownBlocks.swift \
  Sources/Shared/AgentResponseBlocks.swift \
  Sources/Shared/LocalModelClient.swift \
  Sources/Shared/AppleIntelligenceAudit.swift \
  Sources/Shared/InferenceAdapter.swift \
  Sources/Shared/ModelCatalog.swift \
  Sources/Shared/PromptAssembly.swift

./TestRunner

rm -f TestRunner

echo "=== All Tests Passed ==="
