# Parental Control Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the parental control system to support multiple children, PIN protection, richer dashboard, parent-created exams, push notifications, motivation messages, and weekly reports.

**Architecture:** The app uses `@Observable` DataStore with UserDefaults persistence and CloudKit for parent-child sync. All views are SwiftUI. Parent mode shows a TabView with dashboard/settings; student mode shows calendar/subjects/study log/statistics tabs. Changes span models, DataStore, CloudKit service, and all parent-facing views.

**Tech Stack:** SwiftUI, CloudKit (public database), UserDefaults, Keychain (for PIN), `@Observable` pattern

---

### Task 1: Update Models

**Files:**
- Modify: `Lern Kalender/Lern Kalender/Models.swift`

- [ ] **Step 1: Add `Identifiable` to FamilyLink and add `childName`**

In `Models.swift`, replace the existing `FamilyLink` struct:

```swift
struct FamilyLink: Codable {
    var pairingCode: String
    var isActive: Bool = true
    var linkedDate: Date = Date()
}
```

With:

```swift
struct FamilyLink: Identifiable, Codable {
    var id = UUID()
    var pairingCode: String
    var childName: String = ""
    var isActive: Bool = true
    var linkedDate: Date = Date()
}
```

- [ ] **Step 2: Add MotivationMessage model**

Add after the `StudyGoal` struct:

```swift
struct MotivationMessage: Identifiable, Codable {
    var id = UUID()
    var text: String
    var date: Date = Date()
    var pairingCode: String
    var isRead: Bool = false
}
```

- [ ] **Step 3: Add SharedCalendarEntry model**

Add after `MotivationMessage`:

```swift
struct SharedCalendarEntry: Identifiable, Codable {
    var id = UUID()
    var title: String
    var subject: String
    var date: Date
    var pairingCode: String
    var createdByParent: Bool = true
}
```

- [ ] **Step 4: Verify build**

Build the project in Xcode (Cmd+B). Expected: compiles with no new errors in Models.swift.

- [ ] **Step 5: Commit**

```bash
git add "Lern Kalender/Models.swift"
git commit -m "feat: update FamilyLink model, add MotivationMessage and SharedCalendarEntry"
```

---

### Task 2: Update DataStore for Multi-Child and PIN

**Files:**
- Modify: `Lern Kalender/Lern Kalender/DataStore.swift`

- [ ] **Step 1: Replace single familyLink with array and add new properties**

In `DataStore.swift`, replace these three properties:

```swift
var appMode: AppMode? = nil {
    didSet { saveAppMode() }
}
var familyLink: FamilyLink? = nil {
    didSet { saveFamilyLink() }
}
var studyGoal: StudyGoal? = nil {
    didSet { saveStudyGoal() }
}
```

With:

```swift
var appMode: AppMode? = nil {
    didSet { saveAppMode() }
}
var familyLink: FamilyLink? = nil {
    didSet { saveFamilyLink() }
}
var familyLinks: [FamilyLink] = [] {
    didSet { saveFamilyLinks() }
}
var studyGoal: StudyGoal? = nil {
    didSet { saveStudyGoal() }
}
var studyGoals: [String: StudyGoal] = [:] {
    didSet { saveStudyGoals() }
}
var parentalPIN: String? = nil {
    didSet { saveParentalPIN() }
}
var motivationMessage: MotivationMessage? = nil {
    didSet { saveMotivationMessage() }
}
var sharedCalendarEntries: [SharedCalendarEntry] = [] {
    didSet { saveSharedEntries() }
}
```

- [ ] **Step 2: Add storage keys**

Add after the existing `studyGoalKey`:

```swift
private let familyLinksKey = "familyLinks"
private let studyGoalsKey = "studyGoals"
private let parentalPINKey = "parentalPIN"
private let motivationMessageKey = "motivationMessage"
private let sharedEntriesKey = "sharedCalendarEntries"
```

- [ ] **Step 3: Add loading in init()**

Add at the end of `init()`, after the existing `studyGoal` loading block:

```swift
if let data = UserDefaults.standard.data(forKey: familyLinksKey),
   let decoded = try? JSONDecoder().decode([FamilyLink].self, from: data) {
    familyLinks = decoded
}
// Migration: if old single familyLink exists and familyLinks is empty, migrate it
if familyLinks.isEmpty, let link = familyLink, appMode == .parent {
    familyLinks = [link]
}
if let data = UserDefaults.standard.data(forKey: studyGoalsKey),
   let decoded = try? JSONDecoder().decode([String: StudyGoal].self, from: data) {
    studyGoals = decoded
}
// Migration: if old single studyGoal exists, migrate it
if studyGoals.isEmpty, let goal = studyGoal, let link = familyLink {
    studyGoals[link.pairingCode] = goal
}
if let pin = UserDefaults.standard.string(forKey: parentalPINKey) {
    parentalPIN = pin
}
if let data = UserDefaults.standard.data(forKey: motivationMessageKey),
   let decoded = try? JSONDecoder().decode(MotivationMessage.self, from: data) {
    motivationMessage = decoded
}
if let data = UserDefaults.standard.data(forKey: sharedEntriesKey),
   let decoded = try? JSONDecoder().decode([SharedCalendarEntry].self, from: data) {
    sharedCalendarEntries = decoded
}
```

- [ ] **Step 4: Add save functions**

Add after the existing `saveStudyGoal()` function:

```swift
private func saveFamilyLinks() {
    if let data = try? JSONEncoder().encode(familyLinks) { UserDefaults.standard.set(data, forKey: familyLinksKey) }
}
private func saveStudyGoals() {
    if let data = try? JSONEncoder().encode(studyGoals) { UserDefaults.standard.set(data, forKey: studyGoalsKey) }
}
private func saveParentalPIN() {
    if let pin = parentalPIN { UserDefaults.standard.set(pin, forKey: parentalPINKey) }
    else { UserDefaults.standard.removeObject(forKey: parentalPINKey) }
}
private func saveMotivationMessage() {
    if let msg = motivationMessage, let data = try? JSONEncoder().encode(msg) { UserDefaults.standard.set(data, forKey: motivationMessageKey) }
    else { UserDefaults.standard.removeObject(forKey: motivationMessageKey) }
}
private func saveSharedEntries() {
    if let data = try? JSONEncoder().encode(sharedCalendarEntries) { UserDefaults.standard.set(data, forKey: sharedEntriesKey) }
}
```

- [ ] **Step 5: Verify build**

Build the project (Cmd+B). Expected: compiles successfully.

- [ ] **Step 6: Commit**

```bash
git add "Lern Kalender/DataStore.swift"
git commit -m "feat: add multi-child familyLinks, studyGoals dict, PIN, motivation message, shared entries to DataStore"
```

---

### Task 3: Create PINEntryView

**Files:**
- Create: `Lern Kalender/Lern Kalender/PINEntryView.swift`

- [ ] **Step 1: Create PINEntryView.swift**

Create new file `Lern Kalender/Lern Kalender/PINEntryView.swift`:

```swift
import SwiftUI

struct PINEntryView: View {
    let title: String
    let subtitle: String
    var onComplete: (String) -> Void

    @State private var pin = ""
    @State private var shake = false
    @State private var failCount = 0
    @State private var isLocked = false
    @State private var lockTimer: Timer?

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text(title)
                .font(.title2.bold())

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // PIN dots
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < pin.count ? Color.blue : Color(.tertiarySystemFill))
                        .frame(width: 20, height: 20)
                }
            }
            .offset(x: shake ? -10 : 0)

            if isLocked {
                Text("Zu viele Versuche. Bitte warte 30 Sekunden.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Number pad
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                ForEach(1...9, id: \.self) { digit in
                    pinButton(String(digit))
                }
                Color.clear.frame(height: 60)
                pinButton("0")
                Button {
                    if !pin.isEmpty { pin.removeLast() }
                } label: {
                    Image(systemName: "delete.backward")
                        .font(.title2)
                        .frame(width: 60, height: 60)
                }
                .disabled(isLocked)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    private func pinButton(_ digit: String) -> some View {
        Button {
            guard !isLocked, pin.count < 4 else { return }
            pin += digit
            if pin.count == 4 {
                onComplete(pin)
            }
        } label: {
            Text(digit)
                .font(.title)
                .frame(width: 60, height: 60)
                .background(Color(.secondarySystemBackground), in: Circle())
        }
        .disabled(isLocked)
    }

    func showError() {
        withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) {
            shake = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shake = false
            pin = ""
            failCount += 1
            if failCount >= 3 {
                isLocked = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                    isLocked = false
                    failCount = 0
                }
            }
        }
    }

    func reset() {
        pin = ""
    }
}

struct PINSetupView: View {
    var onPINSet: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var step: PINStep = .enter
    @State private var firstPIN = ""

    enum PINStep {
        case enter, confirm
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .enter:
                    PINEntryView(
                        title: "PIN festlegen",
                        subtitle: "Wähle einen 4-stelligen PIN für die Elternkontrolle."
                    ) { pin in
                        firstPIN = pin
                        step = .confirm
                    }
                case .confirm:
                    PINEntryView(
                        title: "PIN bestätigen",
                        subtitle: "Gib den PIN erneut ein."
                    ) { pin in
                        if pin == firstPIN {
                            onPINSet(pin)
                            dismiss()
                        } else {
                            firstPIN = ""
                            step = .enter
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}

struct PINGateView<Content: View>: View {
    var store: DataStore
    @ViewBuilder var content: () -> Content

    @State private var isUnlocked = false

    var body: some View {
        if store.parentalPIN == nil || isUnlocked {
            content()
        } else {
            PINEntryView(
                title: "PIN eingeben",
                subtitle: "Gib den Eltern-PIN ein, um fortzufahren."
            ) { pin in
                if pin == store.parentalPIN {
                    isUnlocked = true
                }
            }
        }
    }
}
```

- [ ] **Step 2: Verify build**

Build the project (Cmd+B). Expected: compiles successfully. The new file should be automatically included via the PBXFileSystemSynchronizedRootGroup for the "Lern Kalender" folder.

- [ ] **Step 3: Commit**

```bash
git add "Lern Kalender/PINEntryView.swift"
git commit -m "feat: add PINEntryView, PINSetupView, and PINGateView"
```

---

### Task 4: Update CloudKitService for Shared Entries and Motivation Messages

**Files:**
- Modify: `Lern Kalender/Lern Kalender/CloudKitService.swift`

- [ ] **Step 1: Add properties for per-child remote data**

In `CloudKitService`, replace the existing remote data properties:

```swift
// Eltern-Modus: geladene Daten
var remoteGrades: [Grade] = []
var remoteSessions: [StudySession] = []
var remoteSubjects: [Subject] = []
var remoteCurrentStreak: Int = 0
var remoteWeeklyMinutes: Int = 0
var remoteLastUpdated: Date?
```

With:

```swift
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
```

- [ ] **Step 2: Update fetchStudentData to use per-child storage**

Replace the existing `fetchStudentData` method:

```swift
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
```

- [ ] **Step 3: Update syncStudentData to also sync entries**

In `syncStudentData(from:)`, add after the existing `subjectsJSON` encoding block:

```swift
if let entriesData = try? encoder.encode(store.entries) {
    record["entriesJSON"] = entriesData as CKRecordValue
}
```

- [ ] **Step 4: Add SharedCalendarEntry methods**

Add after the `sendActivityNotification` method:

```swift
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
```

- [ ] **Step 5: Add MotivationMessage methods**

Add after the SharedCalendarEntry methods:

```swift
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
```

- [ ] **Step 6: Update setupCloudKitSchema to include new record types**

In `setupCloudKitSchema()`, add before the "Setup-Records wieder löschen" comment:

```swift
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
```

And add to the cleanup block:

```swift
try await publicDB.deleteRecord(withID: savedSE.recordID)
try await publicDB.deleteRecord(withID: savedMM.recordID)
```

- [ ] **Step 7: Verify build**

Build the project (Cmd+B). Expected: build errors in `ParentDashboardView` because it still references old `remoteGrades`, `remoteSessions`, etc. This is expected and will be fixed in Task 6.

- [ ] **Step 8: Commit**

```bash
git add "Lern Kalender/CloudKitService.swift"
git commit -m "feat: add per-child remote data, shared calendar entries, motivation messages to CloudKitService"
```

---

### Task 5: Remove Disconnect from Child + Add PIN Gate to Settings

**Files:**
- Modify: `Lern Kalender/Lern Kalender/ParentalControlViews.swift`
- Modify: `Lern Kalender/Lern Kalender/SettingsView.swift`

- [ ] **Step 1: Remove disconnect button from ParentalSetupView**

In `ParentalControlViews.swift`, replace the entire connected-state block (lines 29-47):

```swift
if let link = store.familyLink, link.isActive {
    VStack(spacing: 8) {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 32))
            .foregroundStyle(.green)
        Text("Verbunden")
            .font(.headline)
        Text("Code: \(link.pairingCode)")
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)

        Button(role: .destructive) {
            store.familyLink = nil
            store.studyGoal = nil
        } label: {
            Label("Verbindung trennen", systemImage: "xmark.circle")
        }
        .buttonStyle(.bordered)
        .padding(.top, 8)
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
}
```

With (no disconnect button):

```swift
if let link = store.familyLink, link.isActive {
    VStack(spacing: 8) {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 32))
            .foregroundStyle(.green)
        Text("Verbunden")
            .font(.headline)
        Text("Code: \(link.pairingCode)")
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        Text("Nur ein Elternteil kann die Verbindung trennen.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.top, 4)
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
}
```

- [ ] **Step 2: Add PIN gate to SettingsView**

In `SettingsView.swift`, wrap the "Elternkontrolle" Section NavigationLink (the Section starting at line 124) with a PIN gate. Replace:

```swift
// Elternkontrolle
Section {
    NavigationLink {
        ParentalSetupView(store: store)
    } label: {
```

With:

```swift
// Elternkontrolle
Section {
    NavigationLink {
        PINGateView(store: store) {
            ParentalSetupView(store: store)
        }
    } label: {
```

- [ ] **Step 3: Add PIN setup option in SettingsView**

In `SettingsView.swift`, add a new Section after the "Familie" section and before the "CloudKit" section. Add a new `@State` at the top of the struct:

```swift
@State private var showingPINSetup = false
```

And add this section:

```swift
if store.appMode == .student && store.familyLink != nil {
    Section {
        if store.parentalPIN != nil {
            HStack {
                Label("PIN aktiv", systemImage: "lock.fill")
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            Button("PIN ändern") {
                showingPINSetup = true
            }
        } else {
            Button {
                showingPINSetup = true
            } label: {
                Label("Eltern-PIN festlegen", systemImage: "lock.fill")
            }
        }
    } header: {
        Text("Sicherheit")
    } footer: {
        Text("Schützt die Einstellungen mit einem 4-stelligen PIN.")
    }
}
```

And add the sheet modifier to the Form (before `.navigationTitle`):

```swift
.sheet(isPresented: $showingPINSetup) {
    PINSetupView { pin in
        store.parentalPIN = pin
    }
}
```

- [ ] **Step 4: Verify build**

Build (Cmd+B). Expected: compiles successfully.

- [ ] **Step 5: Commit**

```bash
git add "Lern Kalender/ParentalControlViews.swift" "Lern Kalender/SettingsView.swift"
git commit -m "feat: remove child disconnect, add PIN gate to settings"
```

---

### Task 6: Multi-Child Parent Pairing

**Files:**
- Modify: `Lern Kalender/Lern Kalender/ParentalControlViews.swift`

- [ ] **Step 1: Update ParentPairingView to ask for child name and store in familyLinks**

In `ParentalControlViews.swift`, in `ParentPairingView`, add a `@State` property:

```swift
@State private var childName = ""
```

In the `if !isPaired` block, add a TextField before the code input field (before the `TextField("000000"`):

```swift
TextField("Name des Kindes", text: $childName)
    .font(.title3)
    .multilineTextAlignment(.center)
    .padding()
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    .padding(.horizontal, 40)
```

Update the Verbinden button's disabled condition:

```swift
.disabled(codeInput.count != 6 || childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isChecking)
```

In `verifyCode()`, replace:

```swift
if found {
    store.familyLink = FamilyLink(pairingCode: codeInput)
    store.appMode = .parent
    isPaired = true
```

With:

```swift
if found {
    let link = FamilyLink(pairingCode: codeInput, childName: childName.trimmingCharacters(in: .whitespacesAndNewlines))
    store.familyLinks.append(link)
    store.familyLink = link
    store.appMode = .parent
    isPaired = true
```

- [ ] **Step 2: Verify build**

Build (Cmd+B). Expected: compiles. There will be remaining build errors in `ParentDashboardView` from Task 4 changes — that's expected and fixed in the next task.

- [ ] **Step 3: Commit**

```bash
git add "Lern Kalender/ParentalControlViews.swift"
git commit -m "feat: add child name to pairing flow, store in familyLinks array"
```

---

### Task 7: Redesign Parent Dashboard

**Files:**
- Modify: `Lern Kalender/Lern Kalender/ParentalControlViews.swift`

- [ ] **Step 1: Rewrite ParentDashboardView completely**

Replace the entire `ParentDashboardView` struct (from `// MARK: - Parent Dashboard View` to the closing `}` before `// MARK: - Study Goal Setting View`) with:

```swift
// MARK: - Parent Dashboard View

struct ParentDashboardView: View {
    var store: DataStore
    private let cloudKit = CloudKitService.shared
    @State private var selectedChild: FamilyLink?
    @State private var showingAddChild = false
    @State private var showingAddExam = false
    @State private var showingWeeklyReport = false
    @State private var motivationText = ""
    @State private var isSendingMotivation = false

    private var isWeekendReportAvailable: Bool {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 || weekday == 6 || weekday == 7 // So, Fr, Sa
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Child tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.familyLinks) { link in
                            Button {
                                selectedChild = link
                                refreshData()
                            } label: {
                                Text(link.childName.isEmpty ? link.pairingCode : link.childName)
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedChild?.id == link.id ? Color.blue : Color(.tertiarySystemFill), in: Capsule())
                                    .foregroundStyle(selectedChild?.id == link.id ? .white : .primary)
                            }
                        }
                        Button {
                            showingAddChild = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                if let child = selectedChild, let data = cloudKit.remoteData[child.pairingCode] {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Sync status
                            if cloudKit.isSyncing {
                                ProgressView("Daten werden geladen...")
                            }
                            if let error = cloudKit.syncError {
                                Label(error, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .padding(.horizontal)
                            }

                            // Goal progress
                            if let goal = store.studyGoals[child.pairingCode] {
                                parentGoalSection(data: data, goal: goal)
                            }

                            // Quick stats
                            HStack(spacing: 12) {
                                StatCard(title: "Serie", value: "\(data.currentStreak) Tage", icon: "flame.fill", color: .orange)
                                StatCard(title: "Diese Woche", value: formatHoursMinutes(data.weeklyMinutes), icon: "clock.fill", color: .blue)
                            }
                            .padding(.horizontal)

                            // Today's sessions
                            todaySessionsSection(data: data)

                            // Week overview
                            weekOverviewSection(data: data)

                            // Grades
                            gradesSection(data: data)

                            // Upcoming exams
                            examsSection(data: data, pairingCode: child.pairingCode)

                            // Study goal setting
                            goalSettingSection(pairingCode: child.pairingCode)

                            // Motivation message
                            motivationSection(pairingCode: child.pairingCode)

                            Spacer(minLength: 20)
                        }
                        .padding(.top, 8)
                    }
                    .refreshable { refreshData() }
                } else if selectedChild != nil {
                    VStack(spacing: 12) {
                        if cloudKit.isSyncing {
                            ProgressView("Daten werden geladen...")
                        } else {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 30))
                                .foregroundStyle(.secondary)
                            Text("Noch keine Daten")
                                .foregroundStyle(.secondary)
                            Button("Aktualisieren") { refreshData() }
                                .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 60)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Wähle ein Kind aus oder füge eines hinzu.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 60)
                }
            }
            .navigationTitle("Eltern-Dashboard")
            .toolbar {
                if isWeekendReportAvailable {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingWeeklyReport = true
                        } label: {
                            Image(systemName: "doc.text.fill")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddChild) {
                ParentPairingView(store: store)
            }
            .sheet(isPresented: $showingAddExam) {
                if let child = selectedChild {
                    AddExamFromParentView(store: store, pairingCode: child.pairingCode)
                }
            }
            .sheet(isPresented: $showingWeeklyReport) {
                WeeklyReportView(store: store)
            }
            .onAppear {
                if selectedChild == nil { selectedChild = store.familyLinks.first }
                refreshData()
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func parentGoalSection(data: CloudKitService.ChildRemoteData, goal: StudyGoal) -> some View {
        let todayMinutes = data.sessions.filter { Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.minutes }
        let dailyProgress = goal.dailyMinutesGoal > 0 ? Double(todayMinutes) / Double(goal.dailyMinutesGoal) : 0
        let weeklyProgress = goal.weeklyMinutesGoal > 0 ? Double(data.weeklyMinutes) / Double(goal.weeklyMinutesGoal) : 0

        VStack(spacing: 8) {
            if goal.dailyMinutesGoal > 0 {
                goalBar(label: "Heute", current: todayMinutes, goal: goal.dailyMinutesGoal, progress: dailyProgress)
            }
            if goal.weeklyMinutesGoal > 0 {
                goalBar(label: "Diese Woche", current: data.weeklyMinutes, goal: goal.weeklyMinutesGoal, progress: weeklyProgress)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func goalBar(label: String, current: Int, goal: Int, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption.bold())
                Spacer()
                Text("\(formatHoursMinutes(current)) / \(formatHoursMinutes(goal))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if progress >= 1.0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green).font(.caption)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(.tertiarySystemFill))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progress >= 1.0 ? Color.green : Color.blue)
                        .frame(width: min(CGFloat(progress), 1.0) * geo.size.width)
                }
            }
            .frame(height: 8)
        }
    }

    @ViewBuilder
    private func todaySessionsSection(data: CloudKitService.ChildRemoteData) -> some View {
        let todaySessions = data.sessions
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }

        VStack(alignment: .leading, spacing: 8) {
            Text("Heute gelernt")
                .font(.headline)
            if todaySessions.isEmpty {
                Text("Noch keine Lernzeit heute")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(todaySessions) { session in
                    HStack {
                        Text(session.subject).font(.subheadline)
                        Spacer()
                        Text(formatHoursMinutes(session.minutes))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(session.date, style: .time)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func weekOverviewSection(data: CloudKitService.ChildRemoteData) -> some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: today)?.start else { return }

        VStack(alignment: .leading, spacing: 8) {
            Text("Wochenübersicht")
                .font(.headline)
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { offset in
                    let day = cal.date(byAdding: .day, value: offset, to: weekStart)!
                    let mins = data.sessions
                        .filter { cal.isDate($0.date, inSameDayAs: day) }
                        .reduce(0) { $0 + $1.minutes }
                    let isToday = cal.isDateInToday(day)

                    VStack(spacing: 4) {
                        Text(WeekdayHelper.abbreviation(for: cal.component(.weekday, from: day)))
                            .font(.caption2.bold())
                            .foregroundStyle(isToday ? .blue : .secondary)
                        Text("\(mins)m")
                            .font(.system(.caption2, design: .rounded))
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        mins > 0 ? Color.blue.opacity(min(Double(mins) / 60.0, 1.0) * 0.3 + 0.1) : Color(.tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func gradesSection(data: CloudKitService.ChildRemoteData) -> some View {
        if !data.grades.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Noten")
                    .font(.headline)

                ForEach(data.grades.sorted(by: { $0.date > $1.date }).prefix(10)) { grade in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(grade.subject)
                                .font(.subheadline.bold())
                            Text(grade.date, format: .dateTime.day().month())
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text(grade.type.icon)
                            .font(.caption)
                        Text(gradeString(grade.grade))
                            .font(.title3.bold())
                            .foregroundStyle(gradeColor(grade.grade))
                    }
                    .padding(.vertical, 2)
                }

                // Averages
                let gradesBySubject = Dictionary(grouping: data.grades, by: \.subject)
                if gradesBySubject.count > 1 {
                    Divider()
                    Text("Durchschnitte")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ForEach(gradesBySubject.keys.sorted(), id: \.self) { subject in
                        let grades = gradesBySubject[subject] ?? []
                        let avg = grades.map(\.grade).reduce(0, +) / Double(grades.count)
                        HStack {
                            Text(subject).font(.caption)
                            Spacer()
                            Text("Ø \(gradeString(avg))")
                                .font(.caption.bold())
                                .foregroundStyle(gradeColor(avg))
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func examsSection(data: CloudKitService.ChildRemoteData, pairingCode: String) -> some View {
        let upcomingExams = data.entries
            .filter { $0.type == .klassenarbeit && $0.date > Date() }
            .sorted { $0.date < $1.date }

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Klassenarbeiten")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddExam = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
            if upcomingExams.isEmpty {
                Text("Keine anstehenden Klassenarbeiten")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(upcomingExams.prefix(5)) { entry in
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title).font(.subheadline.bold())
                            Text(entry.date, format: .dateTime.day().month().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func goalSettingSection(pairingCode: String) -> some View {
        let goal = Binding(
            get: { store.studyGoals[pairingCode] ?? StudyGoal() },
            set: { store.studyGoals[pairingCode] = $0 }
        )

        VStack(alignment: .leading, spacing: 8) {
            Text("Lernziele")
                .font(.headline)
            Stepper("Täglich: \(goal.wrappedValue.dailyMinutesGoal) min", value: goal.dailyMinutesGoal, in: 0...240, step: 15)
                .font(.subheadline)
            Stepper("Wöchentlich: \(goal.wrappedValue.weeklyMinutesGoal) min", value: goal.weeklyMinutesGoal, in: 0...1200, step: 30)
                .font(.subheadline)
            Button("Ziel speichern") {
                Task {
                    try? await CloudKitService.shared.saveStudyGoal(goal.wrappedValue, pairingCode: pairingCode)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func motivationSection(pairingCode: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nachricht senden")
                .font(.headline)
            HStack {
                TextField("Toll gemacht! 👍", text: $motivationText)
                    .textFieldStyle(.roundedBorder)
                Button {
                    sendMotivation(pairingCode: pairingCode)
                } label: {
                    if isSendingMotivation {
                        ProgressView()
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .disabled(motivationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingMotivation)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func refreshData() {
        guard let child = selectedChild else { return }
        Task {
            await cloudKit.fetchStudentData(pairingCode: child.pairingCode)
            if let goal = await cloudKit.fetchStudyGoal(pairingCode: child.pairingCode) {
                store.studyGoals[child.pairingCode] = goal
            }
        }
    }

    private func sendMotivation(pairingCode: String) {
        isSendingMotivation = true
        let msg = MotivationMessage(text: motivationText, pairingCode: pairingCode)
        Task {
            try? await cloudKit.saveMotivationMessage(msg)
            await MainActor.run {
                motivationText = ""
                isSendingMotivation = false
            }
        }
    }
}
```

- [ ] **Step 2: Verify build**

Build (Cmd+B). Expected: compiles successfully (except possibly StatCard which is referenced but should already exist as a private struct — if not, we add it in the next step).

- [ ] **Step 3: Add StatCard if missing**

Check if `StatCard` exists. If not, add it after `ParentDashboardView`:

```swift
private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add "Lern Kalender/ParentalControlViews.swift"
git commit -m "feat: redesign parent dashboard with multi-child tabs, rich sections, inline goals, motivation"
```

---

### Task 8: Add AddExamFromParentView

**Files:**
- Modify: `Lern Kalender/Lern Kalender/ParentalControlViews.swift`

- [ ] **Step 1: Add AddExamFromParentView**

Add after `ParentDashboardView` (before `StudyGoalSettingView`):

```swift
// MARK: - Add Exam from Parent

struct AddExamFromParentView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore
    let pairingCode: String

    @State private var title = ""
    @State private var subject = ""
    @State private var date = Date()
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Klassenarbeit") {
                    TextField("Titel (z.B. Mathe-Test Kapitel 5)", text: $title)
                    TextField("Fach", text: $subject)
                    DatePicker("Datum", selection: $date)
                        .environment(\.locale, Locale(identifier: "de_DE"))
                }
            }
            .navigationTitle("Klassenarbeit eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        let entry = SharedCalendarEntry(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            pairingCode: pairingCode
        )
        Task {
            try? await CloudKitService.shared.saveSharedCalendarEntry(entry)
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}
```

- [ ] **Step 2: Verify build**

Build (Cmd+B). Expected: compiles successfully.

- [ ] **Step 3: Commit**

```bash
git add "Lern Kalender/ParentalControlViews.swift"
git commit -m "feat: add AddExamFromParentView for parent-created exams"
```

---

### Task 9: Update ContentView for New Parent Layout

**Files:**
- Modify: `Lern Kalender/Lern Kalender/ContentView.swift`

- [ ] **Step 1: Remove separate StudyGoalSettingView tab**

In `ContentView.swift`, replace the parent-mode TabView:

```swift
if store.appMode == .parent {
    TabView {
        ParentDashboardView(store: store)
            .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
        StudyGoalSettingView(store: store)
            .tabItem { Label("Lernziele", systemImage: "target") }
        ParentSettingsTab(store: store)
            .tabItem { Label("Einstellungen", systemImage: "gearshape.fill") }
    }
}
```

With (goals are now inline in dashboard):

```swift
if store.appMode == .parent {
    TabView {
        ParentDashboardView(store: store)
            .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
        ParentSettingsTab(store: store)
            .tabItem { Label("Einstellungen", systemImage: "gearshape.fill") }
    }
}
```

- [ ] **Step 2: Update ParentSettingsTab for multi-child disconnect**

Replace the entire `ParentSettingsTab` struct:

```swift
struct ParentSettingsTab: View {
    var store: DataStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Verbundene Kinder") {
                    if store.familyLinks.isEmpty {
                        Text("Keine Kinder verbunden")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.familyLinks) { link in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(link.childName.isEmpty ? "Kind" : link.childName)
                                        .font(.headline)
                                    Text("Code: \(link.pairingCode)")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .onDelete { offsets in
                            store.familyLinks.remove(atOffsets: offsets)
                            if store.familyLinks.isEmpty {
                                store.appMode = nil
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        store.familyLinks = []
                        store.familyLink = nil
                        store.appMode = nil
                        store.studyGoals = [:]
                    } label: {
                        Label("Alle Verbindungen trennen", systemImage: "xmark.circle")
                    }
                }
            }
            .navigationTitle("Einstellungen")
        }
    }
}
```

- [ ] **Step 3: Add motivation message banner to student view**

In the student-mode `.onAppear` block, add motivation message loading after the existing studyGoal fetch:

```swift
// Motivations-Nachricht laden
if let link = store.familyLink, link.isActive {
    Task {
        if let msg = await CloudKitService.shared.fetchMotivationMessage(pairingCode: link.pairingCode) {
            if store.motivationMessage == nil || store.motivationMessage?.text != msg.text {
                await MainActor.run { store.motivationMessage = msg }
            }
        }
    }
}
```

Add a new `@State` to `ContentView`:

```swift
@State private var showingMotivation = false
```

Add after the `.fullScreenCover(isPresented: $showWrapped)` block:

```swift
.alert("Nachricht von deinen Eltern", isPresented: $showingMotivation) {
    Button("OK") {
        store.motivationMessage = nil
    }
} message: {
    Text(store.motivationMessage?.text ?? "")
}
.onChange(of: store.motivationMessage) { _, newValue in
    if newValue != nil { showingMotivation = true }
}
```

- [ ] **Step 4: Load shared calendar entries on student side**

In the student-mode `.onAppear`, add:

```swift
// Shared calendar entries laden
if let link = store.familyLink, link.isActive {
    Task {
        let shared = await CloudKitService.shared.fetchSharedCalendarEntries(pairingCode: link.pairingCode)
        await MainActor.run { store.sharedCalendarEntries = shared }
    }
}
```

- [ ] **Step 5: Verify build**

Build (Cmd+B). Expected: compiles successfully.

- [ ] **Step 6: Commit**

```bash
git add "Lern Kalender/ContentView.swift"
git commit -m "feat: update parent layout, multi-child settings, motivation banner, shared entry loading"
```

---

### Task 10: Show Shared Calendar Entries in CalendarTab

**Files:**
- Modify: `Lern Kalender/Lern Kalender/CalendarTab.swift`

- [ ] **Step 1: Find where daily entries are displayed and add shared entries**

In `CalendarTab.swift`, find where `store.entries(for: selectedDate)` is used to display the day's events. Add shared calendar entries to the display. After the existing entries list, add:

```swift
// Shared entries from parents
let sharedForDay = store.sharedCalendarEntries.filter {
    Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
}
if !sharedForDay.isEmpty {
    ForEach(sharedForDay) { shared in
        HStack(spacing: 10) {
            Image(systemName: "doc.text.fill")
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(shared.title)
                        .font(.subheadline.bold())
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                if !shared.subject.isEmpty {
                    Text(shared.subject)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(shared.date, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
```

The exact insertion point depends on the CalendarTab structure. Read the file and find the appropriate location where day events are listed.

- [ ] **Step 2: Verify build**

Build (Cmd+B). Expected: compiles successfully.

- [ ] **Step 3: Commit**

```bash
git add "Lern Kalender/CalendarTab.swift"
git commit -m "feat: display parent-shared calendar entries in CalendarTab"
```

---

### Task 11: Create WeeklyReportView

**Files:**
- Create: `Lern Kalender/Lern Kalender/WeeklyReportView.swift`

- [ ] **Step 1: Create WeeklyReportView.swift**

```swift
import SwiftUI

struct WeeklyReportView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore
    private let cloudKit = CloudKitService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Wochenbericht")
                        .font(.largeTitle.bold())
                        .padding(.top)

                    Text(weekRangeString())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if store.familyLinks.isEmpty {
                        Text("Keine Kinder verbunden")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 40)
                    } else {
                        ForEach(store.familyLinks) { link in
                            childReportCard(link: link)
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func childReportCard(link: FamilyLink) -> some View {
        let data = cloudKit.remoteData[link.pairingCode]
        let sessions = data?.sessions ?? []
        let grades = data?.grades ?? []

        let cal = Calendar.current
        let now = Date()
        let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let lastWeekStart = cal.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? now

        let thisWeekSessions = sessions.filter { $0.date >= weekStart }
        let lastWeekSessions = sessions.filter { $0.date >= lastWeekStart && $0.date < weekStart }
        let thisWeekMinutes = thisWeekSessions.reduce(0) { $0 + $1.minutes }
        let lastWeekMinutes = lastWeekSessions.reduce(0) { $0 + $1.minutes }

        let thisWeekGrades = grades.filter { $0.date >= weekStart }

        let percentChange: Int? = lastWeekMinutes > 0
            ? Int(((Double(thisWeekMinutes) / Double(lastWeekMinutes)) - 1.0) * 100)
            : nil

        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "person.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.blue, in: Circle())
                Text(link.childName.isEmpty ? "Kind" : link.childName)
                    .font(.title3.bold())
                Spacer()
            }

            Divider()

            // Total time
            HStack {
                Label("Gesamtlernzeit", systemImage: "clock.fill")
                    .font(.subheadline)
                Spacer()
                Text(formatHoursMinutes(thisWeekMinutes))
                    .font(.subheadline.bold())
            }

            // Comparison
            if let pct = percentChange {
                HStack {
                    Label("Vs. letzte Woche", systemImage: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                        .foregroundStyle(pct >= 0 ? .green : .orange)
                    Spacer()
                    Text("\(pct >= 0 ? "+" : "")\(pct)%")
                        .font(.caption.bold())
                        .foregroundStyle(pct >= 0 ? .green : .orange)
                }
            }

            // Per subject
            let bySubject = Dictionary(grouping: thisWeekSessions, by: \.subject)
            if !bySubject.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pro Fach").font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach(bySubject.keys.sorted(), id: \.self) { subject in
                        let mins = bySubject[subject]?.reduce(0) { $0 + $1.minutes } ?? 0
                        HStack {
                            Text(subject).font(.caption)
                            Spacer()
                            Text(formatHoursMinutes(mins)).font(.caption.monospacedDigit())
                        }
                    }
                }
            }

            // Grades this week
            if !thisWeekGrades.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Neue Noten").font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach(thisWeekGrades) { grade in
                        HStack {
                            Text(grade.subject).font(.caption)
                            Spacer()
                            Text(gradeString(grade.grade))
                                .font(.caption.bold())
                                .foregroundStyle(gradeColor(grade.grade))
                        }
                    }
                }
            }

            // Goal progress
            if let goal = store.studyGoals[link.pairingCode], goal.weeklyMinutesGoal > 0 {
                let progress = Double(thisWeekMinutes) / Double(goal.weeklyMinutesGoal)
                HStack {
                    Label("Wochenziel", systemImage: "target")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(min(progress, 1.0) * 100))%")
                        .font(.caption.bold())
                        .foregroundStyle(progress >= 1.0 ? .green : .blue)
                }
            }

            // Streak
            if let streak = data?.currentStreak, streak > 0 {
                HStack {
                    Label("Serie", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("\(streak) Tage")
                        .font(.caption.bold())
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func weekRangeString() -> String {
        let cal = Calendar.current
        let now = Date()
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start,
              let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) else {
            return ""
        }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        fmt.dateFormat = "d. MMM"
        return "\(fmt.string(from: weekStart)) - \(fmt.string(from: weekEnd))"
    }
}
```

- [ ] **Step 2: Verify build**

Build (Cmd+B). Expected: compiles successfully.

- [ ] **Step 3: Commit**

```bash
git add "Lern Kalender/WeeklyReportView.swift"
git commit -m "feat: add WeeklyReportView with per-child weekly summary and comparison"
```

---

### Task 12: Enhanced Push Notifications

**Files:**
- Modify: `Lern Kalender/Lern Kalender/DataStore.swift`

- [ ] **Step 1: Update syncToCloudIfNeeded to send specific notifications**

In `DataStore.swift`, update `addSession` to send a notification:

```swift
func addSession(_ session: StudySession) {
    studySessions.append(session)
    syncToCloudIfNeeded()
    sendSessionNotification(session)
}

private func sendSessionNotification(_ session: StudySession) {
    guard appMode == .student, let link = familyLink, link.isActive else { return }
    Task {
        await CloudKitService.shared.sendActivityNotification(
            type: "session",
            message: "\(session.subject) - \(formatHoursMinutes(session.minutes)) gelernt",
            pairingCode: link.pairingCode
        )
    }
}
```

Update `addGrade` similarly:

```swift
func addGrade(_ grade: Grade) {
    grades.append(grade)
    syncToCloudIfNeeded()
    sendGradeNotification(grade)
}

private func sendGradeNotification(_ grade: Grade) {
    guard appMode == .student, let link = familyLink, link.isActive else { return }
    Task {
        await CloudKitService.shared.sendActivityNotification(
            type: "grade",
            message: "Neue Note: \(grade.subject) \(gradeString(grade.grade))",
            pairingCode: link.pairingCode
        )
    }
}
```

- [ ] **Step 2: Verify build**

Build (Cmd+B). Expected: compiles successfully.

- [ ] **Step 3: Commit**

```bash
git add "Lern Kalender/DataStore.swift"
git commit -m "feat: send push notifications to parents on new sessions and grades"
```

---

### Task 13: Final Cleanup and Verification

**Files:**
- All modified files

- [ ] **Step 1: Remove unused StudyGoalSettingView references**

The old `StudyGoalSettingView` in `ParentalControlViews.swift` can be kept for now (it's not hurting anything) or removed. The goal setting is now inline in the dashboard.

- [ ] **Step 2: Full build verification**

Build the entire project (Cmd+Shift+K to clean, then Cmd+B). Fix any remaining compilation errors.

- [ ] **Step 3: Run on device/simulator**

Cmd+R to run. Test:
1. Student flow: generate code, verify PIN setup works
2. Parent flow: enter code with child name, verify dashboard loads
3. Check child tabs appear for multiple children
4. Verify motivation message sends and appears
5. Verify exam creation from parent side
6. Check weekly report availability on Friday-Sunday

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete parental control redesign with multi-child, PIN, dashboard, notifications, weekly report"
```
