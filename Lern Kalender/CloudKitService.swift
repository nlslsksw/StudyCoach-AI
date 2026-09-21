import CloudKit
import Foundation

// MARK: - CloudKit Service

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
        let digits = (0..<6).map { _ in String(Int.random(in: 0...9)) }
        return digits.joined()
    }

    func createFamilyLink(code: String) async throws {
        let record = CKRecord(recordType: "FamilyLink")
        record["pairingCode"] = code as CKRecordValue
        record["isActive"] = true as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue

        try await publicDB.save(record)
    }

    func lookupPairingCode(_ code: String) async throws -> Bool {
        let predicate = NSPredicate(format: "pairingCode == %@ AND isActive == 1", code)
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

            if let gradesData = try? encoder.encode(store.grades.filter { inYear($0.date) }) {
                record["gradesJSON"] = gradesData as CKRecordValue
            }
            if let sessionsData = try? encoder.encode(store.studySessions.filter { inYear($0.date) }) {
                record["sessionsJSON"] = sessionsData as CKRecordValue
            }
            if let subjectsData = try? encoder.encode(subjects) {
                record["subjectsJSON"] = subjectsData as CKRecordValue
            }
            if let entriesData = try? encoder.encode(store.entries.filter { inYear($0.date) }) {
                record["entriesJSON"] = entriesData as CKRecordValue
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
            let predicate = NSPredicate(format: "pairingCode == %@", pairingCode)
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

            if let gradesData = record["gradesJSON"] as? Data,
               let grades = try? decoder.decode([Grade].self, from: gradesData) {
                data.grades = grades
            }
            if let sessionsData = record["sessionsJSON"] as? Data,
               let sessions = try? decoder.decode([StudySession].self, from: sessionsData) {
                data.sessions = sessions
            }
            if let subjectsData = record["subjectsJSON"] as? Data,
               let subjects = try? decoder.decode([Subject].self, from: subjectsData) {
                data.subjects = subjects
            }
            if let entriesData = record["entriesJSON"] as? Data,
               let entries = try? decoder.decode([CalendarEntry].self, from: entriesData) {
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
        let predicate = NSPredicate(format: "pairingCode == %@", pairingCode)
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
        let dataPredicate = NSPredicate(format: "pairingCode == %@", pairingCode)
        let dataSubscription = CKQuerySubscription(
            recordType: "StudentData",
            predicate: dataPredicate,
            subscriptionID: "studentData-\(pairingCode)",
            options: [.firesOnRecordUpdate]
        )
        let dataInfo = CKSubscription.NotificationInfo()
        dataInfo.shouldSendContentAvailable = true  // silent — just sync data
        dataSubscription.notificationInfo = dataInfo
        try? await publicDB.save(dataSubscription)

        // 2. Activity notification — visible push when the child logs a session.
        let actPredicate = NSPredicate(format: "pairingCode == %@", pairingCode)
        let actSubscription = CKQuerySubscription(
            recordType: "ActivityNotification",
            predicate: actPredicate,
            subscriptionID: "activity-\(pairingCode)",
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
        record["pairingCode"] = pairingCode as CKRecordValue
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
        if let data = try? encoder.encode(entry) {
            record["entryJSON"] = data as CKRecordValue
        }
        record["pairingCode"] = entry.pairingCode as CKRecordValue
        record["entryDate"] = entry.date as CKRecordValue
        try await publicDB.save(record)
    }

    func fetchSharedCalendarEntries(pairingCode: String) async -> [SharedCalendarEntry] {
        let predicate = NSPredicate(format: "pairingCode == %@", pairingCode)
        let query = CKQuery(recordType: "SharedCalendarEntry", predicate: predicate)

        guard let results = try? await publicDB.records(matching: query) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var entries: [SharedCalendarEntry] = []
        for matchResult in results.matchResults {
            if let record = try? matchResult.1.get(),
               let data = record["entryJSON"] as? Data,
               let entry = try? decoder.decode(SharedCalendarEntry.self, from: data) {
                entries.append(entry)
            }
        }
        return entries
    }

    // MARK: - Motivation Messages (Eltern → Kind)

    func saveMotivationMessage(_ message: MotivationMessage) async throws {
        let record = CKRecord(recordType: "MotivationMessage")
        record["pairingCode"] = message.pairingCode as CKRecordValue
        record["text"] = message.text as CKRecordValue
        record["date"] = message.date as CKRecordValue
        try await publicDB.save(record)
    }

    func fetchMotivationMessage(pairingCode: String) async -> MotivationMessage? {
        let predicate = NSPredicate(format: "pairingCode == %@", pairingCode)
        let query = CKQuery(recordType: "MotivationMessage", predicate: predicate)
        let sort = NSSortDescriptor(key: "date", ascending: false)
        query.sortDescriptors = [sort]

        guard let results = try? await publicDB.records(matching: query, resultsLimit: 1),
              let matchResult = results.matchResults.first,
              let record = try? matchResult.1.get() else {
            return nil
        }

        let text = record["text"] as? String ?? ""
        let date = record["date"] as? Date ?? Date()
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
            familyLink["pairingCode"] = "__setup__" as CKRecordValue
            familyLink["isActive"] = 1 as CKRecordValue
            familyLink["createdAt"] = Date() as CKRecordValue
            let savedFL = try await publicDB.save(familyLink)

            // 2. StudentData
            let studentData = CKRecord(recordType: "StudentData")
            studentData["pairingCode"] = "__setup__" as CKRecordValue
            studentData["gradesJSON"] = Data() as CKRecordValue
            studentData["sessionsJSON"] = Data() as CKRecordValue
            studentData["subjectsJSON"] = Data() as CKRecordValue
            studentData["lastUpdated"] = Date() as CKRecordValue
            studentData["currentStreak"] = 0 as CKRecordValue
            studentData["totalMinutesThisWeek"] = 0 as CKRecordValue
            let savedSD = try await publicDB.save(studentData)

            // 3. StudyGoal
            let studyGoal = CKRecord(recordType: "StudyGoal")
            studyGoal["pairingCode"] = "__setup__" as CKRecordValue
            studyGoal["dailyMinutesGoal"] = 0 as CKRecordValue
            studyGoal["weeklyMinutesGoal"] = 0 as CKRecordValue
            let savedSG = try await publicDB.save(studyGoal)

            // 4. ActivityNotification
            let notification = CKRecord(recordType: "ActivityNotification")
            notification["pairingCode"] = "__setup__" as CKRecordValue
            notification["type"] = "setup" as CKRecordValue
            notification["message"] = "Schema erstellt" as CKRecordValue
            notification["timestamp"] = Date() as CKRecordValue
            let savedAN = try await publicDB.save(notification)

            // 5. SharedCalendarEntry
            let sharedEntry = CKRecord(recordType: "SharedCalendarEntry")
            sharedEntry["pairingCode"] = "__setup__" as CKRecordValue
            sharedEntry["entryJSON"] = Data() as CKRecordValue
            sharedEntry["entryDate"] = Date() as CKRecordValue
            let savedSE = try await publicDB.save(sharedEntry)

            // 6. MotivationMessage
            let motivation = CKRecord(recordType: "MotivationMessage")
            motivation["pairingCode"] = "__setup__" as CKRecordValue
            motivation["text"] = "setup" as CKRecordValue
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
        let predicate = NSPredicate(format: "pairingCode == %@", pairingCode)
        let query = CKQuery(recordType: "StudentData", predicate: predicate)
        let results = try await publicDB.records(matching: query)

        if let matchResult = results.matchResults.first,
           let record = try? matchResult.1.get() {
            return record
        }

        let newRecord = CKRecord(recordType: "StudentData")
        newRecord["pairingCode"] = pairingCode as CKRecordValue
        return newRecord
    }

    private func findOrCreateGoalRecord(pairingCode: String) async throws -> CKRecord {
        let predicate = NSPredicate(format: "pairingCode == %@", pairingCode)
        let query = CKQuery(recordType: "StudyGoal", predicate: predicate)
        let results = try await publicDB.records(matching: query)

        if let matchResult = results.matchResults.first,
           let record = try? matchResult.1.get() {
            return record
        }

        let newRecord = CKRecord(recordType: "StudyGoal")
        newRecord["pairingCode"] = pairingCode as CKRecordValue
        return newRecord
    }
}
