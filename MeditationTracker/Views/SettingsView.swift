import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MeditationSession.startDate, order: .reverse) private var sessions: [MeditationSession]

    @AppStorage(SettingsKeys.dailyGoalMinutes) private var dailyGoalMinutes = 10
    @AppStorage(SettingsKeys.defaultTimerMinutes) private var defaultTimerMinutes = 10
    @AppStorage(SettingsKeys.timerChimeEnabled) private var chimeEnabled = true
    @AppStorage(SettingsKeys.reminderEnabled) private var reminderEnabled = false
    @AppStorage(SettingsKeys.reminderSeconds) private var reminderSeconds = 8 * 3600

    @State private var showingPermissionAlert = false
    @State private var confirmDeleteAll = false

    private var reminderTime: Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: .now).addingTimeInterval(TimeInterval(reminderSeconds)) },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderSeconds = (parts.hour ?? 8) * 3600 + (parts.minute ?? 0) * 60
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goals") {
                    Stepper("Daily goal: \(dailyGoalMinutes) min", value: $dailyGoalMinutes, in: 1...240)
                    Stepper("Default timer: \(defaultTimerMinutes) min", value: $defaultTimerMinutes, in: 1...180)
                    Toggle("Chime when timer ends", isOn: $chimeEnabled)
                }

                Section {
                    Toggle("Daily reminder", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("Remind me at", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("A gentle notification each day to help you build the habit.")
                }

                Section {
                    ShareLink(
                        item: CSVFile(sessions: sessions),
                        preview: SharePreview("Meditation Log.csv", image: Image(systemName: "tablecells"))
                    ) {
                        Label("Export Sessions (CSV)", systemImage: "square.and.arrow.up")
                    }
                    .disabled(sessions.isEmpty)

                    Button(role: .destructive) {
                        confirmDeleteAll = true
                    } label: {
                        Label("Delete All Sessions", systemImage: "trash")
                    }
                    .disabled(sessions.isEmpty)
                } header: {
                    Text("Your Data")
                } footer: {
                    Text("All data stays on your iPhone. Export a CSV to back it up or open it in Numbers/Excel.")
                }

                Section("About") {
                    LabeledContent("Sessions logged", value: "\(sessions.count)")
                    LabeledContent("Version", value: "1.0")
                }
            }
            .navigationTitle("Settings")
            .onChange(of: reminderEnabled) { _, enabled in
                if enabled {
                    Task {
                        if await NotificationManager.requestAuthorization() {
                            NotificationManager.scheduleDailyReminder(secondsAfterMidnight: reminderSeconds)
                        } else {
                            reminderEnabled = false
                            showingPermissionAlert = true
                        }
                    }
                } else {
                    NotificationManager.cancelDailyReminder()
                }
            }
            .onChange(of: reminderSeconds) { _, seconds in
                if reminderEnabled {
                    NotificationManager.scheduleDailyReminder(secondsAfterMidnight: seconds)
                }
            }
            .alert("Notifications Are Off", isPresented: $showingPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Allow notifications for this app in Settings to get daily reminders.")
            }
            .confirmationDialog("Delete all \(sessions.count) sessions?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) {
                    for session in sessions { modelContext.delete(session) }
                    try? modelContext.save()
                }
            } message: {
                Text("This can't be undone. Consider exporting a CSV first.")
            }
        }
    }
}
