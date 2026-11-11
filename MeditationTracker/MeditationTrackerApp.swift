import SwiftUI
import SwiftData

@main
struct MeditationTrackerApp: App {
    init() {
        Theme.applyAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [MeditationSession.self, JournalEntry.self])
    }
}
