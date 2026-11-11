import SwiftUI
import SwiftData

/// Journal entries and meditation sessions in one timeline, filterable by tag, grouped by month, searchable.
struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MeditationSession.startDate, order: .reverse) private var sessions: [MeditationSession]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]

    @State private var searchText = ""
    @State private var filter: Filter = .all
    @State private var editingSession: MeditationSession?
    @State private var editingEntry: JournalEntry?
    @State private var showingAddSession = false
    @State private var showingAddEntry = false

    enum Filter: Hashable {
        case all, entries, sessions, tag(String)
    }

    enum Item: Identifiable {
        case session(MeditationSession)
        case entry(JournalEntry)

        var id: PersistentIdentifier {
            switch self {
            case .session(let s): s.persistentModelID
            case .entry(let e): e.persistentModelID
            }
        }

        var date: Date {
            switch self {
            case .session(let s): s.startDate
            case .entry(let e): e.createdAt
            }
        }
    }

    // MARK: - Data

    /// Tags with how many entries use each, most used first.
    private var tagCounts: [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for e in entries { for t in e.tags { counts[t, default: 0] += 1 } }
        return counts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { ($0.key, $0.value) }
    }

    private var items: [Item] {
        let query = searchText.trimmingCharacters(in: .whitespaces)

        var result: [Item] = []
        if filter == .all || filter == .sessions {
            result += sessions
                .filter { query.isEmpty || matches($0, query) }
                .map(Item.session)
        }
        switch filter {
        case .all, .entries:
            result += entries.filter { query.isEmpty || matches($0, query) }.map(Item.entry)
        case .tag(let tag):
            result += entries.filter { $0.tags.contains(tag) && (query.isEmpty || matches($0, query)) }.map(Item.entry)
        case .sessions:
            break
        }
        return result.sorted { $0.date > $1.date }
    }

    private func matches(_ s: MeditationSession, _ q: String) -> Bool {
        [s.location, s.notes, s.technique, s.reflectionAnswer, s.reflectionPrompt]
            .contains { $0.localizedCaseInsensitiveContains(q) }
    }

    private func matches(_ e: JournalEntry, _ q: String) -> Bool {
        e.text.localizedCaseInsensitiveContains(q)
            || e.tags.contains { $0.localizedCaseInsensitiveContains(q.trimmingCharacters(in: CharacterSet(charactersIn: "#"))) }
    }

    // MARK: - Body

    var body: some View {
        let list = items
        let groups = Dictionary(grouping: list) { Calendar.current.startOfMonth(for: $0.date) }
        let months = groups.keys.sorted(by: >)

        NavigationStack {
            List {
                Section {
                } header: {
                    overview
                        .textCase(nil)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }

                ForEach(months, id: \.self) { month in
                    let monthItems = groups[month] ?? []
                    Section {
                        ForEach(monthItems) { item in
                            row(for: item)
                                .padding(.vertical, 6)
                                .listRowBackground(Theme.surface)
                                .listRowSeparatorTint(Theme.hairline)
                        }
                        .onDelete { offsets in
                            for index in offsets { delete(monthItems[index]) }
                            try? modelContext.save()
                        }
                    } header: {
                        monthHeader(month, items: monthItems)
                    }
                }
            }
            .overlay {
                if sessions.isEmpty && entries.isEmpty {
                    ContentUnavailableView(
                        "Nothing here yet",
                        systemImage: "book.closed",
                        description: Text("Tap + to write a journal entry or log a session.")
                    )
                } else if list.isEmpty {
                    if searchText.isEmpty {
                        ContentUnavailableView("Nothing in this filter", systemImage: "line.3.horizontal.decrease")
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
            .paperBackground()
            .tint(Theme.ink)
            .searchable(text: $searchText, prompt: "Search entries, tags, notes")
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showingAddEntry = true } label: {
                            Label("Journal entry", systemImage: "square.and.pencil")
                        }
                        Button { showingAddSession = true } label: {
                            Label("Meditation session", systemImage: "circle.circle")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add")
                }
            }
            .onChange(of: tagCounts.map(\.tag)) { _, tags in
                // If the selected tag no longer exists (e.g. its last entry was deleted), go back to All.
                if case .tag(let tag) = filter, !tags.contains(tag) { filter = .all }
            }
            .sheet(item: $editingSession) { session in LogSessionView(session: session) }
            .sheet(item: $editingEntry) { entry in JournalEntryView(entry: entry) }
            .sheet(isPresented: $showingAddSession) { LogSessionView() }
            .sheet(isPresented: $showingAddEntry) { JournalEntryView() }
        }
    }

    // MARK: - Pieces

    /// Counts at a glance plus the filter chips.
    private var overview: some View {
        let tagged = tagCounts
        return VStack(alignment: .leading, spacing: 14) {
            Text(summaryLine(tagCount: tagged.count))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Theme.inkSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip("all", .all, count: entries.count + sessions.count)
                    filterChip("entries", .entries, count: entries.count)
                    filterChip("sessions", .sessions, count: sessions.count)
                    if !tagged.isEmpty {
                        Rectangle().fill(Theme.hairline).frame(width: 1, height: 20)
                    }
                    ForEach(tagged, id: \.tag) { item in
                        filterChip("#\(item.tag)", .tag(item.tag), count: item.count)
                    }
                }
            }
        }
    }

    private func summaryLine(tagCount: Int) -> String {
        func count(_ n: Int, _ one: String, _ many: String) -> String { "\(n) \(n == 1 ? one : many)" }
        return [count(entries.count, "entry", "entries"),
                count(sessions.count, "session", "sessions"),
                count(tagCount, "tag", "tags")].joined(separator: " · ")
    }

    private func filterChip(_ label: String, _ value: Filter, count: Int) -> some View {
        Button {
            withAnimation(.snappy) { filter = value }
        } label: {
            TagChip(tag: label, count: count, selected: filter == value)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(filter == value ? .isSelected : [])
    }

    @ViewBuilder
    private func row(for item: Item) -> some View {
        switch item {
        case .session(let session):
            SessionRow(session: session)
                .onTapGesture { editingSession = session }
        case .entry(let entry):
            JournalEntryRow(entry: entry)
                .onTapGesture { editingEntry = entry }
        }
    }

    private func monthHeader(_ month: Date, items: [Item]) -> some View {
        var seconds = 0
        var entryCount = 0
        for item in items {
            switch item {
            case .session(let s): seconds += s.durationSeconds
            case .entry: entryCount += 1
            }
        }
        var parts: [String] = []
        if seconds > 0 { parts.append(Fmt.total(seconds)) }
        if entryCount > 0 { parts.append("\(entryCount) \(entryCount == 1 ? "entry" : "entries")") }

        return HStack(alignment: .firstTextBaseline) {
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Theme.ink)
                .textCase(nil)
            Spacer()
            Eyebrow(parts.joined(separator: " · "))
        }
        .padding(.top, 8)
    }

    private func delete(_ item: Item) {
        switch item {
        case .session(let s): modelContext.delete(s)
        case .entry(let e): modelContext.delete(e)
        }
    }
}
