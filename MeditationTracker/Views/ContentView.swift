import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Today", systemImage: "circle.circle") }
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            HistoryView()
                .tabItem { Label("History", systemImage: "book.closed") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
        .tint(Theme.ink)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: MeditationSession.self, inMemory: true)
}
