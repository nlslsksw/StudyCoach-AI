import SwiftUI
import Charts

// MARK: - Subjects Tab

struct SubjectsTab: View {
    var store: DataStore
    @State private var showingAddSubject = false
    @State private var showingManageSchoolYears = false
    @State private var mode: SubjectsMode = .subjects
    @State private var showingAddGrade = false

    enum SubjectsMode: String, CaseIterable, Identifiable {
        case subjects = "Fächer"
        case grades = "Noten"
        var id: String { rawValue }
    }

    private var activeSchoolYears: [SchoolYear] {
        store.schoolYears.filter { !$0.isArchived }.sorted { $0.startDate > $1.startDate }
    }
    private var archivedSchoolYears: [SchoolYear] {
        store.schoolYears.filter { $0.isArchived }.sorted { $0.startDate > $1.startDate }
    }
    private var unassigned: [Subject] { store.unassignedSubjects() }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Ansicht", selection: $mode) {
                    ForEach(SubjectsMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                if mode == .grades {
                    GradesOverviewView(store: store)
                } else {
                    subjectsContent
                }
            }
            .navigationTitle(mode == .grades ? "Noten" : "Schulfächer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if mode == .grades {
                        Button { showingAddGrade = true } label: {
                            Image(systemName: "plus")
                        }
                    } else {
                        Menu {
                            Button { showingAddSubject = true } label: {
                                Label("Fach hinzufügen", systemImage: "plus.circle.fill")
                            }
                            Button { showingManageSchoolYears = true } label: {
                                Label("Schuljahre verwalten", systemImage: "folder.badge.gearshape")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSubject) { AddSubjectView(store: store) }
            .sheet(isPresented: $showingManageSchoolYears) { ManageSchoolYearsView(store: store) }
            .sheet(isPresented: $showingAddGrade) { AddGradeView(store: store) }
        }
    }

    @ViewBuilder
    private var subjectsContent: some View {
        Group {
            if store.subjects.isEmpty && store.schoolYears.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Noch keine Fächer")
                            .foregroundStyle(.secondary)
                        Text("Füge deine Schulfächer hinzu, um Noten und Lernzeit zu verwalten.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                        Button { showingAddSubject = true } label: {
                            Label("Fach hinzufügen", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(activeSchoolYears) { schoolYear in
                                SchoolYearSection(store: store, schoolYear: schoolYear, initiallyExpanded: true)
                            }

                            if !unassigned.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    if !store.schoolYears.isEmpty {
                                        Text("Nicht zugeordnet")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 4)
                                            .padding(.top, 8)
                                    }
                                    ForEach(unassigned) { subject in
                                        HStack(spacing: 0) {
                                            NavigationLink(destination: SubjectDetailView(store: store, subject: subject)) {
                                                SubjectCard(store: store, subject: subject)
                                            }
                                            .buttonStyle(.plain)

                                            if !activeSchoolYears.isEmpty {
                                                Menu {
                                                    ForEach(activeSchoolYears) { sy in
                                                        Button(sy.name) {
                                                            withAnimation {
                                                                var updated = subject
                                                                updated.schoolYearId = sy.id
                                                                store.updateSubject(updated)
                                                            }
                                                        }
                                                    }
                                                } label: {
                                                    Image(systemName: "folder.badge.plus")
                                                        .font(.title3)
                                                        .foregroundStyle(.blue)
                                                        .padding(.leading, 8)
                                                }
                                            }
                                        }
                                        .contextMenu { subjectContextMenu(subject) }
                                    }
                                }
                            }

                            if !archivedSchoolYears.isEmpty {
                                DisclosureGroup {
                                    ForEach(archivedSchoolYears) { schoolYear in
                                        SchoolYearSection(store: store, schoolYear: schoolYear, initiallyExpanded: false)
                                    }
                                } label: {
                                    Label("Archiviert", systemImage: "archivebox.fill")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
            }
    }

    @ViewBuilder
    private func subjectContextMenu(_ subject: Subject) -> some View {
        if !store.schoolYears.isEmpty {
            Menu {
                ForEach(store.schoolYears.filter { !$0.isArchived }) { sy in
                    Button(sy.name) {
                        var updated = subject
                        updated.schoolYearId = sy.id
                        store.updateSubject(updated)
                    }
                }
                if subject.schoolYearId != nil {
                    Button("Zuordnung entfernen") {
                        var updated = subject
                        updated.schoolYearId = nil
                        store.updateSubject(updated)
                    }
                }
            } label: { Label("Schuljahr zuordnen", systemImage: "folder") }
        }
        Button(role: .destructive) {
            withAnimation { store.deleteSubject(subject) }
        } label: { Label("Löschen", systemImage: "trash") }
    }
}

// MARK: - School Year Section

struct SchoolYearSection: View {
    var store: DataStore
    let schoolYear: SchoolYear
    let initiallyExpanded: Bool
    @State private var isExpanded: Bool = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            let subjects = store.subjectsFor(schoolYear: schoolYear)
            if subjects.isEmpty {
                Text("Keine Fächer in diesem Schuljahr")
                    .font(.caption).foregroundStyle(.tertiary).padding(.vertical, 4)
            } else {
                ForEach(subjects) { subject in
                    NavigationLink(destination: SubjectDetailView(store: store, subject: subject)) {
                        SubjectCard(store: store, subject: subject)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) { withAnimation { store.deleteSubject(subject) } } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill").foregroundStyle(.blue)
                Text(schoolYear.name).font(.headline)
                if schoolYear.isArchived {
                    Text("Archiviert").font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.secondary.opacity(0.2), in: Capsule())
                }
            }
        }
        .onAppear { isExpanded = initiallyExpanded }
    }
}

// MARK: - Subject Card

struct SubjectCard: View {
    var store: DataStore
    let subject: Subject

    var body: some View {
        let grades = store.gradesFor(subject: subject)
        let minutes = store.studyMinutesFor(subject: subject)

        HStack(spacing: 14) {
            // Icon
            Image(systemName: subject.icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(subject.color, in: RoundedRectangle(cornerRadius: 12))

            // Name + Info
            VStack(alignment: .leading, spacing: 4) {
                Text(subject.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 10) {
                    if !grades.isEmpty {
                        let avg = grades.map(\.grade).reduce(0, +) / Double(grades.count)
                        HStack(spacing: 3) {
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 10))
                            Text("Ø \(gradeString(avg))")
                        }
                        .font(.caption)
                        .foregroundStyle(gradeColor(avg))
                    }
                    if minutes > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                            Text(formatHoursMinutes(minutes))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    if !grades.isEmpty {
                        Text("\(grades.count) Noten")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Durchschnittsnote rechts
            if !grades.isEmpty {
                let avg = grades.map(\.grade).reduce(0, +) / Double(grades.count)
                Text(gradeString(avg))
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(gradeColor(avg))
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Add Subject View

struct AddSubjectView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore

    @State private var name = ""
    @State private var selectedIcon = "book.fill"
    @State private var selectedColor = "blue"
    @State private var selectedSchoolYearId: UUID?

    init(store: DataStore) {
        self.store = store
        _selectedSchoolYearId = State(initialValue: store.activeSchoolYear()?.id)
    }

    private var colorValue: Color {
        Subject(name: "", icon: "", colorName: selectedColor).color
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("z.B. Mathematik, Deutsch...", text: $name)
                }

                if !store.schoolYears.filter({ !$0.isArchived }).isEmpty {
                    Section("Schuljahr") {
                        Picker("Schuljahr", selection: $selectedSchoolYearId) {
                            Text("Nicht zugeordnet").tag(nil as UUID?)
                            ForEach(store.schoolYears.filter { !$0.isArchived }) { sy in
                                Text(sy.name).tag(sy.id as UUID?)
                            }
                        }
                    }
                }

                Section("Symbol") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(Subject.availableIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        selectedIcon == icon ? colorValue.opacity(0.2) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedIcon == icon ? colorValue : .clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(selectedIcon == icon ? colorValue : .secondary)
                        }
                    }
                }

                Section("Farbe") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(Subject.availableColors, id: \.self) { colorName in
                            let color = Subject(name: "", icon: "", colorName: colorName).color
                            Button {
                                selectedColor = colorName
                            } label: {
                                Circle()
                                    .fill(color)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if selectedColor == colorName {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Vorschau
                Section("Vorschau") {
                    HStack(spacing: 14) {
                        Image(systemName: selectedIcon)
                            .font(.title2)
                            .foregroundStyle(colorValue)
                            .frame(width: 36, height: 36)
                            .background(colorValue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        Text(name.isEmpty ? "Fachname" : name)
                            .font(.headline)
                            .foregroundStyle(name.isEmpty ? .secondary : .primary)
                    }
                }
            }
            .navigationTitle("Fach hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let subject = Subject(name: trimmed, icon: selectedIcon, colorName: selectedColor, schoolYearId: selectedSchoolYearId)
                        store.addSubject(subject)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Subject Detail View

struct SubjectDetailView: View {
    var store: DataStore
    let subject: Subject
    @State private var showingAddGrade = false
    @State private var showingAddSession = false
    @State private var showingAIForSubject = false
    @State private var showingAddHomework = false
    @State private var homeworkToEdit: Homework? = nil

    private var grades: [(date: Date, grade: Double, type: GradeType)] {
        store.gradesFor(subject: subject)
    }

    private var sessions: [StudySession] {
        store.sessionsFor(subject: subject)
    }

    private var entries: [CalendarEntry] {
        store.entriesFor(subject: subject)
    }

    private var totalMinutes: Int {
        store.studyMinutesFor(subject: subject)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: subject.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(subject.color)
                        .frame(width: 72, height: 72)
                        .background(subject.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

                    Text(subject.name)
                        .font(.title2.bold())
                }
                .padding(.top, 8)

                // Übersichtskarten
                HStack(spacing: 12) {
                    if !grades.isEmpty {
                        let avg = grades.map(\.grade).reduce(0, +) / Double(grades.count)
                        StatCard(title: "Notenschnitt", value: gradeString(avg), icon: "graduationcap.fill", color: gradeColor(avg))
                    }
                    StatCard(title: "Noten", value: "\(grades.count)", icon: "list.clipboard.fill", color: .blue)
                    StatCard(title: "Lernzeit", value: formatHoursMinutes(totalMinutes), icon: "clock.fill", color: .green)
                }
                .padding(.horizontal)

                // Noten-Bereich
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Noten")
                            .font(.headline)
                        Spacer()
                        Button {
                            showingAddGrade = true
                        } label: {
                            Label("Hinzufügen", systemImage: "plus.circle.fill")
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)

                    if !grades.isEmpty {
                        // Notenschnitt + Sparkline + Beste/Schlechteste
                        SubjectGradeOverview(grades: grades)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            ForEach(Array(grades.enumerated()), id: \.offset) { index, item in
                                HStack(spacing: 10) {
                                    Image(systemName: item.type.icon)
                                        .font(.caption2)
                                        .foregroundStyle(item.type == .schriftlich ? .blue : .orange)
                                        .frame(width: 14)
                                    Text(item.date, format: .dateTime.day().month(.twoDigits).year(.twoDigits))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(gradeString(item.grade))
                                        .font(.subheadline.bold().monospacedDigit())
                                        .foregroundStyle(gradeColor(item.grade))
                                        .frame(width: 36, alignment: .trailing)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)

                                if index < grades.count - 1 {
                                    Divider()
                                        .padding(.leading, 12)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    } else {
                        Text("Noch keine Noten")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }

                // Hausaufgaben-Bereich
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Hausaufgaben")
                            .font(.headline)
                        Spacer()
                        Button {
                            showingAddHomework = true
                        } label: {
                            Label("Hinzufügen", systemImage: "plus.circle.fill")
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)

                    let subjectHomework = store.homeworkFor(subject: subject.name)
                    if subjectHomework.isEmpty {
                        Text("Keine Hausaufgaben")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(subjectHomework.enumerated()), id: \.element.id) { index, hw in
                                HomeworkRow(store: store, homework: hw, onTap: { homeworkToEdit = hw })
                                if index < subjectHomework.count - 1 {
                                    Divider().padding(.leading, 44)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                }

                // Lernzeit-Bereich
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Lernzeit")
                            .font(.headline)
                        Spacer()
                        Button {
                            showingAddSession = true
                        } label: {
                            Label("Eintragen", systemImage: "plus.circle.fill")
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)

                    if !sessions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(sessions.prefix(10).enumerated()), id: \.element.id) { index, session in
                                HStack {
                                    Text(session.date, format: .dateTime.day().month(.abbreviated))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(formatHoursMinutes(session.minutes))
                                        .font(.subheadline.bold().monospacedDigit())
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)

                                if index < min(sessions.count, 10) - 1 {
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                        if sessions.count > 10 {
                            Text("und \(sessions.count - 10) weitere Einträge")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal)
                        }
                    } else {
                        Text("Noch keine Lernzeit eingetragen")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }

                // Kalendereinträge
                if !entries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Kalendereinträge")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            ForEach(Array(entries.prefix(10).enumerated()), id: \.element.id) { index, entry in
                                HStack(spacing: 10) {
                                    Image(systemName: entry.type.icon)
                                        .font(.caption)
                                        .foregroundStyle(entry.type.color)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.title)
                                            .font(.subheadline)
                                        Text(entry.date, format: .dateTime.day().month(.abbreviated).year())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if entry.isCompleted {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)

                                if index < min(entries.count, 10) - 1 {
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.top, 8)
        }
        .navigationTitle(subject.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAIForSubject = true } label: {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                }
                .accessibilityLabel("Aktivitäten und KI für \(subject.name)")
            }
        }
        .sheet(isPresented: $showingAddGrade) {
            SubjectAddGradeView(store: store, subjectName: subject.name)
        }
        .sheet(isPresented: $showingAddSession) {
            SubjectAddSessionView(store: store, subjectName: subject.name)
        }
        .sheet(isPresented: $showingAIForSubject) {
            SubjectActivitySheet(store: store, subject: subject)
        }
        .sheet(isPresented: $showingAddHomework) {
            AddHomeworkView(store: store, initialSubject: subject.name)
        }
        .sheet(item: $homeworkToEdit) { hw in
            AddHomeworkView(store: store, editing: hw)
        }
    }
}

// MARK: - Subject Add Grade View

struct SubjectAddGradeView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore
    let subjectName: String

    @State private var gradeText = ""
    @State private var date = Date()
    @State private var gradeType: GradeType = .schriftlich
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
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
            .navigationTitle("Note für \(subjectName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        guard let parsed = parseGrade(gradeText) else { return }
                        let newGrade = Grade(
                            subject: subjectName,
                            grade: parsed,
                            date: date,
                            type: gradeType,
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        store.addGrade(newGrade)
                        dismiss()
                    }
                    .disabled(parseGrade(gradeText) == nil)
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

// MARK: - Subject Add Session View

struct SubjectAddSessionView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore
    let subjectName: String

    @State private var minutes = 30
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Dauer (Minuten)") {
                    TextField("Minuten", value: $minutes, format: .number)
                        .keyboardType(.numberPad)

                    HStack(spacing: 8) {
                        ForEach([15, 30, 45, 60, 90], id: \.self) { m in
                            Button("\(m) min") {
                                minutes = m
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(minutes == m ? .blue : .secondary)
                        }
                    }
                }

                Section("Wann?") {
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "de_DE"))
                }
            }
            .navigationTitle("Lernzeit für \(subjectName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let session = StudySession(
                            subject: subjectName,
                            date: date,
                            minutes: max(minutes, 1)
                        )
                        store.addSession(session)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Subject Grade Overview

/// Notenschnitt + Inline-Sparkline + Beste/Schlechteste/Trend für ein Fach.
struct SubjectGradeOverview: View {
    let grades: [(date: Date, grade: Double, type: GradeType)]

    private var average: Double {
        guard !grades.isEmpty else { return 0 }
        return grades.map(\.grade).reduce(0, +) / Double(grades.count)
    }
    private var best: Double { grades.map(\.grade).min() ?? 0 }
    private var worst: Double { grades.map(\.grade).max() ?? 0 }
    private var trend: Double? {
        guard grades.count >= 2 else { return nil }
        return grades[grades.count - 2].grade - grades.last!.grade
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 2) {
                Text(String(format: "%.1f", average))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(gradeColor(average))
                Text("Schnitt")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 80)

            VStack(alignment: .leading, spacing: 8) {
                if grades.count >= 2 {
                    sparkline
                        .frame(height: 36)
                }
                HStack(spacing: 12) {
                    Label(gradeString(best), systemImage: "arrow.up.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Label(gradeString(worst), systemImage: "arrow.down.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    if let d = trend, abs(d) > 0.05 {
                        Label("\(d > 0 ? "+" : "")\(String(format: "%.1f", d))",
                              systemImage: d > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2.bold())
                            .foregroundStyle(d > 0 ? .green : .red)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(gradeColor(average).opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var sparkline: some View {
        Chart {
            ForEach(Array(grades.enumerated()), id: \.offset) { idx, item in
                LineMark(
                    x: .value("Idx", idx),
                    y: .value("Note", item.grade)
                )
                .foregroundStyle(gradeColor(average))
                .interpolationMethod(.monotone)
                PointMark(
                    x: .value("Idx", idx),
                    y: .value("Note", item.grade)
                )
                .foregroundStyle(gradeColor(item.grade))
                .symbolSize(22)
            }
        }
        .chartYScale(domain: 6.0...1.0)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

// MARK: - Subject Activity Sheet (KI-Sparkles-Button im Fach-Detail)

/// Zeigt alles, was im Fach passiert ist: Übersichts-Stats, letzte Noten,
/// Lernzeiten, Hausaufgaben — und einen Button, um damit zur KI zu wechseln.
struct SubjectActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore
    let subject: Subject

    @State private var showingAIChat = false

    private var grades: [(date: Date, grade: Double, type: GradeType)] {
        store.gradesFor(subject: subject)
    }
    private var sessions: [StudySession] { store.sessionsFor(subject: subject) }
    private var homework: [Homework] { store.homeworkFor(subject: subject.name) }
    private var openHomework: [Homework] { homework.filter { !$0.isDone } }
    private var totalMinutes: Int { store.studyMinutesFor(subject: subject) }
    private var lastSessionDate: Date? { sessions.first?.date }

    private struct ActivityItem: Identifiable {
        let id = UUID()
        let date: Date
        let icon: String
        let color: Color
        let title: String
        let detail: String
    }

    private var recentActivity: [ActivityItem] {
        var items: [ActivityItem] = []
        for g in grades {
            items.append(ActivityItem(
                date: g.date, icon: "graduationcap.fill", color: gradeColor(g.grade),
                title: "Note: \(gradeString(g.grade))",
                detail: g.type.rawValue
            ))
        }
        for s in sessions.prefix(20) {
            items.append(ActivityItem(
                date: s.date, icon: "clock.fill", color: .blue,
                title: "Gelernt",
                detail: formatHoursMinutes(s.minutes)
            ))
        }
        for hw in homework.prefix(20) {
            items.append(ActivityItem(
                date: hw.dueDate, icon: hw.isDone ? "checkmark.circle.fill" : "checklist",
                color: hw.isDone ? .green : .orange,
                title: hw.title,
                detail: hw.isDone ? "Erledigt" : "Hausaufgabe"
            ))
        }
        return items.sorted { $0.date > $1.date }.prefix(15).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header: Fach + KI-Hinweis
                    header

                    // Übersichts-Stats
                    overviewGrid
                        .padding(.horizontal)

                    // Noten-Quick (falls vorhanden)
                    if !grades.isEmpty {
                        SubjectGradeOverview(grades: grades)
                            .padding(.horizontal)
                    }

                    // Aktivitätsliste
                    if !recentActivity.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Letzte Aktivität")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            VStack(spacing: 0) {
                                ForEach(Array(recentActivity.enumerated()), id: \.element.id) { idx, item in
                                    HStack(spacing: 10) {
                                        Image(systemName: item.icon)
                                            .font(.caption)
                                            .foregroundStyle(item.color)
                                            .frame(width: 22)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.title)
                                                .font(.subheadline)
                                            Text(item.detail)
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                        Spacer()
                                        Text(item.date, format: .dateTime.day().month(.twoDigits).year(.twoDigits))
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    if idx < recentActivity.count - 1 {
                                        Divider().padding(.leading, 44)
                                    }
                                }
                            }
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }

                    // KI-Aktion
                    if store.aiAllowed {
                        Button {
                            showingAIChat = true
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Mit der KI über \(subject.name) sprechen")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .foregroundStyle(.white)
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top, 4)
            }
            .navigationTitle(subject.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAIChat) {
                AIAssistantTab(store: store)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: subject.icon)
                .font(.title2)
                .foregroundStyle(subject.color)
                .frame(width: 52, height: 52)
                .background(subject.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text("Aktivität in \(subject.name)")
                    .font(.headline)
                Text("Tippe die KI-Schaltfläche unten für eine Zusammenfassung.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 6)
    }

    private var overviewGrid: some View {
        let avg = grades.isEmpty ? 0.0 : (grades.map(\.grade).reduce(0, +) / Double(grades.count))
        return HStack(spacing: 10) {
            miniStat(
                icon: "clock.fill",
                color: .blue,
                title: formatHoursMinutes(totalMinutes),
                label: "Lernzeit"
            )
            miniStat(
                icon: "graduationcap.fill",
                color: grades.isEmpty ? .gray : gradeColor(avg),
                title: grades.isEmpty ? "—" : String(format: "%.1f", avg),
                label: "\(grades.count) Note\(grades.count == 1 ? "" : "n")"
            )
            miniStat(
                icon: "checklist",
                color: openHomework.isEmpty ? .green : .orange,
                title: "\(openHomework.count)",
                label: "offen"
            )
        }
    }

    private func miniStat(icon: String, color: Color, title: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Grades Overview (Noten-Modus im Fächer-Tab)

/// Schicke Noten-Übersicht über alle Fächer hinweg: Gesamtschnitt,
/// Verlaufschart aller Noten, pro-Fach-Cards mit Sparkline und Tap → Fach-Detail.
struct GradesOverviewView: View {
    var store: DataStore

    private struct GradePoint: Identifiable {
        let id = UUID()
        let date: Date
        let grade: Double
        let subject: String
    }

    private var gradeSubjects: [String] { store.allGradeSubjects() }

    private var allGrades: [(subject: String, date: Date, grade: Double, type: GradeType)] {
        gradeSubjects.flatMap { subject in
            store.gradesForSubject(subject).map { (subject: subject, date: $0.date, grade: $0.grade, type: $0.type) }
        }
        .sorted { $0.date < $1.date }
    }

    private var totalAvg: Double {
        guard !allGrades.isEmpty else { return 0 }
        return allGrades.map(\.grade).reduce(0, +) / Double(allGrades.count)
    }

    private var schriftlichAvg: Double? {
        let s = allGrades.filter { $0.type == .schriftlich }
        guard !s.isEmpty else { return nil }
        return s.map(\.grade).reduce(0, +) / Double(s.count)
    }
    private var muendlichAvg: Double? {
        let m = allGrades.filter { $0.type == .muendlich }
        guard !m.isEmpty else { return nil }
        return m.map(\.grade).reduce(0, +) / Double(m.count)
    }

    var body: some View {
        if gradeSubjects.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    summaryHeader
                        .padding(.horizontal)

                    if allGrades.count >= 2 {
                        verlaufCard
                            .padding(.horizontal)
                    }

                    perSubjectList
                        .padding(.horizontal)

                    Spacer(minLength: 20)
                }
                .padding(.top, 8)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "graduationcap")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Noch keine Noten")
                .foregroundStyle(.secondary)
            Text("Tippe oben rechts auf +, um eine Note hinzuzufügen.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var summaryHeader: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 18) {
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", totalAvg))
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(gradeColor(totalAvg))
                        .contentTransition(.numericText())
                    Text("Gesamtschnitt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider().frame(height: 60)

                VStack(alignment: .leading, spacing: 6) {
                    if let s = schriftlichAvg {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.fill")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                            Text("Schriftlich")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "Ø %.1f", s))
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(gradeColor(s))
                        }
                    }
                    if let m = muendlichAvg {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text("Mündlich")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "Ø %.1f", m))
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(gradeColor(m))
                        }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "number")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Anzahl")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(allGrades.count)")
                            .font(.caption.bold().monospacedDigit())
                    }
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [gradeColor(totalAvg).opacity(0.18), gradeColor(totalAvg).opacity(0.05)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18)
            )
        }
    }

    private var verlaufCard: some View {
        let points = allGrades.map { GradePoint(date: $0.date, grade: $0.grade, subject: $0.subject) }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Notenverlauf")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Chart {
                ForEach(points) { p in
                    LineMark(
                        x: .value("Datum", p.date),
                        y: .value("Note", p.grade),
                        series: .value("Alle", "alle")
                    )
                    .foregroundStyle(.secondary.opacity(0.4))
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("Datum", p.date),
                        y: .value("Note", p.grade)
                    )
                    .foregroundStyle(store.colorForSubject(p.subject))
                    .symbolSize(40)
                }
                RuleMark(y: .value("Schnitt", totalAvg))
                    .foregroundStyle(gradeColor(totalAvg).opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .chartYScale(domain: 6.0...1.0)
            .chartYAxis {
                AxisMarks(values: [1, 2, 3, 4, 5, 6]) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 160)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var perSubjectList: some View {
        VStack(spacing: 10) {
            ForEach(gradeSubjects, id: \.self) { subjectName in
                let grades = store.gradesForSubject(subjectName)
                if !grades.isEmpty {
                    if let sub = store.subjects.first(where: { $0.name.localizedCaseInsensitiveCompare(subjectName) == .orderedSame }) {
                        NavigationLink(destination: SubjectDetailView(store: store, subject: sub)) {
                            GradeSubjectCard(store: store, subjectName: subjectName,
                                             color: sub.color, icon: sub.icon, grades: grades)
                        }
                        .buttonStyle(.plain)
                    } else {
                        GradeSubjectCard(store: store, subjectName: subjectName,
                                         color: store.colorForSubject(subjectName),
                                         icon: "book.fill", grades: grades)
                    }
                }
            }
        }
    }
}

struct GradeSubjectCard: View {
    var store: DataStore
    let subjectName: String
    let color: Color
    let icon: String
    let grades: [(date: Date, grade: Double, type: GradeType)]

    private var avg: Double { grades.map(\.grade).reduce(0, +) / Double(grades.count) }
    private var trend: Double? {
        guard grades.count >= 2 else { return nil }
        return grades[grades.count - 2].grade - grades.last!.grade
    }
    private var best: Double { grades.map(\.grade).min() ?? 0 }
    private var worst: Double { grades.map(\.grade).max() ?? 0 }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 1) {
                    Text(subjectName)
                        .font(.subheadline.bold())
                    Text("\(grades.count) Note\(grades.count == 1 ? "" : "n") · \(gradeString(best))–\(gradeString(worst))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let d = trend, abs(d) > 0.05 {
                    Image(systemName: d > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.bold())
                        .foregroundStyle(d > 0 ? .green : .red)
                }
                Text(String(format: "%.1f", avg))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(gradeColor(avg))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(gradeColor(avg).opacity(0.15), in: Capsule())
            }

            if grades.count >= 2 {
                Chart {
                    ForEach(Array(grades.enumerated()), id: \.offset) { idx, item in
                        LineMark(
                            x: .value("Idx", idx),
                            y: .value("Note", item.grade)
                        )
                        .foregroundStyle(color)
                        .interpolationMethod(.monotone)
                        PointMark(
                            x: .value("Idx", idx),
                            y: .value("Note", item.grade)
                        )
                        .foregroundStyle(gradeColor(item.grade))
                        .symbolSize(18)
                    }
                }
                .chartYScale(domain: 6.0...1.0)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 30)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
