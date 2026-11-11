import SwiftUI
import SwiftData

/// Write a journal entry (or edit one): mood first, then thoughts, then topic tags.
struct JournalEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [JournalEntry]

    private let entry: JournalEntry?

    @State private var date: Date
    @State private var mood: Int
    @State private var text: String
    @State private var tags: [String]
    @State private var newTag = ""
    @State private var suggestions: [String] = []
    @State private var thinking = false
    @State private var confirmDelete = false
    @FocusState private var writing: Bool

    init(entry: JournalEntry? = nil) {
        self.entry = entry
        _date = State(initialValue: entry?.createdAt ?? .now)
        _mood = State(initialValue: entry?.mood ?? 0)
        _text = State(initialValue: entry?.text ?? "")
        _tags = State(initialValue: entry?.tags ?? [])
    }

    /// Every tag you've used, most used first.
    private var existingTags: [String] {
        var counts: [String: Int] = [:]
        for e in allEntries { for t in e.tags { counts[t, default: 0] += 1 } }
        return counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.map(\.key)
    }

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedText.isEmpty || mood > 0 }

    private var visibleSuggestions: [String] { suggestions.filter { !tags.contains($0) } }

    /// While typing a tag: your existing tags that start with it. Otherwise: your top unused tags.
    private var tagPicks: [String] {
        let query = TagSuggester.normalize(newTag)
        let unused = existingTags.filter { !tags.contains($0) && !visibleSuggestions.contains($0) }
        if query.isEmpty { return Array(unused.prefix(8)) }
        return unused.filter { $0.hasPrefix(query) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    MoodPicker(title: "Right now", selection: $mood)
                } header: { FormHeader("Mood") }

                Section {
                    TextField("What's on your mind? Thoughts, feelings, whatever is here.", text: $text, axis: .vertical)
                        .font(.system(.body, design: .serif))
                        .lineLimit(8...40)
                        .focused($writing)
                } header: { FormHeader("Thoughts") }

                tagSection

                Section {
                    DatePicker("Written", selection: $date, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                } header: { FormHeader("When") }

                if entry != nil {
                    Section {
                        Button("Delete entry", role: .destructive) { confirmDelete = true }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .paperBackground()
            .tint(Theme.ink)
            .navigationTitle(entry == nil ? "Journal entry" : "Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.inkSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .task(id: text) {
                // Refresh suggestions once you pause typing.
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await refreshSuggestions()
            }
            .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let entry { modelContext.delete(entry) }
                    try? modelContext.save()
                    dismiss()
                }
            }
            .onAppear { if entry == nil { writing = true } }
        }
    }

    private var tagSection: some View {
        Section {
            if !tags.isEmpty {
                FlowLayout {
                    ForEach(tags, id: \.self) { tag in
                        Button { withAnimation(.snappy) { tags.removeAll { $0 == tag } } } label: {
                            TagChip(tag: tag, kind: .applied)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove tag \(tag)")
                    }
                }
                .padding(.vertical, 4)
            }

            if !visibleSuggestions.isEmpty || thinking {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Eyebrow("Suggested", color: Theme.sage)
                        if thinking { ProgressView().controlSize(.mini) }
                    }
                    FlowLayout {
                        ForEach(visibleSuggestions, id: \.self) { tag in
                            Button { add(tag) } label: { TagChip(tag: tag, kind: .suggested) }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Add suggested tag \(tag)")
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            HStack {
                Text("#").foregroundStyle(Theme.inkTertiary)
                TextField("Add a tag", text: $newTag)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { add(newTag) }
                if !TagSuggester.normalize(newTag).isEmpty {
                    Button("Add") { add(newTag) }
                        .font(.subheadline.weight(.semibold))
                }
            }

            if !tagPicks.isEmpty {
                FlowLayout {
                    ForEach(tagPicks, id: \.self) { tag in
                        Button { add(tag) } label: { TagChip(tag: tag) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            FormHeader("Tags")
        } footer: {
            Text("Tags are suggested as you write, on your iPhone. If you don't pick any for a new entry, the top suggestions are added when you save.")
        }
    }

    // MARK: - Actions

    private func add(_ raw: String) {
        let tag = TagSuggester.normalize(raw)
        guard !tag.isEmpty else { return }
        withAnimation(.snappy) {
            if !tags.contains(tag) { tags.append(tag) }
            newTag = ""
        }
    }

    private func refreshSuggestions() async {
        let existing = existingTags
        let quick = TagSuggester.suggest(for: text, existing: existing, excluding: Set(tags))
        suggestions = quick

        guard TagSuggester.intelligenceAvailable else { return }
        thinking = true
        let smart = await TagSuggester.intelligentSuggestions(for: text, existing: existing)
        thinking = false
        guard !Task.isCancelled else { return }
        // Keep the keyword matches first, then add the model's ideas.
        var merged = quick
        for tag in smart where !merged.contains(tag) && !tags.contains(tag) { merged.append(tag) }
        suggestions = Array(merged.prefix(5))
    }

    private func save() {
        var finalTags = tags
        if finalTags.isEmpty && entry == nil {
            // New entry with nothing picked: apply the top suggestions automatically.
            // (When editing, an empty tag list is respected as a deliberate choice.)
            let pool = suggestions.isEmpty
                ? TagSuggester.suggest(for: trimmedText, existing: existingTags)
                : suggestions
            finalTags = Array(pool.prefix(2))
        }

        if let entry {
            entry.createdAt = date
            entry.mood = mood
            entry.text = trimmedText
            entry.tags = finalTags
        } else {
            modelContext.insert(JournalEntry(createdAt: date, mood: mood, text: trimmedText, tags: finalTags))
        }
        try? modelContext.save()
        dismiss()
    }
}
