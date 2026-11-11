import SwiftUI
import SwiftData

/// Every session, grouped by month, searchable.
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MeditationSession.startDate, order: .reverse) private var sessions: [MeditationSession]

    @State private var searchText = ""
    @State private var editingSession: MeditationSession?
    @State private var showingAdd = false

    private var filtered: [MeditationSession] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return sessions }
        return sessions.filter {
            $0.location.localizedCaseInsensitiveContains(query)
                || $0.notes.localizedCaseInsensitiveContains(query)
                || $0.technique.localizedCaseInsensitiveContains(query)
                || $0.reflectionAnswer.localizedCaseInsensitiveContains(query)
                || $0.reflectionPrompt.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        let groups = Dictionary(grouping: filtered) { Calendar.current.startOfMonth(for: $0.startDate) }
        let months = groups.keys.sorted(by: >)

        NavigationStack {
            List {
                ForEach(months, id: \.self) { month in
                    let monthSessions = groups[month] ?? []
                    Section {
                        ForEach(monthSessions) { session in
                            SessionRow(session: session)
                                .padding(.vertical, 6)
                                .listRowBackground(Theme.surface)
                                .listRowSeparatorTint(Theme.hairline)
                                .onTapGesture { editingSession = session }
                        }
                        .onDelete { offsets in
                            for index in offsets { modelContext.delete(monthSessions[index]) }
                            try? modelContext.save()
                        }
                    } header: {
                        HStack(alignment: .firstTextBaseline) {
                            Text(month.formatted(.dateTime.month(.wide).year()))
                                .font(.system(.title3, design: .serif))
                                .foregroundStyle(Theme.ink)
                                .textCase(nil)
                            Spacer()
                            Eyebrow(Fmt.total(monthSessions.reduce(0) { $0 + $1.durationSeconds }))
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "Nothing here yet",
                        systemImage: "circle.dotted",
                        description: Text("Sessions and reflections you record will gather here.")
                    )
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .paperBackground()
            .tint(Theme.ink)
            .searchable(text: $searchText, prompt: "Search notes, reflections, places")
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add session")
                }
            }
            .sheet(item: $editingSession) { session in LogSessionView(session: session) }
            .sheet(isPresented: $showingAdd) { LogSessionView() }
        }
    }
}
