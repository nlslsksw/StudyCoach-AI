import SwiftUI

// MARK: - Subjects Tab

struct SubjectsTab: View {
    var store: DataStore
    @State private var showingAddSubject = false
    @State private var showingManageSchoolYears = false

    private var activeSchoolYears: [SchoolYear] {
        store.schoolYears.filter { !$0.isArchived }.sorted { $0.startDate > $1.startDate }
    }
    private var archivedSchoolYears: [SchoolYear] {
        store.schoolYears.filter { $0.isArchived }.sorted { $0.startDate > $1.startDate }
    }
    private var unassigned: [Subject] { store.unassignedSubjects() }

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Schulfächer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
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
            .sheet(isPresented: $showingAddSubject) { AddSubjectView(store: store) }
            .sheet(isPresented: $showingManageSchoolYears) { ManageSchoolYearsView(store: store) }
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

                        // Trend
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
                    } else {
                        Text("Noch keine Noten")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
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
        .sheet(isPresented: $showingAddGrade) {
            SubjectAddGradeView(store: store, subjectName: subject.name)
        }
        .sheet(isPresented: $showingAddSession) {
            SubjectAddSessionView(store: store, subjectName: subject.name)
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
