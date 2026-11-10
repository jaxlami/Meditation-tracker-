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
                                .onTapGesture { editingSession = session }
                        }
                        .onDelete { offsets in
                            for index in offsets { modelContext.delete(monthSessions[index]) }
                            try? modelContext.save()
                        }
                    } header: {
                        HStack {
                            Text(month.formatted(.dateTime.month(.wide).year()))
                            Spacer()
                            Text(Fmt.total(monthSessions.reduce(0) { $0 + $1.durationSeconds }))
                        }
                    }
                }
            }
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "leaf",
                        description: Text("Sessions you time or log will show up here.")
                    )
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, prompt: "Search places, notes, techniques")
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
