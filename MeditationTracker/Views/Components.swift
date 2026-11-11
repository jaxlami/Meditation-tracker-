import SwiftUI

struct CardModifier: ViewModifier {
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.5)
            )
    }
}

extension View {
    func card(padding: CGFloat = 20) -> some View { modifier(CardModifier(padding: padding)) }
}

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 3
    var tint: Color = Theme.sage

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.hairline, lineWidth: max(1, lineWidth / 3))
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.easeInOut(duration: 0.6), value: progress)
    }
}

/// Mood drawn as a circle that fills from the bottom: empty = rough, full = great. No emoji.
struct MoodGlyph: View {
    let value: Int
    var size: CGFloat = 16
    var tint: Color = Theme.sage

    var body: some View {
        let fraction = CGFloat(max(0, min(value, 5))) / 5
        ZStack {
            Circle().strokeBorder(tint, lineWidth: 1)
            Circle()
                .fill(tint)
                .mask(alignment: .bottom) {
                    Rectangle().frame(height: size * fraction)
                }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Mood.label(value))
    }
}

struct SessionRow: View {
    let session: MeditationSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.technique)
                        .font(Theme.headline)
                        .foregroundStyle(Theme.ink)
                    Text(session.startDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                    if !session.location.isEmpty {
                        Text(session.location)
                            .font(.footnote)
                            .foregroundStyle(Theme.inkTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(Fmt.duration(session.durationSeconds))
                        .font(.system(.subheadline, design: .serif))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    if session.moodAfter > 0 {
                        MoodGlyph(value: session.moodAfter, size: 12)
                    }
                }
            }

            if session.hasReflection {
                Text("\u{201C}\(session.reflectionAnswer)\u{201D}")
                    .font(.system(.subheadline, design: .serif).italic())
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(2)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Theme.sage).frame(width: 1.5)
                    }
            }
        }
        .contentShape(Rectangle())
    }
}

struct StatCard: View {
    let title: String
    let value: String
    var tint: Color = Theme.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(title)
            Text(value)
                .font(Theme.numeral(28))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .card(padding: 18)
    }
}

struct MoodPicker: View {
    let title: String
    @Binding var selection: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(selection == 0 ? "Not set" : Mood.label(selection))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .font(.subheadline)
            HStack {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        selection = (selection == value) ? 0 : value
                    } label: {
                        VStack(spacing: 6) {
                            MoodGlyph(value: value, size: 26, tint: selection == value ? Theme.ink : Theme.sage)
                            Text(Mood.label(value))
                                .font(.caption2)
                                .foregroundStyle(selection == value ? Theme.ink : Theme.inkTertiary)
                        }
                        .opacity(selection == 0 || selection == value ? 1 : 0.45)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title): \(Mood.label(value))")
                    .accessibilityAddTraits(selection == value ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 6)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Section header for forms in the editorial style.
struct FormHeader: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Eyebrow(text)
            .padding(.top, 8)
    }
}
