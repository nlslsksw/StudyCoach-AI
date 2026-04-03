import SwiftUI
import Charts

// MARK: - Week Comparison View

struct WeekComparisonView: View {
    var store: DataStore

    private var currentWeekMinutes: Int { store.weeklyTotalMinutes(weekOffset: 0) }
    private var lastWeekMinutes: Int { store.weeklyTotalMinutes(weekOffset: -1) }

    private var changePercent: Int? {
        guard lastWeekMinutes > 0 else { return nil }
        return Int(((Double(currentWeekMinutes) - Double(lastWeekMinutes)) / Double(lastWeekMinutes)) * 100)
    }

    private var dailyComparison: [(day: String, thisWeek: Int, lastWeek: Int)] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EE"

        let now = Date()
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }

        var result: [(day: String, thisWeek: Int, lastWeek: Int)] = []
        for i in 0..<7 {
            guard let thisDay = cal.date(byAdding: .day, value: i, to: weekStart),
                  let lastDay = cal.date(byAdding: .weekOfYear, value: -1, to: thisDay) else { continue }

            let thisDayEnd = cal.date(byAdding: .day, value: 1, to: thisDay) ?? thisDay
            let lastDayEnd = cal.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay

            let thisMin = store.totalMinutes(in: store.sessionsInRange(from: thisDay, to: thisDayEnd))
            let lastMin = store.totalMinutes(in: store.sessionsInRange(from: lastDay, to: lastDayEnd))

            result.append((day: formatter.string(from: thisDay), thisWeek: thisMin, lastWeek: lastMin))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wochenvergleich")
                .font(.headline)

            // Vergleichskarten
            HStack(spacing: 12) {
                ComparisonCard(
                    title: "Diese Woche",
                    value: formatHoursMinutes(currentWeekMinutes),
                    color: .blue
                )
                ComparisonCard(
                    title: "Letzte Woche",
                    value: formatHoursMinutes(lastWeekMinutes),
                    color: .secondary
                )
            }

            if let change = changePercent {
                HStack(spacing: 4) {
                    Image(systemName: change > 0 ? "arrow.up.right" : change < 0 ? "arrow.down.right" : "arrow.right")
                        .font(.caption2.bold())
                    Text(change > 0 ? "+\(change)% mehr gelernt" : change < 0 ? "\(change)% weniger gelernt" : "Gleich viel gelernt")
                        .font(.caption)
                }
                .foregroundStyle(change > 0 ? .green : change < 0 ? .red : .secondary)
            }

            // Tagesvergleich-Chart
            if !dailyComparison.allSatisfy({ $0.thisWeek == 0 && $0.lastWeek == 0 }) {
                Chart {
                    ForEach(dailyComparison, id: \.day) { item in
                        BarMark(
                            x: .value("Tag", item.day),
                            y: .value("Minuten", item.thisWeek)
                        )
                        .foregroundStyle(by: .value("Woche", "Diese Woche"))
                        .position(by: .value("Woche", "Diese Woche"))

                        BarMark(
                            x: .value("Tag", item.day),
                            y: .value("Minuten", item.lastWeek)
                        )
                        .foregroundStyle(by: .value("Woche", "Letzte Woche"))
                        .position(by: .value("Woche", "Letzte Woche"))
                    }
                }
                .chartForegroundStyleScale([
                    "Diese Woche": Color.blue,
                    "Letzte Woche": Color.blue.opacity(0.3)
                ])
                .chartLegend(position: .bottom)
                .frame(height: 160)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ComparisonCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Grade Line Chart

struct GradeLineChart: View {
    var store: DataStore
    @State private var selectedSubject: String = "Alle"

    private var subjects: [String] {
        store.allGradeSubjects()
    }

    private struct GradePoint: Identifiable {
        let id = UUID()
        let subject: String
        let date: Date
        let grade: Double
    }

    private var gradePoints: [GradePoint] {
        if selectedSubject == "Alle" {
            return subjects.flatMap { subject in
                store.gradesForSubject(subject).map { item in
                    GradePoint(subject: subject, date: item.date, grade: item.grade)
                }
            }
        } else {
            return store.gradesForSubject(selectedSubject).map { item in
                GradePoint(subject: selectedSubject, date: item.date, grade: item.grade)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notenentwicklung")
                .font(.headline)

            // Fach-Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterChip(title: "Alle", isSelected: selectedSubject == "Alle") {
                        selectedSubject = "Alle"
                    }
                    ForEach(subjects, id: \.self) { subject in
                        FilterChip(title: subject, isSelected: selectedSubject == subject) {
                            selectedSubject = subject
                        }
                    }
                }
            }

            if gradePoints.isEmpty {
                Text("Noch keine Noten vorhanden")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                Chart(gradePoints) { point in
                    let flipped = 7.0 - point.grade
                    LineMark(
                        x: .value("Datum", point.date),
                        y: .value("Note", flipped)
                    )
                    .foregroundStyle(by: .value("Fach", point.subject))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Datum", point.date),
                        y: .value("Note", flipped)
                    )
                    .foregroundStyle(by: .value("Fach", point.subject))
                }
                .chartYScale(domain: 1...6)
                .chartYAxis {
                    AxisMarks(values: [1, 2, 3, 4, 5, 6]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(7 - v)")
                            }
                        }
                    }
                }
                .chartLegend(position: .bottom)
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.blue : Color(.tertiarySystemFill), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subject Comparison View

struct SubjectComparisonView: View {
    var store: DataStore

    private struct SubjectStat: Identifiable {
        let id = UUID()
        let name: String
        let minutes: Int
        let gradeAvg: Double?
        let gradeCount: Int
    }

    private var stats: [SubjectStat] {
        store.subjects.map { subject in
            let grades = store.gradesFor(subject: subject)
            let avg = grades.isEmpty ? nil : grades.map(\.grade).reduce(0, +) / Double(grades.count)
            return SubjectStat(
                name: subject.name,
                minutes: store.studyMinutesFor(subject: subject),
                gradeAvg: avg,
                gradeCount: grades.count
            )
        }
        .filter { $0.minutes > 0 || $0.gradeCount > 0 }
        .sorted { $0.minutes > $1.minutes }
    }

    private var maxMinutes: Int {
        stats.map(\.minutes).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fächervergleich")
                .font(.headline)

            if stats.isEmpty {
                Text("Noch keine Daten vorhanden")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ForEach(stats) { stat in
                    VStack(spacing: 6) {
                        HStack {
                            Text(stat.name)
                                .font(.subheadline.bold())
                            Spacer()
                            if let avg = stat.gradeAvg {
                                Text("Ø \(gradeString(avg))")
                                    .font(.caption.bold())
                                    .foregroundStyle(gradeColor(avg))
                            }
                        }

                        HStack(spacing: 8) {
                            // Lernzeit-Balken
                            GeometryReader { geo in
                                let width = maxMinutes > 0 ? CGFloat(stat.minutes) / CGFloat(maxMinutes) * geo.size.width : 0
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue.opacity(0.6))
                                    .frame(width: max(width, 2), height: 8)
                            }
                            .frame(height: 8)

                            Text(formatHoursMinutes(stat.minutes))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }

                        HStack(spacing: 12) {
                            Label("\(stat.gradeCount) Noten", systemImage: "graduationcap")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            if stat.gradeCount > 0 && stat.minutes > 0 {
                                let minutesPerGrade = stat.minutes / max(stat.gradeCount, 1)
                                Label("\(minutesPerGrade) min/Note", systemImage: "clock")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
