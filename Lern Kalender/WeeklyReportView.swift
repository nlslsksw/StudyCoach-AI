import SwiftUI

struct WeeklyReportView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore
    private let cloudKit = CloudKitService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Wochenbericht")
                        .font(.largeTitle.bold())
                        .padding(.top)

                    Text(weekRangeString())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if store.familyLinks.isEmpty {
                        Text("Keine Kinder verbunden")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 40)
                    } else {
                        ForEach(store.familyLinks) { link in
                            childReportCard(link: link)
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func childReportCard(link: FamilyLink) -> some View {
        let data = cloudKit.remoteData[link.pairingCode]
        let sessions = data?.sessions ?? []
        let grades = data?.grades ?? []

        let cal = Calendar.current
        let now = Date()
        let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let lastWeekStart = cal.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? now

        let thisWeekSessions = sessions.filter { $0.date >= weekStart }
        let lastWeekSessions = sessions.filter { $0.date >= lastWeekStart && $0.date < weekStart }
        let thisWeekMinutes = thisWeekSessions.reduce(0) { $0 + $1.minutes }
        let lastWeekMinutes = lastWeekSessions.reduce(0) { $0 + $1.minutes }

        let thisWeekGrades = grades.filter { $0.date >= weekStart }

        let percentChange: Int? = lastWeekMinutes > 0
            ? Int(((Double(thisWeekMinutes) / Double(lastWeekMinutes)) - 1.0) * 100)
            : nil

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.blue, in: Circle())
                Text(link.childName.isEmpty ? "Kind" : link.childName)
                    .font(.title3.bold())
                Spacer()
            }

            Divider()

            HStack {
                Label("Gesamtlernzeit", systemImage: "clock.fill")
                    .font(.subheadline)
                Spacer()
                Text(formatHoursMinutes(thisWeekMinutes))
                    .font(.subheadline.bold())
            }

            if let pct = percentChange {
                HStack {
                    Label("Vs. letzte Woche", systemImage: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                        .foregroundStyle(pct >= 0 ? .green : .orange)
                    Spacer()
                    Text("\(pct >= 0 ? "+" : "")\(pct)%")
                        .font(.caption.bold())
                        .foregroundStyle(pct >= 0 ? .green : .orange)
                }
            }

            let bySubject = Dictionary(grouping: thisWeekSessions, by: \.subject)
            if !bySubject.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pro Fach").font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach(bySubject.keys.sorted(), id: \.self) { subject in
                        let mins = bySubject[subject]?.reduce(0) { $0 + $1.minutes } ?? 0
                        HStack {
                            Text(subject).font(.caption)
                            Spacer()
                            Text(formatHoursMinutes(mins)).font(.caption.monospacedDigit())
                        }
                    }
                }
            }

            if !thisWeekGrades.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Neue Noten").font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach(thisWeekGrades) { grade in
                        HStack {
                            Text(grade.subject).font(.caption)
                            Spacer()
                            Text(gradeString(grade.grade))
                                .font(.caption.bold())
                                .foregroundStyle(gradeColor(grade.grade))
                        }
                    }
                }
            }

            if let goal = store.studyGoals[link.pairingCode], goal.weeklyMinutesGoal > 0 {
                let progress = Double(thisWeekMinutes) / Double(goal.weeklyMinutesGoal)
                HStack {
                    Label("Wochenziel", systemImage: "target")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(min(progress, 1.0) * 100))%")
                        .font(.caption.bold())
                        .foregroundStyle(progress >= 1.0 ? .green : .blue)
                }
            }

            if let streak = data?.currentStreak, streak > 0 {
                HStack {
                    Label("Serie", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("\(streak) Tage")
                        .font(.caption.bold())
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func weekRangeString() -> String {
        let cal = Calendar.current
        let now = Date()
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start,
              let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) else {
            return ""
        }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        fmt.dateFormat = "d. MMM"
        return "\(fmt.string(from: weekStart)) - \(fmt.string(from: weekEnd))"
    }
}
