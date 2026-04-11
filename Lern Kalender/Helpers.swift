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
