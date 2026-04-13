import SwiftUI

// MARK: - Edit Entry View

struct EditEntryView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore

    @State private var showValidation = false
    @State private var title: String
    @State private var date: Date
    @State private var type: EventType
    @State private var notes: String
    @State private var reminderEnabled: Bool
    @State private var reminderMinutesBefore: Int
    @State private var grade: Double
    @State private var hasGrade: Bool

    private let reminderOptions = [5, 10, 15, 30, 60]
    private let entryId: UUID

    init(entry: CalendarEntry, store: DataStore) {
        self.store = store
        self.entryId = entry.id
        _title = State(initialValue: entry.title)
        _date = State(initialValue: entry.date)
        _type = State(initialValue: entry.type)
        _notes = State(initialValue: entry.notes)
        _reminderEnabled = State(initialValue: entry.reminderEnabled)
        _reminderMinutesBefore = State(initialValue: entry.reminderMinutesBefore)
        _grade = State(initialValue: entry.grade ?? 3.0)
        _hasGrade = State(initialValue: entry.grade != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Was?") {
                    TextField("z.B. Mathe, Englisch...", text: $title)

                    if !store.subjects.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(store.subjects) { subject in
                                    Button {
                                        title = subject.name
                                    } label: {
                                        Label(subject.name, systemImage: subject.icon)
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(subject.color)
                                }
                            }
                        }
                    }

                    Picker("Typ", selection: $type) {
                        ForEach(EventType.allCases) { eventType in
                            Label(eventType.rawValue, systemImage: eventType.icon)
                                .tag(eventType)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Wann?") {
                    DatePicker("Datum & Uhrzeit", selection: $date)
                }

                Section("Notizen") {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Erinnerung") {
                    Toggle("Erinnerung aktivieren", isOn: $reminderEnabled)
                    if reminderEnabled {
                        Picker("Erinnerung vor", selection: $reminderMinutesBefore) {
                            ForEach(reminderOptions, id: \.self) { min in
                                Text("\(min) min vorher").tag(min)
                            }
                        }
                    }
                }

                if type == .klassenarbeit {
                    Section("Note") {
                        Toggle("Note eintragen", isOn: $hasGrade)
                        if hasGrade {
                            HStack {
                                Text("Note:")
                                Spacer()
                                Text(gradeString(grade))
                                    .font(.title2.bold())
                                    .foregroundStyle(gradeColor(grade))
                            }
                            Slider(value: $grade, in: 1.0...6.0, step: 0.5) {
                                Text("Note")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Eintrag bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            showValidation = true
                            return
                        }
                        var updated = CalendarEntry(
                            title: trimmed,
                            date: date,
                            type: type,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            reminderEnabled: reminderEnabled,
                            reminderMinutesBefore: reminderMinutesBefore
                        )
                        updated.id = entryId
                        updated.grade = (type == .klassenarbeit && hasGrade) ? grade : nil
                        store.updateEntry(updated)
                        dismiss()
                    }
                }
            }
            .alert("Fehlende Angaben", isPresented: $showValidation) {
                Button("OK") { }
            } message: {
                Text("Bitte gib einen Titel ein.")
            }
        }
    }
}

// MARK: - Add Entry View

struct AddEntryView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore

    @State private var showValidation = false
    @State private var title = ""
    @State private var date: Date
    @State private var type: EventType = .lerntag
    @State private var notes = ""
    @State private var reminderEnabled = false
    @State private var reminderMinutesBefore = 15

    private let reminderOptions = [5, 10, 15, 30, 60]

    init(initialDate: Date, store: DataStore) {
        self.store = store
        _date = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Was?") {
                    TextField("z.B. Mathe, Englisch...", text: $title)

                    if !store.subjects.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(store.subjects) { subject in
                                    Button {
                                        title = subject.name
                                    } label: {
                                        Label(subject.name, systemImage: subject.icon)
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(subject.color)
                                }
                            }
                        }
                    }

                    Picker("Typ", selection: $type) {
                        ForEach(EventType.allCases) { eventType in
                            Label(eventType.rawValue, systemImage: eventType.icon)
                                .tag(eventType)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Wann?") {
                    DatePicker("Datum & Uhrzeit", selection: $date)
                }

                Section("Notizen") {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Erinnerung") {
                    Toggle("Erinnerung aktivieren", isOn: $reminderEnabled)
                    if reminderEnabled {
                        Picker("Erinnerung vor", selection: $reminderMinutesBefore) {
                            ForEach(reminderOptions, id: \.self) { min in
                                Text("\(min) min vorher").tag(min)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Neuer Eintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            showValidation = true
                            return
                        }
                        let entry = CalendarEntry(
                            title: trimmed,
                            date: date,
                            type: type,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            reminderEnabled: reminderEnabled,
                            reminderMinutesBefore: reminderMinutesBefore
                        )
                        store.addEntry(entry)
                        dismiss()
                    }
                }
            }
            .alert("Fehlende Angaben", isPresented: $showValidation) {
                Button("OK") { }
            } message: {
                Text("Bitte gib einen Titel ein.")
            }
        }
    }
}
