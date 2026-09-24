import Foundation

/// Die wenigen Werte, die das Home-Screen-Widget anzeigt.
/// Die App schreibt sie in die App Group, das Widget liest sie dort.
struct WidgetSnapshot: Codable {
    var minutesToday: Int = 0
    var streakDays: Int = 0
    var goalMinutes: Int = 0
    /// Nächste Klassenarbeit (Titel und Datum), falls eine ansteht.
    var nextExamTitle: String? = nil
    var nextExamDate: Date? = nil
    /// Offene Hausaufgaben, die heute oder morgen fällig sind.
    var openHomework: Int = 0
    var updated: Date = Date()

    static let appGroup = "group.Ralf-Lohrmann.Lern-Kalender"
    static let key = "widgetSnapshot"

    static var shared: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func load() -> WidgetSnapshot {
        guard let data = shared?.data(forKey: key),
              let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return WidgetSnapshot() }
        return snap
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        WidgetSnapshot.shared?.set(data, forKey: WidgetSnapshot.key)
    }
}
