import SwiftUI
import UserNotifications
import Combine
import CoreMotion

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

    // MARK: Stundenplan-Änderungen (Webuntis-Sync)

    /// Sendet eine sofortige lokale Notification, wenn sich in Webuntis
    /// etwas an einer Stunde geändert hat (Ausfall, Vertretung, Raum, Info).
    static func scheduleTimetableChange(_ change: TimetableChange) {
        let content = UNMutableNotificationContent()
        content.title = change.kind.title
        content.body = change.notificationBody
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = "timetableChange.\(change.slot.sourceId ?? change.slot.id.uuidString).\(change.kind.title)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
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

// MARK: - Theme System

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark, amoled
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Hell"
        case .dark: return "Dunkel"
        case .amoled: return "AMOLED-Schwarz"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark, .amoled: return .dark
        }
    }
}

enum AppAccent: String, CaseIterable, Identifiable {
    case blue, purple, pink, orange, green, teal, indigo
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .orange: return .orange
        case .green: return .green
        case .teal: return .teal
        case .indigo: return .indigo
        }
    }

    var label: String {
        switch self {
        case .blue: return "Blau"
        case .purple: return "Lila"
        case .pink: return "Pink"
        case .orange: return "Orange"
        case .green: return "Grün"
        case .teal: return "Türkis"
        case .indigo: return "Indigo"
        }
    }
}

enum ThemeStore {
    private static let themeKey = "appTheme"
    private static let accentKey = "appAccent"

    static var current: AppTheme {
        get { AppTheme(rawValue: UserDefaults.standard.string(forKey: themeKey) ?? "") ?? .system }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: themeKey)
            NotificationCenter.default.post(name: .appThemeChanged, object: nil)
        }
    }
    static var accent: AppAccent {
        get { AppAccent(rawValue: UserDefaults.standard.string(forKey: accentKey) ?? "") ?? .blue }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: accentKey)
            NotificationCenter.default.post(name: .appThemeChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let appThemeChanged = Notification.Name("appThemeChanged")
}

// MARK: - 3D Tilt Modifier (CoreMotion)

/// Subtiles 3D-Tilt-Effekt für Karten — folgt der Geräte-Neigung.
/// Nutzt einen geteilten MotionManager, damit nicht jede Karte ihren
/// eigenen Sensor-Stream startet.
final class TiltMotion: ObservableObject {
    static let shared = TiltMotion()
    @Published var pitch: Double = 0
    @Published var roll: Double = 0

    private let manager = CMMotionManager()
    private var subscribers = 0

    private init() {}

    func start() {
        subscribers += 1
        guard subscribers == 1, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let attitude = data?.attitude else { return }
            self.pitch = attitude.pitch
            self.roll = attitude.roll
        }
    }

    func stop() {
        subscribers = max(0, subscribers - 1)
        if subscribers == 0 { manager.stopDeviceMotionUpdates() }
    }
}

struct TiltCardModifier: ViewModifier {
    @StateObject private var motion = TiltMotion.shared
    var maxAngle: Double = 6  // Grad

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(clamp(motion.roll * 180 / .pi, -maxAngle, maxAngle)),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.6
            )
            .rotation3DEffect(
                .degrees(-clamp(motion.pitch * 180 / .pi, -maxAngle, maxAngle)),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.6
            )
            .onAppear { motion.start() }
            .onDisappear { motion.stop() }
    }

    private func clamp(_ value: Double, _ minV: Double, _ maxV: Double) -> Double {
        min(max(value, minV), maxV)
    }
}

extension View {
    func tiltCard(_ maxAngle: Double = 6) -> some View {
        modifier(TiltCardModifier(maxAngle: maxAngle))
    }
}

// MARK: - Streak Flame (premium 3-Layer Stack)
//
// Statt Partikel-Chaos: drei überlagerte SF-Symbol-Layer mit
// Glow-Halo, dunkler Hintergrund-Flamme und heller Vorder-Flamme.
// Pattern inspired by Duolingo + Snapchat — Look entsteht durch
// Layering + Gradients + dezenten Puls, nicht durch Bewegung.

struct StreakFlameView: View {
    let streak: Int
    @State private var pulse = false
    @State private var wobble = false

    private var tier: Tier {
        switch streak {
        case ..<1: return .none
        case 1..<7: return .orange
        case 7..<30: return .yellow
        case 30..<100: return .gold
        default: return .blue
        }
    }

    private enum Tier {
        case none, orange, yellow, gold, blue

        // Farbpalette pro Tier
        var foreground: [Color] {
            switch self {
            case .none, .orange: return [
                Color(red: 1.00, green: 0.97, blue: 0.90),  // white-warm
                Color(red: 1.00, green: 0.78, blue: 0.00),  // gold
                Color(red: 1.00, green: 0.59, blue: 0.00),  // orange
                Color(red: 1.00, green: 0.29, blue: 0.00)   // deep orange
            ]
            case .yellow: return [
                Color(red: 1.00, green: 1.00, blue: 0.95),
                Color(red: 1.00, green: 0.85, blue: 0.20),
                Color(red: 1.00, green: 0.55, blue: 0.00),
                Color(red: 0.93, green: 0.25, blue: 0.00)
            ]
            case .gold: return [
                Color(red: 1.00, green: 1.00, blue: 0.95),
                Color(red: 1.00, green: 0.88, blue: 0.30),
                Color(red: 1.00, green: 0.50, blue: 0.10),
                Color(red: 0.85, green: 0.10, blue: 0.00)
            ]
            case .blue: return [
                Color(red: 0.90, green: 0.97, blue: 1.00),
                Color(red: 0.31, green: 0.76, blue: 0.97),  // sky
                Color(red: 0.01, green: 0.53, blue: 0.82),
                Color(red: 0.00, green: 0.34, blue: 0.55)
            ]
            }
        }

        var dark: [Color] {
            switch self {
            case .none, .orange, .yellow, .gold: return [
                Color(red: 0.70, green: 0.13, blue: 0.00),
                Color(red: 0.40, green: 0.05, blue: 0.00)
            ]
            case .blue: return [
                Color(red: 0.00, green: 0.34, blue: 0.55),
                Color(red: 0.00, green: 0.20, blue: 0.35)
            ]
            }
        }

        var halo: Color {
            switch self {
            case .none, .orange, .yellow, .gold:
                return Color(red: 1.00, green: 0.78, blue: 0.00).opacity(0.55)
            case .blue:
                return Color(red: 0.31, green: 0.76, blue: 0.97).opacity(0.55)
            }
        }
    }

    var body: some View {
        ZStack {
            if tier != .none {
                // Layer 1: weicher Glow-Halo dahinter
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [tier.halo, .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 40
                        )
                    )
                    .blur(radius: 12)
                    .scaleEffect(pulse ? 1.18 : 1.0)

                // Layer 2: dunkle Hintergrund-Flamme (größer, leicht versetzt)
                Image(systemName: "flame.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        LinearGradient(colors: tier.dark,
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .scaleEffect(1.18)
                    .offset(y: wobble ? -1.5 : 1.5)
                    .blur(radius: 0.5)

                // Layer 3: helle Vorder-Flamme mit Weiß-Glühkern
                Image(systemName: "flame.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        LinearGradient(colors: tier.foreground,
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .scaleEffect(pulse ? 1.04 : 1.00)
            }
        }
        .compositingGroup()
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                wobble = true
            }
        }
        .allowsHitTesting(false)
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
