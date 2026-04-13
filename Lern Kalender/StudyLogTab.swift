import ActivityKit
import SwiftUI

// MARK: - Study Log Tab

struct StudyLogTab: View {
    var store: DataStore
    @State private var showingAdd = false
    @State private var showingTimer = false
    @State private var selectedDate = Date()
    @State private var viewMode: ViewMode = .tag

    enum ViewMode: String, CaseIterable {
        case tag = "Tag"
        case alle = "Alle"
    }

    private var daySessions: [StudySession] {
        store.sessions(for: selectedDate)
    }

    private var allSessions: [StudySession] {
        store.allSessionsSorted()
    }

    // Gruppiere "Alle" nach Datum
    private var groupedSessions: [(date: Date, sessions: [StudySession])] {
        let cal = Calendar.current
        var dict: [Date: [StudySession]] = [:]
        for session in allSessions {
            let day = cal.startOfDay(for: session.date)
            dict[day, default: []].append(session)
        }
        return dict.sorted { $0.key > $1.key }
            .map { (date: $0.key, sessions: $0.value) }
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEE, d. MMMM"
        return formatter.string(from: selectedDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Lernziel-Fortschritt
                GoalProgressView(store: store)
                    .padding(.horizontal)
                    .padding(.top, 4)

                // Modus-Auswahl
                Picker("Ansicht", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                if viewMode == .tag {
                    dayView
                } else {
                    allView
                }
            }
            .navigationTitle("Lernzeit")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingAdd = true
                        } label: {
                            Label("Manuell eintragen", systemImage: "pencil")
                        }
                        Button {
                            showingTimer = true
                        } label: {
                            Label("Timer starten", systemImage: "timer")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddStudySessionView(initialDate: selectedDate, store: store)
            }
            .fullScreenCover(isPresented: $showingTimer) {
                StudyTimerView(store: store)
            }
        }
    }

    // MARK: Tagesansicht

    @ViewBuilder
    private var dayView: some View {
        DatePicker("Datum", selection: $selectedDate, displayedComponents: .date)
            .datePickerStyle(.compact)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .environment(\.locale, Locale(identifier: "de_DE"))

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateString)
                    .font(.headline)
                Text("\(store.totalMinutes(in: daySessions)) min gelernt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatHoursMinutes(store.totalMinutes(in: daySessions)))
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(.blue)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)

        Divider()

        if daySessions.isEmpty {
            emptySessionsView
        } else {
            sessionList(daySessions)
        }
    }

    // MARK: Alle-Ansicht

    @ViewBuilder
    private var allView: some View {
        let total = store.totalMinutes(in: store.studySessions)

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Alle Lernzeiten")
                    .font(.headline)
                Text("\(store.studySessions.count) Einträge")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatHoursMinutes(total))
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(.blue)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)

        Divider()

        if groupedSessions.isEmpty {
            emptySessionsView
        } else {
            List {
                ForEach(groupedSessions, id: \.date) { group in
                    Section {
                        ForEach(group.sessions) { session in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(store.colorForSubject(session.subject))
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.subject)
                                        .fontWeight(.medium)
                                    Text(session.date, format: .dateTime.hour().minute())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text("\(session.minutes) min")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.deleteSession(session)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text(groupDateString(group.date))
                            Spacer()
                            Text(formatHoursMinutes(store.totalMinutes(in: group.sessions)))
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var emptySessionsView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Noch nichts eingetragen")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Lernzeit eintragen") {
                    showingAdd = true
                }
                .buttonStyle(.borderedProminent)
                Button {
                    showingTimer = true
                } label: {
                    Label("Timer", systemImage: "timer")
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @State private var sessionToEdit: StudySession?

    private func sessionList(_ sessions: [StudySession]) -> some View {
        List {
            ForEach(sessions) { session in
                HStack(spacing: 12) {
                    Circle()
                        .fill(store.colorForSubject(session.subject))
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.subject)
                            .fontWeight(.medium)
                        Text(session.date, format: .dateTime.hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(session.minutes) min")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .contextMenu {
                    Button {
                        sessionToEdit = session
                    } label: {
                        Label("Bearbeiten", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        store.deleteSession(session)
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        store.deleteSession(session)
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .sheet(item: $sessionToEdit) { session in
            EditStudySessionView(store: store, session: session)
        }
    }

    private func groupDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "Heute"
        } else if cal.isDateInYesterday(date) {
            return "Gestern"
        } else {
            formatter.dateFormat = "EEEE, d. MMM"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Study Timer View

struct StudyTimerView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore

    @State private var subject = ""
    @State private var isRunning = false
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?
    @State private var startTime: Date?
    @State private var showingSaveConfirm = false
    @State private var activity: Activity<StudyTimerAttributes>?

    private var elapsedMinutes: Int {
        elapsedSeconds / 60
    }

    private var timeString: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()

                if !isRunning && elapsedSeconds == 0 {
                    VStack(spacing: 12) {
                        TextField("Fach eingeben...", text: $subject)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 40)

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
                            let recentSubjects = Array(store.uniqueSubjects().prefix(4))
                            if !recentSubjects.isEmpty {
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
                } else {
                    Text(subject)
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                }

                Text(timeString)
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                if elapsedMinutes > 0 {
                    Text("\(elapsedMinutes) Minuten")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 40) {
                    if isRunning {
                        Button {
                            pauseTimer()
                        } label: {
                            Image(systemName: "pause.fill")
                                .font(.title)
                                .frame(width: 70, height: 70)
                                .background(.orange, in: Circle())
                                .foregroundStyle(.white)
                        }
                    } else if elapsedSeconds > 0 {
                        Button {
                            startTimer()
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.title)
                                .frame(width: 70, height: 70)
                                .background(.green, in: Circle())
                                .foregroundStyle(.white)
                        }
                    } else {
                        Button {
                            startTimer()
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.title)
                                .frame(width: 70, height: 70)
                                .background(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .green, in: Circle())
                                .foregroundStyle(.white)
                        }
                        .disabled(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if elapsedSeconds > 0 {
                        Button {
                            pauseTimer()
                            showingSaveConfirm = true
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.title)
                                .frame(width: 70, height: 70)
                                .background(.red, in: Circle())
                                .foregroundStyle(.white)
                        }
                    }
                }

                Spacer()
            }
            .navigationTitle("Lerntimer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        pauseTimer()
                        endLiveActivity()
                        dismiss()
                    }
                }
            }
            .alert("Lernzeit speichern?", isPresented: $showingSaveConfirm) {
                Button("Speichern") {
                    let minutes = max(elapsedSeconds / 60, 1)
                    let session = StudySession(
                        subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
                        date: startTime ?? Date(),
                        minutes: minutes
                    )
                    store.addSession(session)
                    endLiveActivity()
                    dismiss()
                }
                Button("Verwerfen", role: .destructive) {
                    endLiveActivity()
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("\(subject) - \(formatHoursMinutes(max(elapsedSeconds / 60, 1))) speichern?")
            }
        }
    }

    private func startTimer() {
        if startTime == nil {
            startTime = Date()
        }
        isRunning = true
        UIApplication.shared.isIdleTimerDisabled = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
        }

        let contentState = StudyTimerAttributes.ContentState(
            isPaused: false,
            elapsedAtPause: elapsedSeconds,
            effectiveStartDate: Date().addingTimeInterval(-Double(elapsedSeconds))
        )

        if let activity {
            Task {
                await activity.update(ActivityContent(state: contentState, staleDate: nil))
            }
        } else {
            let authInfo = ActivityAuthorizationInfo()
            print("Live Activities erlaubt: \(authInfo.areActivitiesEnabled)")
            print("Frequent Push erlaubt: \(authInfo.frequentPushesEnabled)")

            let attributes = StudyTimerAttributes(subject: subject)
            do {
                activity = try Activity<StudyTimerAttributes>.request(
                    attributes: attributes,
                    content: ActivityContent(state: contentState, staleDate: nil)
                )
                print("Live Activity gestartet: \(activity?.id ?? "nil")")
            } catch {
                print("Live Activity Fehler: \(error.localizedDescription)")
                print("Live Activity Fehler Details: \(error)")
            }
        }
    }

    private func pauseTimer() {
        isRunning = false
        UIApplication.shared.isIdleTimerDisabled = false
        timer?.invalidate()
        timer = nil

        if let activity {
            let contentState = StudyTimerAttributes.ContentState(
                isPaused: true,
                elapsedAtPause: elapsedSeconds,
                effectiveStartDate: Date()
            )
            Task {
                await activity.update(ActivityContent(state: contentState, staleDate: nil))
            }
        }
    }

    private func endLiveActivity() {
        UIApplication.shared.isIdleTimerDisabled = false
        guard let activity else { return }
        let finalState = StudyTimerAttributes.ContentState(
            isPaused: true,
            elapsedAtPause: elapsedSeconds,
            effectiveStartDate: Date()
        )
        Task {
            await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
        self.activity = nil
    }
}

// MARK: - Add Study Session View

struct AddStudySessionView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore

    @State private var showValidation = false
    @State private var subject = ""
    @State private var date: Date
    @State private var minutes = 30

    init(initialDate: Date, store: DataStore) {
        self.store = store
        _date = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Was hast du gelernt?") {
                    TextField("Fach (z.B. Mathe, Englisch...)", text: $subject)

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
                        let recentSubjects = Array(store.uniqueSubjects().prefix(5))
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

                Section("Wann?") {
                    DatePicker("Datum & Uhrzeit", selection: $date)
                        .environment(\.locale, Locale(identifier: "de_DE"))
                }

                Section("Wie lange?") {
                    Stepper("\(minutes) Minuten", value: $minutes, in: 5...600, step: 5)

                    HStack(spacing: 8) {
                        ForEach([15, 30, 45, 60, 90], id: \.self) { m in
                            Button("\(m)m") {
                                minutes = m
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(minutes == m ? .blue : .secondary)
                        }
                    }
                }
            }
            .navigationTitle("Lernzeit eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let trimmed = subject.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            showValidation = true
                            return
                        }
                        let session = StudySession(subject: trimmed, date: date, minutes: minutes)
                        store.addSession(session)
                        dismiss()
                    }
                }
            }
            .alert("Fehlende Angaben", isPresented: $showValidation) {
                Button("OK") { }
            } message: {
                Text("Bitte wähle ein Fach aus.")
            }
        }
    }
}

// MARK: - Edit Study Session View

struct EditStudySessionView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore
    let session: StudySession

    @State private var showValidation = false
    @State private var subject: String
    @State private var date: Date
    @State private var minutes: Int

    init(store: DataStore, session: StudySession) {
        self.store = store
        self.session = session
        _subject = State(initialValue: session.subject)
        _date = State(initialValue: session.date)
        _minutes = State(initialValue: session.minutes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Was hast du gelernt?") {
                    TextField("Fach", text: $subject)

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
                    }
                }

                Section("Wann?") {
                    DatePicker("Datum & Uhrzeit", selection: $date)
                        .environment(\.locale, Locale(identifier: "de_DE"))
                }

                Section("Wie lange?") {
                    Stepper("\(minutes) Minuten", value: $minutes, in: 1...600, step: 5)

                    HStack(spacing: 8) {
                        ForEach([15, 30, 45, 60, 90], id: \.self) { m in
                            Button("\(m)m") {
                                minutes = m
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(minutes == m ? .blue : .secondary)
                        }
                    }
                }
            }
            .navigationTitle("Lernzeit bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let trimmed = subject.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            showValidation = true
                            return
                        }
                        var updated = session
                        updated.subject = trimmed
                        updated.date = date
                        updated.minutes = minutes
                        store.updateSession(updated)
                        dismiss()
                    }
                }
            }
            .alert("Fehlende Angaben", isPresented: $showValidation) {
                Button("OK") { }
            } message: {
                Text("Bitte wähle ein Fach aus.")
            }
        }
    }
}
