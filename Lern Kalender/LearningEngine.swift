import Foundation

// MARK: - Learning Engine

@Observable
final class LearningEngine {
    static let shared = LearningEngine()

    var profile = LearnerProfile()
    var spacedCards: [SpacedCard] = []
    var dailyChallenges: [DailyChallenge] = []
    var quizStats: (total: Int, perfect: Int) = (0, 0)

    private let profileKey = "learnerProfile"
    private let cardsKey = "spacedCards"
    private let challengesKey = "dailyChallenges"
    private let quizStatsKey = "quizStats"

    private init() {
        load()
    }

    // MARK: - XP System

    func earnXP(_ amount: Int, subject: String? = nil, reason: String = "") {
        profile.addXP(amount, subject: subject)
        checkBadges()
        save()
    }

    func xpForStudyTime(minutes: Int) -> Int { max(minutes, 1) }
    func xpForQuizCorrect() -> Int { 10 }
    func xpForCardKnown() -> Int { 5 }
    func xpForStreak(days: Int) -> Int { days * 10 }

    // MARK: - Spaced Repetition

    var cardsDueToday: [SpacedCard] {
        spacedCards.filter(\.isDueToday)
    }

    func addCards(_ cards: [Flashcard], subject: String, topic: String) {
        for card in cards {
            let spacedCard = SpacedCard(
                front: card.front,
                back: card.back,
                subject: subject,
                topic: topic
            )
            spacedCards.append(spacedCard)
        }
        save()
    }

    func reviewCard(id: UUID, known: Bool) {
        guard let idx = spacedCards.firstIndex(where: { $0.id == id }) else { return }
        spacedCards[idx].review(known: known)
        if known {
            earnXP(xpForCardKnown(), subject: spacedCards[idx].subject)
        }
        save()
    }

    func masteryForSubject(_ subject: String) -> Double {
        let subjectCards = spacedCards.filter { $0.subject == subject }
        guard !subjectCards.isEmpty else { return 0 }
        return subjectCards.map(\.masteryLevel).reduce(0, +) / Double(subjectCards.count)
    }

    func masteryForTopic(_ topic: String) -> Double {
        let topicCards = spacedCards.filter { $0.topic == topic }
        guard !topicCards.isEmpty else { return 0 }
        return topicCards.map(\.masteryLevel).reduce(0, +) / Double(topicCards.count)
    }

    // MARK: - Quiz Tracking

    func recordQuiz(score: Int, total: Int, subject: String) {
        quizStats.total += 1
        if score == total { quizStats.perfect += 1 }
        let xp = score * xpForQuizCorrect()
        earnXP(xp, subject: subject)

        if score == total { earnBadge("perfect_quiz") }
        if quizStats.total == 1 { earnBadge("first_quiz") }
        if quizStats.total >= 10 { earnBadge("quiz_10") }

        // Quiz-Challenge abhaken
        for i in dailyChallenges.indices {
            if dailyChallenges[i].type == .quiz && !dailyChallenges[i].isCompleted {
                dailyChallenges[i].isCompleted = true
                earnXP(dailyChallenges[i].xpReward)
                break
            }
        }
        save()
    }

    // MARK: - Daily Challenges

    func generateDailyChallenges(subjects: [String]) {
        let today = LearnerProfile.dateKey(Date())
        if let first = dailyChallenges.first, LearnerProfile.dateKey(first.date) == today { return }

        var challenges: [DailyChallenge] = []

        // Lernzeit-Challenge basierend auf Level
        let targetMinutes = min(15 + profile.level * 5, 60)
        challenges.append(DailyChallenge(
            title: "Lerne \(targetMinutes) Minuten",
            description: "Sammle heute \(targetMinutes) Minuten Lernzeit",
            xpReward: 30 + profile.level * 5,
            type: .studyTime
        ))

        // Karteikarten-Challenge
        let due = cardsDueToday.count
        if due > 0 {
            challenges.append(DailyChallenge(
                title: "\(due) Karten wiederholen",
                description: "Du hast fällige Karteikarten — lerne sie!",
                xpReward: due * 3,
                type: .cards
            ))
        }

        // Schwächstes Fach als Quiz-Challenge
        if !subjects.isEmpty {
            let weakest = subjects.min { a, b in
                (profile.xpPerSubject[a] ?? 0) < (profile.xpPerSubject[b] ?? 0)
            }
            if let subject = weakest {
                challenges.append(DailyChallenge(
                    title: "Quiz: \(subject)",
                    description: "Dein schwächstes Fach — trainiere es!",
                    xpReward: 40,
                    type: .quiz
                ))
            }
        }

        // Serie-Challenge
        if profile.streakDays > 0 {
            challenges.append(DailyChallenge(
                title: "Serie halten: \(profile.streakDays + 1) Tage",
                description: "Lerne heute um deine Serie fortzusetzen!",
                xpReward: profile.streakDays * 5,
                type: .streak
            ))
        }

        dailyChallenges = challenges
        save()
    }

    func completeChallenge(_ challenge: DailyChallenge) {
        guard let idx = dailyChallenges.firstIndex(where: { $0.id == challenge.id }) else { return }
        guard !dailyChallenges[idx].isCompleted else { return }
        dailyChallenges[idx].isCompleted = true
        earnXP(challenge.xpReward)
        save()
    }

    func checkChallenges(store: DataStore) {
        let todayMinutes = store.dayStudyMinutes(on: Date())

        for i in dailyChallenges.indices {
            guard !dailyChallenges[i].isCompleted else { continue }

            switch dailyChallenges[i].type {
            case .studyTime:
                // Prüfe ob genug Minuten gelernt
                let target = Int(dailyChallenges[i].title.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 30
                if todayMinutes >= target {
                    dailyChallenges[i].isCompleted = true
                    earnXP(dailyChallenges[i].xpReward)
                }
            case .streak:
                if store.currentStreak() > 0 {
                    dailyChallenges[i].isCompleted = true
                    earnXP(dailyChallenges[i].xpReward)
                }
            case .cards:
                let due = cardsDueToday.count
                if due == 0 && spacedCards.contains(where: { $0.reviewCount > 0 }) {
                    dailyChallenges[i].isCompleted = true
                    earnXP(dailyChallenges[i].xpReward)
                }
            case .quiz:
                // Wird manuell durch recordQuiz abgehakt
                break
            }
        }
        save()
    }

    // MARK: - Badges

    private func checkBadges() {
        if profile.totalXP >= 100 { earnBadge("xp_100") }
        if profile.totalXP >= 500 { earnBadge("xp_500") }
        if profile.totalXP >= 1000 { earnBadge("xp_1000") }
        if profile.streakDays >= 3 { earnBadge("streak_3") }
        if profile.streakDays >= 7 { earnBadge("streak_7") }
        if profile.streakDays >= 30 { earnBadge("streak_30") }

        let totalCards = spacedCards.filter { $0.reviewCount > 0 }.count
        if totalCards >= 100 { earnBadge("cards_100") }
        if totalCards >= 1 { earnBadge("first_cards") }
    }

    func earnBadge(_ badgeId: String) {
        if profile.badges.contains(where: { $0.id == badgeId }) { return }
        if var badge = Badge.allBadges.first(where: { $0.id == badgeId }) {
            badge.earnedDate = Date()
            profile.badges.append(badge)
            save()
        }
    }

    // MARK: - KI Integration

    func learningContext() -> String {
        var parts: [String] = []
        parts.append("Schüler-Level: \(profile.level) (\(profile.levelTitle))")
        parts.append("Gesamt-XP: \(profile.totalXP)")
        parts.append("Lernserie: \(profile.streakDays) Tage")

        if !profile.xpPerSubject.isEmpty {
            let subjectLevels = profile.xpPerSubject.map { "\($0.key): Level \(profile.subjectLevel(for: $0.key))" }
            parts.append("Fach-Level: \(subjectLevels.joined(separator: ", "))")
        }

        let due = cardsDueToday.count
        if due > 0 { parts.append("Fällige Karteikarten: \(due)") }

        let incompleteChallenges = dailyChallenges.filter { !$0.isCompleted }
        if !incompleteChallenges.isEmpty {
            parts.append("Offene Challenges: \(incompleteChallenges.map(\.title).joined(separator: ", "))")
        }

        return parts.joined(separator: "\n")
    }

    // MARK: - Persistence

    private func load() {
        let ud = UserDefaults.standard
        if let data = ud.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(LearnerProfile.self, from: data) {
            profile = decoded
        }
        if let data = ud.data(forKey: cardsKey),
           let decoded = try? JSONDecoder().decode([SpacedCard].self, from: data) {
            spacedCards = decoded
        }
        if let data = ud.data(forKey: challengesKey),
           let decoded = try? JSONDecoder().decode([DailyChallenge].self, from: data) {
            dailyChallenges = decoded
        }
        if let total = ud.object(forKey: "quizStatsTotal") as? Int,
           let perfect = ud.object(forKey: "quizStatsPerfect") as? Int {
            quizStats = (total, perfect)
        }

        // One-time migration: drop legacy learningPaths data (Hivemind replaces them)
        if ud.object(forKey: "learningPaths") != nil {
            ud.removeObject(forKey: "learningPaths")
        }
    }

    func save() {
        let ud = UserDefaults.standard
        if let data = try? JSONEncoder().encode(profile) { ud.set(data, forKey: profileKey) }
        if let data = try? JSONEncoder().encode(spacedCards) { ud.set(data, forKey: cardsKey) }
        if let data = try? JSONEncoder().encode(dailyChallenges) { ud.set(data, forKey: challengesKey) }
        ud.set(quizStats.total, forKey: "quizStatsTotal")
        ud.set(quizStats.perfect, forKey: "quizStatsPerfect")
    }
}
