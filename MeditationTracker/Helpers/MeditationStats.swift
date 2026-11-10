import Foundation

enum MeditationStats {
    /// Total meditated seconds keyed by the start of each day.
    static func secondsByDay(_ sessions: [MeditationSession], calendar: Calendar = .current) -> [Date: Int] {
        var result: [Date: Int] = [:]
        for session in sessions {
            result[calendar.startOfDay(for: session.startDate), default: 0] += session.durationSeconds
        }
        return result
    }

    static func meditationDays(_ sessions: [MeditationSession], calendar: Calendar = .current) -> Set<Date> {
        Set(sessions.map { calendar.startOfDay(for: $0.startDate) })
    }

    /// Consecutive days up to today. If you haven't meditated yet today,
    /// the streak through yesterday still counts (it's not broken until the day ends).
    static func currentStreak(_ days: Set<Date>, calendar: Calendar = .current, today: Date = .now) -> Int {
        var day = calendar.startOfDay(for: today)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  days.contains(yesterday) else { return 0 }
            day = yesterday
        }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    static func longestStreak(_ days: Set<Date>, calendar: Calendar = .current) -> Int {
        var longest = 0
        var current = 0
        var previous: Date?
        for day in days.sorted() {
            if let previous,
               let next = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(next, inSameDayAs: day) {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            previous = day
        }
        return longest
    }
}
