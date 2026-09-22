import SwiftUI

// MARK: - Calendar Tab

struct CalendarTab: View {
    var store: DataStore
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var showingAddEntry = false
    @State private var showingAddSession = false
    @State private var showingDeleteAll = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Kalender
                VStack(spacing: 8) {
                    MonthHeader(displayedMonth: $displayedMonth)
                    CalendarGrid(displayedMonth: displayedMonth, selectedDate: $selectedDate, store: store)
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)

                Divider()
                    .padding(.top, 6)

                DayDetailSection(date: selectedDate, store: store, onAddSession: {
                    showingAddSession = true
                })
            }
            .navigationTitle("Lernkalender")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingAddEntry = true
                        } label: {
                            Label("Neuer Eintrag", systemImage: "calendar.badge.plus")
                        }
                        Button {
                            showingAddSession = true
                        } label: {
                            Label("Lernzeit eintragen", systemImage: "clock.badge.checkmark")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigation) {
                    Button {
                        withAnimation {
                            selectedDate = Date()
                            displayedMonth = Date()
                        }
                    } label: {
                        Text("Heute")
                    }
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                AddEntryView(initialDate: selectedDate, store: store)
            }
            .sheet(isPresented: $showingAddSession) {
                AddStudySessionView(initialDate: selectedDate, store: store)
            }
            .alert("Alles löschen?", isPresented: $showingDeleteAll) {
                Button("Abbrechen", role: .cancel) { }
                Button("Alles löschen", role: .destructive) {
                    withAnimation {
                        store.deleteAllData()
                    }
                }
            } message: {
                Text("Alle Einträge, Daueraufgaben und Lernzeiten werden unwiderruflich gelöscht.")
            }
        }
    }
}

// MARK: - Month Header

struct MonthHeader: View {
    @Binding var displayedMonth: Date
    private let calendar = Calendar.current

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: displayedMonth).capitalized
    }

    var body: some View {
        HStack(spacing: 4) {
            chevronButton(systemName: "chevron.left") {
                withAnimation(AppAnimation.snappy) {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                }
            }

            Spacer()

            Text(monthYearString)
                .font(.title3.bold())
                .contentTransition(.numericText())
                .id(monthYearString)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))

            Spacer()

            chevronButton(systemName: "chevron.right") {
                withAnimation(AppAnimation.snappy) {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                }
            }
        }
    }

    private func chevronButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(
                    Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Calendar Grid

struct CalendarGrid: View {
    let displayedMonth: Date
    @Binding var selectedDate: Date
    var store: DataStore

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: 6) {
            // Wochentage-Header
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(WeekdayHelper.abbreviations, id: \.self) { day in
                    Text(day)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .frame(height: 20)
                }
            }

            // Tage
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasKlassenarbeit: store.hasKlassenarbeit(on: date),
                            colors: store.eventColors(on: date),
                            studyMinutes: store.dayStudyMinutes(on: date),
                            itemCount: store.dayItemCount(on: date),
                            holidayName: store.holidayName(on: date)
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedDate = date
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
    }

    private func daysInMonth() -> [Date?] {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstDay = calendar.date(from: components) else { return [] }

        var weekday = calendar.component(.weekday, from: firstDay)
        weekday = weekday == 1 ? 7 : weekday - 1

        guard let range = calendar.range(of: .day, in: .month, for: firstDay) else { return [] }

        var days: [Date?] = Array(repeating: nil, count: weekday - 1)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        return days
    }
}

// MARK: - Day Cell

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasKlassenarbeit: Bool
    let colors: [Color]
    let studyMinutes: Int
    let itemCount: Int
    var holidayName: String? = nil

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(.subheadline, design: .rounded, weight: (isToday || hasKlassenarbeit) ? .bold : .medium))
                .foregroundStyle(foregroundColorForKA)

            if studyMinutes > 0 {
                Text("\(studyMinutes)m")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .purple)
            } else if !colors.isEmpty {
                HStack(spacing: 2) {
                    ForEach(Array(colors.prefix(3).enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(isSelected ? .white : color)
                            .frame(width: 5, height: 5)
                    }
                }
            } else {
                // Platzhalter damit Zellen gleich hoch bleiben
                Color.clear.frame(height: 5)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var foregroundColor: Color {
        if isSelected { return .white }
        if isToday { return .blue }
        return .primary
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 10)
                .fill(hasKlassenarbeit ? Color.red : Color.blue)
                .shadow(color: (hasKlassenarbeit ? Color.red : Color.blue).opacity(0.35), radius: 3, y: 1)
        } else if isToday {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(hasKlassenarbeit ? Color.red : Color.blue, lineWidth: 1.5)
                .background(RoundedRectangle(cornerRadius: 10).fill((hasKlassenarbeit ? Color.red : Color.blue).opacity(0.08)))
        } else if hasKlassenarbeit {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.red.opacity(0.15))
        } else if itemCount > 0 || studyMinutes > 0 {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemFill))
        } else if holidayName != nil {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.green.opacity(0.1))
        } else {
            Color.clear
        }
    }

    private var foregroundColorForKA: Color {
        if isSelected { return .white }
        if hasKlassenarbeit && !isToday { return .red }
        return foregroundColor
    }
}

// MARK: - Day Detail Section

struct DayDetailSection: View {
    let date: Date
    var store: DataStore
    var onAddSession: () -> Void

    @State private var entryToEdit: CalendarEntry?
    @State private var entryToDelete: CalendarEntry?
    @State private var entryToGrade: CalendarEntry?
    @State private var gradeInput: Double = 3.0
    @State private var entryToLogTime: CalendarEntry?
    @State private var minutesInput: Int = 30
    @State private var sessionToEdit: StudySession?

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d. MMMM"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Ferien-Banner mit Gradient
            if let holiday = store.holidayName(on: date) {
                HStack(spacing: 8) {
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            LinearGradient(colors: [.orange, .yellow],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )
                    Text(holiday)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("Ferien")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(colors: [Color.orange.opacity(0.10), Color.yellow.opacity(0.04)],
                                   startPoint: .leading, endPoint: .trailing)
                )
            }

            // Kompakter Tages-Header — Datum klein als Sub-Label, Lernzeit
            // als dezenter Pill rechts. Hauptfokus liegt jetzt auf der Liste
            // darunter, nicht auf dem Header.
            HStack(spacing: 8) {
                Text(dateString)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                let dayMinutes = store.totalMinutes(in: store.sessions(for: date))
                if dayMinutes > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                        Text(formatHoursMinutes(dayMinutes))
                            .font(.caption.bold().monospacedDigit())
                    }
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.12), in: Capsule())
                }
                Button {
                    onAddSession()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.purple)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            let dayEntries = store.entries(for: date)
            let dayRecurring = store.recurringTasks(for: date)
            let daySessions = store.sessions(for: date)

            if dayEntries.isEmpty && dayRecurring.isEmpty && daySessions.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "book.closed")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("Keine Einträge")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    if !dayRecurring.isEmpty {
                        Section("Daueraufgaben") {
                            ForEach(dayRecurring) { task in
                                HStack(spacing: 10) {
                                    Image(systemName: "repeat")
                                        .foregroundStyle(.green)
                                    Text(task.title)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("Dauerhaft")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.green.opacity(0.15), in: Capsule())
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    if !dayEntries.isEmpty {
                        Section("Einträge") {
                            ForEach(dayEntries) { entry in
                                EntryRow(entry: entry) {
                                    if entry.type == .klassenarbeit && !entry.isCompleted {
                                        // Klassenarbeit abhaken -> Note abfragen
                                        gradeInput = entry.grade ?? 3.0
                                        entryToGrade = entry
                                    } else if entry.type == .lerntag && !entry.isCompleted {
                                        // Lerntag abhaken -> Lernzeit abfragen
                                        minutesInput = 30
                                        entryToLogTime = entry
                                    } else {
                                        store.toggleCompleted(entry)
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        entryToEdit = entry
                                    } label: {
                                        Label("Bearbeiten", systemImage: "pencil")
                                    }
                                    if entry.type == .klassenarbeit {
                                        Button {
                                            gradeInput = entry.grade ?? 3.0
                                            entryToGrade = entry
                                        } label: {
                                            Label("Note eingeben", systemImage: "graduationcap")
                                        }
                                    }
                                    Button(role: .destructive) {
                                        entryToDelete = entry
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        entryToDelete = entry
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    if entry.type == .klassenarbeit {
                                        Button {
                                            gradeInput = entry.grade ?? 3.0
                                            entryToGrade = entry
                                        } label: {
                                            Label("Note", systemImage: "graduationcap")
                                        }
                                        .tint(.purple)
                                    }
                                }
                            }
                        }
                    }

                    // Shared entries from parents
                    let sharedForDay = store.sharedCalendarEntries.filter {
                        Calendar.current.isDate($0.date, inSameDayAs: date)
                    }
                    if !sharedForDay.isEmpty {
                        Section("Von Eltern eingetragen") {
                            ForEach(sharedForDay) { shared in
                                HStack(spacing: 10) {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundStyle(.red)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Text(shared.title)
                                                .font(.subheadline.bold())
                                            Image(systemName: "person.2.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.blue)
                                        }
                                        if !shared.subject.isEmpty {
                                            Text(shared.subject)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(shared.date, format: .dateTime.hour().minute())
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    if !daySessions.isEmpty {
                        Section("Lernzeiten") {
                            ForEach(daySessions) { session in
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
                                .padding(.vertical, 2)
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
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .sheet(item: $entryToEdit) { entry in
            EditEntryView(entry: entry, store: store)
        }
        .sheet(item: $sessionToEdit) { session in
            EditStudySessionView(store: store, session: session)
        }
        .alert("Eintrag löschen?", isPresented: Binding(
            get: { entryToDelete != nil },
            set: { if !$0 { entryToDelete = nil } }
        )) {
            Button("Abbrechen", role: .cancel) { entryToDelete = nil }
            Button("Löschen", role: .destructive) {
                if let entry = entryToDelete {
                    store.deleteEntry(entry)
                    entryToDelete = nil
                }
            }
        } message: {
            if let entry = entryToDelete {
                Text("\"\(entry.title)\" wirklich löschen?")
            }
        }
        .alert("Note eintragen", isPresented: Binding(
            get: { entryToGrade != nil },
            set: { if !$0 { entryToGrade = nil } }
        )) {
            TextField("Note", value: $gradeInput, format: .number)
                .keyboardType(.decimalPad)
            Button("Speichern") {
                if let entry = entryToGrade {
                    let clamped = min(max(gradeInput, 1.0), 6.0)
                    store.setGrade(for: entry, grade: clamped)
                    if !entry.isCompleted {
                        store.toggleCompleted(entry)
                    }
                    entryToGrade = nil
                }
            }
            Button("Ohne Note abhaken") {
                if let entry = entryToGrade {
                    if !entry.isCompleted {
                        store.toggleCompleted(entry)
                    }
                    entryToGrade = nil
                }
            }
            Button("Abbrechen", role: .cancel) { entryToGrade = nil }
        } message: {
            if let entry = entryToGrade {
                Text("Welche Note hast du für \"\(entry.title)\" bekommen? (1-6)")
            }
        }
        .alert("Wie lange hast du gelernt?", isPresented: Binding(
            get: { entryToLogTime != nil },
            set: { if !$0 { entryToLogTime = nil } }
        )) {
            TextField("Minuten", value: $minutesInput, format: .number)
                .keyboardType(.numberPad)
            Button("Speichern") {
                if let entry = entryToLogTime {
                    let mins = max(minutesInput, 1)
                    let session = StudySession(
                        subject: entry.title,
                        date: entry.date,
                        minutes: mins
                    )
                    store.addSession(session)
                    store.toggleCompleted(entry)
                    entryToLogTime = nil
                }
            }
            Button("Ohne Lernzeit abhaken") {
                if let entry = entryToLogTime {
                    store.toggleCompleted(entry)
                    entryToLogTime = nil
                }
            }
            Button("Abbrechen", role: .cancel) { entryToLogTime = nil }
        } message: {
            if let entry = entryToLogTime {
                Text("Wie viele Minuten hast du für \"\(entry.title)\" gelernt?")
            }
        }
    }
}

// MARK: - Entry Row

struct EntryRow: View {
    let entry: CalendarEntry
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon-Plakette mit Type-Farbe
            Image(systemName: entry.type.icon)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(colors: [entry.type.color, entry.type.color.opacity(0.75)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .shadow(color: entry.type.color.opacity(0.3), radius: 3, x: 0, y: 1)
                .opacity(entry.isCompleted ? 0.45 : 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.subheadline.bold())
                    .strikethrough(entry.isCompleted)
                    .foregroundStyle(entry.isCompleted ? .secondary : .primary)

                HStack(spacing: 6) {
                    Text(entry.type.rawValue)
                        .font(.caption2)
                        .foregroundStyle(entry.type.color)
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(entry.date, format: .dateTime.hour().minute())
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if entry.reminderEnabled {
                        Image(systemName: "bell.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    if !entry.notes.isEmpty {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(entry.notes)
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if let grade = entry.grade {
                Text(gradeString(grade))
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(gradeColor(grade))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(gradeColor(grade).opacity(0.15), in: Capsule())
            }

            Button {
                onToggle()
            } label: {
                Image(systemName: entry.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(entry.isCompleted ? .green : .secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
