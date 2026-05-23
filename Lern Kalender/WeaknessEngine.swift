import Foundation
import SwiftUI

// MARK: - Adaptive Schwachstellen-Engine
//
// Sammelt aus mehreren Quellen, welche Themen einem Schüler schwer
// fallen, und schlägt vor Klausuren gezielt Übungen dazu vor.
//
// Datenquellen:
// - Quiz-Ergebnisse (LearningEngine.recordQuiz mit Topic)
// - Karteikarten-Reviews (LearningEngine.reviewCard via SpacedCard.topic)
// - Noten (DataStore.addGrade pro Fach, ohne Topic)
//
// Score pro (Fach, Thema): 0…1, Exponential Moving Average (alpha 0.3).
// 1.0 = sehr stark, 0.0 = sehr schwach.

struct WeaknessEntry: Codable, Identifiable {
    var id: String { "\(subject)|\(topic)" }
    var subject: String
    var topic: String
    var score: Double  // 0...1
    var sampleCount: Int
    var lastUpdated: Date

    var weaknessPercent: Int { Int((1 - score) * 100) }
}

@MainActor
@Observable
final class WeaknessEngine {
    static let shared = WeaknessEngine()

    private let key = "weaknessEntries"
    private var entries: [String: WeaknessEntry] = [:]

    private init() { load() }

    // MARK: – Public API

    /// Trägt ein neues Stichproben-Ergebnis (0…1) ein und updated den EMA.
    func record(subject: String, topic: String, correct: Double) {
        let id = "\(subject)|\(topic)"
        let clamped = max(0, min(1, correct))
        if var existing = entries[id] {
            // EMA mit alpha=0.3 — neue Stichproben wirken sich spürbar aus,
            // alte Stichproben verblassen aber nicht zu schnell.
            existing.score = existing.score * 0.7 + clamped * 0.3
            existing.sampleCount += 1
            existing.lastUpdated = Date()
            entries[id] = existing
        } else {
            entries[id] = WeaknessEntry(
                subject: subject, topic: topic,
                score: clamped, sampleCount: 1,
                lastUpdated: Date()
            )
        }
        save()
    }

    /// Quiz: 0/total = 0.0, total/total = 1.0
    func recordQuiz(score: Int, total: Int, subject: String, topic: String) {
        guard total > 0, !topic.isEmpty else { return }
        let ratio = Double(score) / Double(total)
        record(subject: subject, topic: topic, correct: ratio)
    }

    /// Karteikarte: bekannt = 1.0, nicht bekannt = 0.0
    func recordCardReview(subject: String, topic: String, known: Bool) {
        guard !topic.isEmpty else { return }
        record(subject: subject, topic: topic, correct: known ? 1.0 : 0.0)
    }

    /// Schul-Note (1–6) wird in einen 0…1 Score umgerechnet (1 = 1.0,
    /// 6 = 0.0). Beeinflusst alle Themen des Fachs gleichermaßen leicht.
    func recordGrade(_ grade: Double, subject: String) {
        let normalized = max(0, min(1, (6.0 - grade) / 5.0))
        // Alle bisherigen Themen des Fachs leicht zur Note ziehen — schwächer
        // gewichtet (alpha 0.15), damit eine einzelne Note keine Topic-Daten
        // überschreibt.
        for (id, entry) in entries where entry.subject == subject {
            var updated = entry
            updated.score = updated.score * 0.85 + normalized * 0.15
            updated.lastUpdated = Date()
            entries[id] = updated
        }
        save()
    }

    // MARK: – Queries

    /// Alle Einträge eines Fachs, schwächste zuerst.
    func weaknesses(forSubject subject: String) -> [WeaknessEntry] {
        entries.values
            .filter { $0.subject.localizedCaseInsensitiveCompare(subject) == .orderedSame }
            .sorted { $0.score < $1.score }
    }

    /// Schwächen über alle Fächer, schwächste zuerst.
    func allWeaknesses(maxScore: Double = 0.7, limit: Int = 10) -> [WeaknessEntry] {
        entries.values
            .filter { $0.score <= maxScore && $0.sampleCount >= 2 }
            .sorted { $0.score < $1.score }
            .prefix(limit)
            .map { $0 }
    }

    /// Bei welchen Fächern stehen in den nächsten N Tagen Klausuren an?
    func upcomingExamSubjects(in store: DataStore, withinDays days: Int = 14) -> [String] {
        let cal = Calendar.current
        let now = Date()
        let until = cal.date(byAdding: .day, value: days, to: now) ?? now
        let upcoming = store.entries.filter {
            $0.type == .klassenarbeit && $0.date >= now && $0.date <= until
        }
        var set = Set<String>()
        for e in upcoming { set.insert(e.title) }
        return Array(set)
    }

    /// Empfehlungs-Pakete vor Klausuren: pro fach mit anstehender Klausur
    /// die 5 schwächsten Themen.
    struct ExamRecommendation: Identifiable {
        let id = UUID()
        let subject: String
        let examDate: Date
        let weakTopics: [WeaknessEntry]
    }

    func examRecommendations(from store: DataStore, withinDays days: Int = 14) -> [ExamRecommendation] {
        let cal = Calendar.current
        let now = Date()
        let until = cal.date(byAdding: .day, value: days, to: now) ?? now
        let upcoming = store.entries.filter {
            $0.type == .klassenarbeit && $0.date >= now && $0.date <= until
        }
        var byTitle: [String: Date] = [:]
        for e in upcoming {
            if byTitle[e.title] == nil || (byTitle[e.title] ?? Date.distantFuture) > e.date {
                byTitle[e.title] = e.date
            }
        }
        return byTitle.map { (subject, examDate) in
            let weak = weaknesses(forSubject: subject)
                .filter { $0.score < 0.8 }
                .prefix(5)
            return ExamRecommendation(subject: subject, examDate: examDate, weakTopics: Array(weak))
        }
        .sorted { $0.examDate < $1.examDate }
    }

    // MARK: – Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([WeaknessEntry].self, from: data) else { return }
        entries = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }

    private func save() {
        let list = Array(entries.values)
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Für Tests / Debug.
    func reset() {
        entries.removeAll()
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - UI: Today-Card vor Klausuren

struct WeaknessExamCard: View {
    var store: DataStore
    @State private var recommendations: [WeaknessEngine.ExamRecommendation] = []

    var body: some View {
        Group {
            if !recommendations.isEmpty {
                VStack(spacing: 10) {
                    ForEach(recommendations) { rec in
                        recCard(rec)
                    }
                }
            }
        }
        .onAppear { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .weaknessUpdated)) { _ in
            reload()
        }
    }

    private func reload() {
        recommendations = WeaknessEngine.shared.examRecommendations(from: store)
            .filter { !$0.weakTopics.isEmpty }
    }

    private func recCard(_ rec: WeaknessEngine.ExamRecommendation) -> some View {
        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: rec.examDate).day ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        LinearGradient(colors: [.red, .orange],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text("Klausur: \(rec.subject)")
                        .font(.subheadline.bold())
                    Text(daysUntil == 0 ? "Heute" : (daysUntil == 1 ? "Morgen" : "in \(daysUntil) Tagen"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(rec.weakTopics.count) schwach")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.12), in: Capsule())
            }
            VStack(spacing: 0) {
                ForEach(rec.weakTopics) { topic in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(scoreColor(topic.score))
                            .frame(width: 7, height: 7)
                        Text(topic.topic)
                            .font(.caption)
                        Spacer()
                        Text("\(topic.weaknessPercent)%")
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(scoreColor(topic.score))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(12)
        .background(
            ZStack {
                LinearGradient(colors: [.red.opacity(0.08), .orange.opacity(0.04)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(.red.opacity(0.18), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        )
    }

    private func scoreColor(_ s: Double) -> Color {
        switch s {
        case ..<0.3: return .red
        case ..<0.6: return .orange
        default: return .yellow
        }
    }
}

// MARK: - UI: Schwachstellen-Section im Fach-Detail

struct WeaknessSubjectSection: View {
    let subject: String
    @State private var items: [WeaknessEntry] = []

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "scope")
                        .foregroundStyle(.orange)
                    Text("Deine Schwachstellen")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal)

                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, entry in
                        HStack(spacing: 10) {
                            Text(entry.topic)
                                .font(.subheadline)
                            Spacer()
                            ProgressView(value: entry.score)
                                .tint(scoreColor(entry.score))
                                .frame(width: 80)
                            Text("\(Int(entry.score * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 36, alignment: .trailing)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        if idx < items.count - 1 {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                )
                .padding(.horizontal)
            }
            .onAppear { reload() }
            .onReceive(NotificationCenter.default.publisher(for: .weaknessUpdated)) { _ in
                reload()
            }
        }
    }

    private func reload() {
        items = WeaknessEngine.shared.weaknesses(forSubject: subject).prefix(8).map { $0 }
    }

    private func scoreColor(_ s: Double) -> Color {
        switch s {
        case ..<0.3: return .red
        case ..<0.6: return .orange
        case ..<0.8: return .yellow
        default: return .green
        }
    }
}

extension Notification.Name {
    static let weaknessUpdated = Notification.Name("weaknessUpdated")
}
