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
    case unitedStates = "United States"

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
        case .unitedStates:
            return [
                // 2025/2026
                SchoolHoliday(name: "Thanksgiving Break", start: date(26, 11, 2025), end: date(28, 11, 2025)),
                SchoolHoliday(name: "Winter Break", start: date(19, 12, 2025), end: date(2, 1, 2026)),
                SchoolHoliday(name: "Spring Break", start: date(23, 3, 2026), end: date(27, 3, 2026)),
                SchoolHoliday(name: "Sommerferien", start: date(12, 6, 2026), end: date(1, 9, 2026)),
                // 2026/2027
                SchoolHoliday(name: "Thanksgiving Break", start: date(25, 11, 2026), end: date(27, 11, 2026)),
                SchoolHoliday(name: "Winter Break", start: date(18, 12, 2026), end: date(1, 1, 2027)),
                SchoolHoliday(name: "Spring Break", start: date(22, 3, 2027), end: date(26, 3, 2027)),
                SchoolHoliday(name: "Sommerferien", start: date(11, 6, 2027), end: date(1, 9, 2027)),
            ]
        }
    }

    // MARK: - Holiday Data 2026/2027 (Germany only — additive)

    /// Returns holidays for the 2026/2027 school year. Call AFTER the base
    /// holidays(for:) and concatenate the two arrays if you need both years.
    static func holidays2027(for bundesland: Bundesland) -> [SchoolHoliday] {
        switch bundesland {
        case .badenWuerttemberg:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(26, 10, 2026), end: date(30, 10, 2026)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(23, 12, 2026), end: date(9, 1, 2027)),
                SchoolHoliday(name: "Osterferien", start: date(29, 3, 2027), end: date(10, 4, 2027)),
                SchoolHoliday(name: "Pfingstferien", start: date(25, 5, 2027), end: date(5, 6, 2027)),
                SchoolHoliday(name: "Sommerferien", start: date(29, 7, 2027), end: date(11, 9, 2027)),
            ]
        case .bayern:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(2, 11, 2026), end: date(6, 11, 2026)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(23, 12, 2026), end: date(9, 1, 2027)),
                SchoolHoliday(name: "Winterferien", start: date(15, 2, 2027), end: date(19, 2, 2027)),
                SchoolHoliday(name: "Osterferien", start: date(29, 3, 2027), end: date(9, 4, 2027)),
                SchoolHoliday(name: "Pfingstferien", start: date(25, 5, 2027), end: date(4, 6, 2027)),
                SchoolHoliday(name: "Sommerferien", start: date(2, 8, 2027), end: date(13, 9, 2027)),
            ]
        case .berlin:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(19, 10, 2026), end: date(31, 10, 2026)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(23, 12, 2026), end: date(2, 1, 2027)),
                SchoolHoliday(name: "Winterferien", start: date(1, 2, 2027), end: date(6, 2, 2027)),
                SchoolHoliday(name: "Osterferien", start: date(29, 3, 2027), end: date(9, 4, 2027)),
                SchoolHoliday(name: "Sommerferien", start: date(8, 7, 2027), end: date(21, 8, 2027)),
            ]
        case .brandenburg:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(19, 10, 2026), end: date(31, 10, 2026)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(23, 12, 2026), end: date(2, 1, 2027)),
                SchoolHoliday(name: "Winterferien", start: date(1, 2, 2027), end: date(6, 2, 2027)),
                SchoolHoliday(name: "Osterferien", start: date(29, 3, 2027), end: date(9, 4, 2027)),
                SchoolHoliday(name: "Sommerferien", start: date(8, 7, 2027), end: date(21, 8, 2027)),
            ]
        case .bremen:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(12, 10, 2026), end: date(24, 10, 2026)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(23, 12, 2026), end: date(5, 1, 2027)),
                SchoolHoliday(name: "Osterferien", start: date(22, 3, 2027), end: date(3, 4, 2027)),
                SchoolHoliday(name: "Pfingstferien", start: date(14, 5, 2027), end: date(18, 5, 2027)),
                SchoolHoliday(name: "Sommerferien", start: date(24, 6, 2027), end: date(4, 8, 2027)),
            ]
        case .hamburg:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(19, 10, 2026), end: date(30, 10, 2026)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(23, 12, 2026), end: date(2, 1, 2027)),
                SchoolHoliday(name: "Osterferien", start: date(1, 3, 2027), end: date(12, 3, 2027)),
                SchoolHoliday(name: "Pfingstferien", start: date(10, 5, 2027), end: date(14, 5, 2027)),
                SchoolHoliday(name: "Sommerferien", start: date(1, 7, 2027), end: date(11, 8, 2027)),
            ]
        case .hessen:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(19, 10, 2026), end: date(30, 10, 2026)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(23, 12, 2026), end: date(9, 1, 2027)),
                SchoolHoliday(name: "Osterferien", start: date(6, 4, 2027), end: date(16, 4, 2027)),
                SchoolHoliday(name: "Sommerferien", start: date(5, 7, 2027), end: date(13, 8, 2027)),
            ]
        case .mecklenburgVorpommern:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(24, 10, 2026), end: date(28, 10, 2026)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(21, 12, 2026), end: date(2, 1, 2027)),
                SchoolHoliday(name: "Winterferien", start: date(8, 2, 2027), end: date(13, 2, 2027)),
                SchoolHoliday(name: "Osterferien", start: date(22, 3, 2027), end: date(31, 3, 2027)),
                SchoolHoliday(name: "Pfingstferien", start: date(14, 5, 2027), end: date(18, 5, 2027)),
                SchoolHoliday(name: "Sommerferien", start: date(12, 7, 2027), end: date(21, 8, 2027)),
            ]
        case .niedersachsen:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(19, 10, 2026), end: date(31, 10, 2026)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(23, 12, 2026), end: date(5, 1, 2027)),
                SchoolHoliday(name: "Osterferien", start: date(22, 3, 2027), end: date(3, 4, 2027)),
                SchoolHoliday(name: "Pfingstferien", start: date(14, 5, 2027), end: date(18, 5, 2027)),
                SchoolHoliday(name: "Sommerferien", start: date(24, 6, 2027), end: date(4, 8, 2027)),
            ]
        case .nordrheinWestfalen:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(12, 10, 2026), end: date(24, 10, 2026)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(23, 12, 2026), end: date(6, 1, 2027)),
                SchoolHoliday(name: "Osterferien", start: date(22, 3, 2027), end: date(3, 4, 2027)),
                SchoolHoliday(name: "Sommerferien", start: date(28, 6, 2027), end: date(10, 8, 2027)),
            ]
        case .rheinlandPfalz:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(12, 10, 2026), end: date(23, 10, 2026)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(23, 12, 2026), end: date(8, 1, 2027)),
                SchoolHoliday(name: "Osterferien", start: date(29, 3, 2027), end: date(9, 4, 2027)),
                SchoolHoliday(name: "Sommerferien", start: date(5, 7, 2027), end: date(13, 8, 2027)),
            ]
        case .saarland:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(12, 10, 2026), end: date(24, 10, 2026)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(21, 12, 2026), end: date(2, 1, 2027)),
                SchoolHoliday(name: "Winterferien", start: date(15, 2, 2027), end: date(20, 2, 2027)),
                SchoolHoliday(name: "Osterferien", start: date(29, 3, 2027), end: date(9, 4, 2027)),
                SchoolHoliday(name: "Sommerferien", start: date(5, 7, 2027), end: date(16, 8, 2027)),
            ]
        case .sachsen:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(12, 10, 2026), end: date(24, 10, 2026)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(23, 12, 2026), end: date(2, 1, 2027)),
                SchoolHoliday(name: "Winterferien", start: date(8, 2, 2027), end: date(20, 2, 2027)),
                SchoolHoliday(name: "Osterferien", start: date(29, 3, 2027), end: date(9, 4, 2027)),
                SchoolHoliday(name: "Sommerferien", start: date(28, 6, 2027), end: date(6, 8, 2027)),
            ]
        case .sachsenAnhalt:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(19, 10, 2026), end: date(30, 10, 2026)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(21, 12, 2026), end: date(2, 1, 2027)),
                SchoolHoliday(name: "Winterferien", start: date(1, 2, 2027), end: date(6, 2, 2027)),
                SchoolHoliday(name: "Osterferien", start: date(29, 3, 2027), end: date(3, 4, 2027)),
                SchoolHoliday(name: "Sommerferien", start: date(19, 7, 2027), end: date(1, 9, 2027)),
            ]
        case .schleswigHolstein:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(19, 10, 2026), end: date(30, 10, 2026)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(23, 12, 2026), end: date(6, 1, 2027)),
                SchoolHoliday(name: "Osterferien", start: date(29, 3, 2027), end: date(12, 4, 2027)),
                SchoolHoliday(name: "Sommerferien", start: date(28, 6, 2027), end: date(9, 8, 2027)),
            ]
        case .thueringen:
            return [
                SchoolHoliday(name: "Herbstferien", start: date(5, 10, 2026), end: date(17, 10, 2026)),
                SchoolHoliday(name: "Weihnachtsferien", start: date(23, 12, 2026), end: date(2, 1, 2027)),
                SchoolHoliday(name: "Winterferien", start: date(8, 2, 2027), end: date(13, 2, 2027)),
                SchoolHoliday(name: "Osterferien", start: date(29, 3, 2027), end: date(10, 4, 2027)),
                SchoolHoliday(name: "Sommerferien", start: date(28, 6, 2027), end: date(7, 8, 2027)),
            ]
        case .unitedStates:
            return [] // already included both years in holidays(for:)
        }
    }
}
