import SwiftUI

// MARK: - Learner Profile

struct LearnerProfile: Codable {
    var totalXP: Int = 0
    var xpPerSubject: [String: Int] = [:]
    var badges: [Badge] = []
    var dailyXPLog: [String: Int] = [:] // "2026-04-03": 120
    var streakDays: Int = 0

    var level: Int { totalXP / 500 + 1 }
    var xpForNextLevel: Int { level * 500 }
    var xpInCurrentLevel: Int { totalXP % 500 }
    var levelProgress: Double { Double(xpInCurrentLevel) / Double(500) }

    var levelTitle: String {
        switch level {
        case 1...3: return "Anfänger"
        case 4...7: return "Fortgeschritten"
        case 8...12: return "Experte"
        case 13...20: return "Meister"
        default: return "Legende"
        }
    }

    func subjectLevel(for subject: String) -> Int {
        (xpPerSubject[subject] ?? 0) / 200 + 1
    }

    func subjectTitle(for subject: String) -> String {
        switch subjectLevel(for: subject) {
        case 1: return "Anfänger"
        case 2: return "Lernend"
        case 3: return "Fortgeschritten"
        case 4...5: return "Experte"
        default: return "Meister"
        }
    }

    mutating func addXP(_ amount: Int, subject: String? = nil) {
        totalXP += amount
        if let subject {
            xpPerSubject[subject, default: 0] += amount
        }
        let today = Self.dateKey(Date())
        dailyXPLog[today, default: 0] += amount
    }

    static func dateKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

// MARK: - Badge

struct Badge: Identifiable, Codable {
    var id: String
    var name: String
    var icon: String
    var description: String
    var earnedDate: Date?

    var isEarned: Bool { earnedDate != nil }

    static let allBadges: [Badge] = [
        Badge(id: "first_quiz", name: "Quiz-Starter", icon: "questionmark.circle.fill", description: "Erstes Quiz abgeschlossen"),
        Badge(id: "first_cards", name: "Karten-Starter", icon: "rectangle.on.rectangle", description: "Erste Karteikarten gelernt"),
        Badge(id: "streak_3", name: "3-Tage-Serie", icon: "flame.fill", description: "3 Tage in Folge gelernt"),
        Badge(id: "streak_7", name: "7-Tage-Serie", icon: "flame.fill", description: "7 Tage in Folge gelernt"),
        Badge(id: "streak_30", name: "Monats-Serie", icon: "flame.fill", description: "30 Tage in Folge gelernt"),
        Badge(id: "xp_100", name: "100 XP", icon: "star.fill", description: "100 XP gesammelt"),
        Badge(id: "xp_500", name: "500 XP", icon: "star.fill", description: "500 XP gesammelt"),
        Badge(id: "xp_1000", name: "1000 XP", icon: "star.circle.fill", description: "1000 XP gesammelt"),
        Badge(id: "quiz_10", name: "Quiz-Profi", icon: "checkmark.circle.fill", description: "10 Quizze abgeschlossen"),
        Badge(id: "cards_100", name: "Karten-Meister", icon: "rectangle.stack.fill", description: "100 Karteikarten gelernt"),
        Badge(id: "perfect_quiz", name: "Perfekt!", icon: "star.fill", description: "Ein Quiz mit 100% abgeschlossen"),
        Badge(id: "all_subjects", name: "Allrounder", icon: "books.vertical.fill", description: "In jedem Fach mindestens 1h gelernt"),
        Badge(id: "ai_chat", name: "KI-Nutzer", icon: "cpu.fill", description: "Erste Frage an die KI gestellt"),
    ]
}

// MARK: - Spaced Repetition Card

struct SpacedCard: Identifiable, Codable {
    var id = UUID()
    var front: String
    var back: String
    var subject: String
    var topic: String

    // Spaced Repetition
    var interval: Int = 1 // Tage bis zur nächsten Wiederholung
    var easeFactor: Double = 2.5
    var nextReviewDate: Date = Date()
    var reviewCount: Int = 0
    var correctCount: Int = 0

    var isDueToday: Bool {
        Calendar.current.startOfDay(for: nextReviewDate) <= Calendar.current.startOfDay(for: Date())
    }

    var masteryLevel: Double {
        guard reviewCount > 0 else { return 0 }
        return min(Double(correctCount) / Double(reviewCount), 1.0)
    }

    mutating func review(known: Bool) {
        reviewCount += 1
        if known {
            correctCount += 1
            if reviewCount == 1 {
                interval = 1
            } else if reviewCount == 2 {
                interval = 3
            } else {
                interval = Int(Double(interval) * easeFactor)
            }
            easeFactor = max(1.3, easeFactor + 0.1)
        } else {
            interval = 1
            easeFactor = max(1.3, easeFactor - 0.2)
        }
        nextReviewDate = Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
    }
}

// MARK: - Daily Challenge

struct DailyChallenge: Identifiable, Codable {
    var id = UUID()
    var title: String
    var description: String
    var xpReward: Int
    var type: ChallengeType
    var isCompleted: Bool = false
    var date: Date = Date()

    enum ChallengeType: String, Codable {
        case studyTime = "Lernzeit"
        case quiz = "Quiz"
        case cards = "Karteikarten"
        case streak = "Serie"
    }
}
