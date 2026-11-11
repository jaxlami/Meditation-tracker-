import Foundation
import SwiftData

/// One meditation sit: when it started, how long it lasted, where it happened and how it felt.
@Model
final class MeditationSession {
    var startDate: Date = Date()
    var durationSeconds: Int = 0
    var location: String = ""
    var technique: String = "Mindfulness"
    /// 0 = not recorded, otherwise 1 (rough) ... 5 (great)
    var moodBefore: Int = 0
    var moodAfter: Int = 0
    var notes: String = ""
    var createdAt: Date = Date()
    /// The daily question shown after the session (kept with the answer so it never changes later).
    var reflectionPrompt: String = ""
    /// Your answer to the daily question. Empty = not answered.
    var reflectionAnswer: String = ""

    init(
        startDate: Date = .now,
        durationSeconds: Int,
        location: String = "",
        technique: Technique = .mindfulness,
        moodBefore: Int = 0,
        moodAfter: Int = 0,
        notes: String = "",
        reflectionPrompt: String = "",
        reflectionAnswer: String = ""
    ) {
        self.startDate = startDate
        self.durationSeconds = durationSeconds
        self.location = location
        self.technique = technique.rawValue
        self.moodBefore = moodBefore
        self.moodAfter = moodAfter
        self.notes = notes
        self.reflectionPrompt = reflectionPrompt
        self.reflectionAnswer = reflectionAnswer
        self.createdAt = .now
    }

    var techniqueKind: Technique { Technique(rawValue: technique) ?? .other }
    var endDate: Date { startDate.addingTimeInterval(TimeInterval(durationSeconds)) }
    var hasReflection: Bool { !reflectionAnswer.isEmpty }
}

enum Technique: String, CaseIterable, Identifiable {
    case mindfulness = "Mindfulness"
    case breathing = "Breathing"
    case bodyScan = "Body Scan"
    case lovingKindness = "Loving-Kindness"
    case visualization = "Visualization"
    case mantra = "Mantra"
    case walking = "Walking"
    case guided = "Guided"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .mindfulness: "circle.dotted"
        case .breathing: "wind"
        case .bodyScan: "figure.mind.and.body"
        case .lovingKindness: "heart"
        case .visualization: "eye"
        case .mantra: "waveform"
        case .walking: "figure.walk"
        case .guided: "headphones"
        case .other: "circle"
        }
    }
}

enum Mood {
    static let labels = ["", "Rough", "Low", "Okay", "Good", "Great"]

    static func label(_ value: Int) -> String {
        labels.indices.contains(value) ? labels[value] : ""
    }
}
