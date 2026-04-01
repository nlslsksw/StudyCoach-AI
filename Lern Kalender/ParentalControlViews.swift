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
                .disabled(codeInput.count != 6 || isChecking)

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
                        store.familyLink = FamilyLink(pairingCode: codeInput)
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Sync-Status
                    if cloudKit.isSyncing {
                        ProgressView("Daten werden geladen...")
                    }

                    if let error = cloudKit.syncError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    if let lastUpdate = cloudKit.remoteLastUpdated {
                        let formatter = RelativeDateTimeFormatter()
                        Text("Zuletzt aktualisiert: \(formatter.localizedString(for: lastUpdate, relativeTo: Date()))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Übersichtskarten
                    HStack(spacing: 12) {
                        StatCard(title: "Aktuelle Serie", value: "\(cloudKit.remoteCurrentStreak) Tage", icon: "flame.fill", color: .orange)
                        StatCard(title: "Diese Woche", value: formatHoursMinutes(cloudKit.remoteWeeklyMinutes), icon: "clock.fill", color: .blue)
                    }
                    .padding(.horizontal)

                    // Noten
                    if !cloudKit.remoteGrades.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Noten")
                                .font(.headline)
                                .padding(.horizontal)

                            let gradesBySubject = Dictionary(grouping: cloudKit.remoteGrades, by: \.subject)
                            ForEach(gradesBySubject.keys.sorted(), id: \.self) { subject in
                                let grades = gradesBySubject[subject] ?? []
                                let avg = grades.map(\.grade).reduce(0, +) / Double(grades.count)

                                HStack {
                                    Text(subject)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text("Ø \(gradeString(avg))")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(gradeColor(avg))
                                    Text("(\(grades.count) Noten)")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                    }

                    // Lernzeit pro Fach
                    if !cloudKit.remoteSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Lernzeiten")
                                .font(.headline)

                            let sessionsBySubject = Dictionary(grouping: cloudKit.remoteSessions, by: \.subject)
                            ForEach(sessionsBySubject.keys.sorted(), id: \.self) { subject in
                                let sessions = sessionsBySubject[subject] ?? []
                                let total = sessions.reduce(0) { $0 + $1.minutes }
                                HStack {
                                    Text(subject)
                                        .font(.subheadline)
                                    Spacer()
                                    Text(formatHoursMinutes(total))
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                    }

                    if cloudKit.remoteGrades.isEmpty && cloudKit.remoteSessions.isEmpty && !cloudKit.isSyncing {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 30))
                                .foregroundStyle(.secondary)
                            Text("Noch keine Daten")
                                .foregroundStyle(.secondary)
                            Text("Die Daten werden angezeigt, sobald dein Kind Lernzeiten oder Noten einträgt.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top, 8)
            }
            .navigationTitle("Eltern-Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        refreshData()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(cloudKit.isSyncing)
                }
            }
            .onAppear {
                refreshData()
            }
        }
    }

    private func refreshData() {
        guard let link = store.familyLink else { return }
        Task {
            await cloudKit.fetchStudentData(pairingCode: link.pairingCode)
            // Auch Lernziele laden
            if let goal = await cloudKit.fetchStudyGoal(pairingCode: link.pairingCode) {
                await MainActor.run {
                    store.studyGoal = goal
                }
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
