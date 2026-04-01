import Foundation

// MARK: - Bundesland

enum Bundesland: String, Codable, CaseIterable, Identifiable {
    case badenWuerttemberg = "Baden-Württemberg"
    case bayern = "Bayern"
    case berlin = "Berlin"
    case brandenburg = "Brandenburg"
    case bremen = "Bremen"
    case hamburg = "Hamburg"
    case hessen = "Hessen"
    case mecklenburgVorpommern = "Mecklenburg-Vorpommern"
    case niedersachsen = "Niedersachsen"
    case nordrheinWestfalen = "Nordrhein-Westfalen"
    case rheinlandPfalz = "Rheinland-Pfalz"
    case saarland = "Saarland"
    case sachsen = "Sachsen"
    case sachsenAnhalt = "Sachsen-Anhalt"
    case schleswigHolstein = "Schleswig-Holstein"
    case thueringen = "Thüringen"

    var id: String { rawValue }
}

// MARK: - School Holiday

struct SchoolHoliday: Identifiable {
    let id = UUID()
    let name: String
    let start: Date
    let end: Date
}

// MARK: - Holiday Data 2025/2026

struct SchoolHolidayData {

    private static func date(_ day: Int, _ month: Int, _ year: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }

    static func holidays(for bundesland: Bundesland) -> [SchoolHoliday] {
        switch bundesland {
        case .badenWuerttemberg:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(27, 10, 2025), end: date(30, 10, 2025)),
                SchoolHoliday(name: "Herbstferien", start: date(31, 10, 2025), end: date(31, 10, 2025)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(22, 12, 2025), end: date(5, 1, 2026)),
                SchoolHoliday(name: "Osterferien", start: date(30, 3, 2026), end: date(11, 4, 2026)),
                SchoolHoliday(name: "Pfingstferien", start: date(26, 5, 2026), end: date(6, 6, 2026)),
                SchoolHoliday(name: "Sommerferien", start: date(30, 7, 2026), end: date(12, 9, 2026)),
            ]
        case .bayern:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(3, 11, 2025), end: date(7, 11, 2025)),
                SchoolHoliday(name: "Herbstferien", start: date(19, 11, 2025), end: date(19, 11, 2025)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(22, 12, 2025), end: date(5, 1, 2026)),
                SchoolHoliday(name: "Winterferien", start: date(16, 2, 2026), end: date(20, 2, 2026)),
                SchoolHoliday(name: "Osterferien", start: date(30, 3, 2026), end: date(10, 4, 2026)),
                SchoolHoliday(name: "Pfingstferien", start: date(26, 5, 2026), end: date(6, 6, 2026)),
                SchoolHoliday(name: "Sommerferien", start: date(3, 8, 2026), end: date(14, 9, 2026)),
            ]
        case .berlin:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(20, 10, 2025), end: date(1, 11, 2025)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(22, 12, 2025), end: date(2, 1, 2026)),
                SchoolHoliday(name: "Winterferien", start: date(2, 2, 2026), end: date(7, 2, 2026)),
                SchoolHoliday(name: "Osterferien", start: date(30, 3, 2026), end: date(10, 4, 2026)),
                SchoolHoliday(name: "Osterferien", start: date(15, 5, 2026), end: date(15, 5, 2026)),
                SchoolHoliday(name: "Pfingstferien", start: date(26, 5, 2026), end: date(26, 5, 2026)),
                SchoolHoliday(name: "Sommerferien", start: date(9, 7, 2026), end: date(22, 8, 2026)),
            ]
        case .brandenburg:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(20, 10, 2025), end: date(1, 11, 2025)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(22, 12, 2025), end: date(2, 1, 2026)),
                SchoolHoliday(name: "Winterferien", start: date(2, 2, 2026), end: date(7, 2, 2026)),
                SchoolHoliday(name: "Osterferien", start: date(30, 3, 2026), end: date(10, 4, 2026)),
                SchoolHoliday(name: "Osterferien", start: date(15, 5, 2026), end: date(15, 5, 2026)),
                SchoolHoliday(name: "Pfingstferien", start: date(26, 5, 2026), end: date(26, 5, 2026)),
                SchoolHoliday(name: "Sommerferien", start: date(9, 7, 2026), end: date(22, 8, 2026)),
            ]
        case .bremen:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(13, 10, 2025), end: date(25, 10, 2025)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(22, 12, 2025), end: date(5, 1, 2026)),
                SchoolHoliday(name: "Winterferien", start: date(2, 2, 2026), end: date(3, 2, 2026)),
                SchoolHoliday(name: "Osterferien", start: date(23, 3, 2026), end: date(7, 4, 2026)),
                SchoolHoliday(name: "Pfingstferien", start: date(15, 5, 2026), end: date(26, 5, 2026)),
                SchoolHoliday(name: "Sommerferien", start: date(2, 7, 2026), end: date(12, 8, 2026)),
            ]
        case .hamburg:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(20, 10, 2025), end: date(31, 10, 2025)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(17, 12, 2025), end: date(2, 1, 2026)),
                SchoolHoliday(name: "Winterferien", start: date(30, 1, 2026), end: date(30, 1, 2026)),
                SchoolHoliday(name: "Osterferien", start: date(2, 3, 2026), end: date(13, 3, 2026)),
                SchoolHoliday(name: "Pfingstferien", start: date(11, 5, 2026), end: date(15, 5, 2026)),
                SchoolHoliday(name: "Sommerferien", start: date(9, 7, 2026), end: date(19, 8, 2026)),
            ]
        case .hessen:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(6, 10, 2025), end: date(18, 10, 2025)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(22, 12, 2025), end: date(10, 1, 2026)),
                SchoolHoliday(name: "Osterferien", start: date(30, 3, 2026), end: date(10, 4, 2026)),
                SchoolHoliday(name: "Sommerferien", start: date(29, 6, 2026), end: date(7, 8, 2026)),
            ]
        case .mecklenburgVorpommern:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(2, 10, 2025), end: date(2, 10, 2025)),
                SchoolHoliday(name: "Herbstferien", start: date(20, 10, 2025), end: date(24, 10, 2025)),
                SchoolHoliday(name: "Herbstferien", start: date(3, 11, 2025), end: date(3, 11, 2025)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(20, 12, 2025), end: date(3, 1, 2026)),
                SchoolHoliday(name: "Winterferien", start: date(9, 2, 2026), end: date(20, 2, 2026)),
                SchoolHoliday(name: "Osterferien", start: date(30, 3, 2026), end: date(8, 4, 2026)),
                SchoolHoliday(name: "Pfingstferien", start: date(15, 5, 2026), end: date(22, 5, 2026)),
                SchoolHoliday(name: "Pfingstferien", start: date(26, 5, 2026), end: date(26, 5, 2026)),
                SchoolHoliday(name: "Sommerferien", start: date(13, 7, 2026), end: date(22, 8, 2026)),
            ]
        case .niedersachsen:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(13, 10, 2025), end: date(25, 10, 2025)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(22, 12, 2025), end: date(5, 1, 2026)),
                SchoolHoliday(name: "Winterferien", start: date(2, 2, 2026), end: date(3, 2, 2026)),
                SchoolHoliday(name: "Osterferien", start: date(23, 3, 2026), end: date(7, 4, 2026)),
                SchoolHoliday(name: "Pfingstferien", start: date(15, 5, 2026), end: date(26, 5, 2026)),
                SchoolHoliday(name: "Sommerferien", start: date(2, 7, 2026), end: date(12, 8, 2026)),
            ]
        case .nordrheinWestfalen:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(13, 10, 2025), end: date(25, 10, 2025)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(22, 12, 2025), end: date(6, 1, 2026)),
                SchoolHoliday(name: "Osterferien", start: date(30, 3, 2026), end: date(11, 4, 2026)),
                SchoolHoliday(name: "Pfingstferien", start: date(26, 5, 2026), end: date(26, 5, 2026)),
                SchoolHoliday(name: "Sommerferien", start: date(20, 7, 2026), end: date(1, 9, 2026)),
            ]
        case .rheinlandPfalz:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(13, 10, 2025), end: date(24, 10, 2025)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(22, 12, 2025), end: date(7, 1, 2026)),
                SchoolHoliday(name: "Osterferien", start: date(30, 3, 2026), end: date(10, 4, 2026)),
                SchoolHoliday(name: "Sommerferien", start: date(29, 6, 2026), end: date(7, 8, 2026)),
            ]
        case .saarland:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(13, 10, 2025), end: date(24, 10, 2025)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(22, 12, 2025), end: date(2, 1, 2026)),
                SchoolHoliday(name: "Winterferien", start: date(16, 2, 2026), end: date(20, 2, 2026)),
                SchoolHoliday(name: "Osterferien", start: date(7, 4, 2026), end: date(17, 4, 2026)),
                SchoolHoliday(name: "Sommerferien", start: date(29, 6, 2026), end: date(7, 8, 2026)),
            ]
        case .sachsen:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(6, 10, 2025), end: date(18, 10, 2025)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(22, 12, 2025), end: date(2, 1, 2026)),
                SchoolHoliday(name: "Winterferien", start: date(9, 2, 2026), end: date(21, 2, 2026)),
                SchoolHoliday(name: "Osterferien", start: date(3, 4, 2026), end: date(10, 4, 2026)),
                SchoolHoliday(name: "Osterferien", start: date(15, 5, 2026), end: date(15, 5, 2026)),
                SchoolHoliday(name: "Sommerferien", start: date(4, 7, 2026), end: date(14, 8, 2026)),
            ]
        case .sachsenAnhalt:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(13, 10, 2025), end: date(25, 10, 2025)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(22, 12, 2025), end: date(5, 1, 2026)),
                SchoolHoliday(name: "Winterferien", start: date(31, 1, 2026), end: date(6, 2, 2026)),
                SchoolHoliday(name: "Osterferien", start: date(30, 3, 2026), end: date(4, 4, 2026)),
                SchoolHoliday(name: "Pfingstferien", start: date(26, 5, 2026), end: date(29, 5, 2026)),
                SchoolHoliday(name: "Sommerferien", start: date(4, 7, 2026), end: date(14, 8, 2026)),
            ]
        case .schleswigHolstein:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(20, 10, 2025), end: date(30, 10, 2025)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(19, 12, 2025), end: date(6, 1, 2026)),
                SchoolHoliday(name: "Winterferien", start: date(2, 2, 2026), end: date(3, 2, 2026)),
                SchoolHoliday(name: "Osterferien", start: date(26, 3, 2026), end: date(10, 4, 2026)),
                SchoolHoliday(name: "Pfingstferien", start: date(15, 5, 2026), end: date(15, 5, 2026)),
                SchoolHoliday(name: "Sommerferien", start: date(4, 7, 2026), end: date(15, 8, 2026)),
            ]
        case .thueringen:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(6, 10, 2025), end: date(18, 10, 2025)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(22, 12, 2025), end: date(3, 1, 2026)),
                SchoolHoliday(name: "Winterferien", start: date(16, 2, 2026), end: date(21, 2, 2026)),
                SchoolHoliday(name: "Osterferien", start: date(7, 4, 2026), end: date(17, 4, 2026)),
                SchoolHoliday(name: "Pfingstferien", start: date(15, 5, 2026), end: date(15, 5, 2026)),
                SchoolHoliday(name: "Sommerferien", start: date(4, 7, 2026), end: date(14, 8, 2026)),
            ]
        }
    }
}
