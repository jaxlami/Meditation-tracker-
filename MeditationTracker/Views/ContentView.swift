import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Today", systemImage: "leaf") }
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            HistoryView()
                .tabItem { Label("History", systemImage: "list.bullet") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: MeditationSession.self, inMemory: true)
}
