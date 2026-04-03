import Foundation
import Security

@Observable
final class AIService {
    static let shared = AIService()

    var isGenerating = false
    var error: String?

    private let keychainKey = "groqAPIKey"

    private init() {
        hasAPIKey = loadFromKeychain() != nil
    }

    // MARK: - API Key Management

    var hasAPIKey: Bool = false

    var selectedModel: String {
        get { UserDefaults.standard.string(forKey: "aiModel") ?? "llama-3.3-70b-versatile" }
        set { UserDefaults.standard.set(newValue, forKey: "aiModel") }
    }

    static let availableModels = [
        "llama-3.3-70b-versatile",
        "llama-3.1-8b-instant",
        "mixtral-8x7b-32768",
        "gemma2-9b-it"
    ]

    var apiKey: String? {
        get { loadFromKeychain() }
        set {
            if let key = newValue, !key.isEmpty {
                saveToKeychain(key)
                hasAPIKey = true
            } else {
                deleteFromKeychain()
                hasAPIKey = false
            }
        }
    }

    private func refreshKeyStatus() {
        hasAPIKey = loadFromKeychain() != nil
    }

    // MARK: - Generate Study Plan

    func generateStudyPlan(text: String, subject: String, examDate: Date) async throws -> [StudyPlanDay] {
        guard let key = apiKey, !key.isEmpty else {
            throw AIError.noAPIKey
        }

        isGenerating = true
        error = nil
        defer { isGenerating = false }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let examDateStr = dateFormatter.string(from: examDate)
        let todayStr = dateFormatter.string(from: Date())

        let prompt = """
        Du bist ein Lernplan-Assistent für Schüler. Erstelle einen realistischen Lernplan als JSON-Array.

        Fach: \(subject)
        Klassenarbeit am: \(examDateStr)
        Heute ist: \(todayStr)

        Aufgaben/Stoff:
        \(text)

        Antworte NUR mit einem JSON-Array, ohne Markdown-Formatierung, ohne Code-Blöcke, nur reines JSON:
        [{"day": "YYYY-MM-DD", "topic": "Was an diesem Tag gelernt werden soll", "duration": 30}]

        Regeln:
        - Verteile den Stoff gleichmäßig auf die Tage bis zur Klassenarbeit
        - Letzter Tag vor der Klassenarbeit: Wiederholung
        - Duration in Minuten (15-60)
        - Maximal 60 Minuten pro Tag
        - Beginne ab morgen
        """

        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!

        let body: [String: Any] = [
            "model": selectedModel,
            "messages": [
                ["role": "system", "content": "Du antwortest immer auf Deutsch. Du gibst NUR JSON zurück, ohne Erklärungen."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            if httpResponse.statusCode == 401 {
                throw AIError.invalidKey
            }
            throw AIError.apiError("Status \(httpResponse.statusCode): \(errorBody)")
        }

        // Parse OpenAI-compatible response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let responseText = message["content"] as? String else {
            throw AIError.parseError
        }

        // Clean response text (remove markdown code blocks if present)
        let cleanText = responseText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleanText.data(using: .utf8),
              let days = try? JSONDecoder().decode([StudyPlanDay].self, from: jsonData) else {
            throw AIError.parseError
        }

        return days
    }

    // MARK: - Ask Question (Allgemeine KI-Frage)

    struct AIResponse {
        var text: String
        var actions: [[String: Any]] = []
    }

    func askQuestion(_ question: String, context: String = "") async throws -> String {
        let response = try await askWithActions(question, chatHistory: [], context: context)
        return response.text
    }

    func askWithActions(_ question: String, chatHistory: [ChatMessage] = [], context: String = "") async throws -> AIResponse {
        guard let key = apiKey, !key.isEmpty else {
            throw AIError.noAPIKey
        }

        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!

        let systemPrompt = """
        Du bist ein Lern-Assistent in einer Schüler-App. Regeln:
        - Antworte auf Deutsch, kurz und direkt
        - Keine langen Erklärungen wenn der Schüler nur etwas eintragen will
        - Bei Aktionen: bestätige kurz was du gemacht hast, z.B. "Erledigt! 10 min Deutsch und 10 min Englisch eingetragen."
        - Sei freundlich aber nicht übertrieben
        - Nutze die App-Daten um hilfreiche Tipps zu geben

        Du kannst Aktionen in der App ausführen. Füge dafür am Ende einen Block ein:

        ///ACTIONS///
        [{"action": "add_session", "subject": "Mathe", "minutes": 30, "date": "2026-04-03"}]
        ///END///

        Aktionen:
        - add_session: Lernzeit (subject, minutes, date im Format YYYY-MM-DD)
        - add_entry: Kalendereintrag (title, date, type: "lerntag"/"klassenarbeit"/"erinnerung")
        - add_grade: Note (subject, grade als Zahl, type: "schriftlich"/"muendlich")

        Nutze Aktionen wenn der Schüler darum bittet. Kurz bestätigen, nicht erklären was du tust.
        """

        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        if !context.isEmpty {
            messages.append(["role": "system", "content": "App-Daten des Schülers:\n\(context)"])
        }
        // Bisherigen Chat-Verlauf senden (max letzte 20 Nachrichten)
        for msg in chatHistory.suffix(20) {
            messages.append(["role": msg.role, "content": msg.text])
        }
        messages.append(["role": "user", "content": question])

        let body: [String: Any] = [
            "model": selectedModel,
            "messages": messages,
            "temperature": 0.7
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unbekannt"
            if httpResponse.statusCode == 401 {
                throw AIError.invalidKey
            }
            throw AIError.apiError("Status \(httpResponse.statusCode): \(errorBody)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.parseError
        }

        // Parse actions from response
        var text = content
        var actions: [[String: Any]] = []

        if let actionsRange = content.range(of: "///ACTIONS///"),
           let endRange = content.range(of: "///END///") {
            let actionsString = String(content[actionsRange.upperBound..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            text = String(content[..<actionsRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)

            if let jsonData = actionsString.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                actions = parsed
            }
        }

        return AIResponse(text: text, actions: actions)
    }

    // MARK: - Explain Topic (Thema erklären)

    func explainTopic(subject: String, topic: String) async throws -> String {
        try await askQuestion(
            "Erkläre mir das Thema '\(topic)' im Fach \(subject). Erkläre es einfach und verständlich für einen Schüler. Nutze Beispiele."
        )
    }

    // MARK: - Generate Quiz (strukturiert)

    func generateQuiz(subject: String, topic: String, questionCount: Int = 5) async throws -> [QuizQuestion] {
        guard let key = apiKey, !key.isEmpty else { throw AIError.noAPIKey }

        let prompt = """
        Erstelle ein Quiz mit \(questionCount) Fragen zum Thema '\(topic)' im Fach \(subject).
        Antworte NUR mit JSON, ohne Erklärungen:
        [{"question": "Frage?", "options": ["A", "B", "C", "D"], "correctIndex": 0}]
        correctIndex ist 0-basiert (0=erste Option). Alle Fragen auf Deutsch.
        """

        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        let body: [String: Any] = [
            "model": selectedModel,
            "messages": [
                ["role": "system", "content": "Du antwortest NUR mit JSON. Kein Text, keine Erklärungen."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw AIError.networkError }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else { throw AIError.parseError }

        let clean = content.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = clean.data(using: .utf8),
              let questions = try? JSONDecoder().decode([QuizQuestion].self, from: jsonData) else { throw AIError.parseError }

        return questions
    }

    // MARK: - Generate Flashcards (Karteikarten)

    func generateFlashcards(subject: String, topic: String, count: Int = 10) async throws -> [Flashcard] {
        guard let key = apiKey, !key.isEmpty else { throw AIError.noAPIKey }

        let prompt = """
        Erstelle \(count) Karteikarten zum Thema '\(topic)' im Fach \(subject).
        Antworte NUR mit JSON:
        [{"front": "Frage/Begriff", "back": "Antwort/Erklärung"}]
        Auf Deutsch. Kurze, prägnante Inhalte.
        """

        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        let body: [String: Any] = [
            "model": selectedModel,
            "messages": [
                ["role": "system", "content": "Du antwortest NUR mit JSON. Kein Text, keine Erklärungen."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw AIError.networkError }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else { throw AIError.parseError }

        let clean = content.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = clean.data(using: .utf8),
              let cards = try? JSONDecoder().decode([Flashcard].self, from: jsonData) else { throw AIError.parseError }

        return cards
    }

    // MARK: - Summarize Notes (Zusammenfassung)

    func summarizeNotes(text: String, subject: String) async throws -> String {
        try await askQuestion(
            "Fasse den folgenden Text zusammen. Erstelle eine übersichtliche Zusammenfassung mit den wichtigsten Punkten als Aufzählung:\n\n\(text)",
            context: "Fach: \(subject)"
        )
    }

    // MARK: - Keychain

    private func saveToKeychain(_ value: String) {
        deleteFromKeychain()
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Quiz & Flashcard Models

struct QuizQuestion: Codable, Identifiable {
    var id = UUID()
    var question: String
    var options: [String]
    var correctIndex: Int

    enum CodingKeys: String, CodingKey {
        case question, options, correctIndex
    }
}

struct Flashcard: Codable, Identifiable {
    var id = UUID()
    var front: String
    var back: String

    enum CodingKeys: String, CodingKey {
        case front, back
    }
}

// MARK: - Other Models

struct StudyPlanDay: Codable, Identifiable {
    var id = UUID()
    var day: String
    var topic: String
    var duration: Int

    enum CodingKeys: String, CodingKey {
        case day, topic, duration
    }

    var date: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: day)
    }
}

enum AIError: LocalizedError {
    case noAPIKey
    case networkError
    case invalidKey
    case apiError(String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "Kein API-Key. Bitte in den Einstellungen eingeben."
        case .networkError: return "Netzwerkfehler. Bitte prüfe deine Internetverbindung."
        case .invalidKey: return "Ungültiger API-Key. Bitte überprüfe den Key in den Einstellungen."
        case .apiError(let msg): return "API-Fehler: \(msg)"
        case .parseError: return "Antwort konnte nicht verarbeitet werden. Bitte versuche es erneut."
        }
    }
}
