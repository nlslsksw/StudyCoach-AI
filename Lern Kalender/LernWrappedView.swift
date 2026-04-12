import SwiftUI

// MARK: - Lern Wrapped View (Spotify-Style)

struct LernWrappedView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore
    let schoolYear: SchoolYear?
    let isHalbjahr: Bool

    @State private var currentPage = 0
    @State private var progress: CGFloat = 0
    @State private var timer: Timer?
    @State private var contentVisible = false

    private let pageDuration: TimeInterval = 6.0
    private let pages: [WrappedPage]

    init(store: DataStore, schoolYear: SchoolYear?, isHalbjahr: Bool) {
        self.store = store
        self.schoolYear = schoolYear
        self.isHalbjahr = isHalbjahr
        self.pages = Self.buildPages(store: store, schoolYear: schoolYear, isHalbjahr: isHalbjahr)
    }

    var body: some View {
        ZStack {
            // Animated Gradient Background
            let page = pages[currentPage]
            LinearGradient(
                colors: page.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .overlay {
                // Subtile animierte Kreise im Hintergrund
                GeometryReader { geo in
                    Circle()
                        .fill(page.gradientColors.last?.opacity(0.3) ?? .clear)
                        .frame(width: 300, height: 300)
                        .blur(radius: 80)
                        .offset(x: contentVisible ? geo.size.width * 0.3 : -geo.size.width * 0.2,
                                y: contentVisible ? -geo.size.height * 0.1 : geo.size.height * 0.1)
                    Circle()
                        .fill(page.gradientColors.first?.opacity(0.2) ?? .clear)
                        .frame(width: 250, height: 250)
                        .blur(radius: 60)
                        .offset(x: contentVisible ? -geo.size.width * 0.2 : geo.size.width * 0.3,
                                y: contentVisible ? geo.size.height * 0.5 : geo.size.height * 0.3)
                }
            }

            VStack(spacing: 0) {
                // Story Progress Bars
                HStack(spacing: 3) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(.white.opacity(0.25))
                                Capsule()
                                    .fill(.white.opacity(0.9))
                                    .frame(width: i < currentPage ? geo.size.width : (i == currentPage ? geo.size.width * progress : 0))
                            }
                        }
                        .frame(height: 2.5)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Close Button
                HStack {
                    Spacer()
                    Button {
                        stopTimer()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.bold())
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(.white.opacity(0.15), in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()

                // Content
                VStack(spacing: 0) {
                    if page.style == .intro || page.style == .outro {
                        // Intro/Outro: zentriert, groß
                        VStack(spacing: 24) {
                            Text(page.emoji ?? "")
                                .font(.system(size: 72))
                                .scaleEffect(contentVisible ? 1.0 : 0.5)
                                .opacity(contentVisible ? 1 : 0)

                            Text(page.title)
                                .font(.system(size: 22, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .opacity(contentVisible ? 1 : 0)
                                .offset(y: contentVisible ? 0 : 20)

                            Text(page.value)
                                .font(.system(size: 42, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .scaleEffect(contentVisible ? 1.0 : 0.8)
                                .opacity(contentVisible ? 1 : 0)

                            if let sub = page.subtitle {
                                Text(sub)
                                    .font(.system(size: 18, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .opacity(contentVisible ? 1 : 0)
                                    .offset(y: contentVisible ? 0 : 10)
                            }
                        }
                    } else if page.style == .bigNumber {
                        // Große Zahl im Zentrum
                        VStack(spacing: 16) {
                            Text(page.emoji ?? "")
                                .font(.system(size: 48))
                                .opacity(contentVisible ? 1 : 0)
                                .offset(y: contentVisible ? 0 : -20)

                            Text(page.title)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                                .tracking(2)
                                .textCase(.uppercase)
                                .multilineTextAlignment(.center)
                                .opacity(contentVisible ? 1 : 0)
                                .offset(y: contentVisible ? 0 : 15)

                            Text(page.value)
                                .font(.system(size: 72, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .scaleEffect(contentVisible ? 1.0 : 0.3)
                                .opacity(contentVisible ? 1 : 0)

                            if let sub = page.subtitle {
                                Text(sub)
                                    .font(.system(size: 20, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .opacity(contentVisible ? 1 : 0)
                                    .offset(y: contentVisible ? 0 : 10)
                            }
                        }
                    } else if page.style == .highlight {
                        // Highlight: Fachname groß, Detail drunter
                        VStack(spacing: 20) {
                            Text(page.emoji ?? "")
                                .font(.system(size: 56))
                                .scaleEffect(contentVisible ? 1.0 : 0.5)
                                .opacity(contentVisible ? 1 : 0)

                            Text(page.title)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                                .tracking(3)
                                .textCase(.uppercase)
                                .opacity(contentVisible ? 1 : 0)

                            Text(page.value)
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.5)
                                .lineLimit(2)
                                .opacity(contentVisible ? 1 : 0)
                                .offset(y: contentVisible ? 0 : 30)

                            if let sub = page.subtitle {
                                Text(sub)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .opacity(contentVisible ? 1 : 0)
                                    .offset(y: contentVisible ? 0 : 15)

                                // Dekorative Linie
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white.opacity(0.3))
                                    .frame(width: contentVisible ? 60 : 0, height: 3)
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)
                .animation(.spring(response: 0.7, dampingFraction: 0.8), value: contentVisible)

                Spacer()

                // Bottom Label
                Text(isHalbjahr ? "HALBJAHRES-RÜCKBLICK" : "SCHULJAHRES-RÜCKBLICK")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.bottom, 30)
            }

            // Tap-Bereiche (unsichtbar)
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { prevPage() }
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { nextPage() }
            }
        }
        .onAppear {
            contentVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                contentVisible = true
            }
            startTimer()
            WrappedAudio.shared.play()
        }
        .onDisappear {
            stopTimer()
            WrappedAudio.shared.stop()
        }
        .statusBarHidden()
    }

    // MARK: - Timer & Navigation

    private func startTimer() {
        progress = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            progress += 0.03 / pageDuration
            if progress >= 1.0 { nextPage() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func nextPage() {
        stopTimer()
        if currentPage < pages.count - 1 {
            contentVisible = false
            WrappedAudio.shared.onSlideChange()
            withAnimation(.easeInOut(duration: 0.4)) {
                currentPage += 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                contentVisible = true
            }
            startTimer()
        } else {
            dismiss()
        }
    }

    private func prevPage() {
        stopTimer()
        if currentPage > 0 {
            contentVisible = false
            WrappedAudio.shared.onSlideChange()
            withAnimation(.easeInOut(duration: 0.4)) {
                currentPage -= 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                contentVisible = true
            }
        }
        startTimer()
    }

    // MARK: - Page Builder

    private static func buildPages(store: DataStore, schoolYear: SchoolYear?, isHalbjahr: Bool) -> [WrappedPage] {
        let cal = Calendar.current
        let now = Date()

        let start: Date
        let end: Date
        let periodName: String

        if let sy = schoolYear {
            if isHalbjahr {
                let mid = cal.date(byAdding: .month, value: 6, to: sy.startDate) ?? now
                if now < mid {
                    start = sy.startDate; end = mid; periodName = "1. Halbjahr"
                } else {
                    start = mid; end = sy.endDate; periodName = "2. Halbjahr"
                }
            } else {
                start = sy.startDate; end = sy.endDate; periodName = sy.name
            }
        } else {
            start = cal.date(byAdding: .month, value: isHalbjahr ? -6 : -12, to: now) ?? now
            end = now
            periodName = isHalbjahr ? "Letztes Halbjahr" : "Letztes Jahr"
        }

        let sessions = store.studySessions.filter { $0.date >= start && $0.date < end }
        let totalMinutes = sessions.reduce(0) { $0 + $1.minutes }
        let totalHours = totalMinutes / 60
        let studyDays = Set(sessions.map { cal.startOfDay(for: $0.date) }).count

        let grades = store.grades.filter { $0.date >= start && $0.date < end }
        let avgGrade: Double? = grades.isEmpty ? nil : grades.map(\.grade).reduce(0, +) / Double(grades.count)

        var subjectMinutes: [String: Int] = [:]
        for s in sessions { subjectMinutes[s.subject, default: 0] += s.minutes }
        let topSubject = subjectMinutes.max(by: { $0.value < $1.value })

        var subjectGrades: [String: [Double]] = [:]
        for g in grades { subjectGrades[g.subject, default: []].append(g.grade) }
        let bestGradeSubject = subjectGrades.min(by: {
            ($0.value.reduce(0, +) / Double($0.value.count)) < ($1.value.reduce(0, +) / Double($1.value.count))
        })

        var dayMinutes: [Date: Int] = [:]
        for s in sessions { dayMinutes[cal.startOfDay(for: s.date), default: 0] += s.minutes }
        let busiestDay = dayMinutes.max(by: { $0.value < $1.value })
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "de_DE")
        dayFormatter.dateFormat = "d. MMMM"

        let sortedDays = dayMinutes.keys.sorted()
        var maxStreak = 0; var cs = 1
        for i in 1..<sortedDays.count {
            if (cal.dateComponents([.day], from: sortedDays[i-1], to: sortedDays[i]).day ?? 0) == 1 {
                cs += 1; maxStreak = max(maxStreak, cs)
            } else { cs = 1 }
        }
        if sortedDays.count == 1 { maxStreak = 1 }

        var pages: [WrappedPage] = []

        // 1. Intro
        pages.append(WrappedPage(
            emoji: "📚", title: "Dein Lern-Rückblick", value: periodName,
            subtitle: schoolYear?.name, style: .intro,
            gradientColors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.15, green: 0.05, blue: 0.3)]
        ))

        // 2. Gesamte Lernzeit
        pages.append(WrappedPage(
            emoji: "⏱", title: "Gesamte Lernzeit",
            value: totalHours > 0 ? "\(totalHours) Std \(totalMinutes % 60) Min" : "\(totalMinutes) Min",
            subtitle: nil, style: .bigNumber,
            gradientColors: [Color(red: 0.4, green: 0.1, blue: 0.6), Color(red: 0.2, green: 0.0, blue: 0.5)]
        ))

        // 3. Lerntage
        pages.append(WrappedPage(
            emoji: "📅", title: "Lerntage", value: "\(studyDays)",
            subtitle: studyDays == 1 ? "Tag gelernt" : "Tage gelernt", style: .bigNumber,
            gradientColors: [Color(red: 0.0, green: 0.3, blue: 0.5), Color(red: 0.0, green: 0.15, blue: 0.4)]
        ))

        // 4. Top Fach
        if let top = topSubject {
            pages.append(WrappedPage(
                emoji: "🏆", title: "Meistgelerntes Fach", value: top.key,
                subtitle: formatHoursMinutes(top.value), style: .highlight,
                gradientColors: [Color(red: 0.6, green: 0.3, blue: 0.0), Color(red: 0.4, green: 0.15, blue: 0.0)]
            ))
        }

        // 5. Längste Serie
        if maxStreak > 1 {
            pages.append(WrappedPage(
                emoji: "🔥", title: "Längste Serie", value: "\(maxStreak)",
                subtitle: "Tage am Stück", style: .bigNumber,
                gradientColors: [Color(red: 0.7, green: 0.1, blue: 0.1), Color(red: 0.4, green: 0.0, blue: 0.1)]
            ))
        }

        // 6. Aktivster Tag
        if let busiest = busiestDay {
            pages.append(WrappedPage(
                emoji: "💪", title: "Aktivster Tag", value: dayFormatter.string(from: busiest.key),
                subtitle: formatHoursMinutes(busiest.value) + " gelernt", style: .highlight,
                gradientColors: [Color(red: 0.0, green: 0.4, blue: 0.4), Color(red: 0.0, green: 0.2, blue: 0.3)]
            ))
        }

        // 7. Notendurchschnitt
        if let avg = avgGrade {
            let emoji = avg <= 1.5 ? "🌟" : avg <= 2.5 ? "✨" : avg <= 3.5 ? "👍" : "📝"
            pages.append(WrappedPage(
                emoji: emoji, title: "Notendurchschnitt", value: String(format: "%.1f", avg),
                subtitle: "\(grades.count) Noten insgesamt", style: .bigNumber,
                gradientColors: avg <= 2.0
                    ? [Color(red: 0.0, green: 0.4, blue: 0.2), Color(red: 0.0, green: 0.2, blue: 0.15)]
                    : [Color(red: 0.3, green: 0.2, blue: 0.5), Color(red: 0.15, green: 0.1, blue: 0.3)]
            ))
        }

        // 8. Bestes Notenfach
        if let best = bestGradeSubject {
            let avg = best.value.reduce(0, +) / Double(best.value.count)
            pages.append(WrappedPage(
                emoji: "⭐️", title: "Stärkstes Fach", value: best.key,
                subtitle: "Ø \(String(format: "%.1f", avg))", style: .highlight,
                gradientColors: [Color(red: 0.1, green: 0.3, blue: 0.5), Color(red: 0.05, green: 0.15, blue: 0.35)]
            ))
        }

        // 9. Outro
        pages.append(WrappedPage(
            emoji: "🎉", title: periodName + " ist geschafft!",
            value: ["Weiter so!", "Du rockst!", "Stark!", "Beeindruckend!"].randomElement() ?? "Weiter so!",
            subtitle: nil, style: .outro,
            gradientColors: [Color(red: 0.5, green: 0.1, blue: 0.4), Color(red: 0.2, green: 0.0, blue: 0.3)]
        ))

        if pages.count < 3 {
            pages.insert(WrappedPage(
                emoji: "📖", title: "Noch wenig Daten", value: "Lern weiter!",
                subtitle: "Der Rückblick wird besser mit mehr Einträgen", style: .intro,
                gradientColors: [Color(red: 0.2, green: 0.2, blue: 0.25), Color(red: 0.1, green: 0.1, blue: 0.15)]
            ), at: 1)
        }

        return pages
    }
}

// MARK: - Page Model

private enum WrappedPageStyle {
    case intro, outro, bigNumber, highlight
}

private struct WrappedPage {
    let emoji: String?
    let title: String
    let value: String
    let subtitle: String?
    let style: WrappedPageStyle
    let gradientColors: [Color]
}

// MARK: - Wrapped Trigger Helper

struct WrappedTrigger {

    // Halbjahreszeugnisse pro Bundesland pro Schuljahr: [(day, month, year)]
    private static let halbjahresEnde: [Bundesland: [(Int, Int, Int)]] = [
        // 2025/2026
        .badenWuerttemberg:       [(30, 1, 2026), (29, 1, 2027)],
        .bayern:                  [(13, 2, 2026), (12, 2, 2027)],
        .berlin:                  [(30, 1, 2026), (29, 1, 2027)],
        .brandenburg:             [(30, 1, 2026), (29, 1, 2027)],
        .bremen:                  [(30, 1, 2026), (29, 1, 2027)],
        .hamburg:                 [(29, 1, 2026), (28, 1, 2027)],
        .hessen:                  [(30, 1, 2026), (29, 1, 2027)],
        .mecklenburgVorpommern:   [( 6, 2, 2026), ( 5, 2, 2027)],
        .niedersachsen:           [(30, 1, 2026), (29, 1, 2027)],
        .nordrheinWestfalen:      [( 6, 2, 2026), ( 5, 2, 2027)],
        .rheinlandPfalz:          [(30, 1, 2026), (29, 1, 2027)],
        .saarland:                [(13, 2, 2026), (12, 2, 2027)],
        .sachsen:                 [( 6, 2, 2026), ( 5, 2, 2027)],
        .sachsenAnhalt:           [(30, 1, 2026), (29, 1, 2027)],
        .schleswigHolstein:       [(30, 1, 2026), (29, 1, 2027)],
        .thueringen:              [(13, 2, 2026), (12, 2, 2027)],
        // USA: semester ends in December
        .unitedStates:            [(19, 12, 2025), (18, 12, 2026)],
    ]

    /// Returns all Sommerferien-Start dates across both school years as
    /// potential Schuljahres-Ende triggers (one day before summer break).
    private static func schuljahresEndeDates(bundesland: Bundesland) -> [Date] {
        let cal = Calendar.current
        let allHolidays = SchoolHolidayData.holidays(for: bundesland)
            + SchoolHolidayData.holidays2027(for: bundesland)
        return allHolidays
            .filter { $0.name == "Sommerferien" }
            .compactMap { cal.date(byAdding: .day, value: -1, to: $0.start) }
    }

    private static func makeDate(_ day: Int, _ month: Int, _ year: Int) -> Date {
        var c = DateComponents()
        c.day = day; c.month = month; c.year = year
        return Calendar.current.date(from: c) ?? Date()
    }

    static func shouldShowWrapped(store: DataStore) -> (show: Bool, isHalbjahr: Bool, schoolYear: SchoolYear?)? {
        guard let bundesland = store.selectedBundesland else { return nil }
        let cal = Calendar.current
        let now = Date()
        let shown = UserDefaults.standard.string(forKey: "lastWrappedShown") ?? ""
        let windowDays = 30 // 30 Tage Fenster nach dem Datum

        // Halbjahr-Check (all dates for this region — 2025/26 + 2026/27)
        if let dates = halbjahresEnde[bundesland] {
            for hj in dates {
                let hjDate = makeDate(hj.0, hj.1, hj.2)
                let hjEnd = cal.date(byAdding: .day, value: windowDays, to: hjDate) ?? hjDate
                let hjKey = "hj_\(bundesland.rawValue)_\(hj.2)"
                if now >= hjDate && now <= hjEnd && !shown.contains(hjKey) {
                    let sy = store.activeSchoolYear()
                    return (true, true, sy)
                }
            }
        }

        // Schuljahres-Ende-Check (all Sommerferien starts across both years)
        for sjDate in schuljahresEndeDates(bundesland: bundesland) {
            let sjEnd = cal.date(byAdding: .day, value: windowDays, to: sjDate) ?? sjDate
            let sjKey = "sj_\(bundesland.rawValue)_\(cal.component(.year, from: sjDate))"
            if now >= sjDate && now <= sjEnd && !shown.contains(sjKey) {
                let sy = store.activeSchoolYear()
                return (true, false, sy)
            }
        }

        return nil
    }

    /// Returns which Wrapped types are currently in their 30-day window
    /// (regardless of whether they have already been auto-shown).
    static func availableWrapped(store: DataStore) -> (halbjahr: Bool, jahr: Bool) {
        guard let bundesland = store.selectedBundesland else { return (false, false) }
        let cal = Calendar.current
        let now = Date()
        let windowDays = 30

        var hjAvailable = false
        if let dates = halbjahresEnde[bundesland] {
            for hj in dates {
                let hjDate = makeDate(hj.0, hj.1, hj.2)
                let hjEnd = cal.date(byAdding: .day, value: windowDays, to: hjDate) ?? hjDate
                if now >= hjDate && now <= hjEnd { hjAvailable = true; break }
            }
        }

        var sjAvailable = false
        for sjDate in schuljahresEndeDates(bundesland: bundesland) {
            let sjEnd = cal.date(byAdding: .day, value: windowDays, to: sjDate) ?? sjDate
            if now >= sjDate && now <= sjEnd { sjAvailable = true; break }
        }

        return (hjAvailable, sjAvailable)
    }

    static func markAsShown(store: DataStore, isHalbjahr: Bool) {
        guard let bundesland = store.selectedBundesland else { return }
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let key = isHalbjahr ? "hj_\(bundesland.rawValue)_\(year)" : "sj_\(bundesland.rawValue)_\(year)"
        let existing = UserDefaults.standard.string(forKey: "lastWrappedShown") ?? ""
        UserDefaults.standard.set(existing + "," + key, forKey: "lastWrappedShown")
    }
}
