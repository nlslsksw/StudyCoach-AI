import Foundation
import Security

// MARK: - Webuntis Service
//
// Minimaler JSON-RPC-Client für die "klassische" Webuntis-API
// (https://{server}/WebUntis/jsonrpc.do?school={schoolName}).
// Auth-Daten werden lokal gespeichert: alles außer dem Passwort in
// UserDefaults, das Passwort im Keychain. Es findet kein iCloud-Sync
// statt — Webuntis-Zugang ist gerätelokal.
//
// Diese Implementierung deckt den Login + Stundenplan + Hausaufgaben
// ab; sie ist bewusst defensiv und gibt strukturierte Fehler zurück.

@MainActor
@Observable
final class WebuntisService {
    static let shared = WebuntisService()

    // MARK: Persisted credentials

    private let udServer = "webuntisServer"
    private let udSchool = "webuntisSchool"
    private let udUser = "webuntisUser"
    private let udLastSync = "webuntisLastSync"
    private let keychainAccount = "webuntis.password"

    var server: String {
        get { UserDefaults.standard.string(forKey: udServer) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: udServer) }
    }
    var school: String {
        get { UserDefaults.standard.string(forKey: udSchool) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: udSchool) }
    }
    var user: String {
        get { UserDefaults.standard.string(forKey: udUser) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: udUser) }
    }
    var lastSync: Date? {
        get { UserDefaults.standard.object(forKey: udLastSync) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: udLastSync) }
    }

    var password: String {
        get { Keychain.read(account: keychainAccount) ?? "" }
        set { Keychain.write(account: keychainAccount, password: newValue) }
    }

    var isConfigured: Bool {
        !server.isEmpty && !school.isEmpty && !user.isEmpty && !password.isEmpty
    }

    // MARK: Runtime-Status

    var isSyncing = false
    var lastError: String?

    private var sessionId: String?
    private var personType: Int?
    private var personId: Int?

    // MARK: - Public API

    /// Verbindet, holt Stundenplan + Hausaufgaben und mappt sie in den DataStore.
    /// Stundenplan: aktuelle Woche. Hausaufgaben: nächste 4 Wochen.
    /// Beide Sync-Schritte laufen unabhängig — wenn einer fehlschlägt, wird
    /// der andere trotzdem versucht und der Fehler gesammelt zurückgegeben.
    func sync(into store: DataStore) async {
        guard isConfigured else {
            lastError = "Bitte erst in den Einstellungen verbinden."
            return
        }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await authenticate()
        } catch {
            lastError = (error as? WebuntisError)?.userMessage ?? error.localizedDescription
            return
        }

        let weekRange = currentWeekRange()
        // Webuntis zeigt nur diese und nächste Woche → wir fetchen 14 Tage.
        let endRange = addDays(7, to: weekRange.end)
        var errors: [String] = []
        var importedSlots = 0
        var importedHomework = 0
        var changes: [TimetableChange] = []

        // 1) Stundenplan — verschiedene Methodennamen ausprobieren, falls
        //    eine Schule den Klassiker getTimetable abgeschaltet hat.
        do {
            let slots = try await fetchTimetable(from: weekRange.start, to: endRange)
            await MainActor.run { changes = mergeTimetable(slots, into: store) }
            importedSlots = slots.count
        } catch {
            let msg = (error as? WebuntisError)?.userMessage ?? error.localizedDescription
            errors.append("Stundenplan: \(msg)")
        }

        // 2) Hausaufgaben
        do {
            let homework = try await fetchHomework(from: weekRange.start, to: addDays(28, to: weekRange.end))
            await MainActor.run { mergeHomework(homework, into: store) }
            importedHomework = homework.count
        } catch {
            let msg = (error as? WebuntisError)?.userMessage ?? error.localizedDescription
            errors.append("Hausaufgaben: \(msg)")
        }

        // Benachrichtigungen bei neuen Vertretungen/Ausfällen — nicht beim
        // allerersten Sync (sonst poppt für jede Stunde ein Ping auf).
        if lastSync != nil {
            for change in changes.prefix(10) {
                NotificationHelper.scheduleTimetableChange(change)
            }
        }

        try? await logout()
        lastSync = Date()

        if errors.isEmpty {
            lastError = nil
        } else if importedSlots == 0 && importedHomework == 0 {
            lastError = errors.joined(separator: "\n\n")
        } else {
            // Teilweise erfolgreich
            lastError = "Teilweise importiert (\(importedSlots) Stunden, \(importedHomework) Hausaufgaben).\n\n" + errors.joined(separator: "\n\n")
        }
    }

    /// Testet die Zugangsdaten, ohne Daten zu importieren.
    func testLogin() async throws {
        try await authenticate()
        try? await logout()
    }

    /// Sucht über die öffentliche Webuntis-School-Search-API.
    /// Liefert Treffer, aus denen der Nutzer Schule + Server auswählen kann.
    struct SchoolSearchResult: Identifiable, Hashable {
        let id = UUID()
        let displayName: String
        let loginName: String
        let server: String
        let address: String
    }

    func searchSchools(query: String) async throws -> [SchoolSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard let url = URL(string: "https://mobile.webuntis.com/ms/schoolquery2") else { return [] }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "id": UUID().uuidString,
            "method": "searchSchool",
            "params": [["search": trimmed]],
            "jsonrpc": "2.0"
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw WebuntisError.http((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let result = json?["result"] as? [String: Any],
              let schools = result["schools"] as? [[String: Any]] else { return [] }

        return schools.compactMap { s -> SchoolSearchResult? in
            guard let displayName = s["displayName"] as? String,
                  let loginName = s["loginName"] as? String,
                  let server = s["server"] as? String else { return nil }
            let address = (s["address"] as? String) ?? ""
            return SchoolSearchResult(
                displayName: displayName,
                loginName: loginName,
                server: server,
                address: address
            )
        }
    }

    /// Löscht alle gespeicherten Webuntis-Daten (Credentials + Sync-Status).
    func disconnect() {
        UserDefaults.standard.removeObject(forKey: udServer)
        UserDefaults.standard.removeObject(forKey: udSchool)
        UserDefaults.standard.removeObject(forKey: udUser)
        UserDefaults.standard.removeObject(forKey: udLastSync)
        Keychain.delete(account: keychainAccount)
        sessionId = nil
        personType = nil
        personId = nil
        lastError = nil
    }

    // MARK: - JSON-RPC core

    private var endpointURL: URL? {
        guard !server.isEmpty, !school.isEmpty else { return nil }
        let rawHost = server.trimmingCharacters(in: .whitespacesAndNewlines)
        // Falls der Nutzer "hepta.webuntis.com" oder einen vollen Hostnamen
        // eingegeben hat, übernehmen; sonst Subdomain ergänzen.
        let host = rawHost.contains(".") ? rawHost : "\(rawHost).webuntis.com"

        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = host
        comps.path = "/WebUntis/jsonrpc.do"
        comps.queryItems = [URLQueryItem(name: "school", value: school)]
        return comps.url
    }

    private func rpc(method: String, params: Any) async throws -> Any {
        guard let url = endpointURL else { throw WebuntisError.notConfigured }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let sessionId {
            req.setValue("JSESSIONID=\(sessionId)", forHTTPHeaderField: "Cookie")
        }

        let body: [String: Any] = [
            "id": UUID().uuidString,
            "method": method,
            "params": params,
            "jsonrpc": "2.0"
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw WebuntisError.http(code, url: url.absoluteString)
        }
        let json = try JSONSerialization.jsonObject(with: data)
        guard let dict = json as? [String: Any] else { throw WebuntisError.malformed }

        if let err = dict["error"] as? [String: Any] {
            let code = err["code"] as? Int ?? -1
            let msg = err["message"] as? String ?? "Unbekannter Fehler"
            throw WebuntisError.rpc(code: code, message: msg)
        }
        return dict["result"] ?? NSNull()
    }

    private func authenticate() async throws {
        let result = try await rpc(method: "authenticate", params: [
            "user": user,
            "password": password,
            "client": "LernKalenderApp"
        ])
        guard let r = result as? [String: Any],
              let sid = r["sessionId"] as? String else {
            throw WebuntisError.authFailed
        }
        sessionId = sid
        personType = r["personType"] as? Int
        personId = r["personId"] as? Int
    }

    private func logout() async throws {
        _ = try? await rpc(method: "logout", params: [String: Any]())
        sessionId = nil
    }

    // MARK: - Endpoints

    private struct RawSlot {
        let id: Int
        let date: Int     // 20260522
        let startTime: Int // 800
        let endTime: Int  // 845
        let subject: String
        let originalSubject: String?
        let room: String
        let teacher: String
        let isCancelled: Bool
        let isSubstitution: Bool
        let info: String
    }

    private func fetchTimetable(from start: Int, to end: Int) async throws -> [RawSlot] {
        guard let personType, let personId else { throw WebuntisError.authFailed }

        let optionsParams: [String: Any] = [
            "options": [
                "startDate": start,
                "endDate": end,
                "element": ["id": personId, "type": personType],
                "showInfo": true,
                "showSubstText": true,
                "showLsText": true,
                "showStudentgroup": false,
                "klasseFields": ["id", "name"],
                "roomFields": ["id", "name"],
                "subjectFields": ["id", "name"],
                "teacherFields": ["id", "name"]
            ]
        ]

        let flatParams: [String: Any] = [
            "id": personId,
            "type": personType,
            "startDate": start,
            "endDate": end
        ]

        // Reihenfolge: zuerst getTimetable mit Options-Wrapper (Standard),
        // dann ohne Wrapper (manche Schulen), dann getTimetable2017 (neuer).
        let attempts: [(method: String, params: Any)] = [
            ("getTimetable", optionsParams),
            ("getTimetable", flatParams),
            ("getTimetable2017", optionsParams)
        ]

        var lastError: Error?
        for attempt in attempts {
            do {
                let result = try await rpc(method: attempt.method, params: attempt.params)
                return parseTimetable(result)
            } catch let err as WebuntisError {
                if case .rpc(let code, _) = err, code == -32601 {
                    // method not found -> nächste Variante probieren
                    lastError = err
                    continue
                }
                throw err
            }
        }
        throw lastError ?? WebuntisError.rpc(code: -32601, message: "Stundenplan-API nicht verfügbar")
    }

    private func parseTimetable(_ result: Any) -> [RawSlot] {
        guard let arr = result as? [[String: Any]] else { return [] }
        return arr.compactMap { entry in
            guard let id = entry["id"] as? Int,
                  let date = entry["date"] as? Int,
                  let s = entry["startTime"] as? Int,
                  let e = entry["endTime"] as? Int else { return nil }
            let subjects = (entry["su"] as? [[String: Any]]) ?? []
            let rooms = (entry["ro"] as? [[String: Any]]) ?? []
            let teachers = (entry["te"] as? [[String: Any]]) ?? []

            // Bei Vertretung enthält das erste Element manchmal "orgname"
            // (original) und "name" (vertretendes Fach).
            let subj = (subjects.first?["name"] as? String) ?? ""
            let origSubj = subjects.first?["orgname"] as? String
            let room = (rooms.first?["name"] as? String) ?? ""
            let teach = (teachers.first?["name"] as? String) ?? ""

            // Code: "cancelled" (Ausfall), "irregular" (Vertretung), sonst regulär.
            let code = (entry["code"] as? String) ?? ""
            let isCancelled = code.lowercased() == "cancelled"
            let isSubstitution = code.lowercased() == "irregular" || (origSubj != nil && origSubj != subj)

            // Info-Text aus mehreren möglichen Feldern.
            var info = ""
            if let s = entry["substText"] as? String, !s.isEmpty { info = s }
            if info.isEmpty, let s = entry["lstext"] as? String, !s.isEmpty { info = s }
            if info.isEmpty, let s = entry["info"] as? String, !s.isEmpty { info = s }
            if info.isEmpty, let s = entry["statflags"] as? String, !s.isEmpty { info = s }

            return RawSlot(
                id: id, date: date, startTime: s, endTime: e,
                subject: subj, originalSubject: origSubj,
                room: room, teacher: teach,
                isCancelled: isCancelled, isSubstitution: isSubstitution,
                info: info
            )
        }
    }

    private struct RawHomework {
        let id: Int
        let dueDate: Int   // 20260522
        let subject: String
        let text: String
    }

    private func fetchHomework(from start: Int, to end: Int) async throws -> [RawHomework] {
        let dictParams: [String: Any] = [
            "startDate": start,
            "endDate": end
        ]

        // Webuntis benennt die Methode je nach Version unterschiedlich,
        // manche Versionen wollen außerdem positionale Parameter [start, end]
        // statt eines Dicts. Wir probieren alle gängigen Kombinationen.
        let attempts: [(method: String, params: Any)] = [
            ("getHomeWork", dictParams),
            ("getHomeworks", dictParams),
            ("getHomeWorks", dictParams),
            ("getHomework", dictParams),
            ("getStudentHomeWork", dictParams),
            ("getHomeWorkForUser", dictParams),
            ("getHomeWork", [start, end]),
            ("getHomeworks", [start, end])
        ]

        var lastError: Error?
        for attempt in attempts {
            do {
                let result = try await rpc(method: attempt.method, params: attempt.params)
                return parseHomework(result)
            } catch let err as WebuntisError {
                if case .rpc(let code, _) = err, code == -32601 || code == -32602 {
                    // -32601 = method not found, -32602 = invalid params
                    lastError = err
                    continue
                }
                throw err
            }
        }
        throw lastError ?? WebuntisError.rpc(
            code: -32601,
            message: "Hausaufgaben-API ist auf eurer Webuntis-Instanz nicht über JSON-RPC verfügbar. Vermutlich gehen Hausaufgaben nur über die neue REST-API (kann ich nachrüsten)."
        )
    }

    private func parseHomework(_ result: Any) -> [RawHomework] {
        guard let dict = result as? [String: Any] else { return [] }
        let records = (dict["records"] as? [[String: Any]]) ?? (dict["homeworks"] as? [[String: Any]]) ?? []
        let lessons = (dict["lessons"] as? [[String: Any]]) ?? []

        let subjectByLessonId: [Int: String] = Dictionary(uniqueKeysWithValues:
            lessons.compactMap { lesson -> (Int, String)? in
                guard let id = lesson["id"] as? Int else { return nil }
                let name = (lesson["subject"] as? String) ?? (lesson["name"] as? String) ?? ""
                return (id, name)
            }
        )

        return records.compactMap { r in
            guard let id = r["id"] as? Int,
                  let dueDate = r["dueDate"] as? Int else { return nil }
            let text = (r["text"] as? String) ?? (r["topic"] as? String) ?? ""
            let lessonId = r["lessonId"] as? Int ?? 0
            let subject = subjectByLessonId[lessonId] ?? (r["subject"] as? String ?? "Allgemein")
            return RawHomework(id: id, dueDate: dueDate, subject: subject, text: text)
        }
    }

    // MARK: - Mapping in den DataStore

    /// Merge mit Diff-Detection: ergebnis enthält die Beschreibungen
    /// neu erkannter Vertretungen/Ausfälle, damit der Aufrufer
    /// Notifications schicken kann.
    @discardableResult
    private func mergeTimetable(_ raw: [RawSlot], into store: DataStore) -> [TimetableChange] {
        var changes: [TimetableChange] = []
        for slot in raw {
            let weekday = isoWeekday(forYYYYMMDD: slot.date)
            let start = hhmm(from: slot.startTime)
            let end = hhmm(from: slot.endTime)
            let lesson = lessonFromStart(slot.startTime)
            let sourceId = String(slot.id)
            let dateValue = dateFromYYYYMMDD(slot.date)

            if let idx = store.timetable.firstIndex(where: { $0.sourceId == sourceId }) {
                let existing = store.timetable[idx]
                var updated = existing
                updated.date = dateValue
                updated.weekday = weekday
                updated.lesson = lesson
                updated.startTime = start
                updated.endTime = end
                updated.subject = slot.subject.isEmpty ? existing.subject : slot.subject
                updated.originalSubject = slot.originalSubject
                updated.room = slot.room
                updated.teacher = slot.teacher
                updated.isCancelled = slot.isCancelled
                updated.isSubstitution = slot.isSubstitution
                updated.info = slot.info

                changes.append(contentsOf: diffChanges(old: existing, new: updated))
                store.timetable[idx] = updated
            } else {
                let new = TimetableSlot(
                    date: dateValue,
                    weekday: weekday, lesson: lesson,
                    startTime: start, endTime: end,
                    subject: slot.subject.isEmpty ? "Unbekannt" : slot.subject,
                    room: slot.room, teacher: slot.teacher,
                    sourceId: sourceId,
                    isCancelled: slot.isCancelled,
                    isSubstitution: slot.isSubstitution,
                    originalSubject: slot.originalSubject,
                    info: slot.info
                )
                store.timetable.append(new)

                if slot.isCancelled || slot.isSubstitution || !slot.info.isEmpty {
                    changes.append(TimetableChange(slot: new, kind: changeKind(for: new)))
                }
            }
        }
        return changes
    }

    private func diffChanges(old: TimetableSlot, new: TimetableSlot) -> [TimetableChange] {
        var result: [TimetableChange] = []
        if !old.isCancelled && new.isCancelled {
            result.append(TimetableChange(slot: new, kind: .cancelled))
        } else if !old.isSubstitution && new.isSubstitution {
            result.append(TimetableChange(slot: new, kind: .substitution))
        } else if old.info != new.info && !new.info.isEmpty {
            result.append(TimetableChange(slot: new, kind: .info))
        } else if old.room != new.room && !new.room.isEmpty {
            result.append(TimetableChange(slot: new, kind: .roomChange))
        }
        return result
    }

    private func changeKind(for slot: TimetableSlot) -> TimetableChange.Kind {
        if slot.isCancelled { return .cancelled }
        if slot.isSubstitution { return .substitution }
        return .info
    }

    private func mergeHomework(_ raw: [RawHomework], into store: DataStore) {
        for hw in raw {
            let due = dateFromYYYYMMDD(hw.dueDate) ?? Date()
            let sourceId = String(hw.id)
            if let idx = store.homework.firstIndex(where: { $0.sourceId == sourceId }) {
                var existing = store.homework[idx]
                existing.subject = hw.subject
                existing.title = hw.text.isEmpty ? existing.title : hw.text
                existing.dueDate = due
                store.homework[idx] = existing
            } else {
                let item = Homework(
                    subject: hw.subject,
                    title: hw.text.isEmpty ? "Hausaufgabe" : hw.text,
                    notes: "",
                    dueDate: due,
                    sourceId: sourceId
                )
                store.homework.append(item)
            }
        }
    }

    // MARK: - Date helpers

    private func currentWeekRange() -> (start: Int, end: Int) {
        let cal = Calendar(identifier: .iso8601)
        let now = Date()
        let interval = cal.dateInterval(of: .weekOfYear, for: now)
        let start = interval?.start ?? now
        let end = cal.date(byAdding: .day, value: 6, to: start) ?? now
        return (yyyymmdd(start), yyyymmdd(end))
    }

    private func yyyymmdd(_ date: Date) -> Int {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 1970) * 10000 + (c.month ?? 1) * 100 + (c.day ?? 1)
    }

    private func addDays(_ days: Int, to yyyymmdd: Int) -> Int {
        guard let date = dateFromYYYYMMDD(yyyymmdd),
              let added = Calendar.current.date(byAdding: .day, value: days, to: date)
        else { return yyyymmdd }
        return self.yyyymmdd(added)
    }

    private func dateFromYYYYMMDD(_ raw: Int) -> Date? {
        var c = DateComponents()
        c.year = raw / 10000
        c.month = (raw % 10000) / 100
        c.day = raw % 100
        return Calendar.current.date(from: c)
    }

    private func isoWeekday(forYYYYMMDD raw: Int) -> Int {
        guard let d = dateFromYYYYMMDD(raw) else { return 1 }
        let wd = Calendar.current.component(.weekday, from: d)
        return wd == 1 ? 7 : wd - 1
    }

    private func hhmm(from intTime: Int) -> String {
        let h = intTime / 100
        let m = intTime % 100
        return String(format: "%02d:%02d", h, m)
    }

    private func lessonFromStart(_ start: Int) -> Int {
        // Heuristik: 1. Stunde ~ 7:45-8:00, danach ~45min-Slots.
        let totalMin = (start / 100) * 60 + (start % 100)
        let firstStart = 7 * 60 + 45
        let slot = max(1, (totalMin - firstStart) / 50 + 1)
        return slot
    }
}

// MARK: - Timetable Change (für Push-Benachrichtigungen)

struct TimetableChange {
    let slot: TimetableSlot
    let kind: Kind

    enum Kind {
        case cancelled, substitution, roomChange, info
        var title: String {
            switch self {
            case .cancelled: return "Stunde fällt aus"
            case .substitution: return "Vertretung"
            case .roomChange: return "Raum geändert"
            case .info: return "Neue Info"
            }
        }
    }

    var notificationBody: String {
        let subj = slot.subject
        let when: String = {
            if let d = slot.date {
                let f = DateFormatter()
                f.locale = Locale(identifier: "de_DE")
                f.dateFormat = "EEE d.MM."
                return f.string(from: d)
            }
            return ""
        }()
        switch kind {
        case .cancelled:
            return "\(subj) \(when) \(slot.startTime) entfällt"
        case .substitution:
            let from = slot.originalSubject.map { "(statt \($0)) " } ?? ""
            return "\(subj) \(from)\(when) \(slot.startTime)"
        case .roomChange:
            return "\(subj) \(when): neuer Raum \(slot.room)"
        case .info:
            return "\(subj) \(when): \(slot.info)"
        }
    }
}

// MARK: - Errors

enum WebuntisError: Error {
    case notConfigured
    case authFailed
    case http(Int, url: String? = nil)
    case rpc(code: Int, message: String)
    case malformed

    var userMessage: String {
        switch self {
        case .notConfigured: return "Bitte erst Schule und Zugangsdaten eingeben."
        case .authFailed: return "Login fehlgeschlagen. Bitte Zugangsdaten prüfen."
        case .http(let code, let url):
            if code == 404 {
                return "Schule oder Server nicht gefunden (HTTP 404). Prüfe Server-Adresse und Schul-Login-Name; am sichersten ist „Schule suchen“.\n\nVersuchte URL:\n\(url ?? "?")"
            }
            return "Server-Fehler (HTTP \(code))."
        case .rpc(_, let message): return "Webuntis: \(message)"
        case .malformed: return "Antwort vom Server war ungültig."
        }
    }
}

// MARK: - Keychain (einfacher Wrapper für Passwörter)

enum Keychain {
    private static let service = "de.lernkalender.webuntis"

    static func write(account: String, password: String) {
        let data = Data(password.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
