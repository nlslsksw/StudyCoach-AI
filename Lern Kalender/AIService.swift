import Foundation
import Security

// MARK: - AI Provider

enum AIProvider: String, CaseIterable, Identifiable {
    case backend = "backend"
    case groq = "groq"
    case openai = "openai"
    case gemini = "gemini"
    case claude = "claude"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .backend: return "StudyCoach (Groq)"
        case .groq: return "Groq"
        case .openai: return "OpenAI"
        case .gemini: return "Google Gemini"
        case .claude: return "Anthropic Claude"
        }
    }

    var apiURL: String {
        switch self {
        case .backend: return "https://tudycoach-api.nils-lohrmann11.workers.dev/"
        case .groq: return "https://api.groq.com/openai/v1/chat/completions"
        case .openai: return "https://api.openai.com/v1/chat/completions"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
        case .claude: return "https://api.anthropic.com/v1/messages"
        }
    }

    var keychainKey: String {
        switch self {
        case .backend: return ""
        case .groq: return "groqAPIKey"
        case .openai: return "openaiAPIKey"
        case .gemini: return "geminiAPIKey"
        case .claude: return "claudeAPIKey"
        }
    }

    var models: [(id: String, name: String)] {
        switch self {
        case .backend:
            return [
                ("llama-3.3-70b-versatile", "Llama 3.3 70B (Standard)"),
                ("llama-3.1-8b-instant", "Llama 3.1 8B (Schnell)"),
                ("mixtral-8x7b-32768", "Mixtral 8x7B"),
                ("gemma2-9b-it", "Gemma 2 9B")
            ]
        case .groq:
            return [
                ("llama-3.3-70b-versatile", "Llama 3.3 70B"),
                ("llama-3.1-8b-instant", "Llama 3.1 8B (Schnell)"),
                ("mixtral-8x7b-32768", "Mixtral 8x7B"),
                ("gemma2-9b-it", "Gemma 2 9B")
            ]
        case .openai:
            return [
                ("gpt-4o", "GPT-4o"),
                ("gpt-4o-mini", "GPT-4o Mini (Günstig)"),
                ("gpt-4.1", "GPT-4.1")
            ]
        case .gemini:
            return [
                ("gemini-2.5-flash", "Gemini 2.5 Flash"),
                ("gemini-2.0-flash", "Gemini 2.0 Flash"),
                ("gemini-1.5-pro", "Gemini 1.5 Pro")
            ]
        case .claude:
            return [
                ("claude-sonnet-4-5-20250514", "Claude Sonnet 4.5"),
                ("claude-haiku-3-5-20241022", "Claude Haiku 3.5 (Schnell)")
            ]
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .backend: return ""
        case .groq: return "gsk_..."
        case .openai: return "sk-..."
        case .gemini: return "AIza..."
        case .claude: return "sk-ant-..."
        }
    }

    var isOpenAICompatible: Bool {
        self != .claude
    }
}

@Observable
final class AIService {
    static let shared = AIService()

    var isGenerating = false
    var error: String?

    private init() {
        hasAPIKey = true
    }

    // MARK: - API Key Management

    var hasAPIKey: Bool = true

    var selectedProvider: AIProvider {
        get { AIProvider(rawValue: UserDefaults.standard.string(forKey: "aiProvider") ?? "backend") ?? .backend }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "aiProvider")
            // Reset model to provider's default when switching
            selectedModel = newValue.models.first?.id ?? "llama-3.3-70b-versatile"
        }
    }

    var hasCustomKey: Bool {
        guard selectedProvider != .backend else { return false }
        return loadFromKeychain(forKey: selectedProvider.keychainKey) != nil
    }

    var selectedModel: String {
        get { UserDefaults.standard.string(forKey: "aiModel") ?? selectedProvider.models.first?.id ?? "llama-3.3-70b-versatile" }
        set { UserDefaults.standard.set(newValue, forKey: "aiModel") }
    }

    var language: String {
        get { UserDefaults.standard.string(forKey: "aiLanguage") ?? "Deutsch" }
        set { UserDefaults.standard.set(newValue, forKey: "aiLanguage") }
    }

    var responseStyle: String {
        get { UserDefaults.standard.string(forKey: "aiStyle") ?? "normal" }
        set { UserDefaults.standard.set(newValue, forKey: "aiStyle") }
    }

    var chatHistoryLimit: Int {
        get { UserDefaults.standard.object(forKey: "aiHistoryLimit") as? Int ?? 20 }
        set { UserDefaults.standard.set(newValue, forKey: "aiHistoryLimit") }
    }

    var suggestionsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "aiSuggestions") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "aiSuggestions") }
    }

    var assistantName: String {
        get { UserDefaults.standard.string(forKey: "aiName") ?? "Lern-Assistent" }
        set { UserDefaults.standard.set(newValue, forKey: "aiName") }
    }

    static let availableModels = [
        "llama-3.3-70b-versatile",
        "llama-3.1-8b-instant",
        "mixtral-8x7b-32768",
        "gemma2-9b-it"
    ]

    static let availableLanguages = ["Deutsch", "Englisch", "Französisch", "Spanisch", "Türkisch"]

    static let availableStyles = [
        ("kurz", "Kurz & knapp"),
        ("normal", "Normal"),
        ("ausfuehrlich", "Ausführlich"),
        ("kindgerecht", "Kindgerecht")
    ]

    var apiKey: String? {
        get {
            if selectedProvider == .backend { return nil }
            return loadFromKeychain(forKey: selectedProvider.keychainKey)
        }
        set {
            guard selectedProvider != .backend else { return }
            if let key = newValue, !key.isEmpty {
                saveToKeychain(key, forKey: selectedProvider.keychainKey)
            } else {
                deleteFromKeychain(forKey: selectedProvider.keychainKey)
            }
        }
    }

    func apiKey(for provider: AIProvider) -> String? {
        guard provider != .backend else { return nil }
        return loadFromKeychain(forKey: provider.keychainKey)
    }

    func setApiKey(_ key: String?, for provider: AIProvider) {
        guard provider != .backend else { return }
        if let key = key, !key.isEmpty {
            saveToKeychain(key, forKey: provider.keychainKey)
        } else {
            deleteFromKeychain(forKey: provider.keychainKey)
        }
    }

    // MARK: - API Request Helper

    private func makeAPIRequest(body: [String: Any]) throws -> URLRequest {
        let provider = selectedProvider
        let url: URL

        if provider == .backend {
            url = URL(string: provider.apiURL)!
        } else if let key = apiKey, !key.isEmpty {
            url = URL(string: provider.apiURL)!
        } else {
            // Fallback to backend if no custom key
            url = URL(string: AIProvider.backend.apiURL)!
        }

        var finalBody = body

        // Claude needs special handling
        if provider == .claude, let key = apiKey, !key.isEmpty {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

            // Extract system messages and convert to Claude format
            if var messages = finalBody["messages"] as? [[String: String]] {
                let systemMessages = messages.filter { $0["role"] == "system" }
                messages = messages.filter { $0["role"] != "system" }
                let systemText = systemMessages.compactMap { $0["content"] }.joined(separator: "\n\n")

                finalBody["messages"] = messages
                if !systemText.isEmpty {
                    finalBody["system"] = systemText
                }
                finalBody["max_tokens"] = 4096
            }

            request.httpBody = try JSONSerialization.data(withJSONObject: finalBody)
            return request
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth for non-backend providers
        if provider != .backend, let key = apiKey, !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: finalBody)
        return request
    }

    /// Extracts the response text from either OpenAI or Claude format
    func extractContent(from data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.parseError
        }

        // OpenAI format (Groq, OpenAI, Gemini, Backend)
        if let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }

        // Claude format
        if let content = json["content"] as? [[String: Any]],
           let text = content.first?["text"] as? String {
            return text
        }

        throw AIError.parseError
    }

    // MARK: - Generate Study Plan

    func generateStudyPlan(text: String, subject: String, examDate: Date) async throws -> [StudyPlanDay] {
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

        let body: [String: Any] = [
            "model": selectedModel,
            "messages": [
                ["role": "system", "content": "Du antwortest immer auf Deutsch. Du gibst NUR JSON zurück, ohne Erklärungen."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]

        let request = try makeAPIRequest(body: body)

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

        // Parse response (works with OpenAI, Groq, Gemini, and Claude format)
        let responseText = try extractContent(from: data)

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

        let styleInstruction: String = {
            switch responseStyle {
            case "kurz": return "Antworte sehr kurz und knapp, maximal 2-3 Sätze."
            case "ausfuehrlich": return "Antworte ausführlich mit Erklärungen und Beispielen."
            case "kindgerecht": return "Antworte kindgerecht, einfach und mit Beispielen. Nutze einfache Wörter."
            default: return "Antworte kurz und direkt."
            }
        }()

        let systemPrompt = """
        Du bist \(assistantName), ein Lern-Assistent in einer Schüler-App. Regeln:
        - Antworte auf \(language)
        - \(styleInstruction)
        - Sei freundlich aber nicht übertrieben
        - Nutze die App-Daten um hilfreiche Tipps zu geben

        STRENGE REGELN für Aktionen:
        - Du darfst NUR Aktionen ausführen wenn der Schüler dich DIREKT und EINDEUTIG darum bittet
        - Wörter die eine Aktion auslösen: "trag ein", "erstelle", "mach mir", "speichere", "füge hinzu", "eintragen"
        - Wörter die KEINE Aktion auslösen: "erkläre", "was ist", "wie geht", "hilf mir", "zeig mir", "erzähl"
        - Im ZWEIFEL: KEINE Aktion ausführen, stattdessen nachfragen "Soll ich das eintragen?"
        - NIEMALS Aktionen ausführen bei Fragen, Erklärungen, Quiz-Antworten oder allgemeinen Gesprächen
        - Wenn du eine Aktion ausführst, schreibe GENAU was: "Erledigt! Eingetragen: 10 min Deutsch, 10 min Englisch."
        - Wenn du NICHTS einträgst, schreibe KEINEN ///ACTIONS/// Block — gar nicht, auch nicht leer

        Du kannst Aktionen in der App ausführen. Füge dafür am Ende einen Block ein:

        ///ACTIONS///
        [{"action": "add_session", "subject": "Mathe", "minutes": 30, "date": "2026-04-03"}]
        ///END///

        Aktionen:
        - add_session: Lernzeit (subject, minutes, date im Format YYYY-MM-DD)
        - add_entry: Kalendereintrag (title, date, type: "lerntag"/"klassenarbeit"/"erinnerung")
        - add_grade: Note (subject, grade als Zahl, type: "schriftlich"/"muendlich")
        - create_quiz: Quiz erstellen (subject, topic) — Wenn der Schüler ein Quiz will, nutze diese Aktion
        - create_flashcards: Karteikarten erstellen (subject, topic) — Wenn der Schüler Karteikarten will
        - create_topic: Hivemind-Topic erstellen (subject, topic) — Wenn der Schüler ein Topic / einen Lernpfad / einen Lernfeed will
        - add_subject: Fach erstellen (name, icon, color) — icon: eines von "book.fill","pencil","function","globe.europe.africa.fill","theatermasks.fill","sportscourt.fill","music.note","paintbrush.fill","cpu.fill","leaf.fill","cross.fill","building.columns.fill" — color: eines von "blue","green","orange","purple","pink","red","teal","indigo","mint","cyan"

        Nutze Aktionen wenn der Schüler darum bittet. Kurz bestätigen, nicht erklären was du tust.
        """

        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        if !context.isEmpty {
            messages.append(["role": "system", "content": "App-Daten des Schülers:\n\(context)"])
        }
        // Bisherigen Chat-Verlauf senden
        for msg in chatHistory.suffix(chatHistoryLimit) {
            messages.append(["role": msg.role, "content": msg.text])
        }
        messages.append(["role": "user", "content": question])

        let body: [String: Any] = [
            "model": selectedModel,
            "messages": messages,
            "temperature": 0.7
        ]

        let request = try makeAPIRequest(body: body)

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

        let content = try extractContent(from: data)

        // Parse actions from response
        var text = content
        var actions: [[String: Any]] = []

        // Verschiedene Formate erkennen
        let markers = [
            ("///ACTIONS///", "///END///"),
            ("///ACTIONS///", "///END"),
            ("[{\"action\"", "}]")
        ]

        for (startMarker, endMarker) in markers.prefix(2) {
            if let actionsRange = content.range(of: startMarker),
               let endRange = content.range(of: endMarker) {
                let actionsString = String(content[actionsRange.upperBound..<endRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                text = String(content[..<actionsRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)

                if let jsonData = actionsString.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                    actions = parsed
                }
                break
            }
        }

        // Fallback: JSON-Array direkt im Text suchen
        if actions.isEmpty, let jsonStart = content.range(of: "[{\"action\"") {
            let jsonPart = String(content[jsonStart.lowerBound...])
            // Finde das Ende des JSON-Arrays
            if let jsonEnd = jsonPart.range(of: "}]") {
                let jsonString = String(jsonPart[...jsonEnd.upperBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let jsonData = jsonString.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                    actions = parsed
                    text = String(content[..<jsonStart.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
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
        let prompt = """
        Erstelle ein Quiz mit \(questionCount) Fragen zum Thema '\(topic)' im Fach \(subject).
        Antworte NUR mit JSON, ohne Erklärungen:
        [{"question": "Frage?", "options": ["A", "B", "C", "D"], "correctIndex": 0}]
        correctIndex ist 0-basiert (0=erste Option). Alle Fragen auf Deutsch.
        """

        let body: [String: Any] = [
            "model": selectedModel,
            "messages": [
                ["role": "system", "content": "Du antwortest NUR mit JSON. Kein Text, keine Erklärungen."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]

        let request = try makeAPIRequest(body: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw AIError.networkError }

        let quizContent = try extractContent(from: data)

        let clean = quizContent.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = clean.data(using: .utf8),
              let questions = try? JSONDecoder().decode([QuizQuestion].self, from: jsonData) else { throw AIError.parseError }

        return questions
    }

    // MARK: - Generate Flashcards (Karteikarten)

    func generateFlashcards(subject: String, topic: String, count: Int = 10) async throws -> [Flashcard] {
        let prompt = """
        Erstelle \(count) Karteikarten zum Thema '\(topic)' im Fach \(subject).
        Antworte NUR mit JSON:
        [{"front": "Frage/Begriff", "back": "Antwort/Erklärung"}]
        Auf Deutsch. Kurze, prägnante Inhalte.
        """

        let body: [String: Any] = [
            "model": selectedModel,
            "messages": [
                ["role": "system", "content": "Du antwortest NUR mit JSON. Kein Text, keine Erklärungen."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]

        let request = try makeAPIRequest(body: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw AIError.networkError }

        let cardContent = try extractContent(from: data)

        let clean = cardContent.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func saveToKeychain(_ value: String, forKey key: String) {
        deleteFromKeychain(forKey: key)
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadFromKeychain(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
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
        case .noAPIKey: return "KI-Service nicht verfügbar. Bitte prüfe deine Internetverbindung."
        case .networkError: return "Netzwerkfehler. Bitte prüfe deine Internetverbindung."
        case .invalidKey: return "Ungültiger API-Key. Bitte überprüfe den Key in den Einstellungen."
        case .apiError(let msg): return "API-Fehler: \(msg)"
        case .parseError: return "Antwort konnte nicht verarbeitet werden. Bitte versuche es erneut."
        }
    }
}
