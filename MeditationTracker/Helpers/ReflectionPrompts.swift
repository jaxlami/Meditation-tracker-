import Foundation

/// A short, affirmation-style question for each day. Everyone sees the same one all day; it changes at midnight.
enum ReflectionPrompts {
    static let all: [String] = [
        "What are you grateful for in this moment?",
        "What quality do you want to carry into today?",
        "What did your mind keep returning to, and can you meet it kindly?",
        "Where in your body do you feel most at ease right now?",
        "What is one thing you can let go of today?",
        "What would it look like to be gentle with yourself today?",
        "What are you looking forward to?",
        "Who has made your life a little lighter lately?",
        "What do you already have that you once hoped for?",
        "What small thing went right today?",
        "What does calm feel like for you, in a few words?",
        "What intention will you hold for the rest of the day?",
        "What are you learning to accept?",
        "What strength did you rely on this week?",
        "What would you tell a friend who felt the way you feel now?",
        "What can wait until tomorrow?",
        "What brought you here to sit today?",
        "Which sound, smell or sight do you want to notice today?",
        "What is enough, just as it is?",
        "What made you smile recently?",
        "What are you proud of, however small?",
        "What does your body need from you today?",
        "What thought would you like to believe more often?",
        "Where can you make a little more space today?",
        "What is one kind thing you can do for someone today?",
        "What are you holding onto that is no longer yours to carry?",
        "What moment from today would you like to remember?",
        "What helps you come back to yourself?",
        "What do you appreciate about the place you are in?",
        "What is quietly going well in your life?",
        "How would you like to respond, rather than react, today?",
        "What feeling is asking for your attention?",
        "What are you curious about right now?",
        "What does rest look like for you this week?",
        "What simple pleasure can you enjoy today?",
        "What have you outgrown?",
        "What would make today feel complete?",
        "Who are you becoming?",
        "What is one thing you trust about yourself?",
        "What is beautiful about this ordinary day?",
        "What can you forgive yourself for?",
        "What gives you a sense of home?",
        "Where did you notice patience today?",
        "What are you ready to begin?",
        "What would you do today if you weren't in a hurry?",
        "What lesson keeps finding you?",
        "What part of your routine nourishes you?",
        "What is one word for how you feel after sitting?",
        "What are you giving your attention to, and is it worth it?",
        "What do you want more of in your days?",
        "What do you want less of in your days?",
        "What is true for you right now?",
        "Which relationship would you like to tend to?",
        "What does your breath tell you about today?",
        "What can you celebrate this week?",
        "What did you notice today that you usually miss?",
        "What is one promise you can keep to yourself today?",
        "What do you love about who you are?",
        "What would a softer version of today look like?",
        "What are you thankful your body can do?",
    ]

    /// Today's question (or the question for any other day).
    static func prompt(for date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.startOfDay(for: date)
        let reference = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let days = calendar.dateComponents([.day], from: reference, to: day).day ?? 0
        let index = ((days % all.count) + all.count) % all.count
        return all[index]
    }

    /// A different question from the list, for when today's doesn't land.
    static func another(excluding current: String) -> String {
        all.filter { $0 != current }.randomElement() ?? current
    }
}
