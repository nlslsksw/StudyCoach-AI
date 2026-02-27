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

    private let entriesKey = "calendarEntries"
    private let recurringKey = "recurringTasks"
    private let sessionsKey = "studySessions"
    private let gradesKey = "grades"
    private let subjectsKey = "subjects"

    init() {
        if let data = UserDefaults.standard.data(forKey: entriesKey),
           let decoded = try? JSONDecoder().decode([CalendarEntry].self, from: data) {
            entries = decoded
        }
        if let data = UserDefaults.standard.data(forKey: recurringKey),
           let decoded = try? JSONDecoder().decode([RecurringTask].self, from: data) {
            recurringTasks = decoded
        }
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([StudySession].self, from: data) {
            studySessions = decoded
        }
        if let data = UserDefaults.standard.data(forKey: gradesKey),
           let decoded = try? JSONDecoder().decode([Grade].self, from: data) {
            grades = decoded
        }
        if let data = UserDefaults.standard.data(forKey: subjectsKey),
           let decoded = try? JSONDecoder().decode([Subject].self, from: data) {
            subjects = decoded
        }
    }

    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: entriesKey)
        }
    }

    private func saveRecurring() {
        if let data = try? JSONEncoder().encode(recurringTasks) {
            UserDefaults.standard.set(data, forKey: recurringKey)
        }
    }

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(studySessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }

    private func saveGrades() {
        if let data = try? JSONEncoder().encode(grades) {
            UserDefaults.standard.set(data, forKey: gradesKey)
        }
    }

    private func saveSubjects() {
        if let data = try? JSONEncoder().encode(subjects) {
            UserDefaults.standard.set(data, forKey: subjectsKey)
        }
    }

    // MARK: Entry helpers

    func entries(for date: Date) -> [CalendarEntry] {
        let cal = Calendar.current
        return entries.filter { cal.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    func addEntry(_ entry: CalendarEntry) {
        entries.append(entry)
        NotificationHelper.schedule(for: entry)
    }

    func updateEntry(_ entry: CalendarEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            NotificationHelper.remove(for: entries[idx])
            entries[idx] = entry
            NotificationHelper.schedule(for: entry)
        }
    }

    func deleteEntry(_ entry: CalendarEntry) {
        NotificationHelper.remove(for: entry)
        entries.removeAll { $0.id == entry.id }
    }

    func toggleCompleted(_ entry: CalendarEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx].isCompleted.toggle()
        }
    }

    func setGrade(for entry: CalendarEntry, grade: Double) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx].grade = grade
        }
    }

    func gradesForSubject(_ subject: String) -> [(date: Date, grade: Double, type: GradeType)] {
        // Noten von Kalendereinträgen (Klassenarbeiten)
        var result: [(date: Date, grade: Double, type: GradeType)] = entries
            .filter { $0.type == .klassenarbeit && $0.grade != nil && $0.title.localizedCaseInsensitiveContains(subject) }
            .compactMap { entry in
                guard let grade = entry.grade else { return nil }
                return (date: entry.date, grade: grade, type: GradeType.schriftlich)
            }

        // Noten aus dem separaten Noten-Speicher
        result += grades
            .filter { $0.subject.localizedCaseInsensitiveContains(subject) }
            .map { (date: $0.date, grade: $0.grade, type: $0.type) }

        return result.sorted { $0.date < $1.date }
    }

    func allGradeSubjects() -> [String] {
        var subjects = Set(
            entries.filter { $0.type == .klassenarbeit && $0.grade != nil }
                .map { $0.title }
        )
        for g in grades {
            subjects.insert(g.subject)
        }
        return subjects.sorted()
    }

    func hasKlassenarbeit(on date: Date) -> Bool {
        let cal = Calendar.current
        return entries.contains { $0.type == .klassenarbeit && cal.isDate($0.date, inSameDayAs: date) }
    }

    // MARK: Grade helpers

    func addGrade(_ grade: Grade) {
        grades.append(grade)
    }

    func deleteGrade(_ grade: Grade) {
        grades.removeAll { $0.id == grade.id }
    }

    func uniqueGradeSubjects() -> [String] {
        var subjects = Set(grades.map { $0.subject })
        for entry in entries where entry.type == .klassenarbeit {
            subjects.insert(entry.title)
        }
        return subjects.sorted()
    }

    // MARK: Subject helpers

    func addSubject(_ subject: Subject) {
        subjects.append(subject)
    }

    func deleteSubject(_ subject: Subject) {
        subjects.removeAll { $0.id == subject.id }
    }

    func updateSubject(_ subject: Subject) {
        if let idx = subjects.firstIndex(where: { $0.id == subject.id }) {
            subjects[idx] = subject
        }
    }

    func gradesFor(subject: Subject) -> [(date: Date, grade: Double, type: GradeType)] {
        return gradesForSubject(subject.name)
    }

    func studyMinutesFor(subject: Subject) -> Int {
        studySessions.filter { $0.subject.localizedCaseInsensitiveCompare(subject.name) == .orderedSame }
            .reduce(0) { $0 + $1.minutes }
    }

    func sessionsFor(subject: Subject) -> [StudySession] {
        studySessions.filter { $0.subject.localizedCaseInsensitiveCompare(subject.name) == .orderedSame }
            .sorted { $0.date > $1.date }
    }

    func entriesFor(subject: Subject) -> [CalendarEntry] {
        entries.filter { $0.title.localizedCaseInsensitiveContains(subject.name) }
            .sorted { $0.date > $1.date }
    }

    // MARK: Recurring helpers

    func recurringTasks(for date: Date) -> [RecurringTask] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        return recurringTasks.filter { $0.isActive && $0.weekdays.contains(weekday) }
    }

    func addRecurringTask(_ task: RecurringTask) {
        recurringTasks.append(task)
    }

    func deleteRecurringTask(_ task: RecurringTask) {
        recurringTasks.removeAll { $0.id == task.id }
    }

    func toggleRecurringTask(_ task: RecurringTask) {
        if let idx = recurringTasks.firstIndex(where: { $0.id == task.id }) {
            recurringTasks[idx].isActive.toggle()
        }
    }

    // MARK: Event colors

    func eventColors(on date: Date) -> [Color] {
        var colors: [Color] = []
        let dayEntries = entries(for: date)
        for type in EventType.allCases {
            if dayEntries.contains(where: { $0.type == type }) {
                colors.append(type.color)
            }
        }
        if !recurringTasks(for: date).isEmpty {
            colors.append(.green)
        }
        if !sessions(for: date).isEmpty {
            colors.append(.purple)
        }
        return colors
    }

    // MARK: Day info for calendar

    func dayStudyMinutes(on date: Date) -> Int {
        totalMinutes(in: sessions(for: date))
    }

    func dayItemCount(on date: Date) -> Int {
        entries(for: date).count + recurringTasks(for: date).count
    }

    // MARK: StudySession helpers

    func addSession(_ session: StudySession) {
        studySessions.append(session)
    }

    func deleteSession(_ session: StudySession) {
        studySessions.removeAll { $0.id == session.id }
    }

    func sessions(for date: Date) -> [StudySession] {
        let cal = Calendar.current
        return studySessions.filter { cal.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    func allSessionsSorted() -> [StudySession] {
        studySessions.sorted { $0.date > $1.date }
    }

    func totalMinutes(in sessions: [StudySession]) -> Int {
        sessions.reduce(0) { $0 + $1.minutes }
    }

    func sessionsInRange(from start: Date, to end: Date) -> [StudySession] {
        studySessions.filter { $0.date >= start && $0.date < end }
    }

    func uniqueSubjects() -> [String] {
        Array(Set(studySessions.map { $0.subject })).sorted()
    }

    // MARK: Streak

    func currentStreak() -> Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = cal.startOfDay(for: Date())

        let todaySessions = sessions(for: checkDate)
        if todaySessions.isEmpty {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while true {
            let daySessions = sessions(for: checkDate)
            if daySessions.isEmpty {
                break
            }
            streak += 1
            guard let prevDay = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prevDay
        }

        return streak
    }

    // MARK: Delete All

    func deleteAllData() {
        for entry in entries {
            NotificationHelper.remove(for: entry)
        }
        entries = []
        recurringTasks = []
        studySessions = []
        grades = []
        subjects = []
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
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }

        return longest
    }
}
