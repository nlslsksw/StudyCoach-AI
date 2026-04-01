import Foundation
import Security

@Observable
final class GeminiService {
    static let shared = GeminiService()

    var isGenerating = false
    var error: String?

    private let keychainKey = "geminiAPIKey"

    private init() {}

    // MARK: - API Key Management

    var apiKey: String? {
        get { loadFromKeychain() }
        set {
            if let key = newValue {
                saveToKeychain(key)
            } else {
                deleteFromKeychain()
            }
        }
    }

    var hasAPIKey: Bool { apiKey != nil && !(apiKey?.isEmpty ?? true) }

    // MARK: - Generate Study Plan

    func generateStudyPlan(text: String, subject: String, examDate: Date) async throws -> [StudyPlanDay] {
        guard let key = apiKey, !key.isEmpty else {
            throw GeminiError.noAPIKey
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

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(key)")!

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            if httpResponse.statusCode == 400 {
                throw GeminiError.invalidKey
            }
            throw GeminiError.apiError("Status \(httpResponse.statusCode): \(errorBody)")
        }

        // Parse Gemini response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let responseText = parts.first?["text"] as? String else {
            throw GeminiError.parseError
        }

        // Clean response text (remove markdown code blocks if present)
        var cleanText = responseText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleanText.data(using: .utf8),
              let days = try? JSONDecoder().decode([StudyPlanDay].self, from: jsonData) else {
            throw GeminiError.parseError
        }

        return days
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

// MARK: - Models

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

enum GeminiError: LocalizedError {
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
        case .parseError: return "Lernplan konnte nicht verarbeitet werden. Bitte versuche es erneut."
        }
    }
}
