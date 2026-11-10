import Foundation

/// Keys for values stored with @AppStorage.
enum SettingsKeys {
    static let dailyGoalMinutes = "dailyGoalMinutes"
    static let defaultTimerMinutes = "defaultTimerMinutes"
    static let reminderEnabled = "reminderEnabled"
    /// Reminder time stored as seconds after midnight.
    static let reminderSeconds = "reminderSeconds"
    static let timerChimeEnabled = "timerChimeEnabled"
}
