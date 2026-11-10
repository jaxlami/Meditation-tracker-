import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \MeditationSession.startDate, order: .reverse) private var sessions: [MeditationSession]
    @AppStorage(SettingsKeys.dailyGoalMinutes) private var dailyGoalMinutes = 10

    @State private var showingTimer = false
    @State private var showingLog = false
    @State private var editingSession: MeditationSession?

    private var todaySeconds: Int {
        sessions
            .filter { Calendar.current.isDateInToday($0.startDate) }
            .reduce(0) { $0 + $1.durationSeconds }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Hello"
        }
    }

    var body: some View {
        let days = MeditationStats.meditationDays(sessions)
        let currentStreak = MeditationStats.currentStreak(days)
        let longestStreak = MeditationStats.longestStreak(days)

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    todayCard
                    streakCard(current: currentStreak, longest: longestStreak)

                    Button {
                        showingTimer = true
                    } label: {
                        Label("Start Meditation", systemImage: "play.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        showingLog = true
                    } label: {
                        Label("Log a Session Manually", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    recentSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(greeting)
            .fullScreenCover(isPresented: $showingTimer) { TimerView() }
            .sheet(isPresented: $showingLog) { LogSessionView() }
            .sheet(item: $editingSession) { session in LogSessionView(session: session) }
        }
    }

    private var todayCard: some View {
        let goalSeconds = max(dailyGoalMinutes, 1) * 60
        let progress = Double(todaySeconds) / Double(goalSeconds)
        return HStack(spacing: 20) {
            ZStack {
                ProgressRing(progress: progress, lineWidth: 10)
                Image(systemName: progress >= 1 ? "checkmark" : "leaf.fill")
                    .font(.title2.bold())
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(todaySeconds / 60) of \(dailyGoalMinutes) min")
                    .font(.title2.bold())
                Text(progress >= 1 ? "Daily goal reached 🎉" : "Keep going, you've got this.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func streakCard(current: Int, longest: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label("Current streak", systemImage: "flame.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                Text("\(current) day\(current == 1 ? "" : "s")")
                    .font(.title2.bold())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Label("Best", systemImage: "trophy.fill")
                    .font(.subheadline)
                    .foregroundStyle(.yellow)
                Text("\(longest) day\(longest == 1 ? "" : "s")")
                    .font(.title2.bold())
            }
        }
        .card()
    }

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
                .font(.headline)
                .padding(.top, 8)
            if sessions.isEmpty {
                Text("No sessions yet. Start your first one above!")
                    .foregroundStyle(.secondary)
                    .card()
            } else {
                ForEach(sessions.prefix(5)) { session in
                    SessionRow(session: session)
                        .card()
                        .onTapGesture { editingSession = session }
                }
            }
        }
    }
}
