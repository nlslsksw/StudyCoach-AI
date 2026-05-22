import SwiftUI

// MARK: - Statistics Tab

struct StatisticsTab: View {
    var store: DataStore
    @State private var selectedPeriod: StatPeriod = .woche

    enum StatPeriod: String, CaseIterable {
        case woche = "Woche"
        case monat = "Monat"
        case jahr = "Jahr"
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
        case .jahr:
            start = cal.date(byAdding: .day, value: -364, to: cal.startOfDay(for: now)) ?? now
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

    private var chartData: [(label: String, minutes: Int)] {
        let cal = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")

        switch selectedPeriod {
        case .woche:
            // 7 Balken, pro Tag
            formatter.dateFormat = "EE"
            var result: [(label: String, minutes: Int)] = []
            for i in stride(from: 6, through: 0, by: -1) {
                let day = cal.date(byAdding: .day, value: -i, to: cal.startOfDay(for: now)) ?? now
                let dayEnd = cal.date(byAdding: .day, value: 1, to: day) ?? now
                let total = store.totalMinutes(in: store.sessionsInRange(from: day, to: dayEnd))
                result.append((label: formatter.string(from: day), minutes: total))
            }
            return result

        case .monat:
            // 4-5 Balken, pro Woche
            var result: [(label: String, minutes: Int)] = []
            let start = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: now)) ?? now
            var weekStart = start
            while weekStart < cal.startOfDay(for: now) {
                let weekEnd = min(cal.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart, cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now)
                let total = store.totalMinutes(in: store.sessionsInRange(from: weekStart, to: weekEnd))
                let startDay = cal.component(.day, from: weekStart)
                let endDay = cal.component(.day, from: cal.date(byAdding: .day, value: -1, to: weekEnd) ?? weekEnd)
                let label = "\(startDay)-\(endDay)"
                result.append((label: label, minutes: total))
                weekStart = weekEnd
            }
            return result

        case .jahr:
            // 12 Balken, pro Monat
            formatter.dateFormat = "MMM"
            var result: [(label: String, minutes: Int)] = []
            for i in stride(from: 11, through: 0, by: -1) {
                guard let monthStart = cal.date(byAdding: .month, value: -i, to: cal.startOfDay(for: now)),
                      let interval = cal.dateInterval(of: .month, for: monthStart) else { continue }
                let total = store.totalMinutes(in: store.sessionsInRange(from: interval.start, to: interval.end))
                result.append((label: formatter.string(from: monthStart), minutes: total))
            }
            return result
        }
    }

    private var maxChartMinutes: Int {
        max(chartData.map(\.minutes).max() ?? 1, 1)
    }

    @State private var showLernzeit = true
    @State private var showVergleiche = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Streak (immer sichtbar)
                    HStack(spacing: 16) {
                        StreakCard(
                            title: "Aktuelle Serie",
                            value: store.currentStreak(),
                            icon: "flame.fill",
                            color: .orange,
                            freezeCount: store.streakState.freezeCount
                        )
                        StreakCard(
                            title: "Längste Serie",
                            value: store.longestStreak(),
                            icon: "trophy.fill",
                            color: .yellow,
                            freezeCount: nil
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

                    // Übersichtskarten (immer sichtbar)
                    HStack(spacing: 12) {
                        StatCard(title: "Gesamt", value: formatHoursMinutes(totalMinutes), icon: "clock.fill", color: .blue)
                        StatCard(title: "Tage gelernt", value: "\(totalDays)", icon: "calendar", color: .green)
                        StatCard(title: "Ø pro Tag", value: formatHoursMinutes(totalDays > 0 ? totalMinutes / totalDays : 0), icon: "chart.line.uptrend.xyaxis", color: .orange)
                    }
                    .padding(.horizontal)

                    // MARK: 1) Lernzeit
                    StatSection(title: "Lernzeit", icon: "clock.fill", color: .blue, isExpanded: $showLernzeit) {
                        VStack(spacing: 16) {
                            // Tägliches Balkendiagramm
                            BarChartView(data: chartData, maxValue: maxChartMinutes, showAllLabels: chartData.count <= 12)
                                .frame(height: 180)

                            // Wochenvergleich
                            WeekComparisonView(store: store)

                            // Fächer-Aufschlüsselung
                            if !subjectBreakdown.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Nach Fach")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.secondary)
                                    ForEach(subjectBreakdown, id: \.subject) { item in
                                        HStack(spacing: 12) {
                                            Circle().fill(store.colorForSubject(item.subject)).frame(width: 12, height: 12)
                                            Text(item.subject).fontWeight(.medium)
                                            Spacer()
                                            Text(formatHoursMinutes(item.minutes))
                                                .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                                        }
                                        GeometryReader { geometry in
                                            let width = geometry.size.width
                                            let ratio = totalMinutes > 0 ? CGFloat(item.minutes) / CGFloat(totalMinutes) : 0
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(store.colorForSubject(item.subject).opacity(0.3))
                                                .frame(width: width, height: 8)
                                                .overlay(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(store.colorForSubject(item.subject))
                                                        .frame(width: width * ratio, height: 8)
                                                }
                                        }
                                        .frame(height: 8)
                                    }
                                }
                            }

                            // Fächervergleich
                            SubjectComparisonView(store: store)
                        }
                    }

                    if periodSessions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar").font(.system(size: 40)).foregroundStyle(.secondary)
                            Text("Noch keine Lernzeiten eingetragen").foregroundStyle(.secondary)
                            Text("Trag im Heute-Tab ein, wann du gelernt hast.")
                                .font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top, 8)
            }
            .navigationTitle("Statistik")
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
    /// Wenn gesetzt: zeigt klein das Eis-Symbol als Button oben rechts (öffnet Info-Sheet).
    var freezeCount: Int? = nil

    @State private var showFreezeInfo = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(colors: [color, color.opacity(0.75)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .shadow(color: color.opacity(0.35), radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(value) Tage")
                    .font(.title2.bold().monospacedDigit())
                    .contentTransition(.numericText())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                LinearGradient(colors: [color.opacity(0.16), color.opacity(0.04)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(color.opacity(0.18), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        )
        .overlay(alignment: .topTrailing) {
            if let freezeCount {
                Button {
                    showFreezeInfo = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "snowflake")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(freezeCount)")
                            .font(.caption2.bold().monospacedDigit())
                    }
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.cyan.opacity(0.18), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                .padding(.trailing, 6)
                .sheet(isPresented: $showFreezeInfo) {
                    FreezeInfoSheet(count: freezeCount)
                        .presentationDetents([.medium])
                }
            }
        }
    }
}

struct FreezeInfoSheet: View {
    let count: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "snowflake")
                    .font(.system(size: 56))
                    .foregroundStyle(.cyan)
                    .padding(.top, 8)

                Text("\(count) Eis im Vorrat")
                    .font(.title2.bold())

                Text("Wenn du einen Tag nicht lernst, wird automatisch ein Eis verbraucht und deine Serie läuft weiter. In den Schulferien (Bundesland in den Einstellungen) pausiert die Serie ohne Eis-Verbrauch.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    Label("Alle 7 Tage Serie → +1 Eis", systemImage: "flame.fill")
                    Label("Alle 300 Minuten Lernzeit → +1 Eis", systemImage: "clock.fill")
                    Label("Wochenziel erreicht → +1 Eis", systemImage: "target")
                }
                .font(.subheadline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Streak-Eis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(colors: [color, color.opacity(0.75)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)

            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .contentTransition(.numericText())

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    // Bar mit Farbverlauf von tief (blass) nach hoch (kräftig).
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(
                            item.minutes > 0
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.85), Color.purple.opacity(0.9)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                              )
                            : AnyShapeStyle(Color.blue.opacity(0.12))
                        )
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

// MARK: - Stat Section (aufklappbar)

struct StatSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var isExpanded: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(AppAnimation.snappy) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            LinearGradient(colors: [color, color.opacity(0.75)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .shadow(color: color.opacity(0.3), radius: 3, x: 0, y: 1)
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                )
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
                    .padding(.top, 12)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal)
    }
}
