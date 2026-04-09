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
    var aiAllowed: Bool = true {
        didSet { store.set(aiAllowed, forKey: "aiAllowed") }
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
        if store.object(forKey: "aiAllowed") != nil {
            aiAllowed = store.bool(forKey: "aiAllowed")
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
    func activeSchoolYear() -> SchoolYear? {
        schoolYears.filter { !$0.isArchived }.sorted { $0.startDate > $1.startDate }.first
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

    func gradesForSubject(_ subject: String) -> [(date: Date, grade: Double, type: GradeType)] {
        var result: [(date: Date, grade: Double, type: GradeType)] = entries
            .filter { $0.type == .klassenarbeit && $0.grade != nil && $0.title.localizedCaseInsensitiveContains(subject) }
            .compactMap { entry in
                guard let grade = entry.grade else { return nil }
                return (date: entry.date, grade: grade, type: GradeType.schriftlich)
            }
        result += grades
            .filter { $0.subject.localizedCaseInsensitiveContains(subject) }
            .map { (date: $0.date, grade: $0.grade, type: $0.type) }
        return result.sorted { $0.date < $1.date }
    }

    func allGradeSubjects() -> [String] {
        var subjects = Set(entries.filter { $0.type == .klassenarbeit && $0.grade != nil }.map { $0.title })
        for g in grades { subjects.insert(g.subject) }
        return subjects.sorted()
    }

    func hasKlassenarbeit(on date: Date) -> Bool {
        let cal = Calendar.current
        return entries.contains { $0.type == .klassenarbeit && cal.isDate($0.date, inSameDayAs: date) }
    }

    // MARK: Grade helpers

    func addGrade(_ grade: Grade) {
        grades.append(grade)
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

    func deleteSubject(_ subject: Subject) { subjects.removeAll { $0.id == subject.id } }

    func updateSubject(_ subject: Subject) {
        if let idx = subjects.firstIndex(where: { $0.id == subject.id }) { subjects[idx] = subject }
    }

    func gradesFor(subject: Subject) -> [(date: Date, grade: Double, type: GradeType)] { gradesForSubject(subject.name) }

    func studyMinutesFor(subject: Subject) -> Int {
        studySessions.filter { $0.subject.localizedCaseInsensitiveCompare(subject.name) == .orderedSame }.reduce(0) { $0 + $1.minutes }
    }

    func sessionsFor(subject: Subject) -> [StudySession] {
        studySessions.filter { $0.subject.localizedCaseInsensitiveCompare(subject.name) == .orderedSame }.sorted { $0.date > $1.date }
    }

    func entriesFor(subject: Subject) -> [CalendarEntry] {
        entries.filter { $0.title.localizedCaseInsensitiveContains(subject.name) }.sorted { $0.date > $1.date }
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
        studySessions.append(session)
        syncToCloudIfNeeded()
        sendSessionNotification(session)
        // XP vergeben und Challenges prüfen
        LearningEngine.shared.earnXP(LearningEngine.shared.xpForStudyTime(minutes: session.minutes), subject: session.subject)
        LearningEngine.shared.checkChallenges(store: self)
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

    func currentStreak() -> Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = cal.startOfDay(for: Date())
        if sessions(for: checkDate).isEmpty {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }
        while true {
            if sessions(for: checkDate).isEmpty { break }
            streak += 1
            guard let prevDay = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prevDay
        }
        return streak
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
