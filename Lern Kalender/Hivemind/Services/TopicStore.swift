import Foundation
import SwiftUI

@Observable
final class TopicStore {
    static let shared = TopicStore()

    var topics: [Topic] = []
    var progress: [UUID: TopicProgress] = [:]

    private let topicsKey = "hivemind.topics"
    private let progressKey = "hivemind.progress"

    private init() {
        load()
    }

    // MARK: - CRUD

    @discardableResult
    func addTopic(_ topic: Topic) -> Topic {
        topics.append(topic)
        progress[topic.id] = TopicProgress(id: topic.id)
        save()
        return topic
    }

    func deleteTopic(id: UUID) {
        topics.removeAll { $0.id == id }
        progress[id] = nil
        FeedGenerator.deletePosts(for: id)
        save()
    }

    func topic(id: UUID) -> Topic? { topics.first { $0.id == id } }

    var schoolTopics: [Topic] { topics.filter { !$0.isDiscover } }
    var discoverTopics: [Topic] { topics.filter { $0.isDiscover } }

    // MARK: - Progress

    func progress(for topicId: UUID) -> TopicProgress {
        progress[topicId] ?? TopicProgress(id: topicId)
    }

    func markFeedGenerated(topicId: UUID) {
        var p = progress[topicId] ?? TopicProgress(id: topicId)
        p.feedGeneratedDate = Date()
        p.feedExhausted = false
        progress[topicId] = p
        save()
    }

    func markFeedExhausted(topicId: UUID) {
        var p = progress[topicId] ?? TopicProgress(id: topicId)
        p.feedExhausted = true
        progress[topicId] = p
        save()
    }

    /// Records a user answer on a feed post and bridges relevant scoring to LearningEngine.
    func recordAnswer(post: FeedPost, answer: PostAnswer) {
        var p = progress[post.topicId] ?? TopicProgress(id: post.topicId)
        if !post.isViewed {
            p.postsViewed += 1
        }
        p.lastViewedDate = Date()

        // Update the persisted post with the answer.
        var updated = post
        updated.isViewed = true
        updated.userAnswer = answer
        FeedGenerator.updatePost(updated)

        // Bridge to LearningEngine.
        let topic = self.topic(id: post.topicId)
        let subject = topic?.subject

        switch answer {
        case .quiz(_, let correct):
            if correct { p.postsCorrect += 1 }
            LearningEngine.shared.recordQuiz(score: correct ? 1 : 0, total: 1, subject: subject ?? "Allgemein")
        case .flashcard(let known):
            if known { p.postsCorrect += 1 }
            // Also feed it into the spaced repetition system.
            if case let .flashcard(front, back) = post.type {
                let card = Flashcard(front: front, back: back)
                LearningEngine.shared.addCards([card], subject: subject ?? "Allgemein", topic: topic?.title ?? "")
            }
            if known {
                LearningEngine.shared.earnXP(LearningEngine.shared.xpForCardKnown(), subject: subject)
            }
        case .feynman(_, _, let score):
            // Score is 0…100; award XP proportionally up to 30.
            let xp = Int(Double(score) / 100.0 * 30)
            LearningEngine.shared.earnXP(xp, subject: subject)
            if score >= 60 { p.postsCorrect += 1 }
        case .viewed:
            // Lessons and examples just give a small XP bump for finishing them.
            LearningEngine.shared.earnXP(2, subject: subject)
        }

        progress[post.topicId] = p
        save()
    }

    // MARK: - Persistence (UserDefaults — CloudKit overlay added in CloudKitService)

    private func save() {
        let ud = UserDefaults.standard
        if let data = try? JSONEncoder().encode(topics) {
            ud.set(data, forKey: topicsKey)
        }
        if let data = try? JSONEncoder().encode(Array(progress.values)) {
            ud.set(data, forKey: progressKey)
        }

        // Best-effort CloudKit push for parent visibility — fire-and-forget.
        Task { await CloudKitService.shared.pushTopics(topics, progress: progress) }
    }

    private func load() {
        let ud = UserDefaults.standard
        if let data = ud.data(forKey: topicsKey),
           let decoded = try? JSONDecoder().decode([Topic].self, from: data) {
            topics = decoded
        }
        if let data = ud.data(forKey: progressKey),
           let decodedArray = try? JSONDecoder().decode([TopicProgress].self, from: data) {
            progress = Dictionary(uniqueKeysWithValues: decodedArray.map { ($0.id, $0) })
        }
    }

    // MARK: - CloudKit pull (called from ContentView.onAppear)

    func mergeRemote(topics remote: [Topic], progress remoteProgress: [TopicProgress]) {
        // Add any remote topics not yet local (e.g., parent-assigned topics).
        for r in remote where !topics.contains(where: { $0.id == r.id }) {
            topics.append(r)
        }
        // Overwrite progress with the more recently updated record per id.
        for rp in remoteProgress {
            let local = progress[rp.id]
            if local == nil ||
               (local?.lastViewedDate ?? .distantPast) < (rp.lastViewedDate ?? .distantPast) {
                progress[rp.id] = rp
            }
        }
        save()
    }
}
