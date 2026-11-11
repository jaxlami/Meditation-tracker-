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
    @State private var reflectionPrompt: String
    @State private var reflectionAnswer: String
    /// True once the user picks "different question", so a date change doesn't overwrite their choice.
    @State private var promptChosenManually: Bool
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
        let start = session?.startDate ?? prefillStart
        let storedPrompt = session?.reflectionPrompt ?? ""
        _startDate = State(initialValue: start)
        _durationSeconds = State(initialValue: session?.durationSeconds ?? prefillDurationSeconds ?? defaultMinutes * 60)
        _location = State(initialValue: session?.location ?? "")
        _technique = State(initialValue: session?.techniqueKind ?? prefillTechnique)
        _moodBefore = State(initialValue: session?.moodBefore ?? 0)
        _moodAfter = State(initialValue: session?.moodAfter ?? 0)
        _notes = State(initialValue: session?.notes ?? "")
        _reflectionPrompt = State(initialValue: storedPrompt.isEmpty ? ReflectionPrompts.prompt(for: start) : storedPrompt)
        _reflectionAnswer = State(initialValue: session?.reflectionAnswer ?? "")
        _promptChosenManually = State(initialValue: !storedPrompt.isEmpty)
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

    private var reflectionHeader: String {
        Calendar.current.isDateInToday(startDate) ? "Today's reflection" : "Reflection"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Started", selection: $startDate, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                } header: { FormHeader("When") }

                Section {
                    Stepper(value: minutesBinding, in: 1...600) {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(Fmt.duration(durationSeconds))
                                .font(.system(.body, design: .serif))
                                .foregroundStyle(Theme.inkSecondary)
                                .monospacedDigit()
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presets, id: \.self) { preset in
                                Button("\(preset) min") { durationSeconds = preset * 60 }
                                    .buttonStyle(ChipStyle(selected: durationSeconds == preset * 60))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: { FormHeader("How long") }

                Section {
                    TextField("Home, the park, the office…", text: $location)
                        .textInputAutocapitalization(.words)

                    Button {
                        locator.requestPlaceName()
                    } label: {
                        HStack {
                            Label("Use current location", systemImage: "location")
                                .foregroundStyle(Theme.ink)
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
                            .foregroundStyle(Theme.clay)
                    }

                    if !recentLocations.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recentLocations, id: \.self) { place in
                                    Button(place) { location = place }
                                        .buttonStyle(ChipStyle(selected: location == place))
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: { FormHeader("Where") }

                Section {
                    Picker("Technique", selection: $technique) {
                        ForEach(Technique.allCases) { technique in
                            Text(technique.rawValue).tag(technique)
                        }
                    }
                } header: { FormHeader("Practice") }

                Section {
                    MoodPicker(title: "Before", selection: $moodBefore)
                    MoodPicker(title: "After", selection: $moodAfter)
                } header: {
                    FormHeader("Mood")
                } footer: {
                    Text("Optional. Over time it shows how sitting changes how you feel.")
                }

                Section {
                    TextField("How did it go? Anything you noticed?", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                } header: { FormHeader("Notes") }

                reflectionSection

                if session != nil {
                    Section {
                        Button("Delete session", role: .destructive) { confirmDelete = true }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .paperBackground()
            .tint(Theme.ink)
            .navigationTitle(session == nil ? "Log session" : "Edit session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.inkSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: locator.placeName) { _, newValue in
                if let newValue, !newValue.isEmpty { location = newValue }
            }
            .onChange(of: startDate) { _, newDate in
                // Follow the day's question unless the user picked their own.
                if !promptChosenManually {
                    reflectionPrompt = ReflectionPrompts.prompt(for: newDate)
                }
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

    /// The daily question, directly below Notes.
    private var reflectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                Text(reflectionPrompt)
                    .font(.system(.title3, design: .serif).italic())
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)

                TextField("Write a line or two…", text: $reflectionAnswer, axis: .vertical)
                    .font(.system(.body, design: .serif))
                    .lineLimit(3...12)
            }
            .padding(.vertical, 6)

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    reflectionPrompt = ReflectionPrompts.another(excluding: reflectionPrompt)
                    promptChosenManually = true
                }
            } label: {
                Label("Different question", systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
            }
        } header: {
            FormHeader(reflectionHeader)
        } footer: {
            Text("A new question each day. Answer as much or as little as you like.")
        }
    }

    private func save() {
        let place = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let answer = reflectionAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        // Only keep the question when there's an answer, so no blank reflections are stored.
        let prompt = answer.isEmpty ? "" : reflectionPrompt

        if let session {
            session.startDate = startDate
            session.durationSeconds = durationSeconds
            session.location = place
            session.technique = technique.rawValue
            session.moodBefore = moodBefore
            session.moodAfter = moodAfter
            session.notes = text
            session.reflectionPrompt = prompt
            session.reflectionAnswer = answer
        } else {
            modelContext.insert(MeditationSession(
                startDate: startDate,
                durationSeconds: durationSeconds,
                location: place,
                technique: technique,
                moodBefore: moodBefore,
                moodAfter: moodAfter,
                notes: text,
                reflectionPrompt: prompt,
                reflectionAnswer: answer
            ))
        }
        try? modelContext.save()
        dismiss()
    }
}
