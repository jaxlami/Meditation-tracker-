import SwiftUI
import SwiftData

@main
struct MeditationTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: MeditationSession.self)
    }
}
