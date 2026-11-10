import SwiftUI
import AudioToolbox

/// Full-screen meditation timer. When it finishes (or you end early) it opens the log form pre-filled.
struct TimerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKeys.defaultTimerMinutes) private var defaultTimerMinutes = 10
    @AppStorage(SettingsKeys.timerChimeEnabled) private var chimeEnabled = true

    private enum Phase { case setup, running, paused, finished }

    @State private var phase: Phase = .setup
    @State private var minutes = 10
    @State private var technique: Technique = .mindfulness
    @State private var sessionStart = Date()
    @State private var accumulated: TimeInterval = 0
    @State private var segmentStart: Date?
    @State private var now = Date()
    @State private var loggedSeconds = 0
    @State private var showingLog = false
    @State private var confirmDiscard = false
    @State private var didLoadDefaults = false
    @State private var breathe = false

    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    private let presets = [5, 10, 15, 20, 30, 45, 60]

    private var total: TimeInterval { TimeInterval(minutes * 60) }
    private var elapsed: TimeInterval {
        accumulated + (segmentStart.map { now.timeIntervalSince($0) } ?? 0)
    }
    private var remaining: TimeInterval { max(0, total - elapsed) }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.35), Color(.systemBackground)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                if phase == .setup {
                    setupView
                } else {
                    runningView
                }
            }
            .toolbar {
                if phase == .setup {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
        }
        .onAppear {
            if !didLoadDefaults {
                minutes = defaultTimerMinutes
                didLoadDefaults = true
            }
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            NotificationManager.cancelTimerEnd()
        }
        .onReceive(ticker) { date in
            now = date
            if phase == .running && remaining <= 0 {
                complete()
            }
        }
        .sheet(isPresented: $showingLog, onDismiss: { dismiss() }) {
            LogSessionView(
                prefillStart: sessionStart,
                prefillDurationSeconds: loggedSeconds,
                prefillTechnique: technique
            )
            .interactiveDismissDisabled()
        }
        .confirmationDialog("Discard this session?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep Meditating", role: .cancel) {}
        }
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("\(minutes) min")
                .font(.system(size: 64, weight: .thin, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(presets, id: \.self) { preset in
                        Button("\(preset)") { withAnimation { minutes = preset } }
                            .buttonStyle(.bordered)
                            .tint(minutes == preset ? Color.accentColor : Color.secondary)
                    }
                }
                .padding(.horizontal)
            }

            Stepper("Custom length: \(minutes) min", value: $minutes, in: 1...180)
                .padding(.horizontal, 32)

            Picker("Technique", selection: $technique) {
                ForEach(Technique.allCases) { technique in
                    Label(technique.rawValue, systemImage: technique.icon).tag(technique)
                }
            }
            .pickerStyle(.menu)

            Spacer()

            Button(action: start) {
                Label("Begin", systemImage: "play.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .navigationTitle("New Session")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Running

    private var runningView: some View {
        VStack(spacing: 40) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.18))
                    .scaleEffect(breathe ? 0.95 : 0.6)
                    .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: breathe)
                ProgressRing(progress: total > 0 ? elapsed / total : 0, lineWidth: 8)
                VStack(spacing: 6) {
                    Text(Fmt.clock(remaining))
                        .font(.system(size: 56, weight: .light, design: .rounded))
                        .monospacedDigit()
                    Text(phase == .paused ? "Paused" : technique.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 280, height: 280)
            .onAppear { breathe = true }

            Text("Breathe in as the circle grows, out as it shrinks.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            HStack(spacing: 40) {
                controlButton("xmark", label: "Discard") { confirmDiscard = true }
                controlButton(phase == .paused ? "play.fill" : "pause.fill", label: phase == .paused ? "Resume" : "Pause", prominent: true) {
                    if phase == .paused { resume() } else { pause() }
                }
                controlButton("checkmark", label: "Finish") { finishEarly() }
            }
            .padding(.bottom, 32)
            .disabled(phase == .finished)
        }
    }

    private func controlButton(_ icon: String, label: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(prominent ? .title.bold() : .title3.bold())
                    .frame(width: prominent ? 76 : 56, height: prominent ? 76 : 56)
                    .foregroundStyle(prominent ? Color.white : Color.accentColor)
                    .background(Circle().fill(prominent ? Color.accentColor : Color.accentColor.opacity(0.15)))
            }
            .buttonStyle(.plain)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func start() {
        sessionStart = .now
        now = .now
        accumulated = 0
        segmentStart = .now
        phase = .running
        scheduleEndNotification()
    }

    private func pause() {
        accumulated = elapsed
        segmentStart = nil
        phase = .paused
        NotificationManager.cancelTimerEnd()
    }

    private func resume() {
        now = .now
        segmentStart = .now
        phase = .running
        scheduleEndNotification()
    }

    private func finishEarly() {
        log(seconds: elapsed)
    }

    private func complete() {
        if chimeEnabled {
            AudioServicesPlaySystemSound(1005)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        log(seconds: total)
    }

    private func log(seconds: TimeInterval) {
        accumulated = seconds
        segmentStart = nil
        phase = .finished
        NotificationManager.cancelTimerEnd()
        loggedSeconds = max(1, Int(seconds.rounded()))
        showingLog = true
    }

    private func scheduleEndNotification() {
        let secondsLeft = remaining
        Task {
            if await NotificationManager.requestAuthorization() {
                NotificationManager.scheduleTimerEnd(after: secondsLeft)
            }
        }
    }
}
