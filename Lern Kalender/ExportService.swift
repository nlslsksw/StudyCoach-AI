import SwiftUI
import UniformTypeIdentifiers
import UIKit

// MARK: - Backup Data Model

struct BackupData: Codable {
    let version: Int
    let exportDate: Date
    let entries: [CalendarEntry]
    let recurringTasks: [RecurringTask]
    let studySessions: [StudySession]
    let grades: [Grade]
    let subjects: [Subject]
    let schoolYears: [SchoolYear]

    init(from store: DataStore) {
        self.version = 1
        self.exportDate = Date()
        self.entries = store.entries
        self.recurringTasks = store.recurringTasks
        self.studySessions = store.studySessions
        self.grades = store.grades
        self.subjects = store.subjects
        self.schoolYears = store.schoolYears
    }
}

// MARK: - Export Service

struct ExportService {

    // MARK: JSON Backup

    static func exportJSON(from store: DataStore) -> URL? {
        let backup = BackupData(from: store)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(backup) else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let fileName = "LernKalender_Backup_\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    // MARK: CSV Export

    static func exportGradesCSV(from store: DataStore) -> URL? {
        var csv = "Fach;Note;Typ;Datum;Anmerkung\n"
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"

        for grade in store.grades.sorted(by: { $0.date > $1.date }) {
            let subject = csvEscape(grade.subject)
            let gradeStr = String(format: "%.1f", grade.grade)
            let type = grade.type.rawValue
            let date = formatter.string(from: grade.date)
            let note = csvEscape(grade.note)
            csv += "\(subject);\(gradeStr);\(type);\(date);\(note)\n"
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LernKalender_Noten.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    static func exportSessionsCSV(from store: DataStore) -> URL? {
        var csv = "Fach;Datum;Minuten\n"
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"

        for session in store.studySessions.sorted(by: { $0.date > $1.date }) {
            let subject = csvEscape(session.subject)
            let date = formatter.string(from: session.date)
            csv += "\(subject);\(date);\(session.minutes)\n"
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LernKalender_Lernzeiten.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: PDF Report

    static func exportPDF(from store: DataStore) -> URL? {
        let pageWidth: CGFloat = 595.28  // A4
        let pageHeight: CGFloat = 841.89
        let margin: CGFloat = 50
        let contentWidth = pageWidth - 2 * margin

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let data = renderer.pdfData { context in
            // Seite 1: Titel
            context.beginPage()
            var y: CGFloat = margin

            y = drawText("Lern Kalender", at: CGPoint(x: margin, y: y), width: contentWidth,
                         font: .boldSystemFont(ofSize: 28), color: .systemBlue, in: context)
            y += 4

            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "de_DE")
            dateFormatter.dateFormat = "d. MMMM yyyy"
            y = drawText("Bericht vom \(dateFormatter.string(from: Date()))", at: CGPoint(x: margin, y: y), width: contentWidth,
                         font: .systemFont(ofSize: 14), color: .secondaryLabel, in: context)
            y += 30

            // Statistik-Zusammenfassung
            y = drawText("Zusammenfassung", at: CGPoint(x: margin, y: y), width: contentWidth,
                         font: .boldSystemFont(ofSize: 20), color: .label, in: context)
            y += 8

            let totalMinutes = store.studySessions.reduce(0) { $0 + $1.minutes }
            let totalGrades = store.grades.count
            let avgGrade: String = {
                guard !store.grades.isEmpty else { return "–" }
                let avg = store.grades.map(\.grade).reduce(0, +) / Double(store.grades.count)
                return String(format: "%.1f", avg)
            }()

            let summaryItems = [
                ("Gesamte Lernzeit", formatHoursMinutes(totalMinutes)),
                ("Lerntage", "\(Set(store.studySessions.map { Calendar.current.startOfDay(for: $0.date) }).count)"),
                ("Anzahl Noten", "\(totalGrades)"),
                ("Notendurchschnitt", avgGrade),
                ("Aktuelle Serie", "\(store.currentStreak()) Tage"),
                ("Längste Serie", "\(store.longestStreak()) Tage"),
            ]

            for item in summaryItems {
                y = drawText("\(item.0): \(item.1)", at: CGPoint(x: margin + 10, y: y), width: contentWidth - 10,
                             font: .systemFont(ofSize: 13), color: .label, in: context)
                y += 2
            }
            y += 20

            // Fächer-Übersicht
            y = drawText("Fächer", at: CGPoint(x: margin, y: y), width: contentWidth,
                         font: .boldSystemFont(ofSize: 20), color: .label, in: context)
            y += 8

            for subject in store.subjects {
                if y > pageHeight - 120 {
                    context.beginPage()
                    y = margin
                }

                let grades = store.gradesFor(subject: subject)
                let minutes = store.studyMinutesFor(subject: subject)

                y = drawText(subject.name, at: CGPoint(x: margin + 10, y: y), width: contentWidth - 10,
                             font: .boldSystemFont(ofSize: 15), color: .label, in: context)
                y += 2

                var info: [String] = []
                if !grades.isEmpty {
                    let avg = grades.map(\.grade).reduce(0, +) / Double(grades.count)
                    info.append("Ø \(String(format: "%.1f", avg))")
                    info.append("\(grades.count) Noten")
                }
                if minutes > 0 {
                    info.append(formatHoursMinutes(minutes))
                }

                if !info.isEmpty {
                    y = drawText(info.joined(separator: "  •  "), at: CGPoint(x: margin + 10, y: y), width: contentWidth - 10,
                                 font: .systemFont(ofSize: 12), color: .secondaryLabel, in: context)
                }

                // Noten-Liste
                if !grades.isEmpty {
                    y += 4
                    let gradeFormatter = DateFormatter()
                    gradeFormatter.dateFormat = "dd.MM.yy"
                    for g in grades.suffix(10) {
                        let line = "  \(gradeFormatter.string(from: g.date))  \(g.type.rawValue)  \(String(format: "%.1f", g.grade))"
                        y = drawText(line, at: CGPoint(x: margin + 20, y: y), width: contentWidth - 20,
                                     font: .monospacedDigitSystemFont(ofSize: 11, weight: .regular), color: .label, in: context)
                    }
                }
                y += 12
            }
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LernKalender_Bericht.pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    // MARK: Import

    static func importJSON(from url: URL, into store: DataStore) -> (success: Bool, message: String) {
        guard url.startAccessingSecurityScopedResource() else {
            return (false, "Keine Berechtigung zum Lesen der Datei.")
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else {
            return (false, "Datei konnte nicht gelesen werden.")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let backup = try? decoder.decode(BackupData.self, from: data) else {
            return (false, "Ungültiges Backup-Format.")
        }

        // Alle bestehenden Daten ersetzen
        store.deleteAllData()
        for entry in backup.entries { store.addEntry(entry) }
        for task in backup.recurringTasks { store.addRecurringTask(task) }
        for session in backup.studySessions { store.addSession(session) }
        for grade in backup.grades { store.addGrade(grade) }
        for subject in backup.subjects { store.addSubject(subject) }
        for sy in backup.schoolYears { store.addSchoolYear(sy) }

        return (true, "\(backup.entries.count) Einträge, \(backup.grades.count) Noten, \(backup.studySessions.count) Lernzeiten importiert.")
    }

    // MARK: Private Helpers

    private static func csvEscape(_ text: String) -> String {
        if text.contains(";") || text.contains("\"") || text.contains("\n") {
            return "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return text
    }

    @discardableResult
    private static func drawText(_ text: String, at point: CGPoint, width: CGFloat,
                                  font: UIFont, color: UIColor,
                                  in context: UIGraphicsPDFRendererContext) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        let rect = CGRect(x: point.x, y: point.y, width: width, height: .greatestFiniteMagnitude)
        let boundingRect = (text as NSString).boundingRect(with: rect.size, options: .usesLineFragmentOrigin,
                                                           attributes: attributes, context: nil)

        (text as NSString).draw(in: CGRect(x: point.x, y: point.y, width: width, height: boundingRect.height),
                                withAttributes: attributes)

        return point.y + boundingRect.height
    }
}
