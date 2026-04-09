import Foundation
import SwiftUI

// MARK: - Topic

struct Topic: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var subject: String?         // optional Schul-Fach
    var iconName: String         // SF Symbol
    var colorHex: String         // hex like "#7C3AED"
    var source: TopicSource
    var createdDate: Date = Date()
    var assignedByParent: Bool = false
    var isDiscover: Bool = false // false = Schul-Topic, true = Discover-Topic
    var pairingCode: String?     // set when synced via CloudKit (parent assignment)

    var color: Color { Color(hivemindHex: colorHex) ?? .purple }
}

// MARK: - TopicSource

enum TopicSource: Codable, Hashable {
    case manual(prompt: String)
    case photoOCR(text: String)
    case pdf(filename: String, text: String)
    case webLink(url: URL, text: String)
    case podcast(url: URL, transcript: String)
    case calendarSuggestion(examId: UUID?)

    var label: String {
        switch self {
        case .manual: return "Manuell"
        case .photoOCR: return "Foto"
        case .pdf: return "PDF"
        case .webLink: return "Link"
        case .podcast: return "Podcast"
        case .calendarSuggestion: return "Aus Kalender"
        }
    }

    var sourceText: String? {
        switch self {
        case .manual(let prompt): return prompt
        case .photoOCR(let text): return text
        case .pdf(_, let text): return text
        case .webLink(_, let text): return text
        case .podcast(_, let transcript): return transcript
        case .calendarSuggestion: return nil
        }
    }
}

// MARK: - TopicProgress

struct TopicProgress: Identifiable, Codable, Hashable {
    var id: UUID                 // == Topic.id
    var postsViewed: Int = 0
    var postsCorrect: Int = 0    // bei Quiz/Karten
    var lastViewedDate: Date?
    var feedGeneratedDate: Date?
    var feedExhausted: Bool = false

    /// Returns 0...1 representing how far through the daily feed the user has progressed.
    func percent(totalPosts: Int) -> Double {
        guard totalPosts > 0 else { return 0 }
        return min(Double(postsViewed) / Double(totalPosts), 1.0)
    }
}

// MARK: - FeedPost

struct FeedPost: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var topicId: UUID
    var orderIndex: Int          // sort order in the feed
    var type: PostType
    var isViewed: Bool = false
    var userAnswer: PostAnswer?
}

// MARK: - PostType

enum PostType: Codable, Hashable {
    case textLesson(title: String, body: String)
    case quizCard(question: String, options: [String], correctIndex: Int, explanation: String)
    case flashcard(front: String, back: String)
    case example(scenario: String, walkthrough: String)
    case feynman(prompt: String, expectedKeywords: [String])

    var typeLabel: String {
        switch self {
        case .textLesson: return "Lektion"
        case .quizCard: return "Quiz"
        case .flashcard: return "Karteikarte"
        case .example: return "Beispiel"
        case .feynman: return "Erkläre es"
        }
    }

    var iconName: String {
        switch self {
        case .textLesson: return "lightbulb.fill"
        case .quizCard: return "questionmark.circle.fill"
        case .flashcard: return "rectangle.on.rectangle"
        case .example: return "wand.and.stars"
        case .feynman: return "mic.fill"
        }
    }
}

// MARK: - PostAnswer

enum PostAnswer: Codable, Hashable {
    case quiz(selectedIndex: Int, correct: Bool)
    case flashcard(known: Bool)
    case feynman(transcript: String, feedback: String, score: Int)
    case viewed
}

// MARK: - Feed Close Gesture Setting

enum FeedCloseGesture: String, CaseIterable, Identifiable {
    case backButton = "Zurück-Button"
    case doubleTapTop = "Doppel-Tap oben"

    var id: String { rawValue }

    private static let key = "hivemindCloseGesture"

    static var current: FeedCloseGesture {
        get {
            let raw = UserDefaults.standard.string(forKey: key) ?? FeedCloseGesture.doubleTapTop.rawValue
            return FeedCloseGesture(rawValue: raw) ?? .doubleTapTop
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}

// MARK: - Color hex helper (used by Topic)

extension Color {
    init?(hivemindHex hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xff) / 255.0
        let g = Double((v >> 8) & 0xff) / 255.0
        let b = Double(v & 0xff) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
