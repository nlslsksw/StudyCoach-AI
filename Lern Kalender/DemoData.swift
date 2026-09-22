import Foundation
import SwiftUI

#if DEBUG
extension Notification.Name {
    static let demoSelectTab = Notification.Name("demoSelectTab")
    static let demoOpenTimer = Notification.Name("demoOpenTimer")
    static let demoCloseTimer = Notification.Name("demoCloseTimer")
    static let demoOpenSubject = Notification.Name("demoOpenSubject")
    static let demoCloseSubject = Notification.Name("demoCloseSubject")
    static let demoScrollExams = Notification.Name("demoScrollExams")
}

/// Demo-Daten für Simulatoren/Screenshots. Aktiv nur mit Launch-Argument
/// `-demo student` oder `-demo parent` (Debug-Builds), z. B.
/// `xcrun simctl launch <udid> <bundle> -demo parent`.
enum DemoData {
    static let childCode = "482913"
    static let childName = "Nils"
    static let secondCode = "775120"
    static let secondName = "Lena"

    /// Wird einmal beim Start aus ContentView aufgerufen.
    @MainActor
    static func applyIfRequested(store: DataStore) {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-demo"), idx + 1 < args.count else { return }
        switch args[idx + 1] {
        case "student": seedStudent(store: store)
        case "parent": seedParent(store: store)
        default: break
        }
    }

    // MARK: Schüler

    @MainActor
    static func seedStudent(store: DataStore) {
        store.deleteAllData()
        store.homework = []
        OnboardingTracker.markCompleted()
        store.appMode = .student

        let (year, subjects) = makeSchoolYear()
        store.addSchoolYear(year)
        subjects.forEach { store.addSubject($0) }
        makeGrades().forEach { store.grades.append($0) }
        makeSessions().forEach { store.studySessions.append($0) }
        makeEntries().forEach { store.addEntry($0) }
        makeHomework().forEach { store.addHomework($0) }
        store.timetable = makeTimetable()
        store.streakState.freezeCount = 2
        store.familyLink = FamilyLink(pairingCode: childCode, childName: childName)
        store.studyGoal = StudyGoal(dailyMinutesGoal: 45, weeklyMinutesGoal: 300)
    }

    // MARK: Eltern

    @MainActor
    static func seedParent(store: DataStore) {
        store.deleteAllData()
        OnboardingTracker.markCompleted()
        UserDefaults.standard.set(true, forKey: "parentDashboardOnboardingShown")
        store.appMode = .parent
        store.familyLinks = [
            FamilyLink(pairingCode: childCode, childName: childName),
            FamilyLink(pairingCode: secondCode, childName: secondName)
        ]
        store.studyGoals[childCode] = StudyGoal(dailyMinutesGoal: 45, weeklyMinutesGoal: 300)
        store.studyGoals[secondCode] = StudyGoal(dailyMinutesGoal: 30, weeklyMinutesGoal: 180)

        let (_, subjects) = makeSchoolYear()
        var nils = CloudKitService.ChildRemoteData()
        nils.grades = makeGrades()
        nils.sessions = makeSessions()
        nils.subjects = subjects
        nils.entries = makeEntries()
        nils.currentStreak = 12
        nils.weeklyMinutes = nils.sessions.filter { $0.date >= startOfWeek }.reduce(0) { $0 + $1.minutes }
        nils.lastUpdated = Date().addingTimeInterval(-25 * 60)
        CloudKitService.shared.remoteData[childCode] = nils

        var lena = CloudKitService.ChildRemoteData()
        lena.subjects = [
            Subject(name: "Deutsch", icon: "text.book.closed.fill", colorName: "orange"),
            Subject(name: "Mathe", icon: "function", colorName: "blue"),
            Subject(name: "Sachkunde", icon: "leaf.fill", colorName: "green")
        ]
        lena.grades = [
            Grade(subject: "Deutsch", grade: 2, date: day(-6), type: .schriftlich),
            Grade(subject: "Mathe", grade: 1, date: day(-13), type: .schriftlich)
        ]
        lena.sessions = [
            StudySession(subject: "Deutsch", date: day(0), minutes: 20),
            StudySession(subject: "Mathe", date: day(-1), minutes: 25),
            StudySession(subject: "Sachkunde", date: day(-2), minutes: 15)
        ]
        lena.entries = [CalendarEntry(title: "Deutsch Diktat", date: day(6, hour: 8), type: .klassenarbeit)]
        lena.currentStreak = 4
        lena.weeklyMinutes = 60
        lena.lastUpdated = Date().addingTimeInterval(-3 * 3600)
        CloudKitService.shared.remoteData[secondCode] = lena
    }

    // MARK: Abspieler (echte Bedienung für Bildschirmaufnahmen)

    /// Spielt eine Bedienfolge ab, damit `simctl recordVideo` echte Übergänge aufnimmt.
    /// Start über `-play kind` bzw. `-play eltern`.
    @MainActor
    static func playIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-play"), i + 1 < args.count else { return }
        let script = args[i + 1]
        Task { @MainActor in
            func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
            func send(_ name: Notification.Name, _ object: Any? = nil) {
                NotificationCenter.default.post(name: name, object: object)
            }
            switch script {
            case "kind":
                await wait(2.6);  send(.demoOpenTimer)          // Heute → Lerntimer
                await wait(3.4);  send(.demoCloseTimer)
                await wait(1.0);  send(.demoSelectTab, 1)       // → Kalender
                await wait(3.0);  send(.demoSelectTab, 2)       // → Fächer
                await wait(2.4);  send(.demoOpenSubject, "Mathe")
                await wait(3.6);  send(.demoCloseSubject)
                await wait(1.2);  send(.demoSelectTab, 3)       // → Statistik
                await wait(4.0)
            case "eltern":
                await wait(2.6);  send(.demoScrollExams)        // Dashboard → Klassenarbeiten
                await wait(4.0)
            default: break
            }
        }
    }

    // MARK: Bausteine

    private static var startOfWeek: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }

    private static func day(_ offset: Int, hour: Int = 16) -> Date {
        let cal = Calendar.current
        let d = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: Date())) ?? Date()
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: d) ?? d
    }

    private static func makeSchoolYear() -> (SchoolYear, [Subject]) {
        let year = SchoolYear(name: "2026/27",
                              startDate: AddSchoolYearView.suggestedStart(),
                              endDate: AddSchoolYearView.suggestedEnd())
        let subjects = [
            Subject(name: "Mathe", icon: "function", colorName: "blue", schoolYearId: year.id, targetGrade: 2.0),
            Subject(name: "Deutsch", icon: "text.book.closed.fill", colorName: "orange", schoolYearId: year.id, targetGrade: 2.5),
            Subject(name: "Englisch", icon: "globe", colorName: "green", schoolYearId: year.id, targetGrade: 2.0),
            Subject(name: "Physik", icon: "atom", colorName: "purple", schoolYearId: year.id),
            Subject(name: "Geschichte", icon: "building.columns.fill", colorName: "red", schoolYearId: year.id),
            Subject(name: "Bio", icon: "leaf.fill", colorName: "mint", schoolYearId: year.id, targetGrade: 3.0)
        ]
        return (year, subjects)
    }

    private static func makeGrades() -> [Grade] {
        [
            Grade(subject: "Mathe", grade: 2, date: day(-2), type: .schriftlich),
            Grade(subject: "Mathe", grade: 3, date: day(-16), type: .muendlich),
            Grade(subject: "Deutsch", grade: 2, date: day(-5), type: .schriftlich),
            Grade(subject: "Deutsch", grade: 3, date: day(-19), type: .muendlich),
            Grade(subject: "Englisch", grade: 1, date: day(-8), type: .schriftlich),
            Grade(subject: "Englisch", grade: 2, date: day(-14), type: .muendlich),
            Grade(subject: "Physik", grade: 3, date: day(-10), type: .schriftlich),
            Grade(subject: "Geschichte", grade: 2, date: day(-12), type: .muendlich),
            Grade(subject: "Bio", grade: 4, date: day(-4), type: .schriftlich)
        ]
    }

    /// 12 Tage Streak bis heute, davor eine Lücke, davor nochmal ein paar Tage.
    private static func makeSessions() -> [StudySession] {
        let plan: [(Int, String, Int)] = [
            (0, "Mathe", 45), (0, "Englisch", 20),
            (-1, "Deutsch", 35), (-1, "Mathe", 30),
            (-2, "Physik", 40),
            (-3, "Mathe", 50), (-3, "Bio", 15),
            (-4, "Englisch", 30),
            (-5, "Deutsch", 45),
            (-6, "Geschichte", 25), (-6, "Mathe", 20),
            (-7, "Mathe", 60),
            (-8, "Englisch", 35),
            (-9, "Physik", 30), (-9, "Deutsch", 20),
            (-10, "Bio", 40),
            (-11, "Mathe", 35),
            (-14, "Deutsch", 30),
            (-15, "Mathe", 45),
            (-16, "Englisch", 25),
            (-18, "Geschichte", 40)
        ]
        return plan.map { StudySession(subject: $0.1, date: day($0.0, hour: 15 + abs($0.0) % 3), minutes: $0.2) }
    }

    private static func makeEntries() -> [CalendarEntry] {
        [
            CalendarEntry(title: "Mathe Klassenarbeit", date: day(3, hour: 8), type: .klassenarbeit, notes: "Lineare Funktionen, Kapitel 3–4"),
            CalendarEntry(title: "Englisch Vokabeltest", date: day(9, hour: 10), type: .klassenarbeit, notes: "Unit 2"),
            CalendarEntry(title: "Physik Test", date: day(16, hour: 9), type: .klassenarbeit),
            CalendarEntry(title: "Bio Referat", date: day(5, hour: 11), type: .erinnerung),
            CalendarEntry(title: "Lerntag Mathe", date: day(1, hour: 16), type: .lerntag)
        ]
    }

    /// Wiederkehrender Stundenplan Mo–Fr, je 6 Stunden.
    private static func makeTimetable() -> [TimetableSlot] {
        let times = [("07:45", "08:30"), ("08:35", "09:20"), ("09:40", "10:25"), ("10:30", "11:15"), ("11:35", "12:20"), ("12:25", "13:10")]
        let week: [[(String, String)]] = [
            [("Mathe", "A204"), ("Mathe", "A204"), ("Deutsch", "B112"), ("Englisch", "B115"), ("Sport", "Halle"), ("Sport", "Halle")],
            [("Physik", "C301"), ("Physik", "C301"), ("Geschichte", "A110"), ("Mathe", "A204"), ("Bio", "C205"), ("Musik", "M1")],
            [("Deutsch", "B112"), ("Deutsch", "B112"), ("Englisch", "B115"), ("Kunst", "K2"), ("Kunst", "K2"), ("Ethik", "A108")],
            [("Englisch", "B115"), ("Mathe", "A204"), ("Bio", "C205"), ("Geschichte", "A110"), ("Deutsch", "B112"), ("Physik", "C301")],
            [("Mathe", "A204"), ("Englisch", "B115"), ("Physik", "C301"), ("Deutsch", "B112"), ("Bio", "C205"), ("Geschichte", "A110")]
        ]
        var slots: [TimetableSlot] = []
        for (dayIdx, lessons) in week.enumerated() {
            for (i, lesson) in lessons.enumerated() {
                slots.append(TimetableSlot(weekday: dayIdx + 1, lesson: i + 1, startTime: times[i].0, endTime: times[i].1,
                                           subject: lesson.0, room: lesson.1))
            }
        }
        return slots
    }

    private static func makeHomework() -> [Homework] {
        [
            Homework(subject: "Mathe", title: "S. 87 Nr. 3–7", dueDate: day(1, hour: 8)),
            Homework(subject: "Deutsch", title: "Charakterisierung Faust", dueDate: day(2, hour: 8)),
            Homework(subject: "Englisch", title: "Vocabulary Unit 2", dueDate: day(1, hour: 8), isDone: true),
            Homework(subject: "Bio", title: "Referat vorbereiten", dueDate: day(4, hour: 8))
        ]
    }
}
#endif
