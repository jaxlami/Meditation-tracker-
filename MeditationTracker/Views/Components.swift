import SwiftUI

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.easeInOut(duration: 0.4), value: progress)
    }
}

struct SessionRow: View {
    let session: MeditationSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.techniqueKind.icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(session.technique)
                    .font(.headline)
                Text(session.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !session.location.isEmpty {
                    Label(session.location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.duration(session.durationSeconds))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                if session.moodAfter > 0 {
                    Text(Mood.emoji(session.moodAfter))
                }
            }
        }
        .contentShape(Rectangle())
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card()
    }
}

struct MoodPicker: View {
    let title: String
    @Binding var selection: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(selection == 0 ? "Not set" : Mood.label(selection))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            HStack {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        selection = (selection == value) ? 0 : value
                    } label: {
                        Text(Mood.emoji(value))
                            .font(.title)
                            .padding(6)
                            .background(Circle().fill(selection == value ? Color.accentColor.opacity(0.25) : Color.clear))
                            .opacity(selection == 0 || selection == value ? 1 : 0.4)
                    }
                    .buttonStyle(.borderless)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
