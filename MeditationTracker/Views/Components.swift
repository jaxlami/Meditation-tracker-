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

// MARK: - Tags

/// Lays chips out left to right, wrapping onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, maxWidth: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, maxWidth: bounds.width) {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    private struct Row {
        var y: CGFloat
        var height: CGFloat = 0
        var width: CGFloat = 0
        var items: [(index: Int, x: CGFloat, size: CGSize)] = []
    }

    private func arrange(_ subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row(y: 0)
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let x = row.items.isEmpty ? 0 : row.width + spacing
            if !row.items.isEmpty && x + size.width > maxWidth {
                rows.append(row)
                row = Row(y: row.y + row.height + spacing)
                row.items.append((index, 0, size))
                row.width = size.width
            } else {
                row.items.append((index, x, size))
                row.width = x + size.width
            }
            row.height = max(row.height, size.height)
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}

/// A topic tag. Applied = filled ink, suggested = dashed sage outline, plain = hairline.
struct TagChip: View {
    enum Kind { case applied, suggested, plain }

    let tag: String
    var kind: Kind = .plain
    var count: Int?
    var selected = false

    var body: some View {
        HStack(spacing: 5) {
            if kind == .suggested {
                Image(systemName: "plus").font(.caption2.weight(.semibold))
            }
            Text(tag)
            if let count {
                Text("\(count)")
                    .foregroundStyle(selected ? Theme.paper.opacity(0.7) : Theme.inkTertiary)
            }
            if kind == .applied {
                Image(systemName: "xmark").font(.caption2.weight(.semibold)).opacity(0.7)
            }
        }
        .font(.subheadline.monospacedDigit())
        .foregroundStyle(foreground)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(filled ? Theme.ink : Color.clear))
        .overlay {
            if kind == .suggested {
                Capsule().strokeBorder(Theme.sage, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            } else if !filled {
                Capsule().strokeBorder(Theme.hairline, lineWidth: 1)
            }
        }
        .contentShape(Capsule())
    }

    private var filled: Bool { kind == .applied || selected }
    private var foreground: Color {
        if filled { return Theme.paper }
        return kind == .suggested ? Theme.sage : Theme.ink
    }
}

struct JournalEntryRow: View {
    let entry: JournalEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if entry.mood > 0 {
                    MoodGlyph(value: entry.mood, size: 12)
                } else {
                    Circle().strokeBorder(Theme.hairline, lineWidth: 1).frame(width: 12, height: 12)
                }
            }
            .padding(.top, 5)

            VStack(alignment: .leading, spacing: 8) {
                Text(entry.text.isEmpty ? "No words, just a mood." : entry.text)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(entry.text.isEmpty ? Theme.inkSecondary : Theme.ink)
                    .lineLimit(3)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if !entry.tags.isEmpty {
                        Text(entry.tags.map { "#\($0)" }.joined(separator: "  "))
                            .font(.caption)
                            .foregroundStyle(Theme.sage)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(Theme.inkTertiary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}
