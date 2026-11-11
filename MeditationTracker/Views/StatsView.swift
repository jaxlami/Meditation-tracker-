import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query(sort: \MeditationSession.startDate, order: .reverse) private var sessions: [MeditationSession]
    @AppStorage(SettingsKeys.dailyGoalMinutes) private var dailyGoalMinutes = 10
    @State private var range: ChartRange = .week

    enum ChartRange: String, CaseIterable, Identifiable {
        case week = "7 Days"
        case month = "30 Days"
        var id: String { rawValue }
        var days: Int { self == .week ? 7 : 30 }
    }

    struct DayMinutes: Identifiable {
        let date: Date
        let minutes: Double
        var id: Date { date }
    }

    struct NamedValue: Identifiable {
        let name: String
        let value: Int
        var id: String { name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No patterns yet",
                        systemImage: "circle.dotted",
                        description: Text("Sit a few times and your practice will take shape here.")
                    )
                    .padding(.top, 80)
                } else {
                    VStack(spacing: 16) {
                        summaryGrid
                        chartCard
                        techniqueCard
                        locationsCard
                        moodCard
                    }
                    .padding()
                }
            }
            .paperBackground()
            .navigationTitle("Stats")
        }
    }

    // MARK: - Summary

    private var summaryGrid: some View {
        let days = MeditationStats.meditationDays(sessions)
        let totalSeconds = sessions.reduce(0) { $0 + $1.durationSeconds }
        let average = sessions.isEmpty ? 0 : totalSeconds / sessions.count
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return LazyVGrid(columns: columns, spacing: 12) {
            StatCard(title: "Current streak", value: "\(MeditationStats.currentStreak(days)) days", tint: Theme.clay)
            StatCard(title: "Longest streak", value: "\(MeditationStats.longestStreak(days)) days")
            StatCard(title: "Total time", value: Fmt.total(totalSeconds))
            StatCard(title: "Sessions", value: "\(sessions.count)")
            StatCard(title: "Average session", value: Fmt.duration(average))
            StatCard(title: "Favorite time", value: favoriteTimeOfDay, tint: Theme.sage)
        }
    }

    private var favoriteTimeOfDay: String {
        let buckets = Dictionary(grouping: sessions) { session -> String in
            switch Calendar.current.component(.hour, from: session.startDate) {
            case 5..<12: return "Morning"
            case 12..<17: return "Afternoon"
            case 17..<22: return "Evening"
            default: return "Night"
            }
        }
        return buckets.max { $0.value.count < $1.value.count }?.key ?? "—"
    }

    // MARK: - Daily chart

    private var dailyData: [DayMinutes] {
        let calendar = Calendar.current
        let byDay = MeditationStats.secondsByDay(sessions)
        let today = calendar.startOfDay(for: .now)
        return (0..<range.days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayMinutes(date: day, minutes: Double(byDay[day] ?? 0) / 60)
        }
    }

    private var chartCard: some View {
        let data = dailyData
        let total = data.reduce(0) { $0 + $1.minutes }
        let activeDays = data.filter { $0.minutes > 0 }.count

        return VStack(alignment: .leading, spacing: 12) {
            Picker("Range", selection: $range) {
                ForEach(ChartRange.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Text("\(Int(total)) min across \(activeDays) of \(range.days) days")
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(Theme.inkSecondary)

            Chart {
                ForEach(data) { item in
                    BarMark(
                        x: .value("Day", item.date, unit: .day),
                        y: .value("Minutes", item.minutes)
                    )
                    .foregroundStyle(Theme.sage)
                    .cornerRadius(3)
                }
                RuleMark(y: .value("Goal", Double(dailyGoalMinutes)))
                    .lineStyle(StrokeStyle(lineWidth: 0.75, dash: [3, 4]))
                    .foregroundStyle(Theme.ink)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Goal \(dailyGoalMinutes) min")
                            .font(.caption2)
                            .foregroundStyle(Theme.inkSecondary)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 7)) { _ in
                    AxisGridLine().foregroundStyle(Theme.hairline)
                    AxisValueLabel(format: range == .week
                        ? Date.FormatStyle().weekday(.abbreviated)
                        : Date.FormatStyle().month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Theme.hairline)
                    AxisValueLabel().foregroundStyle(Theme.inkTertiary)
                }
            }
            .frame(height: 200)
        }
        .card()
    }

    // MARK: - Techniques

    private var techniqueCard: some View {
        let totals = Dictionary(grouping: sessions, by: \.technique)
            .map { NamedValue(name: $0.key, value: $0.value.reduce(0) { $0 + $1.durationSeconds } / 60) }
            .sorted { $0.value > $1.value }

        return VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Techniques")
            Chart(totals) { item in
                BarMark(
                    x: .value("Minutes", item.value),
                    y: .value("Technique", item.name)
                )
                .foregroundStyle(Theme.sage)
                .cornerRadius(3)
                .annotation(position: .trailing) {
                    Text("\(item.value) min")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(totals.count) * 36 + 10)
        }
        .card()
    }

    // MARK: - Locations

    private var locationsCard: some View {
        let places = Dictionary(grouping: sessions.filter { !$0.location.isEmpty }, by: \.location)
            .map { NamedValue(name: $0.key, value: $0.value.count) }
            .sorted { $0.value > $1.value }
            .prefix(5)

        return VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Top places")
            if places.isEmpty {
                Text("Add a location when logging to see where you meditate most.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            } else {
                ForEach(places) { place in
                    HStack {
                        Text(place.name)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Spacer()
                        Text("\(place.value)×")
                            .foregroundStyle(Theme.inkSecondary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .card()
    }

    // MARK: - Mood

    private var moodCard: some View {
        let rated = sessions.filter { $0.moodBefore > 0 && $0.moodAfter > 0 }
        let before = rated.isEmpty ? 0 : Double(rated.reduce(0) { $0 + $1.moodBefore }) / Double(rated.count)
        let after = rated.isEmpty ? 0 : Double(rated.reduce(0) { $0 + $1.moodAfter }) / Double(rated.count)
        let change = after - before

        return VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Mood")
            if rated.isEmpty {
                Text("Rate your mood before and after a session to see how sitting changes how you feel.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            } else {
                HStack(spacing: 16) {
                    moodColumn("Before", value: before)
                    Image(systemName: "arrow.right")
                        .font(.footnote.weight(.light))
                        .foregroundStyle(Theme.inkTertiary)
                    moodColumn("After", value: after)
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(String(format: "%+.1f", change))
                            .font(Theme.numeral(28))
                            .foregroundStyle(change >= 0 ? Theme.sage : Theme.clay)
                        Text("avg change")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
                Text("Based on \(rated.count) rated session\(rated.count == 1 ? "" : "s").")
                    .font(.caption)
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
        .card()
    }

    private func moodColumn(_ title: String, value: Double) -> some View {
        VStack(spacing: 8) {
            MoodGlyph(value: Int(value.rounded()), size: 30)
            Text("\(title) · \(String(format: "%.1f", value))")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
        }
    }
}
