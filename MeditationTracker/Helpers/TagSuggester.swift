import Foundation
import NaturalLanguage
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Suggests topic tags for a journal entry. Everything runs on the device; nothing is sent anywhere.
///
/// Layers, strongest first:
/// 1. Your existing tags that appear in the text (matched on base word forms: "workouts" → "workout").
/// 2. A small built-in keyword list for common topics, so suggestions work from the very first entry.
/// 3. Your existing tags that are close in meaning to words in the text (word embeddings).
/// 4. Apple Intelligence (iOS 26+ on supported devices), run separately via `intelligentSuggestions`.
enum TagSuggester {
    /// Lowercase, trimmed, no leading "#", inner whitespace collapsed to single spaces.
    static func normalize(_ raw: String) -> String {
        raw.lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "#").union(.whitespacesAndNewlines).union(.punctuationCharacters))
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Fast, synchronous suggestions (layers 1–3), best first.
    static func suggest(for text: String, existing: [String], excluding applied: Set<String> = [], limit: Int = 4) -> [String] {
        let words = analyze(text)
        guard !words.isEmpty else { return [] }
        let forms = Set(words.flatMap { [$0.word, $0.lemma] })
        var scores: [String: Double] = [:]

        // 1. Existing tags mentioned directly.
        for tag in existing {
            let parts = tag.split(separator: " ").map(String.init)
            if parts.allSatisfy({ forms.contains($0) || forms.contains(lemma(of: $0)) }) {
                scores[tag, default: 0] += 3
            }
        }

        // 2. Built-in topics.
        for (topic, keywords) in lexicon {
            let hits = keywords.filter { forms.contains($0) }.count
            if hits > 0 { scores[topic, default: 0] += 1.5 + Double(hits) * 0.5 }
        }

        // 3. Existing tags close in meaning (single-word tags only; embeddings are word-level).
        if let embedding = NLEmbedding.wordEmbedding(for: .english) {
            let content = Set(words.filter(\.isContent).map(\.lemma))
            for tag in existing where !tag.contains(" ") {
                let best = content.map { embedding.distance(between: $0, and: tag) }.min() ?? 2
                // Measured: related pairs (workout/gym, kid/childhood, job/work) fall under ~1.0.
                if best < 1.0 { scores[tag, default: 0] += 1 + (1.0 - best) * 2 }
            }
        }

        // Prefer the user's own tag names when a built-in topic has the same name.
        return scores
            .filter { !applied.contains($0.key) }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(limit)
            .map(\.key)
    }

    // MARK: - Apple Intelligence

    static var intelligenceAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    /// Up to 3 tags from the on-device model; empty when it isn't available or the text is too short.
    static func intelligentSuggestions(for text: String, existing: [String]) async -> [String] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard SystemLanguageModel.default.isAvailable,
                  text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20 else { return [] }
            let session = LanguageModelSession(instructions: """
                You organize private journal entries into topics. Give 1 to 3 short, lowercase topic tags \
                (one or two words each, no # symbol). Prefer tags from the user's existing list when they fit; \
                only invent a new tag when none fit. Topics are subjects like childhood, romance, gym, work, family.
                """)
            let prompt = """
                Existing tags: \(existing.isEmpty ? "none yet" : existing.joined(separator: ", "))

                Entry:
                \(text.prefix(2000))
                """
            do {
                let response = try await session.respond(to: prompt, generating: TagIdeas.self)
                return Array(response.content.tags.map(normalize).filter { !$0.isEmpty }.prefix(3))
            } catch {
                return []
            }
        }
        #endif
        return []
    }

    // MARK: - Text analysis

    private struct Token {
        let word: String
        let lemma: String
        let isContent: Bool
    }

    private static func analyze(_ text: String) -> [Token] {
        let tagger = NLTagger(tagSchemes: [.lemma, .lexicalClass])
        tagger.string = text
        var tokens: [Token] = []
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, range in
            let word = text[range].lowercased()
            let lemma = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue.lowercased() ?? word
            let isContent = [NLTag.noun, .verb, .adjective].contains(tag) && word.count > 2
            tokens.append(Token(word: word, lemma: lemma, isContent: isContent))
            return true
        }
        return tokens
    }

    private static func lemma(of word: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = word
        return tagger.tag(at: word.startIndex, unit: .word, scheme: .lemma).0?.rawValue.lowercased() ?? word
    }

    /// Common journaling topics and words that point to them (base forms).
    private static let lexicon: [String: Set<String>] = [
        "romance": ["girlfriend", "boyfriend", "partner", "date", "dating", "crush", "kiss", "romance", "romantic",
                    "relationship", "wife", "husband", "breakup", "flirt", "valentine", "anniversary", "lover"],
        "gym": ["gym", "workout", "squat", "deadlift", "bench", "lift", "lifting", "weight", "cardio", "training",
                "muscle", "protein", "run", "running", "exercise"],
        "childhood": ["childhood", "kid", "grandma", "grandpa", "grandmother", "grandfather",
                      "elementary", "toy", "nostalgia", "nostalgic"],
        "work": ["work", "job", "boss", "office", "deadline", "meeting", "colleague", "coworker", "project",
                 "client", "career", "promotion", "manager", "salary"],
        "family": ["family", "mom", "mum", "dad", "mother", "father", "parent", "sister", "brother", "sibling",
                   "cousin", "aunt", "uncle", "son", "daughter"],
        "friends": ["friend", "friendship", "buddy", "hangout", "party"],
        "anxiety": ["anxious", "anxiety", "nervous", "worried", "worry", "panic", "stress", "stressed", "overwhelmed", "fear"],
        "sleep": ["sleep", "insomnia", "dream", "nap", "exhausted"],
        "health": ["health", "sick", "doctor", "pain", "illness", "diet", "headache", "therapy"],
        "money": ["money", "rent", "debt", "budget", "savings", "bill", "expensive", "invest"],
        "gratitude": ["grateful", "thankful", "gratitude", "blessed", "appreciate"],
        "school": ["school", "class", "exam", "teacher", "homework", "university", "college", "study", "studying"],
    ]
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct TagIdeas {
    @Guide(description: "One to three short lowercase topic tags, one or two words each")
    var tags: [String]
}
#endif
