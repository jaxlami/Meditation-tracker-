import SwiftUI
import SwiftData

/// Month calendar that highlights every day you meditated.
struct CalendarView: View {
    @Query(sort: \MeditationSession.startDate, order: .reverse) private var sessions: [MeditationSession]
    @AppStorage(SettingsKeys.dailyGoalMinutes) private var dailyGoalMinutes = 10

    @State private var month = Calendar.current.startOfMonth(for: .now)
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var editingSession: MeditationSession?
    @State private var showingAdd = false

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let byDay = MeditationStats.secondsByDay(sessions)

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        monthHeader
                        weekdayHeader
                        monthGrid(byDay: byDay)
                        legend
                    }
                    .card()

                    monthSummary(byDay: byDay)
                    dayDetail
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Today") {
                        withAnimation {
                            month = calendar.startOfMonth(for: .now)
                            selectedDay = calendar.startOfDay(for: .now)
                        }
                    }
                }
            }
            .sheet(item: $editingSession) { session in LogSessionView(session: session) }
            .sheet(isPresented: $showingAdd) { LogSessionView(prefillStart: prefillDate(for: selectedDay)) }
        }
    }

    // MARK: - Month grid

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: .now, toGranularity: .month)
    }

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left").padding(8)
            }
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.title3.bold())
            Spacer()
            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right").padding(8)
            }
            .disabled(isCurrentMonth)
        }
    }

    private var weekdayHeader: some View {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        let ordered = Array(symbols[shift...] + symbols[..<shift])
        return HStack(spacing: 4) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var gridDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: month)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: month))
        }
        return days
    }

    private func monthGrid(byDay: [Date: Int]) -> some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day, seconds: byDay[day] ?? 0)
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                if value.translation.width < -50 { changeMonth(by: 1) }
                if value.translation.width > 50 { changeMonth(by: -1) }
            }
        )
    }

    private func dayCell(_ day: Date, seconds: Int) -> some View {
        let meditated = seconds > 0
        let goalMet = seconds >= dailyGoalMinutes * 60
        let isToday = calendar.isDateInToday(day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isFuture = day > .now

        return ZStack {
            Circle()
                .fill(meditated ? Color.accentColor.opacity(goalMet ? 1 : 0.35) : Color.clear)
            if isSelected {
                Circle().strokeBorder(Color.primary, lineWidth: 2)
            } else if isToday {
                Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
            }
            Text("\(calendar.component(.day, from: day))")
                .font(.callout.weight(isToday || meditated ? .bold : .regular))
                .foregroundStyle(goalMet ? Color.white : (isFuture ? Color.secondary : Color.primary))
        }
        .frame(height: 40)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isFuture { selectedDay = day }
        }
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted) + (meditated ? ", meditated \(Fmt.duration(seconds))" : ""))
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(Color.accentColor.opacity(0.35), "Meditated")
            legendItem(Color.accentColor, "Goal reached")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendItem(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }

    // MARK: - Summary & details

    private func monthSummary(byDay: [Date: Int]) -> some View {
        let inMonth = byDay.filter { calendar.isDate($0.key, equalTo: month, toGranularity: .month) }
        let totalSeconds = inMonth.values.reduce(0, +)
        return HStack(spacing: 12) {
            StatCard(title: "Days this month", value: "\(inMonth.count)", systemImage: "calendar.badge.checkmark")
            StatCard(title: "Time this month", value: Fmt.total(totalSeconds), systemImage: "clock")
        }
    }

    private var dayDetail: some View {
        let daySessions = sessions
            .filter { calendar.isDate($0.startDate, inSameDayAs: selectedDay) }
            .sorted { $0.startDate < $1.startDate }

        return VStack(alignment: .leading, spacing: 8) {
            Text(selectedDay.formatted(date: .complete, time: .omitted))
                .font(.headline)

            if daySessions.isEmpty {
                Text("No meditation on this day.")
                    .foregroundStyle(.secondary)
                    .card()
            } else {
                ForEach(daySessions) { session in
                    SessionRow(session: session)
                        .card()
                        .onTapGesture { editingSession = session }
                }
            }

            Button {
                showingAdd = true
            } label: {
                Label("Add Session to This Day", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Helpers

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: month) else { return }
        if newMonth > calendar.startOfMonth(for: .now) { return }
        withAnimation { month = newMonth }
    }

    /// For a past day, prefill with the same clock time as now; for today, use now.
    private func prefillDate(for day: Date) -> Date {
        if calendar.isDateInToday(day) { return .now }
        let time = calendar.dateComponents([.hour, .minute], from: .now)
        return calendar.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: 0, of: day) ?? day
    }
}
