import Foundation

/// Developer fallback for configuration: reads `KEY=value` pairs from a
/// `.env.local` file. The Keychain remains the primary store for secrets
/// (see AGENTS.md §3); this exists so dev builds work without a manual
/// Settings round-trip. Values are never written back to the Keychain.
///
/// Lookup order for a key:
///   1. Process environment (e.g. launched from a shell with the var set)
///   2. `.env.local` in the current working directory
///   3. `.env.local` next to the app bundle (MinhAgent.app sits in the repo root)
public enum EnvFile {
    public static func value(for key: String) -> String? {
        if let env = ProcessInfo.processInfo.environment[key], !env.isEmpty {
            return env
        }
        for url in candidateURLs() {
            if let v = parse(url: url)[key], !v.isEmpty { return v }
        }
        return nil
    }

    private static func candidateURLs() -> [URL] {
        var urls = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(".env.local")
        ]
        let bundleURL = Bundle.main.bundleURL
        if bundleURL.pathExtension == "app" {
            urls.append(
                bundleURL.deletingLastPathComponent().appendingPathComponent(".env.local"))
        }
        return urls
    }

    /// Parses `KEY=value` lines. Ignores blank lines, `#` comments, and
    /// strips one pair of surrounding quotes from values.
    static func parse(url: URL) -> [String: String] {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        return parse(contents: raw)
    }

    static func parse(contents: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in contents.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"),
                let eq = trimmed.firstIndex(of: "=")
            else { continue }
            let key = String(trimmed[..<eq]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: eq)...])
                .trimmingCharacters(in: .whitespaces)
            if value.count >= 2,
                (value.hasPrefix("\"") && value.hasSuffix("\""))
                    || (value.hasPrefix("'") && value.hasSuffix("'"))
            {
                value = String(value.dropFirst().dropLast())
            }
            guard !key.isEmpty else { continue }
            result[key] = value
        }
        return result
    }
}
