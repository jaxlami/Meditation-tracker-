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

    private let presets = [5, 10, 15, 20, 30, 45, 60]

    private var total: TimeInterval { TimeInterval(minutes * 60) }
    private var elapsed: TimeInterval {
        accumulated + (segmentStart.map { now.timeIntervalSince($0) } ?? 0)
    }
    private var remaining: TimeInterval { max(0, total - elapsed) }

    var body: some View {
        ZStack {
            PaperBackground()

            if phase == .setup {
                setupView
                    .transition(.opacity)
            } else {
                runningView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: phase == .setup)
        .statusBarHidden(phase != .setup)
        .persistentSystemOverlays(phase == .setup ? .automatic : .hidden)
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
        .task {
            // Ticks four times a second while the timer screen is open.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                now = .now
                if phase == .running && remaining <= 0 {
                    complete()
                }
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
            Button("Keep sitting", role: .cancel) {}
        }
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Close") { dismiss() }
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer()

            Eyebrow("New session")
                .padding(.bottom, 16)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(minutes)")
                    .font(Theme.numeral(108, weight: .ultraLight))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text("min")
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Theme.inkSecondary)
            }

            HStack(spacing: 28) {
                stepButton("minus") { if minutes > 1 { minutes -= 1 } }
                stepButton("plus") { if minutes < 180 { minutes += 1 } }
            }
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { preset in
                        Button("\(preset)") { withAnimation(.snappy) { minutes = preset } }
                            .buttonStyle(ChipStyle(selected: minutes == preset))
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 36)

            Menu {
                Picker("Technique", selection: $technique) {
                    ForEach(Technique.allCases) { technique in
                        Label(technique.rawValue, systemImage: technique.icon).tag(technique)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(technique.rawValue)
                        .font(.system(.body, design: .serif))
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            }
            .padding(.top, 20)

            Spacer()

            Button(action: start) {
                Text("Begin")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .sensoryFeedback(.selection, trigger: minutes)
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40)
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
    }

    // MARK: - Running

    private var runningView: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                // Breathing orb: soft sage light that grows and settles.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.sage.opacity(0.45), Theme.sage.opacity(0.12), .clear],
                            center: .center, startRadius: 0, endRadius: 170
                        )
                    )
                    .scaleEffect(breathe ? 1.0 : 0.62)
                    .blur(radius: 6)
                    .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: breathe)

                ProgressRing(progress: total > 0 ? elapsed / total : 0, lineWidth: 1.5, tint: Theme.ink)
                    .padding(8)

                VStack(spacing: 10) {
                    Text(Fmt.clock(remaining))
                        .font(Theme.numeral(64, weight: .ultraLight))
                        .foregroundStyle(Theme.ink)
                    Eyebrow(phase == .paused ? "Paused" : technique.rawValue)
                }
            }
            .frame(width: 300, height: 300)
            .onAppear { breathe = true }

            Text("Breathe in as the light grows, out as it settles.")
                .font(.system(.footnote, design: .serif).italic())
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 36)

            Spacer()

            HStack(spacing: 44) {
                controlButton("xmark", label: "Discard") { confirmDiscard = true }
                controlButton(phase == .paused ? "play.fill" : "pause.fill", label: phase == .paused ? "Resume" : "Pause", prominent: true) {
                    if phase == .paused { resume() } else { pause() }
                }
                controlButton("checkmark", label: "Finish") { finishEarly() }
            }
            .padding(.bottom, 40)
            .disabled(phase == .finished)
        }
    }

    private func controlButton(_ icon: String, label: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: prominent ? 20 : 15, weight: .light))
                    .frame(width: prominent ? 72 : 52, height: prominent ? 72 : 52)
                    .foregroundStyle(prominent ? Theme.paper : Theme.ink)
                    .background(Circle().fill(prominent ? Theme.ink : Color.clear))
                    .overlay(Circle().strokeBorder(prominent ? Color.clear : Theme.hairline, lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.inkTertiary)
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
