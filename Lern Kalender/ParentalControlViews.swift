import SwiftUI

// MARK: - Parental Setup View

struct ParentalSetupView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
                    .padding(.top, 40)

                Text("Elternkontrolle")
                    .font(.title.bold())

                Text("Verbinde das Gerät eines Elternteils mit dieser App, um Lernfortschritte zu teilen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                VStack(spacing: 12) {
                    // Status anzeigen wenn bereits verbunden
                    if let link = store.familyLink, link.isActive {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.green)
                            Text("Verbunden")
                                .font(.headline)
                            Text("Code: \(link.pairingCode)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Text("Nur ein Elternteil kann die Verbindung trennen.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 4)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                    } else {
                        // Wahl: Schüler oder Eltern
                        NavigationLink {
                            StudentPairingView(store: store)
                        } label: {
                            RoleCard(
                                icon: "person.fill",
                                title: "Ich bin Schüler/in",
                                subtitle: "Code generieren und mit Eltern teilen",
                                color: .blue
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ParentPairingView(store: store)
                        } label: {
                            RoleCard(
                                icon: "person.2.fill",
                                title: "Ich bin ein Elternteil",
                                subtitle: "Code eingeben und Lernfortschritte einsehen",
                                color: .green
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }
}

private struct RoleCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(color, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Student Pairing View

struct StudentPairingView: View {
    var store: DataStore
    @State private var pairingCode = ""
    @State private var isCreating = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 20) {
            if pairingCode.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                    Text("Code generieren")
                        .font(.headline)
                    Text("Erstelle einen 6-stelligen Code, den du deinen Eltern gibst.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        generateAndSave()
                    } label: {
                        Label("Code erstellen", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCreating)

                    if isCreating {
                        ProgressView()
                    }

                    if let error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)

                    Text("Dein Pairing-Code:")
                        .font(.headline)

                    Text(pairingCode)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .tracking(8)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                    Text("Teile diesen Code mit deinen Eltern.\nSie geben ihn auf ihrem Gerät ein.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    // Teilen-Button
                    ShareLink(item: "Mein Lern Kalender Pairing-Code: \(pairingCode)") {
                        Label("Code teilen", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Schüler-Code")
        .onAppear {
            if let link = store.familyLink {
                pairingCode = link.pairingCode
            }
        }
    }

    private func generateAndSave() {
        isCreating = true
        error = nil
        let code = CloudKitService.shared.generatePairingCode()

        Task {
            do {
                try await CloudKitService.shared.createFamilyLink(code: code)
                await MainActor.run {
                    store.familyLink = FamilyLink(pairingCode: code)
                    store.appMode = .student
                    pairingCode = code
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    self.error = "Fehler: \(error.localizedDescription)"
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Parent Pairing View

struct ParentPairingView: View {
    var store: DataStore
    @State private var codeInput = ""
    @State private var isChecking = false
    @State private var error: String?
    @State private var isPaired = false
    @State private var childName = ""

    var body: some View {
        VStack(spacing: 20) {
            if !isPaired {
                Image(systemName: "rectangle.and.pencil.and.ellipsis")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)

                Text("Code eingeben")
                    .font(.headline)

                Text("Gib den 6-stelligen Code ein, den dir dein Kind gegeben hat.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("Name des Kindes", text: $childName)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 40)

                TextField("000000", text: $codeInput)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .tracking(6)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 40)

                Button {
                    verifyCode()
                } label: {
                    Label("Verbinden", systemImage: "link")
                }
                .buttonStyle(.borderedProminent)
                .disabled(codeInput.count != 6 || childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isChecking)

                if isChecking {
                    ProgressView()
                }

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)
                    Text("Erfolgreich verbunden!")
                        .font(.title2.bold())
                    Text("Du kannst jetzt die Lernfortschritte deines Kindes einsehen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Eltern-Code")
    }

    private func verifyCode() {
        isChecking = true
        error = nil

        Task {
            do {
                let found = try await CloudKitService.shared.lookupPairingCode(codeInput)
                await MainActor.run {
                    if found {
                        let link = FamilyLink(pairingCode: codeInput, childName: childName.trimmingCharacters(in: .whitespacesAndNewlines))
                        store.familyLinks.append(link)
                        store.familyLink = link
                        store.appMode = .parent
                        isPaired = true

                        // Notifications abonnieren
                        Task {
                            await CloudKitService.shared.subscribeToStudentDataChanges(pairingCode: codeInput)
                        }
                    } else {
                        error = "Code nicht gefunden. Bitte überprüfe die Eingabe."
                    }
                    isChecking = false
                }
            } catch {
                await MainActor.run {
                    self.error = "Fehler: \(error.localizedDescription)"
                    isChecking = false
                }
            }
        }
    }
}

// MARK: - Parent Dashboard View

struct ParentDashboardView: View {
    var store: DataStore
    private let cloudKit = CloudKitService.shared
    @State private var selectedChild: FamilyLink?
    @State private var showingAddChild = false
    @State private var showingAddExam = false
    @State private var showingWeeklyReport = false
    @State private var motivationText = ""
    @State private var isSendingMotivation = false

    private var isWeekendReportAvailable: Bool {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 || weekday == 6 || weekday == 7
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if store.familyLinks.isEmpty {
                    // Willkommens-Screen wenn noch kein Kind verbunden
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)

                        Text("Willkommen!")
                            .font(.title.bold())

                        Text("Verbinde dich mit dem Gerät deines Kindes, um Lernfortschritte zu sehen.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button {
                            showingAddChild = true
                        } label: {
                            Label("Kind hinzufügen", systemImage: "plus.circle.fill")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    Spacer()
                } else {
                    // Kind-Auswahl
                    if store.familyLinks.count > 1 {
                        HStack {
                            Picker("Kind", selection: Binding(
                                get: { selectedChild?.id },
                                set: { newId in
                                    if let link = store.familyLinks.first(where: { $0.id == newId }) {
                                        selectedChild = link
                                        refreshData()
                                    }
                                }
                            )) {
                                ForEach(store.familyLinks) { link in
                                    Text(link.childName.isEmpty ? link.pairingCode : link.childName)
                                        .tag(link.id as UUID?)
                                }
                            }
                            .pickerStyle(.segmented)

                            Button {
                                showingAddChild = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }

                if let child = selectedChild, let data = cloudKit.remoteData[child.pairingCode] {
                    ScrollView {
                        VStack(spacing: 16) {
                            if cloudKit.isSyncing {
                                ProgressView("Daten werden geladen...")
                            }
                            if let error = cloudKit.syncError {
                                Label(error, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption).foregroundStyle(.red).padding(.horizontal)
                            }

                            // Goal progress
                            if let goal = store.studyGoals[child.pairingCode] {
                                parentGoalSection(data: data, goal: goal)
                            }

                            // Quick stats
                            HStack(spacing: 12) {
                                StatCard(title: "Serie", value: "\(data.currentStreak) Tage", icon: "flame.fill", color: .orange)
                                StatCard(title: "Diese Woche", value: formatHoursMinutes(data.weeklyMinutes), icon: "clock.fill", color: .blue)
                            }
                            .padding(.horizontal)

                            todaySessionsSection(data: data)
                            weekOverviewSection(data: data)
                            studyTimeDistributionSection(data: data)
                            examCountdownSection(data: data)
                            gradesSection(data: data)
                            examsSection(data: data, pairingCode: child.pairingCode)
                            goalSettingSection(pairingCode: child.pairingCode)
                            motivationSection(pairingCode: child.pairingCode)

                            Spacer(minLength: 20)
                        }
                        .padding(.top, 8)
                    }
                    .refreshable { refreshData() }
                } else if selectedChild != nil {
                    VStack(spacing: 12) {
                        if cloudKit.isSyncing {
                            ProgressView("Daten werden geladen...")
                        } else {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 30)).foregroundStyle(.secondary)
                            Text("Noch keine Daten").foregroundStyle(.secondary)
                            Button("Aktualisieren") { refreshData() }.buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 60)
                }
            }
            .navigationTitle("Eltern-Dashboard")
            .toolbar {
                if isWeekendReportAvailable {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showingWeeklyReport = true } label: {
                            Image(systemName: "doc.text.fill")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddChild, onDismiss: {
                // Nach Hinzufügen: neues Kind auswählen und Daten laden
                if let last = store.familyLinks.last, selectedChild?.id != last.id {
                    selectedChild = last
                    refreshData()
                }
            }) {
                ParentPairingView(store: store)
            }
            .sheet(isPresented: $showingAddExam) {
                if let child = selectedChild {
                    AddExamFromParentView(store: store, pairingCode: child.pairingCode)
                }
            }
            .sheet(isPresented: $showingWeeklyReport) {
                WeeklyReportView(store: store)
            }
            .onAppear {
                if selectedChild == nil { selectedChild = store.familyLinks.first }
                refreshData()
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func parentGoalSection(data: CloudKitService.ChildRemoteData, goal: StudyGoal) -> some View {
        let todayMinutes = data.sessions.filter { Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.minutes }
        let dailyProgress = goal.dailyMinutesGoal > 0 ? Double(todayMinutes) / Double(goal.dailyMinutesGoal) : 0
        let weeklyProgress = goal.weeklyMinutesGoal > 0 ? Double(data.weeklyMinutes) / Double(goal.weeklyMinutesGoal) : 0

        VStack(spacing: 8) {
            if goal.dailyMinutesGoal > 0 {
                dashboardGoalBar(label: "Heute", current: todayMinutes, goal: goal.dailyMinutesGoal, progress: dailyProgress)
            }
            if goal.weeklyMinutesGoal > 0 {
                dashboardGoalBar(label: "Diese Woche", current: data.weeklyMinutes, goal: goal.weeklyMinutesGoal, progress: weeklyProgress)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func dashboardGoalBar(label: String, current: Int, goal: Int, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption.bold())
                Spacer()
                Text("\(formatHoursMinutes(current)) / \(formatHoursMinutes(goal))")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                if progress >= 1.0 {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(.tertiarySystemFill))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progress >= 1.0 ? Color.green : Color.blue)
                        .frame(width: min(CGFloat(progress), 1.0) * geo.size.width)
                }
            }
            .frame(height: 8)
        }
    }

    @ViewBuilder
    private func todaySessionsSection(data: CloudKitService.ChildRemoteData) -> some View {
        let todaySessions = data.sessions
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }

        VStack(alignment: .leading, spacing: 8) {
            Text("Heute gelernt").font(.headline)
            if todaySessions.isEmpty {
                Text("Noch keine Lernzeit heute").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(todaySessions) { session in
                    HStack {
                        Text(session.subject).font(.subheadline)
                        Spacer()
                        Text(formatHoursMinutes(session.minutes))
                            .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        Text(session.date, style: .time).font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func weekOverviewSection(data: CloudKitService.ChildRemoteData) -> some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if let weekStart = cal.dateInterval(of: .weekOfYear, for: today)?.start {
            VStack(alignment: .leading, spacing: 8) {
                Text("Wochenübersicht").font(.headline)
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { offset in
                        let day = cal.date(byAdding: .day, value: offset, to: weekStart)!
                        let mins = data.sessions
                            .filter { cal.isDate($0.date, inSameDayAs: day) }
                            .reduce(0) { $0 + $1.minutes }
                        let isToday = cal.isDateInToday(day)

                        VStack(spacing: 4) {
                            Text(WeekdayHelper.abbreviation(for: cal.component(.weekday, from: day)))
                                .font(.caption2.bold())
                                .foregroundStyle(isToday ? .blue : .secondary)
                            Text("\(mins)m")
                                .font(.system(.caption2, design: .rounded))
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            mins > 0 ? Color.blue.opacity(min(Double(mins) / 60.0, 1.0) * 0.3 + 0.1) : Color(.tertiarySystemFill),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func studyTimeDistributionSection(data: CloudKitService.ChildRemoteData) -> some View {
        let bySubject = Dictionary(grouping: data.sessions, by: \.subject)
        let totalMinutes = data.sessions.reduce(0) { $0 + $1.minutes }

        if totalMinutes > 0 {
            VStack(alignment: .leading, spacing: 10) {
                Text("Lernzeit-Verteilung").font(.headline)

                ForEach(bySubject.keys.sorted(), id: \.self) { subject in
                    let mins = bySubject[subject]?.reduce(0) { $0 + $1.minutes } ?? 0
                    let pct = Double(mins) / Double(totalMinutes)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(subject).font(.subheadline)
                            Spacer()
                            Text("\(Int(pct * 100))%")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(formatHoursMinutes(mins))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.tertiarySystemFill))
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.blue.opacity(0.7))
                                        .frame(width: geo.size.width * CGFloat(pct))
                                }
                        }
                        .frame(height: 8)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func examCountdownSection(data: CloudKitService.ChildRemoteData) -> some View {
        let upcoming = data.entries
            .filter { $0.type == .klassenarbeit && $0.date > Date() }
            .sorted { $0.date < $1.date }
            .prefix(3)

        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Klassenarbeit-Countdown").font(.headline)

                ForEach(Array(upcoming)) { entry in
                    let daysLeft = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: entry.date)).day ?? 0
                    let subjectMins = data.sessions
                        .filter { $0.subject.localizedCaseInsensitiveCompare(entry.title) == .orderedSame && $0.date >= Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())! }
                        .reduce(0) { $0 + $1.minutes }

                    HStack(spacing: 12) {
                        VStack {
                            Text("\(daysLeft)")
                                .font(.title2.bold())
                                .foregroundStyle(daysLeft <= 3 ? .red : .orange)
                            Text(daysLeft == 1 ? "Tag" : "Tage")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 50)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.subheadline.bold())
                            Text(entry.date, format: .dateTime.day().month().weekday(.wide))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Diese Woche geübt: \(formatHoursMinutes(subjectMins))")
                                .font(.caption2)
                                .foregroundStyle(subjectMins > 0 ? .green : .red)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func gradesSection(data: CloudKitService.ChildRemoteData) -> some View {
        // Noten aus beiden Quellen: standalone Grades + Klassenarbeit-Einträge mit Note
        let entryGrades: [Grade] = data.entries
            .filter { $0.type == .klassenarbeit && $0.grade != nil }
            .map { Grade(subject: $0.title, grade: $0.grade!, date: $0.date, type: .schriftlich) }
        let allGrades = data.grades + entryGrades

        if !allGrades.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Noten").font(.headline)
                ForEach(allGrades.sorted(by: { $0.date > $1.date }).prefix(15)) { grade in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(grade.subject).font(.subheadline.bold())
                            Text(grade.date, format: .dateTime.day().month())
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Image(systemName: grade.type.icon).font(.caption)
                        Text(gradeString(grade.grade))
                            .font(.title3.bold()).foregroundStyle(gradeColor(grade.grade))
                    }
                    .padding(.vertical, 2)
                }
                let gradesBySubject = Dictionary(grouping: allGrades, by: \.subject)
                Divider()
                Text("Durchschnitte").font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(gradesBySubject.keys.sorted(), id: \.self) { subject in
                    let grades = gradesBySubject[subject] ?? []
                    let avg = grades.map(\.grade).reduce(0, +) / Double(grades.count)
                    HStack {
                        Text(subject).font(.caption)
                        Spacer()
                        Text("Ø \(gradeString(avg))").font(.caption.bold()).foregroundStyle(gradeColor(avg))
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func examsSection(data: CloudKitService.ChildRemoteData, pairingCode: String) -> some View {
        let upcomingExams = data.entries
            .filter { $0.type == .klassenarbeit && $0.date > Date() }
            .sorted { $0.date < $1.date }

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Klassenarbeiten").font(.headline)
                Spacer()
                Button { showingAddExam = true } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }
            if upcomingExams.isEmpty {
                Text("Keine anstehenden Klassenarbeiten").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(upcomingExams.prefix(5)) { entry in
                    HStack {
                        Image(systemName: "doc.text.fill").foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title).font(.subheadline.bold())
                            Text(entry.date, format: .dateTime.day().month().hour().minute())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func goalSettingSection(pairingCode: String) -> some View {
        let goal = Binding(
            get: { store.studyGoals[pairingCode] ?? StudyGoal() },
            set: { store.studyGoals[pairingCode] = $0 }
        )

        VStack(alignment: .leading, spacing: 8) {
            Text("Lernziele").font(.headline)
            Stepper("Täglich: \(goal.wrappedValue.dailyMinutesGoal) min", value: goal.dailyMinutesGoal, in: 0...240, step: 15)
                .font(.subheadline)
            Stepper("Wöchentlich: \(goal.wrappedValue.weeklyMinutesGoal) min", value: goal.weeklyMinutesGoal, in: 0...1200, step: 30)
                .font(.subheadline)
            Button("Ziel speichern") {
                Task {
                    try? await CloudKitService.shared.saveStudyGoal(goal.wrappedValue, pairingCode: pairingCode)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func motivationSection(pairingCode: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nachricht senden").font(.headline)
            TextField("Toll gemacht!", text: $motivationText, axis: .vertical)
                .lineLimit(1...4)
                .padding(10)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
            Button {
                sendMotivation(pairingCode: pairingCode)
            } label: {
                HStack {
                    Spacer()
                    if isSendingMotivation {
                        ProgressView()
                    } else {
                        Label("Senden", systemImage: "paperplane.fill")
                    }
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(motivationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingMotivation)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func refreshData() {
        guard let child = selectedChild else { return }
        Task {
            await cloudKit.fetchStudentData(pairingCode: child.pairingCode)
            if let goal = await cloudKit.fetchStudyGoal(pairingCode: child.pairingCode) {
                store.studyGoals[child.pairingCode] = goal
            }
        }
    }

    private func sendMotivation(pairingCode: String) {
        isSendingMotivation = true
        let msg = MotivationMessage(text: motivationText, pairingCode: pairingCode)
        Task {
            try? await cloudKit.saveMotivationMessage(msg)
            await MainActor.run {
                motivationText = ""
                isSendingMotivation = false
            }
        }
    }
}

// MARK: - Add Exam from Parent

struct AddExamFromParentView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore
    let pairingCode: String

    @State private var title = ""
    @State private var subject = ""
    @State private var date = Date()
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Klassenarbeit") {
                    TextField("Titel (z.B. Mathe-Test Kapitel 5)", text: $title)
                    TextField("Fach", text: $subject)
                    DatePicker("Datum", selection: $date)
                        .environment(\.locale, Locale(identifier: "de_DE"))
                }
            }
            .navigationTitle("Klassenarbeit eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        let entry = SharedCalendarEntry(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            pairingCode: pairingCode
        )
        Task {
            try? await CloudKitService.shared.saveSharedCalendarEntry(entry)
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}

// MARK: - Study Goal Setting View (Eltern)

struct StudyGoalSettingView: View {
    var store: DataStore
    @State private var dailyGoal: Int
    @State private var weeklyGoal: Int
    @State private var isSaving = false

    init(store: DataStore) {
        self.store = store
        _dailyGoal = State(initialValue: store.studyGoal?.dailyMinutesGoal ?? 30)
        _weeklyGoal = State(initialValue: store.studyGoal?.weeklyMinutesGoal ?? 150)
    }

    var body: some View {
        Form {
            Section {
                Stepper("Tägliches Ziel: \(dailyGoal) min", value: $dailyGoal, in: 0...240, step: 15)
                HStack(spacing: 6) {
                    ForEach([15, 30, 45, 60, 90], id: \.self) { m in
                        Button("\(m)") {
                            dailyGoal = m
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(dailyGoal == m ? .blue : .secondary)
                    }
                }
            } header: {
                Text("Tägliches Lernziel")
            } footer: {
                Text("Empfohlen: 30-60 Minuten pro Tag")
            }

            Section {
                Stepper("Wöchentliches Ziel: \(weeklyGoal) min", value: $weeklyGoal, in: 0...1200, step: 30)
                HStack(spacing: 6) {
                    ForEach([60, 120, 180, 300], id: \.self) { m in
                        Button(formatHoursMinutes(m)) {
                            weeklyGoal = m
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(weeklyGoal == m ? .blue : .secondary)
                    }
                }
            } header: {
                Text("Wöchentliches Lernziel")
            }

            Section {
                Button {
                    saveGoal()
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                        } else {
                            Label("Ziel speichern", systemImage: "checkmark.circle.fill")
                        }
                        Spacer()
                    }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle("Lernziele setzen")
    }

    private func saveGoal() {
        isSaving = true
        let goal = StudyGoal(dailyMinutesGoal: dailyGoal, weeklyMinutesGoal: weeklyGoal)
        store.studyGoal = goal

        guard let link = store.familyLink else {
            isSaving = false
            return
        }

        Task {
            try? await CloudKitService.shared.saveStudyGoal(goal, pairingCode: link.pairingCode)
            await MainActor.run {
                isSaving = false
            }
        }
    }
}

// MARK: - Goal Progress View (Kind sieht Fortschritt)

struct GoalProgressView: View {
    var store: DataStore

    var body: some View {
        if let goal = store.studyGoal, (goal.dailyMinutesGoal > 0 || goal.weeklyMinutesGoal > 0) {
            VStack(spacing: 8) {
                if goal.dailyMinutesGoal > 0 {
                    let progress = store.dailyGoalProgress(for: Date())
                    GoalBar(label: "Heute", current: store.dayStudyMinutes(on: Date()), goal: goal.dailyMinutesGoal, progress: progress)
                }
                if goal.weeklyMinutesGoal > 0 {
                    let progress = store.weeklyGoalProgress()
                    GoalBar(label: "Diese Woche", current: store.weeklyTotalMinutes(weekOffset: 0), goal: goal.weeklyMinutesGoal, progress: progress)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

private struct GoalBar: View {
    let label: String
    let current: Int
    let goal: Int
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption.bold())
                Spacer()
                Text("\(formatHoursMinutes(current)) / \(formatHoursMinutes(goal))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if progress >= 1.0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.tertiarySystemFill))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progress >= 1.0 ? Color.green : Color.blue)
                        .frame(width: min(CGFloat(progress), 1.0) * geo.size.width)
                }
            }
            .frame(height: 8)
        }
    }
}
