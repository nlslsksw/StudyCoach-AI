import SwiftUI
import UserNotifications

// MARK: - Notification Helper

struct NotificationHelper {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    static func schedule(for entry: CalendarEntry) {
        guard entry.reminderEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = entry.type == .klassenarbeit ? "Klassenarbeit!" : "Lernzeit!"
        content.body = entry.title
        content.sound = .default

        let triggerDate = entry.date.addingTimeInterval(-Double(entry.reminderMinutesBefore * 60))
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: entry.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func remove(for entry: CalendarEntry) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [entry.id.uuidString])
    }

    // MARK: Daily Study Reminder

    static let dailyReminderId = "dailyStudyReminder"
    static let dailyReminderTodayId = "dailyStudyReminder.today"

    private static let dailyEnabledKey = "dailyReminderEnabled"
    private static let dailyHourKey = "dailyReminderHour"
    private static let dailyMinuteKey = "dailyReminderMinute"

    static var dailyReminderEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: dailyEnabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: dailyEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: dailyEnabledKey) }
    }

    static var dailyReminderHour: Int {
        get {
            if UserDefaults.standard.object(forKey: dailyHourKey) == nil { return 18 }
            return UserDefaults.standard.integer(forKey: dailyHourKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: dailyHourKey) }
    }

    static var dailyReminderMinute: Int {
        get {
            if UserDefaults.standard.object(forKey: dailyMinuteKey) == nil { return 0 }
            return UserDefaults.standard.integer(forKey: dailyMinuteKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: dailyMinuteKey) }
    }

    private static let dailyReminderHorizonDays = 14

    private static func dailyReminderId(for date: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "dailyStudyReminder.%04d-%02d-%02d",
                      comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    /// Plant die tägliche Erinnerung neu (für die nächsten ~2 Wochen).
    /// Bei deaktivierter Einstellung werden alle ausstehenden entfernt.
    static func refreshDailyReminder() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let oldIds = requests.map(\.identifier).filter { $0.hasPrefix("dailyStudyReminder") }
            center.removePendingNotificationRequests(withIdentifiers: oldIds)
            guard dailyReminderEnabled else { return }

            let cal = Calendar.current
            let now = Date()
            let hour = dailyReminderHour
            let minute = dailyReminderMinute

            for offset in 0..<dailyReminderHorizonDays {
                guard let day = cal.date(byAdding: .day, value: offset, to: now) else { continue }
                var comps = cal.dateComponents([.year, .month, .day], from: day)
                comps.hour = hour
                comps.minute = minute
                guard let fireDate = cal.date(from: comps), fireDate > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "Zeit zum Lernen!"
                content.body = "Trag jetzt deine heutige Lernzeit ein."
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                    repeats: false
                )
                let request = UNNotificationRequest(
                    identifier: dailyReminderId(for: day),
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        }
    }

    /// Unterdrückt nur die HEUTIGE Erinnerung (z.B. weil schon gelernt wurde).
    /// Die Erinnerungen für die Folgetage bleiben bestehen.
    static func cancelDailyReminderForToday() {
        let id = dailyReminderId(for: Date())
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}

// MARK: - Weekday Helpers

enum WeekdayHelper {
    static let abbreviations = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    static let calendarWeekdays = [2, 3, 4, 5, 6, 7, 1]

    static func abbreviation(for calendarWeekday: Int) -> String {
        switch calendarWeekday {
        case 2: return "Mo"
        case 3: return "Di"
        case 4: return "Mi"
        case 5: return "Do"
        case 6: return "Fr"
        case 7: return "Sa"
        case 1: return "So"
        default: return ""
        }
    }
}

// MARK: - Helpers

func colorForSubject(_ subject: String) -> Color {
    let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .teal, .indigo, .mint, .cyan]
    let hash = abs(subject.hashValue)
    return colors[hash % colors.count]
}

func formatHoursMinutes(_ totalMinutes: Int) -> String {
    let h = totalMinutes / 60
    let m = totalMinutes % 60
    if h > 0 {
        return "\(h)h \(m)m"
    }
    return "\(m)m"
}

func gradeString(_ grade: Double) -> String {
    if grade == Double(Int(grade)) {
        return "\(Int(grade))"
    }
    return String(format: "%.1f", grade)
}

func gradeColor(_ grade: Double) -> Color {
    switch grade {
    case ...1.5: return .green
    case ...2.5: return .mint
    case ...3.5: return .yellow
    case ...4.5: return .orange
    default: return .red
    }
}
