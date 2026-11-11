import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \MeditationSession.startDate, order: .reverse) private var sessions: [MeditationSession]
    @AppStorage(SettingsKeys.dailyGoalMinutes) private var dailyGoalMinutes = 10

    @State private var showingTimer = false
    @State private var showingLog = false
    @State private var editingSession: MeditationSession?

    private var todaySessions: [MeditationSession] {
        sessions.filter { Calendar.current.isDateInToday($0.startDate) }
    }

    private var todaySeconds: Int {
        todaySessions.reduce(0) { $0 + $1.durationSeconds }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Still hours"
        }
    }

    var body: some View {
        let days = MeditationStats.meditationDays(sessions)
        let currentStreak = MeditationStats.currentStreak(days)
        let longestStreak = MeditationStats.longestStreak(days)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    todayCard(current: currentStreak, longest: longestStreak)
                    reflectionCard

                    VStack(spacing: 6) {
                        Button {
                            showingTimer = true
                        } label: {
                            Text("Begin a session")
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button("Log a past session") { showingLog = true }
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSecondary)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                    }

                    recentSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .paperBackground()
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showingTimer) { TimerView() }
            .sheet(isPresented: $showingLog) { LogSessionView() }
            .sheet(item: $editingSession) { session in LogSessionView(session: session) }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            Text(greeting)
                .font(Theme.display(38))
                .foregroundStyle(Theme.ink)
        }
        .padding(.top, 24)
    }

    private func todayCard(current: Int, longest: Int) -> some View {
        let goalSeconds = max(dailyGoalMinutes, 1) * 60
        let progress = Double(todaySeconds) / Double(goalSeconds)
        let minutes = todaySeconds / 60

        return VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 24) {
                ZStack {
                    ProgressRing(progress: progress, lineWidth: 3)
                    VStack(spacing: 0) {
                        Text("\(minutes)")
                            .font(Theme.numeral(34))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                        Text("min")
                            .font(.caption2)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
                .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow("Today")
                    Text(progress >= 1 ? "Goal met for today." : "\(max(0, dailyGoalMinutes - minutes)) min to your goal")
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(Theme.ink)
                    Text("Daily goal · \(dailyGoalMinutes) min")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }

            Rectangle().fill(Theme.hairline).frame(height: 0.5)

            HStack(spacing: 6) {
                Circle().fill(Theme.clay).frame(width: 6, height: 6)
                Text("\(current) day\(current == 1 ? "" : "s") in a row")
                    .foregroundStyle(Theme.ink)
                Text("·").foregroundStyle(Theme.inkTertiary)
                Text("best \(longest)")
                    .foregroundStyle(Theme.inkSecondary)
            }
            .font(.subheadline)
        }
        .card(padding: 22)
    }

    /// Today's question: an intention before you sit, your answer once you've reflected.
    private var reflectionCard: some View {
        let answered = todaySessions.first { $0.hasReflection }
        let prompt = answered?.reflectionPrompt.isEmpty == false
            ? answered!.reflectionPrompt
            : ReflectionPrompts.prompt(for: .now)

        return Button {
            if let answered { editingSession = answered } else { showingTimer = true }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow("Today's reflection", color: Theme.sage)
                Text(prompt)
                    .font(.system(.title3, design: .serif).italic())
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let answered {
                    Text(answered.reflectionAnswer)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .padding(.leading, 12)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Theme.sage).frame(width: 1.5)
                        }
                } else {
                    Text("Hold it in mind as you sit. You'll be asked after your session.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .card(padding: 22)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Recent")
            if sessions.isEmpty {
                Text("Your sessions will gather here.")
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Theme.inkSecondary)
                    .card()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sessions.prefix(5).enumerated()), id: \.element.id) { index, session in
                        if index > 0 {
                            Rectangle().fill(Theme.hairline).frame(height: 0.5)
                        }
                        SessionRow(session: session)
                            .padding(.vertical, 16)
                            .onTapGesture { editingSession = session }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.5))
            }
        }
    }
}
