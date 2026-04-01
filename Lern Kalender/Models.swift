import SwiftUI

// MARK: - Models

enum EventType: String, Codable, CaseIterable, Identifiable {
    case lerntag = "Lerntag"
    case klassenarbeit = "Klassenarbeit"
    case erinnerung = "Erinnerung"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .lerntag: return "book.fill"
        case .klassenarbeit: return "doc.text.fill"
        case .erinnerung: return "bell.fill"
        }
    }

    var color: Color {
        switch self {
        case .lerntag: return .blue
        case .klassenarbeit: return .red
        case .erinnerung: return .orange
        }
    }
}

struct CalendarEntry: Identifiable, Codable {
    var id = UUID()
    var title: String
    var date: Date
    var type: EventType
    var notes: String = ""
    var reminderEnabled: Bool = false
    var reminderMinutesBefore: Int = 15
    var isCompleted: Bool = false
    var grade: Double? = nil
}

struct RecurringTask: Identifiable, Codable {
    var id = UUID()
    var title: String
    var weekdays: [Int]
    var isActive: Bool = true
}

struct StudySession: Identifiable, Codable {
    var id = UUID()
    var subject: String
    var date: Date
    var minutes: Int
}

enum GradeType: String, Codable, CaseIterable, Identifiable {
    case schriftlich = "Schriftlich"
    case muendlich = "Mündlich"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .schriftlich: return "doc.text.fill"
        case .muendlich: return "bubble.left.fill"
        }
    }
}

struct Grade: Identifiable, Codable {
    var id = UUID()
    var subject: String
    var grade: Double
    var date: Date
    var type: GradeType
    var note: String = ""
}

// MARK: - App Mode

enum AppMode: String, Codable {
    case student = "Schüler"
    case parent = "Eltern"
}

struct FamilyLink: Identifiable, Codable {
    var id = UUID()
    var pairingCode: String
    var childName: String = ""
    var isActive: Bool = true
    var linkedDate: Date = Date()
}

struct StudyGoal: Identifiable, Codable {
    var id = UUID()
    var dailyMinutesGoal: Int = 0
    var weeklyMinutesGoal: Int = 0
}

struct MotivationMessage: Identifiable, Codable {
    var id = UUID()
    var text: String
    var date: Date = Date()
    var pairingCode: String
    var isRead: Bool = false
}

struct SharedCalendarEntry: Identifiable, Codable {
    var id = UUID()
    var title: String
    var subject: String
    var date: Date
    var pairingCode: String
    var createdByParent: Bool = true
}

// MARK: - School Year

struct SchoolYear: Identifiable, Codable {
    var id = UUID()
    var name: String
    var startDate: Date
    var endDate: Date
    var isArchived: Bool = false
}

struct Subject: Identifiable, Codable {
    var id = UUID()
    var name: String
    var icon: String = "book.fill"
    var colorName: String = "blue"
    var schoolYearId: UUID? = nil

    var color: Color {
        switch colorName {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "teal": return .teal
        case "indigo": return .indigo
        case "mint": return .mint
        case "cyan": return .cyan
        default: return .blue
        }
    }

    static let availableColors = ["blue", "green", "orange", "purple", "pink", "red", "teal", "indigo", "mint", "cyan"]

    static let availableIcons = ["book.fill", "pencil", "function", "globe.europe.africa.fill", "theatermasks.fill", "sportscourt.fill", "music.note", "paintbrush.fill", "cpu.fill", "leaf.fill", "cross.fill", "building.columns.fill"]
}
