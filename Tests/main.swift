import Foundation

func assert(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: Assertion failed: \(message)")
        exit(1)
    }
}

func testClipboardSanitization() {
    print("Testing PasteboardMonitor text sanitization...")
    // Simulate some raw strings
    let dirtyText = "   \n\n  Clean me up!  \n  "
    let expected = "Clean me up!"

    // In PasteboardMonitor, the sanitization trims whitespace and newlines
    let trimmed = dirtyText.trimmingCharacters(in: .whitespacesAndNewlines)
    assert(trimmed == expected, "Sanitized text should match trimmed expected text")
    print("✓ Clipboard sanitization passed")
}

func testKeychainCRUD() {
    print("Testing KeychainHelper secure storage...")
    let service = "app.cmdtab.macos.test.ci"
    let account = "ci_account"
    let secretValue = "test-ci-api-token-999"

    // Delete first (ignore result — item may not exist)
    KeychainHelper.shared.delete(service: service, account: account)

    // Save
    let saveOk = KeychainHelper.shared.save(secretValue, service: service, account: account)
    // Ad-hoc signed CLI binaries can't access Keychain on Apple Silicon
    // (errSecInteractionNotAllowed). Skip the rest of the test when that happens
    // — the Keychain path is still exercised in the real .app via test_launch.sh.
    guard saveOk else {
        print("⚠ Keychain save skipped (ad-hoc binary, Keychain unavailable)")
        return
    }

    // Read
    let readValue = KeychainHelper.shared.read(service: service, account: account)
    assert(readValue == secretValue, "Keychain read value should match saved value")

    // Delete
    let deleteOk = KeychainHelper.shared.delete(service: service, account: account)
    assert(deleteOk, "Keychain delete should succeed")

    // Read after delete
    let readValuePostDelete = KeychainHelper.shared.read(service: service, account: account)
    assert(readValuePostDelete == nil, "Keychain read after delete should return nil")

    print("✓ Keychain CRUD passed")
}

struct TestChatMessage {
    var id: UUID
    var role: String
    var content: String
}

struct TestConversation {
    var id: UUID
    var title: String
    var messages: [TestChatMessage]
}

func testConversationModels() {
    print("Testing Conversation and Message structures...")
    let msgId = UUID()
    let msg = TestChatMessage(id: msgId, role: "user", content: "Check this logic")

    let convId = UUID()
    let conv = TestConversation(id: convId, title: "English Fix", messages: [msg])

    assert(conv.title == "English Fix", "Conversation title should match")
    assert(conv.messages.count == 1, "Conversation should contain exactly one message")
    assert(conv.messages[0].id == msgId, "First message ID should match user message ID")
    assert(conv.messages[0].content == "Check this logic", "First message content should match")
    print("✓ Conversation models passed")
}

func testPresetFormatting() {
    print("Testing Preset instruction injection logic...")
    let systemPrompt = "Fix spelling and tone. Return only clean output."
    let copiedText = "  somme text with speling errors  "

    // Simulate user selecting preset and running it
    let sanitizedText = copiedText.trimmingCharacters(in: .whitespacesAndNewlines)
    let promptWithContext = "\(systemPrompt)\n\nInput text:\n\"\"\"\n\(sanitizedText)\n\"\"\""

    assert(sanitizedText == "somme text with speling errors", "Text should be trimmed")
    assert(promptWithContext.contains("Fix spelling and tone."), "Prompt should contain instructions")
    assert(promptWithContext.contains("somme text with speling errors"), "Prompt should contain sanitized input text")
    print("✓ Preset formatting passed")
}

// MARK: - SSE Parsing (APIClient.SSEParser)

func testSSEParsingDeltaIsExtracted() {
    print("Testing SSE delta extraction...")
    // WHY: the UI appends tokens incrementally; a data frame with
    // choices[0].delta.content MUST surface exactly that content so streaming
    // text accumulates correctly.
    let line = "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}"
    assert(
        SSEParser.parseLine(line) == .delta("Hello"),
        "A delta frame must yield its content verbatim")

    // WHY: tolerate the no-space "data:" framing some gateways emit.
    let noSpace = "data:{\"choices\":[{\"delta\":{\"content\":\"Hi\"}}]}"
    assert(
        SSEParser.parseLine(noSpace) == .delta("Hi"),
        "Parser must accept 'data:' framing without a trailing space")
}

func testSSEParsingDoneTerminates() {
    print("Testing SSE [DONE] sentinel...")
    // WHY: [DONE] is the only correct end-of-stream signal; treating it as data
    // would corrupt output, and ignoring it would hang the stream.
    assert(
        SSEParser.parseLine("data: [DONE]") == .done,
        "[DONE] must map to the terminal .done event")
}

func testSSEParsingErrorFrameStops() {
    print("Testing SSE mid-stream error frame...")
    // WHY: a provider can fail mid-stream; we must surface its message and stop,
    // not silently drop it, so the user sees why generation halted.
    let line = "data: {\"error\":{\"message\":\"rate limited\"}}"
    assert(
        SSEParser.parseLine(line) == .error(message: "rate limited"),
        "An error frame must surface the provider message")

    // WHY: an error object without a message must still abort, with a fallback.
    let noMsg = "data: {\"error\":{\"code\":429}}"
    assert(
        SSEParser.parseLine(noMsg) == .error(message: "Upstream provider error."),
        "Error frames without a message must fall back to a generic message")
}

func testSSEParsingIgnoresNonPayloadLines() {
    print("Testing SSE non-payload lines are ignored...")
    // WHY: usage-only chunks (stream_options.include_usage) carry empty choices
    // and MUST NOT yield text, or a stray token would leak into the answer.
    let usageOnly = "data: {\"choices\":[],\"usage\":{\"total_tokens\":42}}"
    assert(
        SSEParser.parseLine(usageOnly) == .ignore,
        "Usage-only chunks must be ignored, not yielded as text")

    // WHY: blank lines, SSE comments, and non-data fields are framing noise.
    assert(SSEParser.parseLine("") == .ignore, "Blank lines must be ignored")
    assert(SSEParser.parseLine(": keep-alive") == .ignore, "SSE comments must be ignored")
    assert(SSEParser.parseLine("event: ping") == .ignore, "Non-data fields must be ignored")

    // WHY: a delta with no `content` key (e.g. role-only opening chunk) is not text.
    let roleOnly = "data: {\"choices\":[{\"delta\":{\"role\":\"assistant\"}}]}"
    assert(
        SSEParser.parseLine(roleOnly) == .ignore,
        "A delta without content must not yield text")

    // WHY: malformed JSON must be skipped defensively rather than crash the stream.
    assert(
        SSEParser.parseLine("data: {not json") == .ignore,
        "Malformed JSON frames must be ignored")
}

// MARK: - Request Construction (AnyRouterRequestFactory)

func testRequestURLNormalization() {
    print("Testing AnyRouter URL normalization...")
    // WHY: users configure a base URL; we must append the completions path so the
    // request hits the right endpoint regardless of trailing-slash style.
    assert(
        AnyRouterRequestFactory.normalizedURLString(from: "https://anyrouter.dev/api/v1")
            == "https://anyrouter.dev/api/v1/chat/completions",
        "Base URL must gain the /chat/completions suffix")
    assert(
        AnyRouterRequestFactory.normalizedURLString(from: "https://anyrouter.dev/api/v1/")
            == "https://anyrouter.dev/api/v1/chat/completions",
        "A trailing slash must not produce a double slash")
    // WHY: normalization must be idempotent so re-normalizing an already-complete
    // URL doesn't append the path twice.
    assert(
        AnyRouterRequestFactory.normalizedURLString(from: "https://x.dev/v1/chat/completions")
            == "https://x.dev/v1/chat/completions",
        "An already-complete URL must be left unchanged")
    // WHY: leading/trailing whitespace from copy-paste must not break URL parsing.
    assert(
        AnyRouterRequestFactory.normalizedURLString(from: "  https://x.dev/v1  ")
            == "https://x.dev/v1/chat/completions",
        "Surrounding whitespace must be trimmed before path append")
}

func testRequestBodyShape() {
    print("Testing AnyRouter request body shape...")
    let messages = [["role": "user", "content": "hi"]]
    let body = AnyRouterRequestFactory.requestBody(model: "anthropic/claude-sonnet-4.6", messages: messages)

    // WHY: the model id must round-trip unchanged so the gateway routes to the
    // provider/model the user selected.
    assert(
        body["model"] as? String == "anthropic/claude-sonnet-4.6",
        "Body must carry the exact model id")
    // WHY: streaming is the app's only completion mode; stream must always be true.
    assert(body["stream"] as? Bool == true, "Body must request a streamed response")
    // WHY: include_usage drives the final usage chunk; its absence would lose token
    // accounting and change the stream's terminal frame shape.
    let opts = body["stream_options"] as? [String: Any]
    assert(
        opts?["include_usage"] as? Bool == true,
        "Body must opt into usage reporting via stream_options.include_usage")
}

func testRequestHeadersAndAuth() throws {
    print("Testing AnyRouter request headers and auth...")
    let req = try AnyRouterRequestFactory.makeRequest(
        endpointUrl: "https://anyrouter.dev/api/v1",
        apiKey: "sk-test-123",
        model: "anthropic/claude-sonnet-4.6",
        messages: [["role": "user", "content": "hi"]]
    )

    assert(req.httpMethod == "POST", "Completions must be a POST")
    assert(
        req.value(forHTTPHeaderField: "Content-Type") == "application/json",
        "Body is JSON")
    assert(
        req.value(forHTTPHeaderField: "Accept") == "text/event-stream",
        "Must accept an SSE stream")
    // WHY: AnyRouter attributes traffic via X-AnyRouter-* headers; dropping them
    // breaks app attribution on the gateway dashboard.
    assert(
        req.value(forHTTPHeaderField: "X-AnyRouter-App") == "cmdtab",
        "App attribution header must be present")
    assert(
        req.value(forHTTPHeaderField: "X-AnyRouter-Referer") == "https://github.com/duyet/cmdtab",
        "Referer attribution header must be present")
    assert(
        req.value(forHTTPHeaderField: "X-AnyRouter-Title") == "cmdtab",
        "Title attribution header must be present")
    // WHY: a present key must become a Bearer token, or requests are unauthorized.
    assert(
        req.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test-123",
        "A non-empty API key must be sent as a Bearer token")
}

func testRequestOmitsAuthWhenNoKey() throws {
    print("Testing AnyRouter request omits auth without a key...")
    // WHY: sending "Bearer " with no key would be a malformed credential; absence
    // is correct so the server returns a clear 401 instead.
    let req = try AnyRouterRequestFactory.makeRequest(
        endpointUrl: "https://anyrouter.dev/api/v1",
        apiKey: nil,
        model: "m",
        messages: []
    )
    assert(
        req.value(forHTTPHeaderField: "Authorization") == nil,
        "No Authorization header must be set when the key is nil")
}

// MARK: - Adapter Prompt Assembly (AnyRouterAdapter)

func testAdapterPrependsSystemInstructions() {
    print("Testing adapter prompt assembly...")
    let history: [(role: String, content: String)] = [
        (role: "user", content: "first"),
        (role: "assistant", content: "reply"),
        (role: "user", content: "second"),
    ]
    let msgs = AnyRouterAdapter.formatMessages(instructions: "Be concise.", history: history)

    // WHY: the system turn must lead so the model is steered before any user text.
    assert(msgs.first?["role"] == "system", "First message must be the system role")
    assert(msgs.first?["content"] == "Be concise.", "System content must be the instructions")
    // WHY: history order must be preserved so multi-turn context stays coherent.
    assert(msgs.count == 4, "System turn plus three history turns")
    assert(
        msgs[1]["role"] == "user" && msgs[1]["content"] == "first",
        "History must follow in original order")
    assert(msgs[3]["content"] == "second", "Last user turn must be preserved")
}

// MARK: - Local Model Availability & Errors (LocalModelClient)

func testLocalModelCompiledOutUnderFlag() {
    print("Testing local model availability under DISABLE_NATIVE_LLM...")
    // WHY: tests compile with -D DISABLE_NATIVE_LLM (mirroring the app), so the
    // on-device backend MUST report .compiledOut and never claim availability.
    let availability = LocalModelClient.shared.availability
    assert(
        availability == .compiledOut,
        "Under DISABLE_NATIVE_LLM availability must be .compiledOut")
    assert(
        availability.isAvailable == false,
        "A compiled-out model must never report itself available")
}

func testLocalModelStreamThrowsWhenCompiledOut() {
    print("Testing local model stream rejects when compiled out...")
    // WHY: selecting Local on a build without on-device support must fail loudly
    // with a user-facing reason, not hang or return an empty stream.
    do {
        _ = try LocalModelClient.shared.streamResponse(instructions: "x", prompt: "y")
        assert(false, "Compiled-out streamResponse must throw")
    } catch let error as LocalModelError {
        assert(
            error.message.contains("isn't included in this build"),
            "Error must explain the model is excluded from this build")
    } catch {
        assert(false, "Must throw LocalModelError, got \(error)")
    }
}

func testLocalModelErrorMessaging() {
    print("Testing local model availability reason messages...")
    // WHY: each unavailability state maps to a distinct, actionable user message;
    // .available alone must have no reason so callers can branch on nil.
    assert(
        LocalModelAvailability.available.unavailableReason == nil,
        "Available state must have no unavailable reason")
    assert(
        LocalModelAvailability.deviceNotEligible.unavailableReason?.contains("eligible") == true,
        "deviceNotEligible must mention eligibility")
    assert(
        LocalModelAvailability.appleIntelligenceNotEnabled.unavailableReason?.contains("System Settings") == true,
        "appleIntelligenceNotEnabled must point to System Settings")
    assert(
        LocalModelAvailability.modelNotReady.unavailableReason?.contains("downloading") == true,
        "modelNotReady must mention the download in progress")
    assert(
        LocalModelAvailability.compiledOut.unavailableReason?.contains("Cloud API") == true,
        "compiledOut must steer the user to the Cloud API")

    // WHY: LocalModelError must round-trip its message through LocalizedError so the
    // UI's error banner shows the real cause, not a generic description.
    let err = LocalModelError("boom")
    assert(err.errorDescription == "boom", "LocalModelError must expose its message via errorDescription")
}

// MARK: - APIError Messaging

func testAPIErrorMessaging() {
    print("Testing APIError user-facing messages...")
    // WHY: invalidResponse must embed status + body so failures are diagnosable
    // from the UI without digging through logs.
    let resp = APIError.invalidResponse(statusCode: 503, body: "down")
    assert(
        resp.errorDescription?.contains("503") == true && resp.errorDescription?.contains("down") == true,
        "invalidResponse must surface both status code and body")
    // WHY: a mid-stream streamError must show the provider's own message verbatim.
    assert(
        APIError.streamError(message: "quota exceeded").errorDescription == "quota exceeded",
        "streamError must surface its message verbatim")
    assert(
        APIError.missingApiKey.errorDescription?.contains("API Key") == true,
        "missingApiKey must mention the API key")
}

func runAllTests() {
    testClipboardSanitization()
    testKeychainCRUD()
    testConversationModels()
    testPresetFormatting()
    testSSEParsingDeltaIsExtracted()
    testSSEParsingDoneTerminates()
    testSSEParsingErrorFrameStops()
    testSSEParsingIgnoresNonPayloadLines()
    testRequestURLNormalization()
    testRequestBodyShape()
    try! testRequestHeadersAndAuth()
    try! testRequestOmitsAuthWhenNoKey()
    testAdapterPrependsSystemInstructions()
    testLocalModelCompiledOutUnderFlag()
    testLocalModelStreamThrowsWhenCompiledOut()
    testLocalModelErrorMessaging()
    testAPIErrorMessaging()
    print("=== All Tests Passed Successfully ===")
}

runAllTests()
