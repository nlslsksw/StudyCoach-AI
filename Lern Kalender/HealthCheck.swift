import Foundation
import SwiftUI

// MARK: - Lern-Health-Check
//
// Sonntags wird einmal pro Woche eine KI-generierte Wochen-Zusammenfassung
// erstellt. Sie wird lokal gespeichert und im Today-Tab als Card angezeigt.
// Die KI bekommt deine Lernzeit-Statistik der Woche + Notenstand als
// Kontext und schreibt 2-3 Sätze Feedback + 1 konkreten Tipp.

struct HealthCheckReport: Codable, Identifiable {
    var id = UUID()
    var weekStart: Date
    var weekEnd: Date
    var summary: String
    var generatedAt: Date = Date()
}

@MainActor
@Observable
final class HealthCheckStore {
    static let shared = HealthCheckStore()

    private let key = "healthCheckLatest"
    var latest: HealthCheckReport?
    var isGenerating: Bool = false

    private init() { load() }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        latest = try? JSONDecoder().decode(HealthCheckReport.self, from: data)
    }

    private func save() {
        guard let latest else { return }
        if let data = try? JSONEncoder().encode(latest) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Generiert wöchentlich am Sonntag (oder manuell). Wirft, wenn die KI
    /// nicht verfügbar ist (kein API-Key, kein Netz).
    func generateWeeklyReport(from store: DataStore, force: Bool = false) async throws {
        if !force, let last = latest, isSameWeek(last.weekStart, Date()) {
            return  // schon für diese Woche generiert
        }
        guard AIService.shared.hasAPIKey else {
            throw NSError(domain: "HealthCheck", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Bitte erst KI-Setup abschließen."])
        }
        isGenerating = true
        defer { isGenerating = false }

        let context = buildContext(from: store)
        let prompt = """
        Du bist ein freundlicher Lern-Coach. Schreibe in 2-3 kurzen Sätzen
        eine motivierende Wochen-Zusammenfassung für einen Schüler, plus
        einen konkreten Tipp für die nächste Woche. Sprich den Schüler
        mit "du" an. Vermeide Floskeln. Maximal 350 Zeichen insgesamt.

        Wochen-Daten:
        \(context)
        """

        let summary = try await AIService.shared.askQuestion(prompt)
        let (start, end) = currentWeekRange()
        latest = HealthCheckReport(
            weekStart: start,
            weekEnd: end,
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        save()
    }

    /// Bauet einen kompakten Lernkontext der letzten 7 Tage zusammen.
    private func buildContext(from store: DataStore) -> String {
        let (start, end) = currentWeekRange()
        let cal = Calendar.current
        let sessions = store.studySessions.filter { $0.date >= start && $0.date <= end }
        let totalMin = sessions.reduce(0) { $0 + $1.minutes }
        let daysActive = Set(sessions.map { cal.startOfDay(for: $0.date) }).count
        let bySubject = Dictionary(grouping: sessions, by: \.subject)
            .mapValues { $0.reduce(0) { $0 + $1.minutes } }
            .sorted { $0.value > $1.value }
            .map { "\($0.key): \($0.value) min" }
            .joined(separator: ", ")

        let weekKlausuren = store.entries.filter {
            $0.type == .klassenarbeit && $0.date >= start && $0.date <= end
        }
        let upcomingExams = store.entries.filter {
            $0.type == .klassenarbeit && $0.date > end &&
            $0.date <= cal.date(byAdding: .day, value: 14, to: end)!
        }
        let lastGrades = store.grades.filter { $0.date >= start && $0.date <= end }
            .map { "\($0.subject) \(gradeString($0.grade))" }
            .joined(separator: ", ")

        let streak = store.currentStreak()
        let goal = store.studyGoal?.weeklyMinutesGoal ?? 0

        var lines: [String] = []
        lines.append("Gesamte Lernzeit: \(totalMin) min an \(daysActive) Tagen")
        lines.append("Aktuelle Streak: \(streak) Tage")
        if !bySubject.isEmpty { lines.append("Pro Fach: \(bySubject)") }
        if goal > 0 { lines.append("Wochenziel: \(goal) min (\(totalMin >= goal ? "erreicht" : "verfehlt"))") }
        if !lastGrades.isEmpty { lines.append("Neue Noten: \(lastGrades)") }
        if !weekKlausuren.isEmpty {
            lines.append("Klausuren diese Woche: \(weekKlausuren.map(\.title).joined(separator: ", "))")
        }
        if !upcomingExams.isEmpty {
            lines.append("Klausuren in 2 Wochen: \(upcomingExams.map(\.title).joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }

    private func currentWeekRange() -> (Date, Date) {
        let cal = Calendar(identifier: .iso8601)
        let now = Date()
        let interval = cal.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, duration: 0)
        let end = cal.date(byAdding: .day, value: 6, to: interval.start) ?? now
        return (interval.start, end)
    }

    private func isSameWeek(_ a: Date, _ b: Date) -> Bool {
        let cal = Calendar(identifier: .iso8601)
        let ca = cal.component(.weekOfYear, from: a)
        let cb = cal.component(.weekOfYear, from: b)
        let ya = cal.component(.yearForWeekOfYear, from: a)
        let yb = cal.component(.yearForWeekOfYear, from: b)
        return ca == cb && ya == yb
    }
}

// MARK: - Health Check Card (für TodayTab)

struct HealthCheckCard: View {
    var store: DataStore
    @Bindable private var checker = HealthCheckStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        LinearGradient(colors: [.purple, .pink],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
                Text("Dein Lern-Check")
                    .font(.subheadline.bold())
                Spacer()
                if checker.isGenerating {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Button {
                        Task {
                            try? await checker.generateWeeklyReport(from: store, force: true)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let report = checker.latest {
                Text(report.summary)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Woche \(weekLabel(report.weekStart))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Tippe ↻, um deinen ersten Wochen-Check zu generieren.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                LinearGradient(colors: [.purple.opacity(0.10), .pink.opacity(0.05)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(.purple.opacity(0.15), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        )
    }

    private func weekLabel(_ date: Date) -> String {
        let cal = Calendar(identifier: .iso8601)
        return "KW \(cal.component(.weekOfYear, from: date))"
    }
}
