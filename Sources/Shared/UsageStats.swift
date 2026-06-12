import Foundation

// MARK: - Usage Stats
/// Per-day usage counters backing the welcome-screen activity calendar.
/// Only numbers are persisted (UserDefaults) for usage counters; conversation content
/// is persisted separately as a local JSON file under Application Support.
public struct DayUsage: Codable, Equatable {
    public var sessions: Int = 0
    public var messages: Int = 0
    public var tokens: Int = 0
}

public enum UsageStats {
    private static let storageKey = "usageStatsByDay"

    /// Stable "yyyy-MM-dd" key in the current calendar/timezone.
    public static func dayKey(for date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public static func load() -> [String: DayUsage] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([String: DayUsage].self, from: data)
        else { return [:] }
        return decoded
    }

    public static func save(_ usage: [String: DayUsage]) {
        if let data = try? JSONEncoder().encode(usage) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Rough token estimate for plain text (~4 characters per token).
    public static func estimateTokens(_ text: String) -> Int {
        max(0, text.count / 4)
    }
}
