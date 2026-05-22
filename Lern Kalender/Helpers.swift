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

// MARK: - Attachment Store

/// Verwaltet lokal gespeicherte Anhänge (Bilder/Dokumente) für Hausaufgaben
/// und andere Features. Die Files liegen unter Documents/Attachments/,
/// gespeichert wird nur der relative Pfad — der wird im DataStore mitgeführt.
enum AttachmentStore {
    static var attachmentsDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Attachments", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func url(forRelativePath path: String) -> URL {
        attachmentsDir.appendingPathComponent(path)
    }

    /// Speichert die Daten unter einem neuen UUID-Namen mit gegebener Extension.
    /// Gibt den relativen Pfad (nur Dateiname) zurück.
    @discardableResult
    static func save(data: Data, fileExtension: String) -> String? {
        let name = UUID().uuidString + "." + fileExtension.trimmingCharacters(in: .punctuationCharacters)
        let target = attachmentsDir.appendingPathComponent(name)
        do {
            try data.write(to: target, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func delete(relativePath: String) {
        let url = attachmentsDir.appendingPathComponent(relativePath)
        try? FileManager.default.removeItem(at: url)
    }

    static func isImage(_ relativePath: String) -> Bool {
        let ext = (relativePath as NSString).pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "heic", "heif", "gif"].contains(ext)
    }
}

// MARK: - Design System
//
// Zentrales Theme für die App. Konstanten für Radien/Spacing + ViewModifier,
// damit Cards, Buttons und Akzente überall gleich aussehen.

enum AppRadius {
    static let small: CGFloat = 10
    static let medium: CGFloat = 14
    static let large: CGFloat = 18
    static let xLarge: CGFloat = 22
}

enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
}

enum AppAnimation {
    static let smooth: Animation = .smooth(duration: 0.35)
    static let snappy: Animation = .spring(response: 0.35, dampingFraction: 0.78)
    static let bouncy: Animation = .spring(response: 0.45, dampingFraction: 0.65)
}

/// Card im Standard-App-Look: weicher Hintergrund, dezenter Schatten, gerundet.
struct AppCardStyle: ViewModifier {
    var radius: CGFloat = AppRadius.medium
    var padding: CGFloat = AppSpacing.md
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

/// Akzent-Card mit getöntem Hintergrund + zarte Border-Kante.
struct AppTintedCardStyle: ViewModifier {
    let color: Color
    var radius: CGFloat = AppRadius.medium
    var padding: CGFloat = AppSpacing.md
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [color.opacity(0.18), color.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(color.opacity(0.15), lineWidth: 0.5)
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            )
    }
}

/// Hero-Card mit lebendigem Mesh-Gradient (Fallback Linear für ältere iOS).
struct AppHeroCardStyle: ViewModifier {
    let colors: [Color]
    var radius: CGFloat = AppRadius.large
    var padding: CGFloat = AppSpacing.lg
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                AppMeshBackground(colors: colors)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            )
            .foregroundStyle(.white)
            .shadow(color: (colors.first ?? .black).opacity(0.25), radius: 14, x: 0, y: 6)
    }
}

/// 3x3 MeshGradient für Hero-Cards (iOS 18+), sonst Linear-Gradient-Fallback.
/// Erwartet 2+ Farben; weniger werden auf 2 ergänzt.
struct AppMeshBackground: View {
    let colors: [Color]

    var body: some View {
        let c = expandedColors
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: [
                    c[0], blend(c[0], c[1], 0.4), c[1],
                    blend(c[0], c[2], 0.3), blend(c[1], c[2], 0.5), blend(c[1], c[2], 0.6),
                    c[2], blend(c[2], c[0], 0.4), c[0]
                ]
            )
        } else {
            LinearGradient(colors: c, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    /// Stellt sicher, dass mindestens 3 Farben vorliegen — duplizieren falls zu wenig.
    private var expandedColors: [Color] {
        switch colors.count {
        case 0: return [.blue, .purple, .indigo]
        case 1: return [colors[0], colors[0].opacity(0.8), colors[0]]
        case 2: return [colors[0], colors[1], colors[0]]
        default: return Array(colors.prefix(3))
        }
    }

    private func blend(_ a: Color, _ b: Color, _ t: CGFloat) -> Color {
        // Einfaches Pseudo-Blending über Opacity-Stacking — funktional reicht das
        // für MeshGradient-Anker; Apple interpoliert die Übergänge ohnehin glatt.
        t < 0.5 ? a.opacity(1 - t * 0.4) : b.opacity(1 - (1 - t) * 0.4)
    }
}

extension View {
    func appCard(radius: CGFloat = AppRadius.medium,
                 padding: CGFloat = AppSpacing.md) -> some View {
        modifier(AppCardStyle(radius: radius, padding: padding))
    }
    func appTintedCard(_ color: Color,
                       radius: CGFloat = AppRadius.medium,
                       padding: CGFloat = AppSpacing.md) -> some View {
        modifier(AppTintedCardStyle(color: color, radius: radius, padding: padding))
    }
    func appHeroCard(_ colors: [Color],
                     radius: CGFloat = AppRadius.large,
                     padding: CGFloat = AppSpacing.lg) -> some View {
        modifier(AppHeroCardStyle(colors: colors, radius: radius, padding: padding))
    }
}

/// Animiert eine Zahl beim Wechsel (Counter-Effekt für Statistiken).
struct AnimatedNumber: View {
    let value: Int
    var font: Font = .title2.bold().monospacedDigit()
    var color: Color = .primary
    @State private var displayed: Int = 0

    var body: some View {
        Text("\(displayed)")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .onAppear { animate(to: value) }
            .onChange(of: value) { _, newValue in animate(to: newValue) }
    }

    private func animate(to target: Int) {
        withAnimation(AppAnimation.smooth) { displayed = target }
    }
}
