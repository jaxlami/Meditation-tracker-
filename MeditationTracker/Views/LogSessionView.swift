import SwiftUI
import SwiftData

/// Add a new session or edit an existing one.
struct LogSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MeditationSession.startDate, order: .reverse) private var allSessions: [MeditationSession]
    @StateObject private var locator = LocationHelper()

    private let session: MeditationSession?

    @State private var startDate: Date
    @State private var durationSeconds: Int
    @State private var location: String
    @State private var technique: Technique
    @State private var moodBefore: Int
    @State private var moodAfter: Int
    @State private var notes: String
    @State private var confirmDelete = false

    private let presets = [5, 10, 15, 20, 30, 45, 60]

    init(
        session: MeditationSession? = nil,
        prefillStart: Date = .now,
        prefillDurationSeconds: Int? = nil,
        prefillTechnique: Technique = .mindfulness
    ) {
        self.session = session
        let defaultMinutes = UserDefaults.standard.object(forKey: SettingsKeys.defaultTimerMinutes) as? Int ?? 10
        _startDate = State(initialValue: session?.startDate ?? prefillStart)
        _durationSeconds = State(initialValue: session?.durationSeconds ?? prefillDurationSeconds ?? defaultMinutes * 60)
        _location = State(initialValue: session?.location ?? "")
        _technique = State(initialValue: session?.techniqueKind ?? prefillTechnique)
        _moodBefore = State(initialValue: session?.moodBefore ?? 0)
        _moodAfter = State(initialValue: session?.moodAfter ?? 0)
        _notes = State(initialValue: session?.notes ?? "")
    }

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { max(1, durationSeconds / 60) },
            set: { durationSeconds = $0 * 60 }
        )
    }

    /// Places you've meditated before, most recent first, for one-tap entry.
    private var recentLocations: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for s in allSessions where !s.location.isEmpty {
            if seen.insert(s.location.lowercased()).inserted {
                result.append(s.location)
            }
            if result.count == 8 { break }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Started", selection: $startDate, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                }

                Section("How long") {
                    Stepper(value: minutesBinding, in: 1...600) {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(Fmt.duration(durationSeconds))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(presets, id: \.self) { preset in
                                Button("\(preset) min") { durationSeconds = preset * 60 }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(durationSeconds == preset * 60 ? Color.accentColor : Color.secondary)
                            }
                        }
                    }
                }

                Section("Where") {
                    TextField("e.g. Home, Park, Office", text: $location)
                        .textInputAutocapitalization(.words)

                    Button {
                        locator.requestPlaceName()
                    } label: {
                        HStack {
                            Label("Use Current Location", systemImage: "location.fill")
                            if locator.isLocating {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(locator.isLocating)

                    if let error = locator.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if !recentLocations.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(recentLocations, id: \.self) { place in
                                    Button(place) { location = place }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                }
                            }
                        }
                    }
                }

                Section("Practice") {
                    Picker("Technique", selection: $technique) {
                        ForEach(Technique.allCases) { technique in
                            Label(technique.rawValue, systemImage: technique.icon).tag(technique)
                        }
                    }
                }

                Section {
                    MoodPicker(title: "Before", selection: $moodBefore)
                    MoodPicker(title: "After", selection: $moodAfter)
                } header: {
                    Text("Mood")
                } footer: {
                    Text("Optional. Tracking mood shows how meditation affects you over time.")
                }

                Section("Notes") {
                    TextField("How did it go? Any thoughts or insights?", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                }

                if session != nil {
                    Section {
                        Button("Delete Session", role: .destructive) { confirmDelete = true }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(session == nil ? "Log Session" : "Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .bold()
                }
            }
            .onChange(of: locator.placeName) { _, newValue in
                if let newValue, !newValue.isEmpty { location = newValue }
            }
            .confirmationDialog("Delete this session?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let session { modelContext.delete(session) }
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
    }

    private func save() {
        let place = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let session {
            session.startDate = startDate
            session.durationSeconds = durationSeconds
            session.location = place
            session.technique = technique.rawValue
            session.moodBefore = moodBefore
            session.moodAfter = moodAfter
            session.notes = text
        } else {
            modelContext.insert(MeditationSession(
                startDate: startDate,
                durationSeconds: durationSeconds,
                location: place,
                technique: technique,
                moodBefore: moodBefore,
                moodAfter: moodAfter,
                notes: text
            ))
        }
        try? modelContext.save()
        dismiss()
    }
}
