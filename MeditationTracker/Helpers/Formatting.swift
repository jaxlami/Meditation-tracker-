import Foundation

enum Fmt {
    /// "45 sec", "12 min", "12 min 30 sec", "1 h 5 min"
    static func duration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) sec" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours) h \(minutes) min" : "\(hours) h"
        }
        return secs > 0 ? "\(minutes) min \(secs) sec" : "\(minutes) min"
    }

    /// Short total, e.g. "45 min" or "12.5 h"
    static func total(_ seconds: Int) -> String {
        if seconds < 3600 { return "\(seconds / 60) min" }
        return String(format: "%.1f h", Double(seconds) / 3600)
    }

    /// Countdown clock: "09:59" or "1:02:03"
    static func clock(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.up))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? startOfDay(for: date)
    }
}
