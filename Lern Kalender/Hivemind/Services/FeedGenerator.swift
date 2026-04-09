import Foundation

// MARK: - Errors

enum FeedGenerationError: LocalizedError {
    case noAPIKey
    case parsingFailed
    case apiFailed(String)
    case dailyLimitReached

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "Kein KI-Key in den Einstellungen hinterlegt."
        case .parsingFailed: return "KI-Antwort konnte nicht gelesen werden."
        case .apiFailed(let msg): return "KI-Fehler: \(msg)"
        case .dailyLimitReached: return "Du hast heute schon alle Posts gesehen — komm morgen wieder!"
        }
    }
}

// MARK: - JSON shape returned by the AI

private struct AIPost: Decodable {
    let type: String
    let title: String?
    let body: String?
    let question: String?
    let options: [String]?
    let correctIndex: Int?
    let explanation: String?
    let front: String?
    let back: String?
    let scenario: String?
    let walkthrough: String?
    let prompt: String?
    let expectedKeywords: [String]?
}

// MARK: - FeedGenerator

enum FeedGenerator {

    static let postsPerBatch = 15

    /// Generates a batch of `postsPerBatch` posts for the given topic.
    /// Persists them to disk and returns them.
    /// Throws `FeedGenerationError.dailyLimitReached` if the topic already had a generation today.
    static func generateFeed(
        for topic: Topic,
        sourceText: String?,
        previousProgress: TopicProgress?
    ) async throws -> [FeedPost] {

        // Daily-limit guard.
        if let progress = previousProgress,
           let lastGen = progress.feedGeneratedDate,
           Calendar.current.isDateInToday(lastGen),
           progress.feedExhausted {
            throw FeedGenerationError.dailyLimitReached
        }

        guard AIService.shared.hasAPIKey else { throw FeedGenerationError.noAPIKey }

        let prompt = buildPrompt(topic: topic, sourceText: sourceText)

        var raw: String
        do {
            raw = try await AIService.shared.askQuestion(prompt)
        } catch {
            throw FeedGenerationError.apiFailed(error.localizedDescription)
        }

        // Try parse — if it fails, retry once with a stricter wrapper.
        if let posts = parse(raw, topicId: topic.id) {
            try persist(posts: posts, topicId: topic.id)
            return posts
        }

        let strictPrompt = "Antworte AUSSCHLIESSLICH mit einem JSON-Array — kein Markdown, keine Erklärung. Hier ist die Aufgabe:\n\n" + prompt
        do {
            raw = try await AIService.shared.askQuestion(strictPrompt)
        } catch {
            throw FeedGenerationError.apiFailed(error.localizedDescription)
        }
        guard let posts = parse(raw, topicId: topic.id) else {
            throw FeedGenerationError.parsingFailed
        }
        try persist(posts: posts, topicId: topic.id)
        return posts
    }

    // MARK: - Local persistence

    static func loadPosts(for topicId: UUID) -> [FeedPost] {
        let url = postsURL(for: topicId)
        guard let data = try? Data(contentsOf: url) else { return [] }
        do {
            return try JSONDecoder().decode([FeedPost].self, from: data)
        } catch {
            // Corrupt file → wipe so next generation starts clean.
            try? FileManager.default.removeItem(at: url)
            return []
        }
    }

    static func deletePosts(for topicId: UUID) {
        try? FileManager.default.removeItem(at: postsURL(for: topicId))
    }

    static func updatePost(_ post: FeedPost) {
        var posts = loadPosts(for: post.topicId)
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[idx] = post
        try? persist(posts: posts, topicId: post.topicId)
    }

    // MARK: - Private

    private static func persist(posts: [FeedPost], topicId: UUID) throws {
        try ensureDirectoryExists()
        let data = try JSONEncoder().encode(posts)
        try data.write(to: postsURL(for: topicId), options: .atomic)
    }

    private static func feedsDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("feeds", isDirectory: true)
    }

    private static func ensureDirectoryExists() throws {
        let dir = feedsDirectory()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private static func postsURL(for topicId: UUID) -> URL {
        feedsDirectory().appendingPathComponent("\(topicId.uuidString).json")
    }

    private static func buildPrompt(topic: Topic, sourceText: String?) -> String {
        let subjectLine = topic.subject.map { "Schul-Fach: \($0)" } ?? "Bereich: Allgemeinwissen"
        let sourceBlock: String
        if let src = sourceText, !src.isEmpty {
            let trimmed = String(src.prefix(4000))
            sourceBlock = "Lehrmaterial des Schülers:\n\"\"\"\n\(trimmed)\n\"\"\""
        } else {
            sourceBlock = "Kein vorgegebenes Material — generiere zum Topic-Titel."
        }

        return """
        Erstelle einen Lern-Feed mit GENAU \(postsPerBatch) Posts zum Thema "\(topic.title)".
        \(subjectLine)
        \(sourceBlock)

        Mische die Post-Typen abwechslungsreich. Erlaubte Typen und ihre Felder:

        - "textLesson": kurze Mikro-Lektion (1-3 Absätze).
          Felder: title, body
        - "quizCard": Multiple-Choice-Frage mit 4 Optionen.
          Felder: question, options (genau 4 Strings), correctIndex (0-3), explanation
        - "flashcard": klassische Frage/Antwort-Karte.
          Felder: front, back
        - "example": konkrete Anwendung, "So nutzt du das im Alltag".
          Felder: scenario, walkthrough
        - "feynman": eine Aufforderung an den Schüler, etwas in eigenen Worten zu erklären.
          Felder: prompt, expectedKeywords (Array mit 3-6 Keywords, die in einer guten Antwort vorkommen sollten)

        Verteilung pro Batch:
        - 4 textLesson
        - 4 quizCard
        - 3 flashcard
        - 2 example
        - 2 feynman

        Antworte AUSSCHLIESSLICH mit einem JSON-Array. Kein Markdown, kein erklärender Text.
        Format:
        [
          {"type": "textLesson", "title": "...", "body": "..."},
          {"type": "quizCard", "question": "...", "options": ["A","B","C","D"], "correctIndex": 0, "explanation": "..."},
          {"type": "flashcard", "front": "...", "back": "..."},
          {"type": "example", "scenario": "...", "walkthrough": "..."},
          {"type": "feynman", "prompt": "...", "expectedKeywords": ["...", "...", "..."]}
        ]

        Sprache: Deutsch. Niveau: Schüler. Sei prägnant und lehrreich.
        """
    }

    private static func parse(_ raw: String, topicId: UUID) -> [FeedPost]? {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else { return nil }
        guard let aiPosts = try? JSONDecoder().decode([AIPost].self, from: data) else { return nil }

        var posts: [FeedPost] = []
        for (idx, ai) in aiPosts.enumerated() {
            guard let type = mapType(ai) else { continue }
            posts.append(FeedPost(
                topicId: topicId,
                orderIndex: idx,
                type: type
            ))
        }
        return posts.isEmpty ? nil : posts
    }

    private static func mapType(_ ai: AIPost) -> PostType? {
        switch ai.type {
        case "textLesson":
            guard let title = ai.title, let body = ai.body else { return nil }
            return .textLesson(title: title, body: body)
        case "quizCard":
            guard let q = ai.question, let opts = ai.options, opts.count == 4,
                  let correct = ai.correctIndex, (0...3).contains(correct),
                  let explanation = ai.explanation else { return nil }
            return .quizCard(question: q, options: opts, correctIndex: correct, explanation: explanation)
        case "flashcard":
            guard let f = ai.front, let b = ai.back else { return nil }
            return .flashcard(front: f, back: b)
        case "example":
            guard let s = ai.scenario, let w = ai.walkthrough else { return nil }
            return .example(scenario: s, walkthrough: w)
        case "feynman":
            guard let p = ai.prompt, let kws = ai.expectedKeywords else { return nil }
            return .feynman(prompt: p, expectedKeywords: kws)
        default:
            return nil
        }
    }
}
