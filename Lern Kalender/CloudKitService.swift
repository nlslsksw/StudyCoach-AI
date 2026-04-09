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
        guard let link = store.familyLink, link.isActive else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            // Bestehenden Record suchen oder neuen erstellen
            let record = try await findOrCreateStudentData(pairingCode: link.pairingCode)

            // Daten kodieren
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            if let gradesData = try? encoder.encode(store.grades) {
                record["gradesJSON"] = gradesData as CKRecordValue
            }
            if let sessionsData = try? encoder.encode(store.studySessions) {
                record["sessionsJSON"] = sessionsData as CKRecordValue
            }
            if let subjectsData = try? encoder.encode(store.subjects) {
                record["subjectsJSON"] = subjectsData as CKRecordValue
            }
            if let entriesData = try? encoder.encode(store.entries) {
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
        let predicate = NSPredicate(format: "pairingCode == %@", pairingCode)
        let subscription = CKQuerySubscription(
            recordType: "StudentData",
            predicate: predicate,
            options: [.firesOnRecordUpdate]
        )

        let info = CKSubscription.NotificationInfo()
        info.alertBody = "Neue Lernaktivität!"
        info.shouldSendContentAvailable = true
        info.soundName = "default"
        subscription.notificationInfo = info

        try? await publicDB.save(subscription)
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

    // MARK: - Hivemind Topics

    /// Push the child's topics + progress to CloudKit so parents can view them.
    /// No-op if no family link is active.
    func pushTopics(_ topics: [Topic], progress: [UUID: TopicProgress]) async {
        guard let pairingCode = currentPairingCode() else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let record = try await findOrCreateTopicsRecord(pairingCode: pairingCode)
            if let topicsData = try? encoder.encode(topics) {
                record["topicsJSON"] = topicsData as CKRecordValue
            }
            if let progressData = try? encoder.encode(Array(progress.values)) {
                record["progressJSON"] = progressData as CKRecordValue
            }
            record["lastUpdated"] = Date() as CKRecordValue
            try await publicDB.save(record)
        } catch {
            // Silent fail — local state remains source of truth.
        }
    }

    /// Fetch the child's topics + progress (parent side, or device-restore side).
    func fetchTopics(pairingCode: String) async -> (topics: [Topic], progress: [TopicProgress]) {
        let predicate = NSPredicate(format: "pairingCode == %@", pairingCode)
        let query = CKQuery(recordType: "HivemindTopics", predicate: predicate)

        guard let results = try? await publicDB.records(matching: query),
              let matchResult = results.matchResults.first,
              let record = try? matchResult.1.get() else {
            return ([], [])
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var topics: [Topic] = []
        var progress: [TopicProgress] = []
        if let data = record["topicsJSON"] as? Data,
           let decoded = try? decoder.decode([Topic].self, from: data) {
            topics = decoded
        }
        if let data = record["progressJSON"] as? Data,
           let decoded = try? decoder.decode([TopicProgress].self, from: data) {
            progress = decoded
        }
        return (topics, progress)
    }

    /// Parents push an assigned topic to a child's record. Marks `assignedByParent = true`.
    func assignTopicToChild(_ topic: Topic, pairingCode: String) async {
        var assignedTopic = topic
        assignedTopic.assignedByParent = true
        assignedTopic.pairingCode = pairingCode

        let (existing, existingProgress) = await fetchTopics(pairingCode: pairingCode)
        var updated = existing
        if !updated.contains(where: { $0.id == assignedTopic.id }) {
            updated.append(assignedTopic)
        }
        await pushTopics(updated, progress: Dictionary(uniqueKeysWithValues: existingProgress.map { ($0.id, $0) }))
    }

    private func findOrCreateTopicsRecord(pairingCode: String) async throws -> CKRecord {
        let predicate = NSPredicate(format: "pairingCode == %@", pairingCode)
        let query = CKQuery(recordType: "HivemindTopics", predicate: predicate)
        let results = try await publicDB.records(matching: query)
        if let matchResult = results.matchResults.first,
           let record = try? matchResult.1.get() {
            return record
        }
        let new = CKRecord(recordType: "HivemindTopics")
        new["pairingCode"] = pairingCode as CKRecordValue
        return new
    }

    /// Returns the active pairing code from a UserDefaults bridge written by DataStore.
    /// Used to avoid a circular dependency between CloudKitService and DataStore.
    private func currentPairingCode() -> String? {
        return UserDefaults.standard.string(forKey: "currentPairingCodeBridge")
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

            // 7. HivemindTopics
            let hivemind = CKRecord(recordType: "HivemindTopics")
            hivemind["pairingCode"] = "__setup__" as CKRecordValue
            hivemind["topicsJSON"] = Data() as CKRecordValue
            hivemind["progressJSON"] = Data() as CKRecordValue
            hivemind["lastUpdated"] = Date() as CKRecordValue
            let savedHM = try await publicDB.save(hivemind)

            // Setup-Records wieder löschen
            try await publicDB.deleteRecord(withID: savedFL.recordID)
            try await publicDB.deleteRecord(withID: savedSD.recordID)
            try await publicDB.deleteRecord(withID: savedSG.recordID)
            try await publicDB.deleteRecord(withID: savedAN.recordID)
            try await publicDB.deleteRecord(withID: savedSE.recordID)
            try await publicDB.deleteRecord(withID: savedMM.recordID)
            try await publicDB.deleteRecord(withID: savedHM.recordID)

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
