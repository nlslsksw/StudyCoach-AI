import SwiftUI

// MARK: - Statistics Tab

struct StatisticsTab: View {
    var store: DataStore
    @State private var selectedPeriod: StatPeriod = .woche
    @State private var showingAddGrade = false

    enum StatPeriod: String, CaseIterable {
        case woche = "Woche"
        case monat = "Monat"
    }

    private var periodSessions: [StudySession] {
        let cal = Calendar.current
        let now = Date()
        let start: Date
        switch selectedPeriod {
        case .woche:
            start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? now
        case .monat:
            start = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: now)) ?? now
        }
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now
        return store.sessionsInRange(from: start, to: end)
    }

    private var totalMinutes: Int {
        store.totalMinutes(in: periodSessions)
    }

    private var totalDays: Int {
        let cal = Calendar.current
        let uniqueDays = Set(periodSessions.map { cal.startOfDay(for: $0.date) })
        return uniqueDays.count
    }

    private var subjectBreakdown: [(subject: String, minutes: Int)] {
        var dict: [String: Int] = [:]
        for s in periodSessions {
            dict[s.subject, default: 0] += s.minutes
        }
        return dict.map { (subject: $0.key, minutes: $0.value) }
            .sorted { $0.minutes > $1.minutes }
    }

    private var dailyData: [(label: String, minutes: Int)] {
        let cal = Calendar.current
        let now = Date()
        let dayCount = selectedPeriod == .woche ? 7 : 30
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = selectedPeriod == .woche ? "EE" : "d."

        var result: [(label: String, minutes: Int)] = []
        for i in stride(from: dayCount - 1, through: 0, by: -1) {
            let day = cal.date(byAdding: .day, value: -i, to: cal.startOfDay(for: now)) ?? now
            let dayEnd = cal.date(byAdding: .day, value: 1, to: day) ?? now
            let daySessions = store.sessionsInRange(from: day, to: dayEnd)
            let total = store.totalMinutes(in: daySessions)
            result.append((label: formatter.string(from: day), minutes: total))
        }
        return result
    }

    private var maxDailyMinutes: Int {
        max(dailyData.map(\.minutes).max() ?? 1, 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Streak
                    HStack(spacing: 16) {
                        StreakCard(
                            title: "Aktuelle Serie",
                            value: store.currentStreak(),
                            icon: "flame.fill",
                            color: .orange
                        )
                        StreakCard(
                            title: "Längste Serie",
                            value: store.longestStreak(),
                            icon: "trophy.fill",
                            color: .yellow
                        )
                    }
                    .padding(.horizontal)

                    Picker("Zeitraum", selection: $selectedPeriod) {
                        ForEach(StatPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    HStack(spacing: 12) {
                        StatCard(title: "Gesamt", value: formatHoursMinutes(totalMinutes), icon: "clock.fill", color: .blue)
                        StatCard(title: "Tage gelernt", value: "\(totalDays)", icon: "calendar", color: .green)
                        StatCard(title: "Ø pro Tag", value: formatHoursMinutes(totalDays > 0 ? totalMinutes / totalDays : 0), icon: "chart.line.uptrend.xyaxis", color: .orange)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tägliche Lernzeit")
                            .font(.headline)
                            .padding(.horizontal)

                        BarChartView(data: dailyData, maxValue: maxDailyMinutes, showAllLabels: selectedPeriod == .woche)
                            .frame(height: 180)
                            .padding(.horizontal)
                    }

                    if !subjectBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Nach Fach")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(subjectBreakdown, id: \.subject) { item in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(colorForSubject(item.subject))
                                        .frame(width: 12, height: 12)
                                    Text(item.subject)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(formatHoursMinutes(item.minutes))
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal)

                                GeometryReader { geometry in
                                    let width = geometry.size.width
                                    let ratio = totalMinutes > 0 ? CGFloat(item.minutes) / CGFloat(totalMinutes) : 0
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(colorForSubject(item.subject).opacity(0.3))
                                        .frame(width: width, height: 8)
                                        .overlay(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(colorForSubject(item.subject))
                                                .frame(width: width * ratio, height: 8)
                                        }
                                }
                                .frame(height: 8)
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Notenbereich
                    let gradeSubjects = store.allGradeSubjects()

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Noten")
                                .font(.headline)
                            Spacer()
                            Button {
                                showingAddGrade = true
                            } label: {
                                Label("Note hinzufügen", systemImage: "plus.circle.fill")
                                    .font(.subheadline)
                            }
                        }
                        .padding(.horizontal)

                        if !gradeSubjects.isEmpty {
                            // Gesamtdurchschnitt
                            let allGrades = gradeSubjects.flatMap { store.gradesForSubject($0) }
                            if !allGrades.isEmpty {
                                let totalAvg = allGrades.map(\.grade).reduce(0, +) / Double(allGrades.count)
                                let schriftlich = allGrades.filter { $0.type == .schriftlich }
                                let muendlich = allGrades.filter { $0.type == .muendlich }
                                HStack(spacing: 16) {
                                    VStack(spacing: 4) {
                                        Text(String(format: "%.1f", totalAvg))
                                            .font(.system(size: 36, weight: .bold, design: .rounded))
                                            .foregroundStyle(gradeColor(totalAvg))
                                        Text("Gesamtschnitt")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(width: 100)

                                    VStack(alignment: .leading, spacing: 6) {
                                        if !schriftlich.isEmpty {
                                            let sAvg = schriftlich.map(\.grade).reduce(0, +) / Double(schriftlich.count)
                                            Label("Schriftlich: Ø \(String(format: "%.1f", sAvg)) (\(schriftlich.count)x)", systemImage: "doc.text.fill")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        if !muendlich.isEmpty {
                                            let mAvg = muendlich.map(\.grade).reduce(0, +) / Double(muendlich.count)
                                            Label("Mündlich: Ø \(String(format: "%.1f", mAvg)) (\(muendlich.count)x)", systemImage: "bubble.left.fill")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        let best = allGrades.map(\.grade).min() ?? 0
                                        let worst = allGrades.map(\.grade).max() ?? 0
                                        HStack(spacing: 12) {
                                            Label("Beste: \(gradeString(best))", systemImage: "arrow.up.circle.fill")
                                                .font(.caption)
                                                .foregroundStyle(.green)
                                            Label("\(gradeString(worst))", systemImage: "arrow.down.circle.fill")
                                                .font(.caption)
                                                .foregroundStyle(.red)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding()
                                .background(gradeColor(totalAvg).opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal)
                            }

                            // Pro Fach
                            ForEach(gradeSubjects, id: \.self) { subject in
                                let grades = store.gradesForSubject(subject)
                                if !grades.isEmpty {
                                    let avg = grades.map(\.grade).reduce(0, +) / Double(grades.count)
                                    VStack(alignment: .leading, spacing: 8) {
                                        // Fach-Header mit Durchschnitt
                                        HStack {
                                            Text(subject)
                                                .font(.subheadline.bold())
                                            Spacer()
                                            Text("Ø \(String(format: "%.1f", avg))")
                                                .font(.subheadline.bold().monospacedDigit())
                                                .foregroundStyle(gradeColor(avg))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(gradeColor(avg).opacity(0.12), in: Capsule())
                                        }
                                        .padding(.horizontal)

                                        // Noten als Zeilen
                                        VStack(spacing: 0) {
                                            ForEach(Array(grades.enumerated()), id: \.offset) { index, item in
                                                HStack(spacing: 8) {
                                                    Image(systemName: item.type.icon)
                                                        .font(.caption)
                                                        .foregroundStyle(item.type == .schriftlich ? .blue : .orange)
                                                        .frame(width: 20)
                                                    Text(item.date, format: .dateTime.day().month(.abbreviated).year())
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                    Text(item.type.rawValue)
                                                        .font(.caption2)
                                                        .foregroundStyle(.tertiary)
                                                    Spacer()
                                                    Text(gradeString(item.grade))
                                                        .font(.title3.bold().monospacedDigit())
                                                        .foregroundStyle(gradeColor(item.grade))
                                                        .frame(width: 40, alignment: .trailing)
                                                }
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)

                                                if index < grades.count - 1 {
                                                    Divider()
                                                        .padding(.leading, 16)
                                                }
                                            }
                                        }
                                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                                        .padding(.horizontal)

                                        // Trend-Anzeige
                                        if grades.count >= 2 {
                                            let lastGrade = grades.last!.grade
                                            let prevGrade = grades[grades.count - 2].grade
                                            let diff = prevGrade - lastGrade
                                            HStack(spacing: 4) {
                                                Image(systemName: diff > 0 ? "arrow.up.right" : diff < 0 ? "arrow.down.right" : "arrow.right")
                                                    .font(.caption2.bold())
                                                Text(diff > 0 ? "Verbessert um \(String(format: "%.1f", diff))" : diff < 0 ? "Verschlechtert um \(String(format: "%.1f", abs(diff)))" : "Gleichgeblieben")
                                                    .font(.caption)
                                            }
                                            .foregroundStyle(diff > 0 ? .green : diff < 0 ? .red : .secondary)
                                            .padding(.horizontal)
                                        }
                                    }
                                    .padding(.bottom, 8)
                                }
                            }
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "graduationcap")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.tertiary)
                                Text("Noch keine Noten")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                    }

                    if periodSessions.isEmpty && gradeSubjects.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("Noch keine Lernzeiten eingetragen")
                                .foregroundStyle(.secondary)
                            Text("Trage im \"Lernzeit\"-Tab ein, wann du gelernt hast.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top, 8)
            }
            .navigationTitle("Statistik")
            .sheet(isPresented: $showingAddGrade) {
                AddGradeView(store: store)
            }
        }
    }
}

// MARK: - Add Grade View

struct AddGradeView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore

    @State private var subject = ""
    @State private var gradeText = ""
    @State private var date = Date()
    @State private var gradeType: GradeType = .schriftlich
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Fach") {
                    TextField("z.B. Mathe, Englisch...", text: $subject)

                    if !store.subjects.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(store.subjects) { sub in
                                    Button {
                                        subject = sub.name
                                    } label: {
                                        Label(sub.name, systemImage: sub.icon)
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(sub.color)
                                }
                            }
                        }
                    } else {
                        let recentSubjects = Array(store.uniqueGradeSubjects().prefix(5))
                        if !recentSubjects.isEmpty && subject.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(recentSubjects, id: \.self) { sub in
                                        Button(sub) {
                                            subject = sub
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Art") {
                    Picker("Notentyp", selection: $gradeType) {
                        ForEach(GradeType.allCases) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Note") {
                    HStack {
                        TextField("z.B. 2, 1.5, 3+", text: $gradeText)
                            .keyboardType(.decimalPad)
                        if let parsed = parseGrade(gradeText) {
                            Spacer()
                            Text(gradeString(parsed))
                                .font(.title2.bold())
                                .foregroundStyle(gradeColor(parsed))
                        }
                    }
                    HStack(spacing: 6) {
                        ForEach([1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0, 6.0], id: \.self) { g in
                            Button(gradeString(g)) {
                                gradeText = gradeString(g)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .tint(parseGrade(gradeText) == g ? .blue : .secondary)
                        }
                    }
                }

                Section("Wann?") {
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "de_DE"))
                }

                Section("Anmerkung") {
                    TextField("Optional", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Note hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let trimmed = subject.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty, let parsed = parseGrade(gradeText) else { return }
                        let newGrade = Grade(
                            subject: trimmed,
                            grade: parsed,
                            date: date,
                            type: gradeType,
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        store.addGrade(newGrade)
                        dismiss()
                    }
                    .disabled(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parseGrade(gradeText) == nil)
                }
            }
        }
    }

    private func parseGrade(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty, let value = Double(trimmed) else { return nil }
        guard value >= 1.0 && value <= 6.0 else { return nil }
        return value
    }
}

// MARK: - Streak Card

struct StreakCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(value) Tage")
                    .font(.title3.bold().monospacedDigit())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title3.bold().monospacedDigit())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Bar Chart View

struct BarChartView: View {
    let data: [(label: String, minutes: Int)]
    let maxValue: Int
    let showAllLabels: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: showAllLabels ? 6 : 2) {
            ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 4) {
                    if item.minutes > 0 {
                        Text("\(item.minutes)")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }

                    RoundedRectangle(cornerRadius: 3)
                        .fill(item.minutes > 0 ? Color.blue : Color.blue.opacity(0.15))
                        .frame(height: max(CGFloat(item.minutes) / CGFloat(maxValue) * 140, 4))

                    if showAllLabels || index % 5 == 0 || index == data.count - 1 {
                        Text(item.label)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("")
                            .font(.system(size: 9))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
