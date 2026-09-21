import SwiftUI

// MARK: - DataStore

@Observable
final class DataStore {
    var entries: [CalendarEntry] = [] {
        didSet { saveEntries() }
    }
    var recurringTasks: [RecurringTask] = [] {
        didSet { saveRecurring() }
    }
    var studySessions: [StudySession] = [] {
        didSet { saveSessions() }
    }
    var grades: [Grade] = [] {
        didSet { saveGrades() }
    }
    var subjects: [Subject] = [] {
        didSet { saveSubjects() }
    }
    var schoolYears: [SchoolYear] = [] {
        didSet { saveSchoolYears() }
    }

    var selectedBundesland: Bundesland? = nil {
        didSet { saveBundesland() }
    }
    var showHolidays: Bool = true {
        didSet { store.set(showHolidays, forKey: showHolidaysKey) }
    }

    var appMode: AppMode? = nil {
        didSet { saveAppMode() }
    }
    var familyLink: FamilyLink? = nil {
        didSet {
            saveFamilyLink()
            UserDefaults.standard.set(familyLink?.pairingCode, forKey: "currentPairingCodeBridge")
        }
    }
    var familyLinks: [FamilyLink] = [] {
        didSet {
            saveFamilyLinks()
            // Parent mode: bridge the FIRST active child code as the default.
            if let first = familyLinks.first(where: { $0.isActive }) {
                UserDefaults.standard.set(first.pairingCode, forKey: "currentPairingCodeBridge")
            }
        }
    }
    var studyGoal: StudyGoal? = nil {
        didSet { saveStudyGoal() }
    }
    var studyGoals: [String: StudyGoal] = [:] {
        didSet { saveStudyGoals() }
    }
    var parentalPIN: String? = nil {
        didSet { saveParentalPIN() }
    }
    var motivationMessage: MotivationMessage? = nil {
        didSet { saveMotivationMessage() }
    }
    var sharedCalendarEntries: [SharedCalendarEntry] = [] {
        didSet { saveSharedEntries() }
    }
    var streakState: StreakState = StreakState() {
        didSet { saveStreakState() }
    }
    var homework: [Homework] = [] {
        didSet { saveHomework() }
    }
    var timetable: [TimetableSlot] = [] {
        didSet { saveTimetable() }
    }

    private let entriesKey = "calendarEntries"
    private let recurringKey = "recurringTasks"
    private let sessionsKey = "studySessions"
    private let gradesKey = "grades"
    private let subjectsKey = "subjects"
    private let schoolYearsKey = "schoolYears"
    private let bundeslandKey = "selectedBundesland"
    private let showHolidaysKey = "showHolidays"
    private let appModeKey = "appMode"
    private let familyLinkKey = "familyLink"
    private let studyGoalKey = "studyGoal"
    private let familyLinksKey = "familyLinks"
    private let studyGoalsKey = "studyGoals"
    private let parentalPINKey = "parentalPIN"
    private let motivationMessageKey = "motivationMessage"
    private let sharedEntriesKey = "sharedCalendarEntries"
    private let streakStateKey = "streakState"
    private let homeworkKey = "homework"
    private let timetableKey = "timetable"

    private let store = NSUbiquitousKeyValueStore.default

    private static let migrationKey = "didMigrateToiCloud"

    init() {
        store.synchronize()

        // Migration: Daten von UserDefaults nach iCloud kopieren (einmalig)
        if !UserDefaults.standard.bool(forKey: Self.migrationKey) {
            migrateFromUserDefaults()
            UserDefaults.standard.set(true, forKey: Self.migrationKey)
        }

        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] _ in
            self?.loadAll()
        }

        loadAll()
    }

    private func migrateFromUserDefaults() {
        let ud = UserDefaults.standard
        let keys = [entriesKey, recurringKey, sessionsKey, gradesKey, subjectsKey,
                    schoolYearsKey, familyLinkKey, studyGoalKey, familyLinksKey,
                    studyGoalsKey, motivationMessageKey, sharedEntriesKey]
        for key in keys {
            if let data = ud.data(forKey: key), store.data(forKey: key) == nil {
                store.set(data, forKey: key)
            }
        }
        // String-basierte Keys
        if let bl = ud.string(forKey: bundeslandKey), store.string(forKey: bundeslandKey) == nil {
            store.set(bl, forKey: bundeslandKey)
        }
        if let mode = ud.string(forKey: appModeKey), store.string(forKey: appModeKey) == nil {
            store.set(mode, forKey: appModeKey)
        }
        if let pin = ud.string(forKey: parentalPINKey), store.string(forKey: parentalPINKey) == nil {
            store.set(pin, forKey: parentalPINKey)
        }
        if ud.object(forKey: showHolidaysKey) != nil && store.object(forKey: showHolidaysKey) == nil {
            store.set(ud.bool(forKey: showHolidaysKey), forKey: showHolidaysKey)
        }
        store.synchronize()
    }

    private func loadAll() {
        if let data = store.data(forKey: entriesKey),
           let decoded = try? JSONDecoder().decode([CalendarEntry].self, from: data) {
            entries = decoded
        }
        if let data = store.data(forKey: recurringKey),
           let decoded = try? JSONDecoder().decode([RecurringTask].self, from: data) {
            recurringTasks = decoded
        }
        if let data = store.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([StudySession].self, from: data) {
            studySessions = decoded
        }
        if let data = store.data(forKey: gradesKey),
           let decoded = try? JSONDecoder().decode([Grade].self, from: data) {
            grades = decoded
        }
        if let data = store.data(forKey: subjectsKey),
           let decoded = try? JSONDecoder().decode([Subject].self, from: data) {
            subjects = decoded
        }
        if let data = store.data(forKey: schoolYearsKey),
           let decoded = try? JSONDecoder().decode([SchoolYear].self, from: data) {
            schoolYears = decoded
        }
        if let blString = store.string(forKey: bundeslandKey),
           let bl = Bundesland(rawValue: blString) {
            selectedBundesland = bl
        }
        showHolidays = store.object(forKey: showHolidaysKey) as? Bool ?? true
        if let modeString = store.string(forKey: appModeKey),
           let mode = AppMode(rawValue: modeString) {
            appMode = mode
        }
        if let data = store.data(forKey: familyLinkKey),
           let decoded = try? JSONDecoder().decode(FamilyLink.self, from: data) {
            familyLink = decoded
        }
        if let data = store.data(forKey: studyGoalKey),
           let decoded = try? JSONDecoder().decode(StudyGoal.self, from: data) {
            studyGoal = decoded
        }
        if let data = store.data(forKey: familyLinksKey),
           let decoded = try? JSONDecoder().decode([FamilyLink].self, from: data) {
            familyLinks = decoded
        }
        // Migration: if old single familyLink exists and familyLinks is empty, migrate it
        if familyLinks.isEmpty, let link = familyLink, appMode == .parent {
            familyLinks = [link]
        }
        if let data = store.data(forKey: studyGoalsKey),
           let decoded = try? JSONDecoder().decode([String: StudyGoal].self, from: data) {
            studyGoals = decoded
        }
        // Migration: if old single studyGoal exists, migrate it
        if studyGoals.isEmpty, let goal = studyGoal, let link = familyLink {
            studyGoals[link.pairingCode] = goal
        }
        if let pin = store.string(forKey: parentalPINKey) {
            parentalPIN = pin
        }
        if let data = store.data(forKey: motivationMessageKey),
           let decoded = try? JSONDecoder().decode(MotivationMessage.self, from: data) {
            motivationMessage = decoded
        }
        if let data = store.data(forKey: sharedEntriesKey),
           let decoded = try? JSONDecoder().decode([SharedCalendarEntry].self, from: data) {
            sharedCalendarEntries = decoded
        }
        if let data = store.data(forKey: streakStateKey),
           let decoded = try? JSONDecoder().decode(StreakState.self, from: data) {
            streakState = decoded
        }
        if let data = store.data(forKey: homeworkKey),
           let decoded = try? JSONDecoder().decode([Homework].self, from: data) {
            homework = decoded
        }
        if let data = store.data(forKey: timetableKey),
           let decoded = try? JSONDecoder().decode([TimetableSlot].self, from: data) {
            timetable = decoded
        }
    }

    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) { store.set(data, forKey: entriesKey) }
    }
    private func saveRecurring() {
        if let data = try? JSONEncoder().encode(recurringTasks) { store.set(data, forKey: recurringKey) }
    }
    private func saveSessions() {
        if let data = try? JSONEncoder().encode(studySessions) { store.set(data, forKey: sessionsKey) }
    }
    private func saveGrades() {
        if let data = try? JSONEncoder().encode(grades) { store.set(data, forKey: gradesKey) }
    }
    private func saveSubjects() {
        if let data = try? JSONEncoder().encode(subjects) { store.set(data, forKey: subjectsKey) }
    }
    private func saveSchoolYears() {
        if let data = try? JSONEncoder().encode(schoolYears) { store.set(data, forKey: schoolYearsKey) }
    }
    private func saveBundesland() {
        if let bl = selectedBundesland { store.set(bl.rawValue, forKey: bundeslandKey) }
        else { store.removeObject(forKey: bundeslandKey) }
    }
    private func saveAppMode() {
        if let mode = appMode { store.set(mode.rawValue, forKey: appModeKey) }
        else { store.removeObject(forKey: appModeKey) }
    }
    private func saveFamilyLink() {
        if let link = familyLink, let data = try? JSONEncoder().encode(link) { store.set(data, forKey: familyLinkKey) }
        else { store.removeObject(forKey: familyLinkKey) }
    }
    private func saveStudyGoal() {
        if let goal = studyGoal, let data = try? JSONEncoder().encode(goal) { store.set(data, forKey: studyGoalKey) }
        else { store.removeObject(forKey: studyGoalKey) }
    }
    private func saveFamilyLinks() {
        if let data = try? JSONEncoder().encode(familyLinks) { store.set(data, forKey: familyLinksKey) }
    }
    private func saveStudyGoals() {
        if let data = try? JSONEncoder().encode(studyGoals) { store.set(data, forKey: studyGoalsKey) }
    }
    private func saveParentalPIN() {
        if let pin = parentalPIN { store.set(pin, forKey: parentalPINKey) }
        else { store.removeObject(forKey: parentalPINKey) }
    }
    private func saveMotivationMessage() {
        if let msg = motivationMessage, let data = try? JSONEncoder().encode(msg) { store.set(data, forKey: motivationMessageKey) }
        else { store.removeObject(forKey: motivationMessageKey) }
    }
    private func saveSharedEntries() {
        if let data = try? JSONEncoder().encode(sharedCalendarEntries) { store.set(data, forKey: sharedEntriesKey) }
    }
    private func saveStreakState() {
        if let data = try? JSONEncoder().encode(streakState) { store.set(data, forKey: streakStateKey) }
    }
    private func saveHomework() {
        if let data = try? JSONEncoder().encode(homework) { store.set(data, forKey: homeworkKey) }
    }

    // MARK: Homework helpers

    func addHomework(_ hw: Homework) { homework.append(hw) }
    func updateHomework(_ hw: Homework) {
        if let idx = homework.firstIndex(where: { $0.id == hw.id }) { homework[idx] = hw }
    }
    func deleteHomework(_ hw: Homework) {
        // Anhänge lokal aufräumen
        for path in hw.attachmentRelativePaths {
            AttachmentStore.delete(relativePath: path)
        }
        homework.removeAll { $0.id == hw.id }
    }
    func toggleHomeworkDone(_ hw: Homework) {
        if let idx = homework.firstIndex(where: { $0.id == hw.id }) { homework[idx].isDone.toggle() }
    }

    /// Offene Hausaufgaben, älteste zuerst (überfällig oben).
    func openHomework() -> [Homework] {
        homework.filter { !$0.isDone }.sorted { $0.dueDate < $1.dueDate }
    }
    func homeworkFor(subject: String) -> [Homework] {
        homework.filter { $0.subject.localizedCaseInsensitiveCompare(subject) == .orderedSame }
            .sorted { $0.dueDate < $1.dueDate }
    }
    func upcomingHomework(within days: Int = 7) -> [Homework] {
        let cal = Calendar.current
        let now = Date()
        let until = cal.date(byAdding: .day, value: days, to: now) ?? now
        return homework.filter { !$0.isDone && $0.dueDate <= until }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private func saveTimetable() {
        if let data = try? JSONEncoder().encode(timetable) { store.set(data, forKey: timetableKey) }
    }

    // MARK: Timetable helpers

    func addSlot(_ s: TimetableSlot) { timetable.append(s) }
    func updateSlot(_ s: TimetableSlot) {
        if let idx = timetable.firstIndex(where: { $0.id == s.id }) { timetable[idx] = s }
    }
    func deleteSlot(_ s: TimetableSlot) { timetable.removeAll { $0.id == s.id } }
    func slotsFor(weekday: Int) -> [TimetableSlot] {
        timetable.filter { $0.weekday == weekday }
            .sorted { ($0.lesson, $0.startTime) < ($1.lesson, $1.startTime) }
    }

    /// Slots für ein konkretes Datum: bevorzugt date-gebundene Webuntis-
    /// Einträge, ergänzt durch wiederkehrende (date == nil), wenn an dem
    /// Wochentag keine konkrete Stunde liegt.
    func slotsFor(date: Date) -> [TimetableSlot] {
        let cal = Calendar.current
        var wd = cal.component(.weekday, from: date)
        wd = wd == 1 ? 7 : wd - 1
        let dated = timetable.filter { slot in
            guard let d = slot.date else { return false }
            return cal.isDate(d, inSameDayAs: date)
        }
        if !dated.isEmpty {
            return dated.sorted { $0.startTime < $1.startTime }
        }
        return timetable.filter { $0.date == nil && $0.weekday == wd }
            .sorted { $0.startTime < $1.startTime }
    }

    func todaySlots() -> [TimetableSlot] {
        slotsFor(date: Date())
    }

    // MARK: Holiday helpers

    func holidayName(on date: Date) -> String? {
        guard showHolidays, let bundesland = selectedBundesland else { return nil }
        let cal = Calendar.current
        let checkDate = cal.startOfDay(for: date)
        for holiday in SchoolHolidayData.holidays(for: bundesland) {
            let start = cal.startOfDay(for: holiday.start)
            let end = cal.startOfDay(for: holiday.end)
            if checkDate >= start && checkDate <= end { return holiday.name }
        }
        return nil
    }

    // MARK: SchoolYear helpers

    func addSchoolYear(_ schoolYear: SchoolYear) { schoolYears.append(schoolYear) }

    func deleteSchoolYear(_ schoolYear: SchoolYear) {
        for i in subjects.indices where subjects[i].schoolYearId == schoolYear.id {
            subjects[i].schoolYearId = nil
        }
        schoolYears.removeAll { $0.id == schoolYear.id }
    }

    func updateSchoolYear(_ schoolYear: SchoolYear) {
        if let idx = schoolYears.firstIndex(where: { $0.id == schoolYear.id }) { schoolYears[idx] = schoolYear }
    }

    func toggleArchiveSchoolYear(_ schoolYear: SchoolYear) {
        if let idx = schoolYears.firstIndex(where: { $0.id == schoolYear.id }) { schoolYears[idx].isArchived.toggle() }
    }

    func subjectsFor(schoolYear: SchoolYear) -> [Subject] { subjects.filter { $0.schoolYearId == schoolYear.id } }
    func unassignedSubjects() -> [Subject] { subjects.filter { $0.schoolYearId == nil } }
    /// Fächer des aktiven Schuljahres plus nicht zugeordnete – für Statistiken,
    /// damit alte Schuljahre nicht mitgezählt werden.
    func activeSubjects() -> [Subject] {
        guard let active = activeSchoolYear() else { return subjects }
        return subjects.filter { $0.schoolYearId == active.id || $0.schoolYearId == nil }
    }
    /// Aktives Schuljahr: das nicht-archivierte, in dessen Zeitraum heute liegt;
    /// sonst das neueste nicht-archivierte.
    func activeSchoolYear() -> SchoolYear? {
        // Neuestes zuerst: überlappen sich altes und neues Jahr (z. B. altes
        // endet erst Ende September), gewinnt das später gestartete.
        let candidates = schoolYears.filter { !$0.isArchived }.sorted { $0.startDate > $1.startDate }
        let now = Date()
        if let current = candidates.first(where: { dateRange(of: $0).contains(now) }) { return current }
        return candidates.first
    }

    // MARK: Entry helpers

    func entries(for date: Date) -> [CalendarEntry] {
        let cal = Calendar.current
        return entries.filter { cal.isDate($0.date, inSameDayAs: date) }.sorted { $0.date < $1.date }
    }

    func addEntry(_ entry: CalendarEntry) {
        entries.append(entry)
        NotificationHelper.schedule(for: entry)
        syncToCloudIfNeeded()
    }

    func updateEntry(_ entry: CalendarEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            NotificationHelper.remove(for: entries[idx])
            entries[idx] = entry
            NotificationHelper.schedule(for: entry)
            syncToCloudIfNeeded()
        }
    }

    func deleteEntry(_ entry: CalendarEntry) {
        NotificationHelper.remove(for: entry)
        entries.removeAll { $0.id == entry.id }
        syncToCloudIfNeeded()
    }

    func toggleCompleted(_ entry: CalendarEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) { entries[idx].isCompleted.toggle() }
    }

    func setGrade(for entry: CalendarEntry, grade: Double) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) { entries[idx].grade = grade }
    }

    /// Noten für einen Fach-Namen. Ohne expliziten Zeitraum wird auf das
    /// aktive Schuljahr eingeschränkt, damit alte Noten nicht ins neue Jahr
    /// durchrutschen (Fächer werden nur über den Namen zugeordnet).
    func gradesForSubject(_ subject: String, in range: ClosedRange<Date>? = nil) -> [(date: Date, grade: Double, type: GradeType)] {
        let range = range ?? activeSchoolYear().map(dateRange(of:))
        var result: [(date: Date, grade: Double, type: GradeType)] = entries
            .filter { $0.type == .klassenarbeit && $0.grade != nil && $0.title.localizedCaseInsensitiveContains(subject) }
            .filter { inRange($0.date, range) }
            .compactMap { entry in
                guard let grade = entry.grade else { return nil }
                return (date: entry.date, grade: grade, type: GradeType.schriftlich)
            }
        result += grades
            .filter { $0.subject.localizedCaseInsensitiveContains(subject) && inRange($0.date, range) }
            .map { (date: $0.date, grade: $0.grade, type: $0.type) }
        return result.sorted { $0.date < $1.date }
    }

    // MARK: School year ranges

    /// Zeitraum eines Schuljahres, jeweils auf ganze Tage gerundet.
    func dateRange(of schoolYear: SchoolYear) -> ClosedRange<Date> {
        let cal = Calendar.current
        let start = cal.startOfDay(for: schoolYear.startDate)
        let endDay = cal.startOfDay(for: schoolYear.endDate)
        let end = cal.date(byAdding: DateComponents(day: 1, second: -1), to: endDay) ?? schoolYear.endDate
        return start...max(start, end)
    }

    /// Zeitraum des Schuljahres, dem ein Fach zugeordnet ist (nil = kein Schuljahr → alles).
    func dateRange(for subject: Subject) -> ClosedRange<Date>? {
        guard let id = subject.schoolYearId, let sy = schoolYears.first(where: { $0.id == id }) else { return nil }
        return dateRange(of: sy)
    }

    private func inRange(_ date: Date, _ range: ClosedRange<Date>?) -> Bool {
        guard let range else { return true }
        return range.contains(date)
    }

    /// Fächer, zu denen es Noten gibt – ohne Zeitraum nur im aktiven Schuljahr.
    func allGradeSubjects(in range: ClosedRange<Date>? = nil) -> [String] {
        let range = range ?? activeSchoolYear().map(dateRange(of:))
        var subjects = Set(entries.filter { $0.type == .klassenarbeit && $0.grade != nil && inRange($0.date, range) }.map { $0.title })
        for g in grades where inRange(g.date, range) { subjects.insert(g.subject) }
        return subjects.sorted()
    }

    func hasKlassenarbeit(on date: Date) -> Bool {
        let cal = Calendar.current
        return entries.contains { $0.type == .klassenarbeit && cal.isDate($0.date, inSameDayAs: date) }
    }

    // MARK: Grade helpers

    func addGrade(_ grade: Grade) {
        grades.append(grade)
        Task { @MainActor in
            WeaknessEngine.shared.recordGrade(grade.grade, subject: grade.subject)
            NotificationCenter.default.post(name: .weaknessUpdated, object: nil)
        }
        syncToCloudIfNeeded()
        sendGradeNotification(grade)
    }

    private func sendGradeNotification(_ grade: Grade) {
        guard appMode == .student, let link = familyLink, link.isActive else { return }
        Task {
            await CloudKitService.shared.sendActivityNotification(
                type: "grade",
                message: "Neue Note: \(grade.subject) \(gradeString(grade.grade))",
                pairingCode: link.pairingCode
            )
        }
    }

    func deleteGrade(_ grade: Grade) {
        grades.removeAll { $0.id == grade.id }
        syncToCloudIfNeeded()
    }

    func uniqueGradeSubjects() -> [String] {
        var subjects = Set(grades.map { $0.subject })
        for entry in entries where entry.type == .klassenarbeit { subjects.insert(entry.title) }
        return subjects.sorted()
    }

    // MARK: Subject helpers

    func colorForSubject(_ name: String) -> Color {
        if let sub = subjects.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            return sub.color
        }
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .teal, .indigo, .mint, .cyan]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }

    func addSubject(_ subject: Subject) { subjects.append(subject) }

    /// Das Schuljahr, das direkt vor dem angegebenen begann (archiviert oder nicht).
    func previousSchoolYear(before schoolYear: SchoolYear) -> SchoolYear? {
        schoolYears
            .filter { $0.id != schoolYear.id && $0.startDate < schoolYear.startDate }
            .sorted { $0.startDate > $1.startDate }
            .first
    }

    /// Kopiert Name, Icon und Farbe der Fächer aus `source` nach `target`.
    /// Noten/Lernzeiten hängen am Zeitraum und bleiben beim alten Jahr.
    /// Fächer, die es im Ziel schon gibt (Name), werden übersprungen.
    @discardableResult
    func copySubjects(from source: SchoolYear, to target: SchoolYear) -> Int {
        let existing = Set(subjectsFor(schoolYear: target).map { $0.name.lowercased() })
        var copied = 0
        for subject in subjectsFor(schoolYear: source) where !existing.contains(subject.name.lowercased()) {
            subjects.append(Subject(name: subject.name, icon: subject.icon, colorName: subject.colorName, schoolYearId: target.id))
            copied += 1
        }
        return copied
    }

    func deleteSubject(_ subject: Subject) { subjects.removeAll { $0.id == subject.id } }

    func updateSubject(_ subject: Subject) {
        if let idx = subjects.firstIndex(where: { $0.id == subject.id }) { subjects[idx] = subject }
    }

    func gradesFor(subject: Subject) -> [(date: Date, grade: Double, type: GradeType)] {
        gradesForSubject(subject.name, in: dateRange(for: subject))
    }

    func studyMinutesFor(subject: Subject) -> Int {
        sessionsFor(subject: subject).reduce(0) { $0 + $1.minutes }
    }

    func sessionsFor(subject: Subject) -> [StudySession] {
        let range = dateRange(for: subject)
        return studySessions
            .filter { $0.subject.localizedCaseInsensitiveCompare(subject.name) == .orderedSame && inRange($0.date, range) }
            .sorted { $0.date > $1.date }
    }

    func entriesFor(subject: Subject) -> [CalendarEntry] {
        let range = dateRange(for: subject)
        return entries
            .filter { $0.title.localizedCaseInsensitiveContains(subject.name) && inRange($0.date, range) }
            .sorted { $0.date > $1.date }
    }

    // MARK: Recurring helpers

    func recurringTasks(for date: Date) -> [RecurringTask] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        return recurringTasks.filter { $0.isActive && $0.weekdays.contains(weekday) }
    }

    func addRecurringTask(_ task: RecurringTask) { recurringTasks.append(task) }
    func deleteRecurringTask(_ task: RecurringTask) { recurringTasks.removeAll { $0.id == task.id } }
    func toggleRecurringTask(_ task: RecurringTask) {
        if let idx = recurringTasks.firstIndex(where: { $0.id == task.id }) { recurringTasks[idx].isActive.toggle() }
    }

    // MARK: Event colors

    func eventColors(on date: Date) -> [Color] {
        var colors: [Color] = []
        let dayEntries = entries(for: date)
        for type in EventType.allCases {
            if dayEntries.contains(where: { $0.type == type }) { colors.append(type.color) }
        }
        if !recurringTasks(for: date).isEmpty { colors.append(.green) }
        if !sessions(for: date).isEmpty { colors.append(.purple) }
        return colors
    }

    // MARK: Day info for calendar

    func dayStudyMinutes(on date: Date) -> Int { totalMinutes(in: sessions(for: date)) }
    func dayItemCount(on date: Date) -> Int { entries(for: date).count + recurringTasks(for: date).count }

    // MARK: Cloud Sync

    func syncToCloudIfNeeded() {
        guard appMode == .student, let link = familyLink, link.isActive else { return }
        Task { await CloudKitService.shared.syncStudentData(from: self) }
    }

    // MARK: Goal progress

    func dailyGoalProgress(for date: Date) -> Double {
        guard let goal = studyGoal, goal.dailyMinutesGoal > 0 else { return 0 }
        return Double(dayStudyMinutes(on: date)) / Double(goal.dailyMinutesGoal)
    }

    func weeklyGoalProgress() -> Double {
        guard let goal = studyGoal, goal.weeklyMinutesGoal > 0 else { return 0 }
        return Double(weeklyTotalMinutes(weekOffset: 0)) / Double(goal.weeklyMinutesGoal)
    }

    // MARK: Week helpers

    func sessionsForWeek(weekOffset: Int) -> [StudySession] {
        let cal = Calendar.current
        let now = Date()
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start,
              let offsetStart = cal.date(byAdding: .weekOfYear, value: weekOffset, to: weekStart),
              let offsetEnd = cal.date(byAdding: .weekOfYear, value: 1, to: offsetStart) else { return [] }
        return sessionsInRange(from: offsetStart, to: offsetEnd)
    }

    func weeklyTotalMinutes(weekOffset: Int) -> Int { totalMinutes(in: sessionsForWeek(weekOffset: weekOffset)) }

    func gradesForWeek(weekOffset: Int) -> [Grade] {
        let cal = Calendar.current
        let now = Date()
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start,
              let offsetStart = cal.date(byAdding: .weekOfYear, value: weekOffset, to: weekStart),
              let offsetEnd = cal.date(byAdding: .weekOfYear, value: 1, to: offsetStart) else { return [] }
        return grades.filter { $0.date >= offsetStart && $0.date < offsetEnd }
    }

    // MARK: StudySession helpers

    func addSession(_ session: StudySession) {
        // Duplicate guard: skip if an identical session (same subject, same
        // minutes, same calendar day) was already added in the last 60 seconds.
        let cal = Calendar.current
        let isDuplicate = studySessions.contains { existing in
            existing.subject == session.subject &&
            existing.minutes == session.minutes &&
            cal.isDate(existing.date, inSameDayAs: session.date) &&
            abs(existing.date.timeIntervalSinceNow) < 60
        }
        if isDuplicate { return }

        studySessions.append(session)
        // Wenn die Session auf einen Tag fällt, der bereits per Eis überbrückt
        // wurde, geben wir das Eis zurück — der Tag ist ja nun ein echter
        // Lerntag, das Eis war unnötig.
        refundFreezeIfBridged(for: session.date)
        // Streak-State pflegen: erst Lücken überbrücken, dann neue Freezes vergeben
        recomputeAndConsumeFreezes()
        processFreezeAwards()
        // Tägliche Erinnerung für heute zurückziehen (heute wurde ja schon gelernt)
        NotificationHelper.cancelDailyReminderForToday()
        syncToCloudIfNeeded()
        sendSessionNotification(session)
        // XP vergeben und Challenges prüfen
        LearningEngine.shared.earnXP(LearningEngine.shared.xpForStudyTime(minutes: session.minutes), subject: session.subject)
        LearningEngine.shared.checkChallenges(store: self)
    }

    /// Schickt am Wochenende einmal pro Woche einen Wochenbericht als Push
    /// an die Eltern (über den ActivityNotification-Record). Läuft beim
    /// App-Start des Kindes – ohne Öffnen der App gibt es keinen Bericht.
    func sendWeeklyParentReportIfDue(now: Date = Date()) {
        guard appMode == .student, let link = familyLink, link.isActive else { return }
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: now)
        guard weekday == 7 || weekday == 1 else { return }   // Samstag oder Sonntag
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        let weekKey = "\(comps.yearForWeekOfYear ?? 0)-\(comps.weekOfYear ?? 0)"
        let sentKey = "lastWeeklyParentReportWeek"
        guard store.string(forKey: sentKey) != weekKey else { return }
        store.set(weekKey, forKey: sentKey)

        let minutes = weeklyTotalMinutes(weekOffset: 0)
        let gradeCount = gradesForWeek(weekOffset: 0).count
        let streak = currentStreak()
        var parts = ["Wochenbericht: \(formatHoursMinutes(minutes)) gelernt"]
        if gradeCount > 0 { parts.append("\(gradeCount) \(gradeCount == 1 ? "neue Note" : "neue Noten")") }
        if streak > 0 { parts.append("Streak \(streak) 🔥") }
        let message = parts.joined(separator: " · ")
        Task {
            await CloudKitService.shared.sendActivityNotification(type: "weekly", message: message, pairingCode: link.pairingCode)
        }
    }

    private func sendSessionNotification(_ session: StudySession) {
        guard appMode == .student, let link = familyLink, link.isActive else { return }
        Task {
            await CloudKitService.shared.sendActivityNotification(
                type: "session",
                message: "\(session.subject) - \(formatHoursMinutes(session.minutes)) gelernt",
                pairingCode: link.pairingCode
            )
        }
    }

    func updateSession(_ session: StudySession) {
        if let idx = studySessions.firstIndex(where: { $0.id == session.id }) { studySessions[idx] = session }
    }

    func deleteSession(_ session: StudySession) {
        studySessions.removeAll { $0.id == session.id }
        // Streak neu prüfen: vielleicht hat der gelöschte Tag eine Lücke
        // hinterlassen, die nun mit Eis überbrückt werden müsste.
        recomputeAndConsumeFreezes()
        syncToCloudIfNeeded()
    }

    func sessions(for date: Date) -> [StudySession] {
        let cal = Calendar.current
        return studySessions.filter { cal.isDate($0.date, inSameDayAs: date) }.sorted { $0.date < $1.date }
    }

    func allSessionsSorted() -> [StudySession] { studySessions.sorted { $0.date > $1.date } }
    func totalMinutes(in sessions: [StudySession]) -> Int { sessions.reduce(0) { $0 + $1.minutes } }
    func sessionsInRange(from start: Date, to end: Date) -> [StudySession] { studySessions.filter { $0.date >= start && $0.date < end } }
    func uniqueSubjects() -> [String] { Array(Set(studySessions.map { $0.subject })).sorted() }

    // MARK: Streak

    /// Datum des allerersten Lerneintrags (Beginn der Messung).
    var firstSessionDate: Date? {
        studySessions.map(\.date).min().map { Calendar.current.startOfDay(for: $0) }
    }

    /// Prüft, ob ein Datum in die Schulferien des gewählten Bundeslandes fällt.
    /// Unabhängig vom `showHolidays`-Toggle (der nur die Anzeige im Kalender steuert).
    func isHolidayDate(_ date: Date) -> Bool {
        guard let bundesland = selectedBundesland else { return false }
        let cal = Calendar.current
        let checkDate = cal.startOfDay(for: date)
        for holiday in SchoolHolidayData.holidays(for: bundesland) {
            let start = cal.startOfDay(for: holiday.start)
            let end = cal.startOfDay(for: holiday.end)
            if checkDate >= start && checkDate <= end { return true }
        }
        return false
    }

    private func freezeUsedSet() -> Set<Date> {
        let cal = Calendar.current
        return Set(streakState.freezeUsedOnDays.map { cal.startOfDay(for: $0) })
    }

    func currentStreak() -> Int {
        let cal = Calendar.current
        let used = freezeUsedSet()
        var streak = 0
        var checkDate = cal.startOfDay(for: Date())

        // Heute leer und kein Feiertag → ab gestern zurückzählen.
        if sessions(for: checkDate).isEmpty {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        let stopBefore = firstSessionDate.map { cal.date(byAdding: .day, value: -1, to: $0) ?? $0 }

        var iter = 0
        while iter < 3650 {
            iter += 1
            if !sessions(for: checkDate).isEmpty {
                streak += 1
            } else if isHolidayDate(checkDate) {
                // Ferien-Tage zählen nicht, brechen aber auch nicht.
            } else if used.contains(checkDate) {
                // Mit Freeze überbrückt — zählt nicht, bricht nicht.
            } else {
                break
            }
            guard let prevDay = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prevDay
            if let stop = stopBefore, checkDate <= stop { break }
        }
        return streak
    }

    /// Gibt ein Eis zurück, wenn das gegebene Datum bereits mit einem
    /// Eis überbrückt wurde — wir brauchen es ja nicht mehr.
    func refundFreezeIfBridged(for date: Date) {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        guard let idx = streakState.freezeUsedOnDays.firstIndex(where: {
            cal.isDate($0, inSameDayAs: day)
        }) else { return }
        var state = streakState
        state.freezeUsedOnDays.remove(at: idx)
        state.freezeCount += 1
        streakState = state
    }

    /// Verbraucht aktiv ein Eis, um den HEUTIGEN Tag zu überbrücken.
    /// Sinnvoll für „Ich skippe heute bewusst — schütze meine Serie jetzt".
    @discardableResult
    func consumeFreezeForToday() -> Bool {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Wenn heute schon gelernt wurde oder schon überbrückt: kein Eis nötig.
        if !sessions(for: today).isEmpty { return false }
        if streakState.freezeUsedOnDays.contains(where: { cal.isDate($0, inSameDayAs: today) }) {
            return false
        }
        guard streakState.freezeCount > 0 else { return false }
        var state = streakState
        state.freezeCount -= 1
        state.freezeUsedOnDays.append(today)
        streakState = state
        return true
    }

    /// Geht von gestern aus rückwärts und schließt offene Lücken automatisch mit Freezes,
    /// solange welche vorhanden sind. Sobald ein Lerntag erreicht ist oder die Freezes
    /// alle sind, hört es auf. Sicher mehrfach aufrufbar (idempotent).
    func recomputeAndConsumeFreezes() {
        guard !studySessions.isEmpty else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard var d = cal.date(byAdding: .day, value: -1, to: today) else { return }

        var state = streakState
        var used = Set(state.freezeUsedOnDays.map { cal.startOfDay(for: $0) })
        let stopBefore = firstSessionDate.map { cal.date(byAdding: .day, value: -1, to: $0) ?? $0 } ?? Date.distantPast

        var changed = false
        var iter = 0
        while iter < 3650 {
            iter += 1
            if d <= stopBefore { break }
            if !sessions(for: d).isEmpty { break }
            if isHolidayDate(d) || used.contains(d) {
                // bereits überbrückt
            } else if state.freezeCount > 0 {
                state.freezeCount -= 1
                used.insert(d)
                state.freezeUsedOnDays.append(d)
                changed = true
            } else {
                break
            }
            guard let prev = cal.date(byAdding: .day, value: -1, to: d) else { break }
            d = prev
        }

        if changed { streakState = state }
    }

    /// Vergibt neue Freezes basierend auf:
    /// - alle 7 Tage in der aktuellen Streak  +1
    /// - alle 300 Minuten Gesamt-Lernzeit    +1
    /// - jedes erreichte Wochenziel          +1
    /// Buckets/Wochen werden persistiert, damit nicht doppelt belohnt wird.
    func processFreezeAwards() {
        var state = streakState
        var changed = false

        // A) Streak-Bucket (alle 7 Tage). Wenn die Serie gebrochen ist, wandert der
        //    Baseline-Bucket auch nach unten — sonst gäbe es nie wieder Eis.
        let newStreakBucket = currentStreak() / 7
        if newStreakBucket > state.awardedStreakBucket {
            state.freezeCount += (newStreakBucket - state.awardedStreakBucket)
            state.awardedStreakBucket = newStreakBucket
            changed = true
        } else if newStreakBucket < state.awardedStreakBucket {
            state.awardedStreakBucket = newStreakBucket
            changed = true
        }

        // B) Gesamt-Minuten-Bucket (alle 300 min)
        let totalMin = studySessions.reduce(0) { $0 + $1.minutes }
        let newMinutesBucket = totalMin / 300
        if newMinutesBucket > state.awardedMinutesBucket {
            state.freezeCount += (newMinutesBucket - state.awardedMinutesBucket)
            state.awardedMinutesBucket = newMinutesBucket
            changed = true
        }

        // C) Wochenziel erreicht
        if let goal = studyGoal, goal.weeklyMinutesGoal > 0 {
            let weeklyMin = weeklyTotalMinutes(weekOffset: 0)
            let weekKey = Self.currentWeekKey()
            if weeklyMin >= goal.weeklyMinutesGoal && !state.awardedWeeks.contains(weekKey) {
                state.freezeCount += 1
                state.awardedWeeks.append(weekKey)
                changed = true
            }
        }

        if changed { streakState = state }
    }

    static func currentWeekKey(for date: Date = Date()) -> String {
        let cal = Calendar(identifier: .iso8601)
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", comps.yearForWeekOfYear ?? 0, comps.weekOfYear ?? 0)
    }

    // MARK: Delete All

    func deleteAllData() {
        for entry in entries { NotificationHelper.remove(for: entry) }
        entries = []
        recurringTasks = []
        studySessions = []
        grades = []
        subjects = []
        schoolYears = []
    }

    func longestStreak() -> Int {
        let cal = Calendar.current
        guard !studySessions.isEmpty else { return 0 }
        let uniqueDays = Set(studySessions.map { cal.startOfDay(for: $0.date) }).sorted()
        guard !uniqueDays.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for i in 1..<uniqueDays.count {
            let diff = cal.dateComponents([.day], from: uniqueDays[i - 1], to: uniqueDays[i]).day ?? 0
            if diff == 1 { current += 1; longest = max(longest, current) }
            else { current = 1 }
        }
        return longest
    }
}
