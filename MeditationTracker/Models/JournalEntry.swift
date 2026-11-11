import Foundation
import SwiftData

/// A free journal entry: how you feel right now, what's on your mind, and topic tags.
@Model
final class JournalEntry {
    var createdAt: Date = Date()
    /// Same scale as session mood: 0 = not set, 1 (rough) ... 5 (great).
    var mood: Int = 0
    var text: String = ""
    /// Lowercase, trimmed, unique topic tags, e.g. ["childhood", "family"].
    var tags: [String] = []

    init(createdAt: Date = .now, mood: Int = 0, text: String = "", tags: [String] = []) {
        self.createdAt = createdAt
        self.mood = mood
        self.text = text
        self.tags = tags
    }
}
