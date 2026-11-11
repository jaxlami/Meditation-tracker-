import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// Lets the Share sheet save the log as a real .csv file (Files, Mail, Numbers, Excel...).
struct CSVFile: Transferable {
    let text: String

    init(sessions: [MeditationSession]) {
        let header = "Date,Start Time,Duration (min),Location,Technique,Mood Before,Mood After,Notes,Reflection Prompt,Reflection"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        let rows = sessions.sorted { $0.startDate < $1.startDate }.map { s in
            [
                dateFormatter.string(from: s.startDate),
                timeFormatter.string(from: s.startDate),
                String(format: "%.1f", Double(s.durationSeconds) / 60),
                s.location,
                s.technique,
                s.moodBefore == 0 ? "" : String(s.moodBefore),
                s.moodAfter == 0 ? "" : String(s.moodAfter),
                s.notes,
                s.reflectionPrompt,
                s.reflectionAnswer,
            ].map(Self.escape).joined(separator: ",")
        }
        text = ([header] + rows).joined(separator: "\n")
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { file in
            Data(file.text.utf8)
        }
        .suggestedFileName("Meditation Log.csv")
    }
}
