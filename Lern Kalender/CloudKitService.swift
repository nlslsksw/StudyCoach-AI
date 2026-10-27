import CloudKit
import Foundation

// MARK: - CloudKit Service
//
// Die Familien-Daten liegen in der ÖFFENTLICHEN CloudKit-Datenbank, damit
// Eltern sie über einen Code abrufen können, ohne Einladungslink und ohne
// eigenes iCloud-Konto. Öffentlich heißt: Jeder mit der App kann die
// Datenbank abfragen. Deshalb gilt hier durchgehend:
//
//   • Gesucht wird nur über `codeHash` (SHA-256 des Codes), nie über den Code.
//   • Alle Nutzdaten werden mit `FamilyCrypto` verschlüsselt, bevor sie das
//     Gerät verlassen. Der Schlüssel ist der Code und steht nur auf den
//     beiden gekoppelten Geräten.
//
// Einzige Ausnahme: der kurze Text einer `ActivityNotification`
// ("Mathe – 45 min gelernt"). Den liest Apple beim Zustellen des Pushes aus
// dem Datensatz, er kann deshalb nicht verschlüsselt sein. Er enthält weder
// Namen noch Noten, und der Datensatz ist nur über den Hash auffindbar.

@Observable
final class CloudKitService {
    static let shared = CloudKitService()

    private let container = CKContainer(identifier: "iCloud.Ralf-Lohrmann.Lern-Kalender")
    private let publicDB: CKDatabase

    var isSyncing = false
    var lastSyncDate: Date?
    var syncError: String?

    // Eltern-Modus: geladene Daten pro Kind (Key = pairingCode)
    var remoteData: [String: ChildRemoteData] = [:]

    struct ChildRemoteData {
        var grades: [Grade] = []
        var sessions: [StudySession] = []
        var subjects: [Subject] = []
        var currentStreak: Int = 0
        var weeklyMinutes: Int = 0
        var lastUpdated: Date?
        var entries: [CalendarEntry] = []
    }

    private init() {
        publicDB = container.publicCloudDatabase
    }

    // MARK: - Pairing

    func generatePairingCode() -> String {
        FamilyCrypto.newCode()
    }

    func createFamilyLink(code: String) async throws {
        let record = CKRecord(recordType: "FamilyLink")
        record["codeHash"] = FamilyCrypto.codeHash(code) as CKRecordValue
        record["isActive"] = true as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue

        try await publicDB.save(record)
    }

    func lookupPairingCode(_ code: String) async throws -> Bool {
        let predicate = NSPredicate(format: "codeHash == %@ AND isActive == 1", FamilyCrypto.codeHash(code))
        let query = CKQuery(recordType: "FamilyLink", predicate: predicate)
        let results = try await publicDB.records(matching: query)

        return !results.matchResults.isEmpty
    }

    // MARK: - Student Data Sync (Kind → Cloud)

    func syncStudentData(from store: DataStore) async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demo") { return }   // Demo: keine Cloud
        #endif
        guard let link = store.familyLink, link.isActive else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            // Bestehenden Record suchen oder neuen erstellen
            let record = try await findOrCreateStudentData(pairingCode: link.pairingCode)

            // Daten kodieren
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            // Eltern sehen nur das aktive Schuljahr – sonst tauchen alte Noten
            // im neuen Jahr wieder auf.
            let range = store.activeSchoolYear().map(store.dateRange(of:))
            func inYear(_ date: Date) -> Bool { range?.contains(date) ?? true }
            let subjects = store.activeSchoolYear().map(store.subjectsFor(schoolYear:)) ?? store.subjects

            // Jedes Feld wird mit dem Kopplungscode verschlüsselt. In der
            // öffentlichen Datenbank steht damit nur unlesbares Material.
            let code = link.pairingCode
            if let roh = try? encoder.encode(store.grades.filter { inYear($0.date) }),
               let zu = FamilyCrypto.seal(roh, code: code) {
                record["gradesJSON"] = zu as CKRecordValue
            }
            if let roh = try? encoder.encode(store.studySessions.filter { inYear($0.date) }),
               let zu = FamilyCrypto.seal(roh, code: code) {
                record["sessionsJSON"] = zu as CKRecordValue
            }
            if let roh = try? encoder.encode(subjects),
               let zu = FamilyCrypto.seal(roh, code: code) {
                record["subjectsJSON"] = zu as CKRecordValue
            }
            if let roh = try? encoder.encode(store.entries.filter { inYear($0.date) }),
               let zu = FamilyCrypto.seal(roh, code: code) {
                record["entriesJSON"] = zu as CKRecordValue
            }

            record["lastUpdated"] = Date() as CKRecordValue
            record["currentStreak"] = store.currentStreak() as CKRecordValue
            record["totalMinutesThisWeek"] = store.weeklyTotalMinutes(weekOffset: 0) as CKRecordValue

            try await publicDB.save(record)
            lastSyncDate = Date()
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    // MARK: - Fetch Student Data (Eltern ← Cloud)

    func fetchStudentData(pairingCode: String) async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demo") { return }   // Demo: keine Cloud
        #endif
        isSyncing = true
        defer { isSyncing = false }

        do {
            let predicate = NSPredicate(format: "codeHash == %@", FamilyCrypto.codeHash(pairingCode))
            let query = CKQuery(recordType: "StudentData", predicate: predicate)
            let results = try await publicDB.records(matching: query)

            guard let matchResult = results.matchResults.first,
                  let record = try? matchResult.1.get() else {
                syncError = "Keine Daten gefunden."
                return
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            var data = ChildRemoteData()

            // Entschlüsseln mit dem Code, den die Eltern eingegeben haben.
            // Schlägt das fehl, passt der Code nicht — dann bleibt das Feld leer.
            func entschluesselt(_ feld: String) -> Data? {
                guard let roh = record[feld] as? Data else { return nil }
                return FamilyCrypto.open(roh, code: pairingCode)
            }
            if let d = entschluesselt("gradesJSON"),
               let grades = try? decoder.decode([Grade].self, from: d) {
                data.grades = grades
            }
            if let d = entschluesselt("sessionsJSON"),
               let sessions = try? decoder.decode([StudySession].self, from: d) {
                data.sessions = sessions
            }
            if let d = entschluesselt("subjectsJSON"),
               let subjects = try? decoder.decode([Subject].self, from: d) {
                data.subjects = subjects
            }
            if let d = entschluesselt("entriesJSON"),
               let entries = try? decoder.decode([CalendarEntry].self, from: d) {
                data.entries = entries
            }
            data.currentStreak = record["currentStreak"] as? Int ?? 0
            data.weeklyMinutes = record["totalMinutesThisWeek"] as? Int ?? 0
            data.lastUpdated = record["lastUpdated"] as? Date

            remoteData[pairingCode] = data
            lastSyncDate = Date()
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    // MARK: - Study Goals

    func saveStudyGoal(_ goal: StudyGoal, pairingCode: String) async throws {
        let record = try await findOrCreateGoalRecord(pairingCode: pairingCode)
        record["dailyMinutesGoal"] = goal.dailyMinutesGoal as CKRecordValue
        record["weeklyMinutesGoal"] = goal.weeklyMinutesGoal as CKRecordValue
        try await publicDB.save(record)
    }

    func fetchStudyGoal(pairingCode: String) async -> StudyGoal? {
        let predicate = NSPredicate(format: "codeHash == %@", FamilyCrypto.codeHash(pairingCode))
        let query = CKQuery(recordType: "StudyGoal", predicate: predicate)

        guard let results = try? await publicDB.records(matching: query),
              let matchResult = results.matchResults.first,
              let record = try? matchResult.1.get() else {
            return nil
        }

        let daily = record["dailyMinutesGoal"] as? Int ?? 0
        let weekly = record["weeklyMinutesGoal"] as? Int ?? 0
        return StudyGoal(dailyMinutesGoal: daily, weeklyMinutesGoal: weekly)
    }

    // MARK: - Notifications (via CloudKit Subscriptions)

    func subscribeToStudentDataChanges(pairingCode: String) async {
        // 1. Generic subscription on StudentData updates (backup / data sync).
        let dataPredicate = NSPredicate(format: "codeHash == %@", FamilyCrypto.codeHash(pairingCode))
        let dataSubscription = CKQuerySubscription(
            recordType: "StudentData",
            predicate: dataPredicate,
            subscriptionID: "studentData-\(FamilyCrypto.codeHash(pairingCode).prefix(16))",
            options: [.firesOnRecordUpdate]
        )
        let dataInfo = CKSubscription.NotificationInfo()
        dataInfo.shouldSendContentAvailable = true  // silent — just sync data
        dataSubscription.notificationInfo = dataInfo
        try? await publicDB.save(dataSubscription)

        // 2. Activity notification — visible push when the child logs a session.
        let actPredicate = NSPredicate(format: "codeHash == %@", FamilyCrypto.codeHash(pairingCode))
        let actSubscription = CKQuerySubscription(
            recordType: "ActivityNotification",
            predicate: actPredicate,
            subscriptionID: "activity-\(FamilyCrypto.codeHash(pairingCode).prefix(16))",
            options: [.firesOnRecordCreation]
        )
        let actInfo = CKSubscription.NotificationInfo()
        // Text kommt aus dem Record ("message"), damit Eltern z. B.
        // "Mathe – 45 min gelernt" oder den Wochenbericht sehen.
        actInfo.titleLocalizationKey = "PUSH_ACTIVITY_TITLE"
        actInfo.alertLocalizationKey = "PUSH_ACTIVITY_BODY"
        actInfo.alertLocalizationArgs = ["message"]
        actInfo.soundName = "default"
        actInfo.shouldSendContentAvailable = true
        actSubscription.notificationInfo = actInfo
        // Bestehende Subscription (alter fester Text) ersetzen
        try? await publicDB.deleteSubscription(withID: actSubscription.subscriptionID)
        try? await publicDB.save(actSubscription)
    }

    /// Einmalig pro Version: Subscriptions aller verbundenen Kinder neu anlegen,
    /// damit bereits gekoppelte Eltern den dynamischen Push-Text bekommen.
    func refreshSubscriptionsIfNeeded(for links: [FamilyLink]) async {
        let key = "activitySubscriptionVersion"
        let version = 2
        guard UserDefaults.standard.integer(forKey: key) < version else { return }
        for link in links where link.isActive {
            await subscribeToStudentDataChanges(pairingCode: link.pairingCode)
        }
        UserDefaults.standard.set(version, forKey: key)
    }

    func sendActivityNotification(type: String, message: String, pairingCode: String) async {
        let record = CKRecord(recordType: "ActivityNotification")
        record["codeHash"] = FamilyCrypto.codeHash(pairingCode) as CKRecordValue
        record["type"] = type as CKRecordValue
        record["message"] = message as CKRecordValue
        record["timestamp"] = Date() as CKRecordValue

        try? await publicDB.save(record)
    }

    // MARK: - Shared Calendar Entries (Eltern → Kind)

    func saveSharedCalendarEntry(_ entry: SharedCalendarEntry) async throws {
        let record = CKRecord(recordType: "SharedCalendarEntry")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let roh = try? encoder.encode(entry),
           let zu = FamilyCrypto.seal(roh, code: entry.pairingCode) {
            record["entryJSON"] = zu as CKRecordValue
        }
        record["codeHash"] = FamilyCrypto.codeHash(entry.pairingCode) as CKRecordValue
        record["entryDate"] = entry.date as CKRecordValue
        try await publicDB.save(record)
    }

    func fetchSharedCalendarEntries(pairingCode: String) async -> [SharedCalendarEntry] {
        let predicate = NSPredicate(format: "codeHash == %@", FamilyCrypto.codeHash(pairingCode))
        let query = CKQuery(recordType: "SharedCalendarEntry", predicate: predicate)

        guard let results = try? await publicDB.records(matching: query) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var entries: [SharedCalendarEntry] = []
        for matchResult in results.matchResults {
            if let record = try? matchResult.1.get(),
               let roh = record["entryJSON"] as? Data,
               let data = FamilyCrypto.open(roh, code: pairingCode),
               let entry = try? decoder.decode(SharedCalendarEntry.self, from: data) {
                entries.append(entry)
            }
        }
        return entries
    }

    // MARK: - Motivation Messages (Eltern → Kind)

    func saveMotivationMessage(_ message: MotivationMessage) async throws {
        let record = CKRecord(recordType: "MotivationMessage")
        record["codeHash"] = FamilyCrypto.codeHash(message.pairingCode) as CKRecordValue
        if let zu = FamilyCrypto.sealText(message.text, code: message.pairingCode) {
            record["textEnc"] = zu as CKRecordValue
        }
        record["date"] = message.date as CKRecordValue
        try await publicDB.save(record)
    }

    func fetchMotivationMessage(pairingCode: String) async -> MotivationMessage? {
        let predicate = NSPredicate(format: "codeHash == %@", FamilyCrypto.codeHash(pairingCode))
        let query = CKQuery(recordType: "MotivationMessage", predicate: predicate)
        let sort = NSSortDescriptor(key: "date", ascending: false)
        query.sortDescriptors = [sort]

        guard let results = try? await publicDB.records(matching: query, resultsLimit: 1),
              let matchResult = results.matchResults.first,
              let record = try? matchResult.1.get() else {
            return nil
        }

        let date = record["date"] as? Date ?? Date()
        guard let roh = record["textEnc"] as? Data,
              let text = FamilyCrypto.openText(roh, code: pairingCode) else { return nil }
        return MotivationMessage(text: text, date: date, pairingCode: pairingCode)
    }

    // MARK: - Schema Setup (Development)

    /// Erstellt alle Record Types automatisch in CloudKit Development.
    /// Einmal ausführen, dann im Dashboard "Deploy to Production" klicken.
    var schemaSetupComplete = false
    var schemaSetupError: String?

    func setupCloudKitSchema() async {
        do {
            // 1. FamilyLink
            let familyLink = CKRecord(recordType: "FamilyLink")
            familyLink["codeHash"] = "__setup__" as CKRecordValue
            familyLink["isActive"] = 1 as CKRecordValue
            familyLink["createdAt"] = Date() as CKRecordValue
            let savedFL = try await publicDB.save(familyLink)

            // 2. StudentData
            let studentData = CKRecord(recordType: "StudentData")
            studentData["codeHash"] = "__setup__" as CKRecordValue
            studentData["gradesJSON"] = Data() as CKRecordValue
            studentData["sessionsJSON"] = Data() as CKRecordValue
            studentData["subjectsJSON"] = Data() as CKRecordValue
            studentData["lastUpdated"] = Date() as CKRecordValue
            studentData["currentStreak"] = 0 as CKRecordValue
            studentData["totalMinutesThisWeek"] = 0 as CKRecordValue
            let savedSD = try await publicDB.save(studentData)

            // 3. StudyGoal
            let studyGoal = CKRecord(recordType: "StudyGoal")
            studyGoal["codeHash"] = "__setup__" as CKRecordValue
            studyGoal["dailyMinutesGoal"] = 0 as CKRecordValue
            studyGoal["weeklyMinutesGoal"] = 0 as CKRecordValue
            let savedSG = try await publicDB.save(studyGoal)

            // 4. ActivityNotification
            let notification = CKRecord(recordType: "ActivityNotification")
            notification["codeHash"] = "__setup__" as CKRecordValue
            notification["type"] = "setup" as CKRecordValue
            notification["message"] = "Schema erstellt" as CKRecordValue
            notification["timestamp"] = Date() as CKRecordValue
            let savedAN = try await publicDB.save(notification)

            // 5. SharedCalendarEntry
            let sharedEntry = CKRecord(recordType: "SharedCalendarEntry")
            sharedEntry["codeHash"] = "__setup__" as CKRecordValue
            sharedEntry["entryJSON"] = Data() as CKRecordValue
            sharedEntry["entryDate"] = Date() as CKRecordValue
            let savedSE = try await publicDB.save(sharedEntry)

            // 6. MotivationMessage
            let motivation = CKRecord(recordType: "MotivationMessage")
            motivation["codeHash"] = "__setup__" as CKRecordValue
            motivation["textEnc"] = Data() as CKRecordValue
            motivation["date"] = Date() as CKRecordValue
            let savedMM = try await publicDB.save(motivation)

            // Setup-Records wieder löschen
            try await publicDB.deleteRecord(withID: savedFL.recordID)
            try await publicDB.deleteRecord(withID: savedSD.recordID)
            try await publicDB.deleteRecord(withID: savedSG.recordID)
            try await publicDB.deleteRecord(withID: savedAN.recordID)
            try await publicDB.deleteRecord(withID: savedSE.recordID)
            try await publicDB.deleteRecord(withID: savedMM.recordID)

            await MainActor.run {
                schemaSetupComplete = true
                schemaSetupError = nil
            }
        } catch {
            await MainActor.run {
                schemaSetupError = error.localizedDescription
                schemaSetupComplete = false
            }
        }
    }

    // MARK: - Private Helpers

    private func findOrCreateStudentData(pairingCode: String) async throws -> CKRecord {
        let predicate = NSPredicate(format: "codeHash == %@", FamilyCrypto.codeHash(pairingCode))
        let query = CKQuery(recordType: "StudentData", predicate: predicate)
        let results = try await publicDB.records(matching: query)

        if let matchResult = results.matchResults.first,
           let record = try? matchResult.1.get() {
            return record
        }

        let newRecord = CKRecord(recordType: "StudentData")
        newRecord["codeHash"] = FamilyCrypto.codeHash(pairingCode) as CKRecordValue
        return newRecord
    }

    private func findOrCreateGoalRecord(pairingCode: String) async throws -> CKRecord {
        let predicate = NSPredicate(format: "codeHash == %@", FamilyCrypto.codeHash(pairingCode))
        let query = CKQuery(recordType: "StudyGoal", predicate: predicate)
        let results = try await publicDB.records(matching: query)

        if let matchResult = results.matchResults.first,
           let record = try? matchResult.1.get() {
            return record
        }

        let newRecord = CKRecord(recordType: "StudyGoal")
        newRecord["codeHash"] = FamilyCrypto.codeHash(pairingCode) as CKRecordValue
        return newRecord
    }
}
