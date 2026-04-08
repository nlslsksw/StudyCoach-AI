# Hivemind-Lernfeed Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Duolingo-style learning path system (`LearnTab`/`LearnPathView`/`LearningPath`) with a Hivemind-inspired Topic+Feed system in a new isolated `Hivemind/` module.

**Architecture:** New feature module `Hivemind/` containing Models, Services (TopicStore with CloudKit-Sync, FeedGenerator using AIService, TopicSourceImporter for OCR/PDF/Link/Podcast) and Views (HivemindTab, TopicFeedView, FeedPostViews, CreateTopicView, DiscoverView, ProfileSheetView). Existing `LearningEngine` is kept (slimmed) for XP, Spaced Repetition, Daily Challenges, Badges. Hivemind module calls `LearningEngine`, never the other way around. Topics + Progress sync via CloudKit, generated feed posts persist locally in `Documents/feeds/<id>.json`.

**Tech Stack:** Swift 5.9+, SwiftUI, `@Observable`, CloudKit, Vision framework (OCR), AIService (Groq-API), Foundation file I/O. iOS 17+. Spec reference: `docs/superpowers/specs/2026-04-08-hivemind-lernfeed-design.md`.

**Important Project Notes:**
- The Xcode project file (`Lern Kalender.xcodeproj/project.pbxproj`) auto-discovers Swift files in the `Lern Kalender/` group when added via Finder, BUT to be safe new files must be **manually added in Xcode** via "Add Files to Project…" with the target "Lern Kalender" checked. The plan flags this in every file-creation task.
- Build verification = `xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' build` from the repo root, OR open Xcode and ⌘B. Use Xcode if xcodebuild is unavailable.
- The user has chosen NO TESTS — every task ends with a manual build verification + commit, not a test run.
- The user has chosen HARD REPLACE — old `LearningPath`/`PathStep` data is discarded; the migration step in Task 2 explicitly removes the UserDefaults key.

---

## File Structure

**New files (all under `Lern Kalender/Hivemind/`):**
```
Hivemind/
├── Models/
│   └── HivemindModels.swift        (Topic, FeedPost, PostType, TopicProgress, TopicSource, PostAnswer)
├── Services/
│   ├── TopicStore.swift            (@Observable, owns topics + progress, CloudKit sync)
│   ├── FeedGenerator.swift         (AI batch generation, daily limit, local persistence)
│   └── TopicSourceImporter.swift   (Image/PDF/URL → text)
└── Views/
    ├── HivemindTab.swift           (main tab view)
    ├── TopicFeedView.swift         (vertical feed scroll)
    ├── FeedPostViews.swift         (5 post sub-views)
    ├── CreateTopicView.swift       (5 source pickers)
    ├── DiscoverView.swift          (category customization)
    └── ProfileSheetView.swift      (XP, Level, Badges, Stats)
```

**Modified files:**
- `Lern Kalender/AIAssistantTab.swift` — remove all `LearningPath`/`LearnPathView`/`pathToOpen`/`create_path` references
- `Lern Kalender/LearningEngine.swift` — remove `learningPaths`, `completeStep`, related load/save code, `LearningPath`-touching challenges
- `Lern Kalender/LearningModels.swift` — remove `LearningPath`, `PathStep`, `PathStep.StepType`, `PathStepJSON`
- `Lern Kalender/CloudKitService.swift` — add `Topic` + `TopicProgress` record types, save/fetch methods, schema-setup additions
- `Lern Kalender/ContentView.swift` — wire `HivemindTab` as a new tab in both iPad sidebar and iPhone TabView for student mode
- `Lern Kalender/ParentalControlViews.swift` — add "Topic für Kind anlegen" entry that opens `CreateTopicView` in parent-mode

**Files to delete:**
- `Lern Kalender/LearnTab.swift`
- `Lern Kalender/LearnPathView.swift`

---

## Task Order Rationale

The plan executes in this order to keep the project compilable after every task:
1. **Phase A — Cleanup** removes references TO `LearningPath` from other files first, THEN removes the type itself. Otherwise the project won't build between steps.
2. **Phase B — Models** introduces the new types in isolation (no consumers yet → trivially compiles).
3. **Phase C — Services** introduces stores and generators that depend only on Models.
4. **Phase D — Views** introduces UI that depends on Services + Models.
5. **Phase E — Integration** wires the new Tab into ContentView and the Parent flow.

Each task is committable and leaves the project in a buildable state.

---

# PHASE A — CLEANUP

## Task 1: Remove LearningPath references from `AIAssistantTab.swift`

`AIAssistantTab.swift` has 6 places that touch the old learning-path system. They must all be removed BEFORE the type itself is deleted, or the project won't compile.

**Files:**
- Modify: `Lern Kalender/AIAssistantTab.swift` (lines 132, 358-362, 850-870, 1140-1180, and references to `message.learningPathId`)

- [ ] **Step 1: Read the relevant sections to confirm exact line content**

Run the tool calls:
- Read `Lern Kalender/AIAssistantTab.swift` at offset 130, limit 10
- Read `Lern Kalender/AIAssistantTab.swift` at offset 355, limit 12
- Read `Lern Kalender/AIAssistantTab.swift` at offset 845, limit 35
- Read `Lern Kalender/AIAssistantTab.swift` at offset 1135, limit 50
- Grep for `learningPathId` in `Lern Kalender/AIAssistantTab.swift` to find the ChatMessage property usages

- [ ] **Step 2: Remove the `pathToOpen` state property**

Edit `Lern Kalender/AIAssistantTab.swift`:

Old:
```swift
    @State private var pathToOpen: LearningPath?
    @State private var navigateToTab: String?
```

New:
```swift
    @State private var navigateToTab: String?
```

- [ ] **Step 3: Remove the `.sheet(item: $pathToOpen)` modifier**

Edit `Lern Kalender/AIAssistantTab.swift`:

Old:
```swift
            .sheet(item: $pathToOpen) { path in
                NavigationStack {
                    LearnPathView(path: path)
                }
            }
            .onAppear {
```

New:
```swift
            .onAppear {
```

- [ ] **Step 4: Remove the "Lernpfad starten" message button block**

Edit `Lern Kalender/AIAssistantTab.swift`. Find the block starting with `// Lernpfad-Link` and the `if let pathId = message.learningPathId {` and remove the entire `Button { ... } label: { ... }` including the closing `}` of the `if` block.

Old (around line 850-880, exact bounds vary — match the whole block from `// Lernpfad-Link` through the closing `}` of the `if let pathId`):
```swift
                // Lernpfad-Link
                if let pathId = message.learningPathId {
                    Button {
                        if let path = LearningEngine.shared.learningPaths.first(where: { $0.id == pathId }) {
                            pathToOpen = path
                        }
                    } label: {
                        // ... button label content ...
                    }
                    // ... possibly more lines until the closing brace of the `if` ...
                }
```

New: (delete the entire block — replace with nothing)

If the next line after the closing `}` is something else (like another sibling view), keep that intact.

- [ ] **Step 5: Remove the `create_path` action handler**

Edit `Lern Kalender/AIAssistantTab.swift`. Find the `case "create_path":` block (around line 1140) and remove from `case "create_path":` through the matching closing `}` before the next `case`.

Old:
```swift
            case "create_path":
                let subject = action["subject"] as? String ?? ""
                let topic = action["topic"] as? String ?? ""
                if !subject.isEmpty && !topic.isEmpty {
                    Task {
                        do {
                            let prompt = """
                            Erstelle einen Lernpfad zum Thema '\(topic)' im Fach \(subject).
                            // ... full prompt ...
                            """
                            // ... generation + parsing + save logic ...
                        }
                    }
                }
```

New: (delete the entire `case "create_path":` block — the next `case` becomes adjacent to the previous one)

- [ ] **Step 6: Find and remove `learningPathId` from the ChatMessage model**

Grep again:
```
Grep pattern: learningPathId  in: Lern Kalender/AIAssistantTab.swift
```

For each match:
- If it's a `var learningPathId: UUID?` declaration in a `struct ChatMessage`, delete that line.
- If it's a usage like `last.learningPathId = path.id`, delete the line.
- If it's used in a `CodingKeys` enum, delete that case as well.

- [ ] **Step 7: Update the `create_path` action documentation in the system prompt**

Edit `Lern Kalender/GeminiService.swift` (which is actually the AIService file). Find the system prompt block in `askWithActions` that lists the actions:

Old:
```swift
        - create_path: Lernpfad erstellen (subject, topic) — Wenn der Schüler einen Lernpfad will
```

New:
```swift
        - create_topic: Hivemind-Topic erstellen (subject, topic) — Wenn der Schüler ein Topic / einen Lernpfad / einen Lernfeed will
```

NOTE: The `create_topic` action is wired up in Task 16 (when CreateTopicView exists). For now we just rename the documentation so the AI stops emitting `create_path`.

- [ ] **Step 8: Build the project to verify no compile errors**

Run from the repo root:
```bash
xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' build 2>&1 | tail -50
```

Expected: BUILD SUCCEEDED.

If the build fails because `LearningPath` / `LearnPathView` / `pathToOpen` is still referenced somewhere, grep for the leftover symbol and remove it.

NOTE: At this point `LearningEngine.swift` still has `learningPaths` as a property and its load/save code. That's OK — the next task removes those.

- [ ] **Step 9: Commit**

```bash
cd "/Users/nilslohrmann/Lern Kalender"
git add "Lern Kalender/AIAssistantTab.swift" "Lern Kalender/GeminiService.swift"
git commit -m "$(cat <<'EOF'
refactor: remove LearningPath references from AIAssistantTab

Prepares the codebase for the Hivemind Topic+Feed system. Removes
pathToOpen state, the LearnPathView sheet, the message-level learning
path link button, and the create_path AI action. The action is renamed
to create_topic in the system prompt (handler will be wired in a later
task).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Slim down `LearningEngine.swift`

Remove `learningPaths` array, `completeStep`, `LearningPath` decode/encode, and any challenges that touch paths.

**Files:**
- Modify: `Lern Kalender/LearningEngine.swift`

- [ ] **Step 1: Remove the `learningPaths` property declaration**

Edit `Lern Kalender/LearningEngine.swift`:

Old (around line 11):
```swift
    var learningPaths: [LearningPath] = []
    var dailyChallenges: [DailyChallenge] = []
```

New:
```swift
    var dailyChallenges: [DailyChallenge] = []
```

- [ ] **Step 2: Remove the `pathsKey` private constant**

Old (around line 17):
```swift
    private let cardsKey = "spacedCards"
    private let pathsKey = "learningPaths"
    private let challengesKey = "dailyChallenges"
```

New:
```swift
    private let cardsKey = "spacedCards"
    private let challengesKey = "dailyChallenges"
```

- [ ] **Step 3: Remove `completeStep` and `xpForPathStep` methods**

Find and delete the entire `completeStep` function in `Lern Kalender/LearningEngine.swift`:

Old (around line 81-94):
```swift
    // MARK: - Learning Paths

    func completeStep(pathId: UUID, stepId: UUID) {
        guard let pathIdx = learningPaths.firstIndex(where: { $0.id == pathId }),
              let stepIdx = learningPaths[pathIdx].steps.firstIndex(where: { $0.id == stepId }) else { return }

        learningPaths[pathIdx].steps[stepIdx].isCompleted = true
        let xp = learningPaths[pathIdx].steps[stepIdx].xpReward
        let subject = learningPaths[pathIdx].subject
        earnXP(xp, subject: subject)

        if learningPaths[pathIdx].isCompleted {
            earnBadge("first_path")
        }
        save()
    }
```

New: (delete the entire block including the `// MARK: - Learning Paths` comment)

Then delete `xpForPathStep`:

Old (around line 37):
```swift
    func xpForPathStep() -> Int { 20 }
```

New: (delete the line)

- [ ] **Step 4: Remove the path-related code in `generateDailyChallenges`**

Edit `Lern Kalender/LearningEngine.swift`. Find the block in `generateDailyChallenges` that uses `learningPaths`:

Old (around line 173-181):
```swift
        // Lernpfad-Challenge wenn aktive Pfade
        let activePaths = learningPaths.filter { !$0.isCompleted }
        if let path = activePaths.first {
            challenges.append(DailyChallenge(
                title: "Lernpfad fortsetzen",
                description: "\(path.title) — \(Int(path.progress * 100))% geschafft",
                xpReward: 30,
                type: .studyTime
            ))
        }
```

New: (delete the entire block)

- [ ] **Step 5: Remove path-related context from `learningContext`**

Edit `Lern Kalender/LearningEngine.swift`. Find in `learningContext()`:

Old (around line 268-272):
```swift
        let activePaths = learningPaths.filter { !$0.isCompleted }
        if !activePaths.isEmpty {
            let pathInfo = activePaths.map { "\($0.title): \(Int($0.progress * 100))%" }
            parts.append("Aktive Lernpfade: \(pathInfo.joined(separator: ", "))")
        }
```

New: (delete the entire block — leave the `let due = cardsDueToday.count` block before it intact)

- [ ] **Step 6: Remove the path load/save code**

Edit `Lern Kalender/LearningEngine.swift`. In `load()`:

Old (around line 294-297):
```swift
        if let data = ud.data(forKey: pathsKey),
           let decoded = try? JSONDecoder().decode([LearningPath].self, from: data) {
            learningPaths = decoded
        }
```

New: (delete the block)

In the same `load()` function, ADD a one-time migration cleanup just before the closing brace:

Old (last lines of `load()`):
```swift
        if let total = ud.object(forKey: "quizStatsTotal") as? Int,
           let perfect = ud.object(forKey: "quizStatsPerfect") as? Int {
            quizStats = (total, perfect)
        }
    }
```

New:
```swift
        if let total = ud.object(forKey: "quizStatsTotal") as? Int,
           let perfect = ud.object(forKey: "quizStatsPerfect") as? Int {
            quizStats = (total, perfect)
        }

        // One-time migration: drop legacy learningPaths data (Hivemind replaces them)
        if ud.object(forKey: "learningPaths") != nil {
            ud.removeObject(forKey: "learningPaths")
        }
    }
```

In `save()`:

Old (around line 312):
```swift
        if let data = try? JSONEncoder().encode(learningPaths) { ud.set(data, forKey: pathsKey) }
```

New: (delete the line)

- [ ] **Step 7: Remove the `first_path` badge from the badge list**

Edit `Lern Kalender/LearningModels.swift`. Find in `Badge.allBadges`:

Old:
```swift
        Badge(id: "first_path", name: "Pfadfinder", icon: "map.fill", description: "Ersten Lernpfad abgeschlossen"),
```

New: (delete the line)

- [ ] **Step 8: Build the project to verify no compile errors**

```bash
xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' build 2>&1 | tail -50
```

Expected: BUILD SUCCEEDED.

NOTE: `LearnTab.swift` and `LearnPathView.swift` still reference `LearningPath` — they will fail to compile. **Solution:** delete those two files BEFORE building. The next sub-step does that.

- [ ] **Step 9: Delete the dead `LearnTab.swift` and `LearnPathView.swift` files**

```bash
cd "/Users/nilslohrmann/Lern Kalender"
rm "Lern Kalender/LearnTab.swift" "Lern Kalender/LearnPathView.swift"
```

In Xcode: open the project, find `LearnTab.swift` and `LearnPathView.swift` in the left sidebar (they will appear in red because they're missing), right-click → "Delete" → "Remove Reference". This removes them from the `.pbxproj` file.

ALTERNATIVE without Xcode: edit `Lern Kalender.xcodeproj/project.pbxproj` and grep for `LearnTab.swift` and `LearnPathView.swift`, then delete every line that references them (PBXFileReference, PBXBuildFile, the `children` arrays). Easier with Xcode.

- [ ] **Step 10: Build again to verify**

```bash
xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' build 2>&1 | tail -50
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 11: Commit**

```bash
cd "/Users/nilslohrmann/Lern Kalender"
git add -A
git commit -m "$(cat <<'EOF'
refactor: slim LearningEngine and delete LearnTab/LearnPathView

Removes learningPaths storage, completeStep, xpForPathStep, the path
challenge generator, and the path entry in learningContext. Adds a
one-time migration to drop the legacy learningPaths UserDefaults key.
Deletes the now-unused LearnTab.swift and LearnPathView.swift files
and the first_path badge.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Slim down `LearningModels.swift`

Remove `LearningPath`, `PathStep`, `PathStep.StepType`, `PathStepJSON`. Keep `LearnerProfile`, `Badge`, `SpacedCard`, `DailyChallenge`.

**Files:**
- Modify: `Lern Kalender/LearningModels.swift`

- [ ] **Step 1: Delete `LearningPath`, `PathStep`, `PathStepJSON`**

Edit `Lern Kalender/LearningModels.swift`. Delete from `// MARK: - Learning Path` (around line 131) all the way to (but NOT including) `// MARK: - Daily Challenge` (around line 188). Then also delete the `// MARK: - JSON Helper` and `PathStepJSON` block at the end of the file.

Old (lines 131-186 plus 207-213):
```swift
// MARK: - Learning Path

struct LearningPath: Identifiable, Codable {
    // ... full struct ...
}

struct PathStep: Identifiable, Codable {
    // ... full struct including StepType enum ...
}
```
And:
```swift
// MARK: - JSON Helper

struct PathStepJSON: Codable {
    var title: String
    var description: String
    var type: String
}
```

New: (both blocks deleted; the file now ends with the `DailyChallenge` struct)

- [ ] **Step 2: Build to verify no remaining references**

```bash
xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' build 2>&1 | tail -50
```

Expected: BUILD SUCCEEDED.

If anything still references `LearningPath`, `PathStep`, or `PathStepJSON`, grep for it and remove the reference. After Tasks 1-2 nothing should remain.

- [ ] **Step 3: Commit**

```bash
cd "/Users/nilslohrmann/Lern Kalender"
git add "Lern Kalender/LearningModels.swift"
git commit -m "$(cat <<'EOF'
refactor: remove LearningPath models from LearningModels

Final cleanup of the learning-path system. Keeps LearnerProfile, Badge,
SpacedCard, and DailyChallenge — these are still used by Hivemind for
XP, gamification, and spaced repetition.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# PHASE B — MODELS

## Task 4: Create `Hivemind/Models/HivemindModels.swift`

The single source of truth for all Hivemind data structures.

**Files:**
- Create: `Lern Kalender/Hivemind/Models/HivemindModels.swift`

- [ ] **Step 1: Verify the Hivemind directory exists, create if needed**

```bash
cd "/Users/nilslohrmann/Lern Kalender"
mkdir -p "Lern Kalender/Hivemind/Models" "Lern Kalender/Hivemind/Services" "Lern Kalender/Hivemind/Views"
```

- [ ] **Step 2: Create `HivemindModels.swift` with the complete model layer**

Write file `Lern Kalender/Hivemind/Models/HivemindModels.swift`:

```swift
import Foundation
import SwiftUI

// MARK: - Topic

struct Topic: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var subject: String?         // optional Schul-Fach
    var iconName: String         // SF Symbol
    var colorHex: String         // hex like "#7C3AED"
    var source: TopicSource
    var createdDate: Date = Date()
    var assignedByParent: Bool = false
    var isDiscover: Bool = false // false = Schul-Topic, true = Discover-Topic
    var pairingCode: String?     // set when synced via CloudKit (parent assignment)

    var color: Color { Color(hex: colorHex) ?? .purple }
}

// MARK: - TopicSource

enum TopicSource: Codable, Hashable {
    case manual(prompt: String)
    case photoOCR(text: String)
    case pdf(filename: String, text: String)
    case webLink(url: URL, text: String)
    case podcast(url: URL, transcript: String)
    case calendarSuggestion(examId: UUID?)

    var label: String {
        switch self {
        case .manual: return "Manuell"
        case .photoOCR: return "Foto"
        case .pdf: return "PDF"
        case .webLink: return "Link"
        case .podcast: return "Podcast"
        case .calendarSuggestion: return "Aus Kalender"
        }
    }

    var sourceText: String? {
        switch self {
        case .manual(let prompt): return prompt
        case .photoOCR(let text): return text
        case .pdf(_, let text): return text
        case .webLink(_, let text): return text
        case .podcast(_, let transcript): return transcript
        case .calendarSuggestion: return nil
        }
    }
}

// MARK: - TopicProgress

struct TopicProgress: Identifiable, Codable, Hashable {
    var id: UUID                 // == Topic.id
    var postsViewed: Int = 0
    var postsCorrect: Int = 0    // bei Quiz/Karten
    var lastViewedDate: Date?
    var feedGeneratedDate: Date?
    var feedExhausted: Bool = false

    /// Returns 0...1 representing how far through the daily feed the user has progressed.
    func percent(totalPosts: Int) -> Double {
        guard totalPosts > 0 else { return 0 }
        return min(Double(postsViewed) / Double(totalPosts), 1.0)
    }
}

// MARK: - FeedPost

struct FeedPost: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var topicId: UUID
    var orderIndex: Int          // sort order in the feed
    var type: PostType
    var isViewed: Bool = false
    var userAnswer: PostAnswer?
}

// MARK: - PostType

enum PostType: Codable, Hashable {
    case textLesson(title: String, body: String)
    case quizCard(question: String, options: [String], correctIndex: Int, explanation: String)
    case flashcard(front: String, back: String)
    case example(scenario: String, walkthrough: String)
    case feynman(prompt: String, expectedKeywords: [String])

    var typeLabel: String {
        switch self {
        case .textLesson: return "Lektion"
        case .quizCard: return "Quiz"
        case .flashcard: return "Karteikarte"
        case .example: return "Beispiel"
        case .feynman: return "Erkläre es"
        }
    }

    var iconName: String {
        switch self {
        case .textLesson: return "lightbulb.fill"
        case .quizCard: return "questionmark.circle.fill"
        case .flashcard: return "rectangle.on.rectangle"
        case .example: return "wand.and.stars"
        case .feynman: return "mic.fill"
        }
    }
}

// MARK: - PostAnswer

enum PostAnswer: Codable, Hashable {
    case quiz(selectedIndex: Int, correct: Bool)
    case flashcard(known: Bool)
    case feynman(transcript: String, feedback: String, score: Int)
    case viewed
}

// MARK: - Color hex helper (used by Topic)

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xff) / 255.0
        let g = Double((v >> 8) & 0xff) / 255.0
        let b = Double(v & 0xff) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
```

- [ ] **Step 3: Add the file to the Xcode project**

In Xcode: right-click the `Lern Kalender` group → "Add Files to Lern Kalender…" → select the new `Hivemind/Models/HivemindModels.swift` → ensure target "Lern Kalender" is checked → "Create groups" → Add.

ALTERNATIVE: open the project in Xcode just once, drag the entire new `Hivemind/` folder onto the project navigator, choose "Create groups" + "Lern Kalender" target.

- [ ] **Step 4: Build to verify**

```bash
xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' build 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED.

If `Color(hex:)` collides with another extension in the project, rename the parameter or move the extension into the file scope only — grep first:
```
Grep pattern: extension Color  in: Lern Kalender
```

- [ ] **Step 5: Commit**

```bash
cd "/Users/nilslohrmann/Lern Kalender"
git add "Lern Kalender/Hivemind/Models/HivemindModels.swift" "Lern Kalender.xcodeproj/project.pbxproj"
git commit -m "$(cat <<'EOF'
feat(hivemind): add HivemindModels with Topic, FeedPost, PostType

Introduces the data layer for the Hivemind feature module: Topic,
TopicSource, TopicProgress, FeedPost, PostType (5 variants), PostAnswer,
plus a Color hex helper used by Topic cards.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# PHASE C — SERVICES

## Task 5: Create `Hivemind/Services/TopicSourceImporter.swift`

Wraps OCR (Vision), PDF text extraction, web fetching. Podcast import is a stub that returns "Coming soon" — the spec marks it as out-of-scope-for-implementation in this iteration.

**Files:**
- Create: `Lern Kalender/Hivemind/Services/TopicSourceImporter.swift`

- [ ] **Step 1: Write the file**

Write `Lern Kalender/Hivemind/Services/TopicSourceImporter.swift`:

```swift
import Foundation
import UIKit
import Vision
import PDFKit

enum TopicImportError: LocalizedError {
    case ocrEmpty
    case pdfTooLarge
    case pdfUnreadable
    case linkFetchFailed(String)
    case podcastNotSupported

    var errorDescription: String? {
        switch self {
        case .ocrEmpty: return "Konnte keinen Text im Bild erkennen — versuch ein anderes Bild oder gib das Thema manuell ein."
        case .pdfTooLarge: return "PDF ist zu groß (max. 5 MB)."
        case .pdfUnreadable: return "PDF konnte nicht gelesen werden."
        case .linkFetchFailed(let msg): return "Link konnte nicht geladen werden: \(msg)"
        case .podcastNotSupported: return "Podcast-Import kommt bald."
        }
    }
}

enum TopicSourceImporter {

    // MARK: - Photo OCR

    static func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw TopicImportError.ocrEmpty }

        let text: String = await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let combined = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: combined)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["de-DE", "en-US"]
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw TopicImportError.ocrEmpty }
        return trimmed
    }

    // MARK: - PDF

    static func extractText(from pdfData: Data) throws -> String {
        guard pdfData.count <= 5 * 1024 * 1024 else { throw TopicImportError.pdfTooLarge }
        guard let document = PDFDocument(data: pdfData) else { throw TopicImportError.pdfUnreadable }

        var combined = ""
        for index in 0..<document.pageCount {
            if let page = document.page(at: index), let pageText = page.string {
                combined += pageText + "\n"
            }
        }

        let trimmed = combined.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw TopicImportError.pdfUnreadable }
        return trimmed
    }

    // MARK: - Web Link (best-effort plain-text scrape)

    static func extractText(from url: URL) async throws -> String {
        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (compatible; Lern-Kalender/1.0)", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else {
                throw TopicImportError.linkFetchFailed("Encoding-Fehler")
            }
            return stripHTML(html)
        } catch let importError as TopicImportError {
            throw importError
        } catch {
            throw TopicImportError.linkFetchFailed(error.localizedDescription)
        }
    }

    private static func stripHTML(_ html: String) -> String {
        // Drop script and style blocks first.
        let withoutScripts = html.replacingOccurrences(
            of: "<script[\\s\\S]*?</script>",
            with: " ",
            options: .regularExpression
        )
        let withoutStyles = withoutScripts.replacingOccurrences(
            of: "<style[\\s\\S]*?</style>",
            with: " ",
            options: .regularExpression
        )
        // Replace tags with spaces.
        let stripped = withoutStyles.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        // Decode the most common entities.
        let entities = stripped
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        // Collapse runs of whitespace.
        let collapsed = entities.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Podcast (stub)

    static func extractText(fromPodcast url: URL) async throws -> String {
        throw TopicImportError.podcastNotSupported
    }
}
```

- [ ] **Step 2: Add to Xcode project**

In Xcode: add `Hivemind/Services/TopicSourceImporter.swift` to the "Lern Kalender" target.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' build 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED. (If `PDFKit` import fails, ensure the Lern Kalender target's "Frameworks, Libraries, and Embedded Content" includes `PDFKit.framework` — add it via Xcode → target → General if missing.)

- [ ] **Step 4: Commit**

```bash
cd "/Users/nilslohrmann/Lern Kalender"
git add "Lern Kalender/Hivemind/Services/TopicSourceImporter.swift" "Lern Kalender.xcodeproj/project.pbxproj"
git commit -m "$(cat <<'EOF'
feat(hivemind): add TopicSourceImporter (OCR, PDF, web link)

Centralizes content extraction for the four supported real-time topic
sources. Photo uses Vision (de+en), PDF uses PDFKit with a 5 MB cap,
web links use a lightweight HTML stripper. Podcast is a stub that
throws .podcastNotSupported (UI shows "Coming soon").

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Create `Hivemind/Services/FeedGenerator.swift`

Wraps the existing `AIService` to generate a batch of `[FeedPost]` for a topic. Persists posts locally per-topic. Tracks daily generation date so the same topic can't generate more than once per day.

**Files:**
- Create: `Lern Kalender/Hivemind/Services/FeedGenerator.swift`

- [ ] **Step 1: Write the file**

Write `Lern Kalender/Hivemind/Services/FeedGenerator.swift`:

```swift
import Foundation

// MARK: - Errors

enum FeedGenerationError: LocalizedError {
    case noAPIKey
    case parsingFailed
    case apiFailed(String)
    case dailyLimitReached

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "Kein KI-Key in den Einstellungen hinterlegt."
        case .parsingFailed: return "KI-Antwort konnte nicht gelesen werden."
        case .apiFailed(let msg): return "KI-Fehler: \(msg)"
        case .dailyLimitReached: return "Du hast heute schon alle Posts gesehen — komm morgen wieder!"
        }
    }
}

// MARK: - JSON shape returned by the AI

private struct AIPost: Decodable {
    let type: String
    let title: String?
    let body: String?
    let question: String?
    let options: [String]?
    let correctIndex: Int?
    let explanation: String?
    let front: String?
    let back: String?
    let scenario: String?
    let walkthrough: String?
    let prompt: String?
    let expectedKeywords: [String]?
}

// MARK: - FeedGenerator

enum FeedGenerator {

    static let postsPerBatch = 15

    /// Generates a batch of `postsPerBatch` posts for the given topic.
    /// Persists them to disk and returns them.
    /// Throws `FeedGenerationError.dailyLimitReached` if the topic already had a generation today.
    static func generateFeed(
        for topic: Topic,
        sourceText: String?,
        previousProgress: TopicProgress?
    ) async throws -> [FeedPost] {

        // Daily-limit guard.
        if let progress = previousProgress,
           let lastGen = progress.feedGeneratedDate,
           Calendar.current.isDateInToday(lastGen),
           progress.feedExhausted {
            throw FeedGenerationError.dailyLimitReached
        }

        guard AIService.shared.hasAPIKey else { throw FeedGenerationError.noAPIKey }

        let prompt = buildPrompt(topic: topic, sourceText: sourceText)

        var raw: String
        do {
            raw = try await AIService.shared.askQuestion(prompt)
        } catch {
            throw FeedGenerationError.apiFailed(error.localizedDescription)
        }

        // Try parse — if it fails, retry once with a stricter wrapper.
        if let posts = parse(raw, topicId: topic.id) {
            try persist(posts: posts, topicId: topic.id)
            return posts
        }

        let strictPrompt = "Antworte AUSSCHLIESSLICH mit einem JSON-Array — kein Markdown, keine Erklärung. Hier ist die Aufgabe:\n\n" + prompt
        do {
            raw = try await AIService.shared.askQuestion(strictPrompt)
        } catch {
            throw FeedGenerationError.apiFailed(error.localizedDescription)
        }
        guard let posts = parse(raw, topicId: topic.id) else {
            throw FeedGenerationError.parsingFailed
        }
        try persist(posts: posts, topicId: topic.id)
        return posts
    }

    // MARK: - Local persistence

    static func loadPosts(for topicId: UUID) -> [FeedPost] {
        let url = postsURL(for: topicId)
        guard let data = try? Data(contentsOf: url) else { return [] }
        do {
            return try JSONDecoder().decode([FeedPost].self, from: data)
        } catch {
            // Corrupt file → wipe so next generation starts clean.
            try? FileManager.default.removeItem(at: url)
            return []
        }
    }

    static func deletePosts(for topicId: UUID) {
        try? FileManager.default.removeItem(at: postsURL(for: topicId))
    }

    static func updatePost(_ post: FeedPost) {
        var posts = loadPosts(for: post.topicId)
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[idx] = post
        try? persist(posts: posts, topicId: post.topicId)
    }

    // MARK: - Private

    private static func persist(posts: [FeedPost], topicId: UUID) throws {
        try ensureDirectoryExists()
        let data = try JSONEncoder().encode(posts)
        try data.write(to: postsURL(for: topicId), options: .atomic)
    }

    private static func feedsDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("feeds", isDirectory: true)
    }

    private static func ensureDirectoryExists() throws {
        let dir = feedsDirectory()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private static func postsURL(for topicId: UUID) -> URL {
        feedsDirectory().appendingPathComponent("\(topicId.uuidString).json")
    }

    private static func buildPrompt(topic: Topic, sourceText: String?) -> String {
        let subjectLine = topic.subject.map { "Schul-Fach: \($0)" } ?? "Bereich: Allgemeinwissen"
        let sourceBlock: String
        if let src = sourceText, !src.isEmpty {
            let trimmed = String(src.prefix(4000))
            sourceBlock = "Lehrmaterial des Schülers:\n\"\"\"\n\(trimmed)\n\"\"\""
        } else {
            sourceBlock = "Kein vorgegebenes Material — generiere zum Topic-Titel."
        }

        return """
        Erstelle einen Lern-Feed mit GENAU \(postsPerBatch) Posts zum Thema "\(topic.title)".
        \(subjectLine)
        \(sourceBlock)

        Mische die Post-Typen abwechslungsreich. Erlaubte Typen und ihre Felder:

        - "textLesson": kurze Mikro-Lektion (1-3 Absätze).
          Felder: title, body
        - "quizCard": Multiple-Choice-Frage mit 4 Optionen.
          Felder: question, options (genau 4 Strings), correctIndex (0-3), explanation
        - "flashcard": klassische Frage/Antwort-Karte.
          Felder: front, back
        - "example": konkrete Anwendung, "So nutzt du das im Alltag".
          Felder: scenario, walkthrough
        - "feynman": eine Aufforderung an den Schüler, etwas in eigenen Worten zu erklären.
          Felder: prompt, expectedKeywords (Array mit 3-6 Keywords, die in einer guten Antwort vorkommen sollten)

        Verteilung pro Batch:
        - 4 textLesson
        - 4 quizCard
        - 3 flashcard
        - 2 example
        - 2 feynman

        Antworte AUSSCHLIESSLICH mit einem JSON-Array. Kein Markdown, kein erklärender Text.
        Format:
        [
          {"type": "textLesson", "title": "...", "body": "..."},
          {"type": "quizCard", "question": "...", "options": ["A","B","C","D"], "correctIndex": 0, "explanation": "..."},
          {"type": "flashcard", "front": "...", "back": "..."},
          {"type": "example", "scenario": "...", "walkthrough": "..."},
          {"type": "feynman", "prompt": "...", "expectedKeywords": ["...", "...", "..."]}
        ]

        Sprache: Deutsch. Niveau: Schüler. Sei prägnant und lehrreich.
        """
    }

    private static func parse(_ raw: String, topicId: UUID) -> [FeedPost]? {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else { return nil }
        guard let aiPosts = try? JSONDecoder().decode([AIPost].self, from: data) else { return nil }

        var posts: [FeedPost] = []
        for (idx, ai) in aiPosts.enumerated() {
            guard let type = mapType(ai) else { continue }
            posts.append(FeedPost(
                topicId: topicId,
                orderIndex: idx,
                type: type
            ))
        }
        return posts.isEmpty ? nil : posts
    }

    private static func mapType(_ ai: AIPost) -> PostType? {
        switch ai.type {
        case "textLesson":
            guard let title = ai.title, let body = ai.body else { return nil }
            return .textLesson(title: title, body: body)
        case "quizCard":
            guard let q = ai.question, let opts = ai.options, opts.count == 4,
                  let correct = ai.correctIndex, (0...3).contains(correct),
                  let explanation = ai.explanation else { return nil }
            return .quizCard(question: q, options: opts, correctIndex: correct, explanation: explanation)
        case "flashcard":
            guard let f = ai.front, let b = ai.back else { return nil }
            return .flashcard(front: f, back: b)
        case "example":
            guard let s = ai.scenario, let w = ai.walkthrough else { return nil }
            return .example(scenario: s, walkthrough: w)
        case "feynman":
            guard let p = ai.prompt, let kws = ai.expectedKeywords else { return nil }
            return .feynman(prompt: p, expectedKeywords: kws)
        default:
            return nil
        }
    }
}
```

- [ ] **Step 2: Add to Xcode project**

In Xcode: add `Hivemind/Services/FeedGenerator.swift` to the "Lern Kalender" target.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' build 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
cd "/Users/nilslohrmann/Lern Kalender"
git add "Lern Kalender/Hivemind/Services/FeedGenerator.swift" "Lern Kalender.xcodeproj/project.pbxproj"
git commit -m "$(cat <<'EOF'
feat(hivemind): add FeedGenerator with batch generation + daily limit

Wraps AIService to produce 15 posts per topic per day, parses the
strict JSON response (with one retry on parse failure), and persists
the posts locally under Documents/feeds/<topic-id>.json. Enforces the
daily limit at the public entry point so callers cannot bypass it.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Create `Hivemind/Services/TopicStore.swift`

The single `@Observable` store for topics + progress. Owns CRUD, integrates with `CloudKitService` for sync (which Task 8 extends), and bridges feed answers to `LearningEngine` (XP, spaced repetition).

**Files:**
- Create: `Lern Kalender/Hivemind/Services/TopicStore.swift`

- [ ] **Step 1: Write the file**

Write `Lern Kalender/Hivemind/Services/TopicStore.swift`:

```swift
import Foundation
import SwiftUI

@Observable
final class TopicStore {
    static let shared = TopicStore()

    var topics: [Topic] = []
    var progress: [UUID: TopicProgress] = [:]

    private let topicsKey = "hivemind.topics"
    private let progressKey = "hivemind.progress"

    private init() {
        load()
    }

    // MARK: - CRUD

    @discardableResult
    func addTopic(_ topic: Topic) -> Topic {
        topics.append(topic)
        progress[topic.id] = TopicProgress(id: topic.id)
        save()
        return topic
    }

    func deleteTopic(id: UUID) {
        topics.removeAll { $0.id == id }
        progress[id] = nil
        FeedGenerator.deletePosts(for: id)
        save()
    }

    func topic(id: UUID) -> Topic? { topics.first { $0.id == id } }

    var schoolTopics: [Topic] { topics.filter { !$0.isDiscover } }
    var discoverTopics: [Topic] { topics.filter { $0.isDiscover } }

    // MARK: - Progress

    func progress(for topicId: UUID) -> TopicProgress {
        progress[topicId] ?? TopicProgress(id: topicId)
    }

    func markFeedGenerated(topicId: UUID) {
        var p = progress[topicId] ?? TopicProgress(id: topicId)
        p.feedGeneratedDate = Date()
        p.feedExhausted = false
        progress[topicId] = p
        save()
    }

    func markFeedExhausted(topicId: UUID) {
        var p = progress[topicId] ?? TopicProgress(id: topicId)
        p.feedExhausted = true
        progress[topicId] = p
        save()
    }

    /// Records a user answer on a feed post and bridges relevant scoring to LearningEngine.
    func recordAnswer(post: FeedPost, answer: PostAnswer) {
        var p = progress[post.topicId] ?? TopicProgress(id: post.topicId)
        if !post.isViewed {
            p.postsViewed += 1
        }
        p.lastViewedDate = Date()

        // Update the persisted post with the answer.
        var updated = post
        updated.isViewed = true
        updated.userAnswer = answer
        FeedGenerator.updatePost(updated)

        // Bridge to LearningEngine.
        let topic = self.topic(id: post.topicId)
        let subject = topic?.subject

        switch answer {
        case .quiz(_, let correct):
            if correct { p.postsCorrect += 1 }
            LearningEngine.shared.recordQuiz(score: correct ? 1 : 0, total: 1, subject: subject ?? "Allgemein")
        case .flashcard(let known):
            if known { p.postsCorrect += 1 }
            // Also feed it into the spaced repetition system.
            if case let .flashcard(front, back) = post.type {
                let card = Flashcard(front: front, back: back)
                LearningEngine.shared.addCards([card], subject: subject ?? "Allgemein", topic: topic?.title ?? "")
            }
            if known {
                LearningEngine.shared.earnXP(LearningEngine.shared.xpForCardKnown(), subject: subject)
            }
        case .feynman(_, _, let score):
            // Score is 0…100; award XP proportionally up to 30.
            let xp = Int(Double(score) / 100.0 * 30)
            LearningEngine.shared.earnXP(xp, subject: subject)
            if score >= 60 { p.postsCorrect += 1 }
        case .viewed:
            // Lessons and examples just give a small XP bump for finishing them.
            LearningEngine.shared.earnXP(2, subject: subject)
        }

        progress[post.topicId] = p
        save()
    }

    // MARK: - Persistence (UserDefaults — CloudKit overlay added in Task 8)

    private func save() {
        let ud = UserDefaults.standard
        if let data = try? JSONEncoder().encode(topics) {
            ud.set(data, forKey: topicsKey)
        }
        if let data = try? JSONEncoder().encode(Array(progress.values)) {
            ud.set(data, forKey: progressKey)
        }

        // Best-effort CloudKit push for parent visibility — fire-and-forget.
        Task { await CloudKitService.shared.pushTopics(topics, progress: progress) }
    }

    private func load() {
        let ud = UserDefaults.standard
        if let data = ud.data(forKey: topicsKey),
           let decoded = try? JSONDecoder().decode([Topic].self, from: data) {
            topics = decoded
        }
        if let data = ud.data(forKey: progressKey),
           let decodedArray = try? JSONDecoder().decode([TopicProgress].self, from: data) {
            progress = Dictionary(uniqueKeysWithValues: decodedArray.map { ($0.id, $0) })
        }
    }

    // MARK: - CloudKit pull (called by Task 16 from ContentView.onAppear)

    func mergeRemote(topics remote: [Topic], progress remoteProgress: [TopicProgress]) {
        // Add any remote topics not yet local (e.g., parent-assigned topics).
        for r in remote where !topics.contains(where: { $0.id == r.id }) {
            topics.append(r)
        }
        // Overwrite progress with the more recently updated record per id.
        for rp in remoteProgress {
            let local = progress[rp.id]
            if local == nil ||
               (local?.lastViewedDate ?? .distantPast) < (rp.lastViewedDate ?? .distantPast) {
                progress[rp.id] = rp
            }
        }
        save()
    }
}
```

- [ ] **Step 2: Add to Xcode project**

In Xcode: add `Hivemind/Services/TopicStore.swift` to the "Lern Kalender" target.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' build 2>&1 | tail -30
```

EXPECTED: This will FAIL with "Value of type 'CloudKitService' has no member 'pushTopics'". That's intentional — Task 8 adds the method. To unblock the build temporarily, comment out the `Task { ... pushTopics ... }` line, then re-enable it after Task 8.

ALTERNATIVE: do Task 8 immediately and skip the temporary comment-out. If executing tasks linearly the alternative is simpler.

- [ ] **Step 4: Commit**

```bash
cd "/Users/nilslohrmann/Lern Kalender"
git add "Lern Kalender/Hivemind/Services/TopicStore.swift" "Lern Kalender.xcodeproj/project.pbxproj"
git commit -m "$(cat <<'EOF'
feat(hivemind): add TopicStore (@Observable) with progress tracking

Owns the topics array and per-topic progress. Bridges feed answers
into LearningEngine: quiz answers update recordQuiz, flashcards flow
into the spaced repetition system, feynman scores award proportional
XP, viewed lessons earn a small XP bump. Persists locally and pushes
to CloudKit for parent visibility (CloudKit method added in Task 8).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Extend `CloudKitService.swift` with Topic methods

Adds `Topic` and `TopicProgress` record types so parents can see what their child is learning and assign topics.

**Files:**
- Modify: `Lern Kalender/CloudKitService.swift`

- [ ] **Step 1: Add `pushTopics` and `fetchTopicsForChild` methods**

Edit `Lern Kalender/CloudKitService.swift`. Find the `// MARK: - Motivation Messages` section and INSERT a new section just before it:

```swift
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

    /// Returns the active pairing code from the local DataStore singleton.
    /// Looked up dynamically to avoid a circular dependency at init.
    private func currentPairingCode() -> String? {
        // Both kid and parent have an active link in the DataStore;
        // this method is called from contexts where DataStore is already created.
        // We use a UserDefaults bridge written by DataStore on every familyLink change.
        return UserDefaults.standard.string(forKey: "currentPairingCodeBridge")
    }
```

- [ ] **Step 2: Bridge `currentPairingCodeBridge` from `DataStore`**

Edit `Lern Kalender/DataStore.swift`. Find the `var familyLink: FamilyLink?` `didSet` block and add a bridge write:

Old:
```swift
    var familyLink: FamilyLink? = nil {
        didSet { saveFamilyLink() }
    }
```

New:
```swift
    var familyLink: FamilyLink? = nil {
        didSet {
            saveFamilyLink()
            UserDefaults.standard.set(familyLink?.pairingCode, forKey: "currentPairingCodeBridge")
        }
    }
```

Also add the same bridge to the parent-side `familyLinks` collection so parents (who have multiple children) can push under the active child:

Old:
```swift
    var familyLinks: [FamilyLink] = [] {
        didSet { saveFamilyLinks() }
    }
```

New:
```swift
    var familyLinks: [FamilyLink] = [] {
        didSet {
            saveFamilyLinks()
            // Parent mode: bridge the FIRST active child code as the default.
            // (Multi-child parent UIs select an explicit child before assigning.)
            if let first = familyLinks.first(where: { $0.isActive }) {
                UserDefaults.standard.set(first.pairingCode, forKey: "currentPairingCodeBridge")
            }
        }
    }
```

- [ ] **Step 3: Extend the schema-setup helper to register the new record type**

Edit `Lern Kalender/CloudKitService.swift`. In `setupCloudKitSchema()`, add a 7th block before the deletion sequence:

Old (the deletion section starts with `// Setup-Records wieder löschen`):
```swift
            let savedMM = try await publicDB.save(motivation)

            // Setup-Records wieder löschen
```

New:
```swift
            let savedMM = try await publicDB.save(motivation)

            // 7. HivemindTopics
            let hivemind = CKRecord(recordType: "HivemindTopics")
            hivemind["pairingCode"] = "__setup__" as CKRecordValue
            hivemind["topicsJSON"] = Data() as CKRecordValue
            hivemind["progressJSON"] = Data() as CKRecordValue
            hivemind["lastUpdated"] = Date() as CKRecordValue
            let savedHM = try await publicDB.save(hivemind)

            // Setup-Records wieder löschen
```

And in the deletion sequence at the bottom:

Old:
```swift
            try await publicDB.deleteRecord(withID: savedMM.recordID)

            await MainActor.run {
```

New:
```swift
            try await publicDB.deleteRecord(withID: savedMM.recordID)
            try await publicDB.deleteRecord(withID: savedHM.recordID)

            await MainActor.run {
```

- [ ] **Step 4: Build to verify**

```bash
xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' build 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED. (If you commented out the `pushTopics` call in Task 7, uncomment it now and rebuild.)

- [ ] **Step 5: Commit**

```bash
cd "/Users/nilslohrmann/Lern Kalender"
git add "Lern Kalender/CloudKitService.swift" "Lern Kalender/DataStore.swift"
git commit -m "$(cat <<'EOF'
feat(cloudkit): add HivemindTopics record type for topic sync

Adds pushTopics, fetchTopics, and assignTopicToChild on CloudKitService.
Wires the schema-setup helper to provision the HivemindTopics record
type. Bridges the active pairing code via UserDefaults to avoid a
circular dependency between CloudKitService and DataStore.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

NOTE for the executor: After deploying, the user must run the existing `setupCloudKitSchema()` action once (it's wired up in `SettingsView.swift` already) so the new `HivemindTopics` record type appears in the CloudKit dashboard. Or they can let CloudKit auto-create it when the first real record is saved (development environment behaviour).

---

# PHASE D — VIEWS

## Task 9: Create `Hivemind/Views/FeedPostViews.swift`

Five sub-views, one per `PostType`. Each takes a `FeedPost` and a callback for answers.

**Files:**
- Create: `Lern Kalender/Hivemind/Views/FeedPostViews.swift`

- [ ] **Step 1: Write the file**

Write `Lern Kalender/Hivemind/Views/FeedPostViews.swift`:

```swift
import SwiftUI
import Speech
import AVFoundation

// MARK: - Dispatcher

struct FeedPostView: View {
    let post: FeedPost
    let topicColor: Color
    let onAnswer: (PostAnswer) -> Void

    var body: some View {
        switch post.type {
        case let .textLesson(title, body):
            TextLessonPostView(title: title, body: body, accent: topicColor, onViewed: { onAnswer(.viewed) })
        case let .quizCard(question, options, correctIndex, explanation):
            QuizPostView(question: question, options: options, correctIndex: correctIndex, explanation: explanation, accent: topicColor, onAnswer: onAnswer)
        case let .flashcard(front, back):
            FlashcardPostView(front: front, back: back, accent: topicColor, onAnswer: onAnswer)
        case let .example(scenario, walkthrough):
            ExamplePostView(scenario: scenario, walkthrough: walkthrough, accent: topicColor, onViewed: { onAnswer(.viewed) })
        case let .feynman(prompt, expectedKeywords):
            FeynmanPostView(prompt: prompt, expectedKeywords: expectedKeywords, accent: topicColor, onAnswer: onAnswer)
        }
    }
}

// MARK: - Common card chrome

private struct PostCard<Content: View>: View {
    let icon: String
    let label: String
    let accent: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(accent.gradient, in: Circle())
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal)
    }
}

// MARK: - Text Lesson

struct TextLessonPostView: View {
    let title: String
    let body: String
    let accent: Color
    let onViewed: () -> Void

    @State private var hasMarkedViewed = false

    var bodyView: some View {
        PostCard(icon: "lightbulb.fill", label: "Lektion", accent: accent) {
            Text(title)
                .font(.title3.bold())
            Text(body)
                .font(.body)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var body: some View {
        bodyView.onAppear {
            guard !hasMarkedViewed else { return }
            hasMarkedViewed = true
            onViewed()
        }
    }
}

// MARK: - Quiz

struct QuizPostView: View {
    let question: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
    let accent: Color
    let onAnswer: (PostAnswer) -> Void

    @State private var selected: Int?

    var body: some View {
        PostCard(icon: "questionmark.circle.fill", label: "Quiz", accent: accent) {
            Text(question)
                .font(.title3.bold())

            VStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.offset) { idx, option in
                    Button {
                        guard selected == nil else { return }
                        selected = idx
                        onAnswer(.quiz(selectedIndex: idx, correct: idx == correctIndex))
                    } label: {
                        HStack {
                            Text(option).font(.subheadline)
                            Spacer()
                            if let s = selected {
                                if idx == correctIndex {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                } else if idx == s {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(answerBackground(idx), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14).stroke(answerBorder(idx), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(selected != nil)
                }
            }

            if selected != nil {
                Text(explanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private func answerBackground(_ idx: Int) -> Color {
        guard let s = selected else { return Color(.tertiarySystemGroupedBackground) }
        if idx == correctIndex { return .green.opacity(0.15) }
        if idx == s { return .red.opacity(0.15) }
        return Color(.tertiarySystemGroupedBackground)
    }

    private func answerBorder(_ idx: Int) -> Color {
        guard let s = selected else { return Color(.separator).opacity(0.3) }
        if idx == correctIndex { return .green }
        if idx == s { return .red }
        return .clear
    }
}

// MARK: - Flashcard

struct FlashcardPostView: View {
    let front: String
    let back: String
    let accent: Color
    let onAnswer: (PostAnswer) -> Void

    @State private var flipped = false
    @State private var answered = false

    var body: some View {
        PostCard(icon: "rectangle.on.rectangle", label: "Karteikarte", accent: accent) {
            Text(flipped ? back : front)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding(.vertical, 12)
                .onTapGesture { withAnimation(.spring(response: 0.4)) { flipped.toggle() } }

            if !flipped {
                Text("Tippe zum Umdrehen")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if !answered {
                HStack(spacing: 12) {
                    Button {
                        answered = true
                        onAnswer(.flashcard(known: false))
                    } label: {
                        Label("Wusste ich nicht", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button {
                        answered = true
                        onAnswer(.flashcard(known: true))
                    } label: {
                        Label("Wusste ich", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            } else {
                Text("Gespeichert ✓")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

// MARK: - Example

struct ExamplePostView: View {
    let scenario: String
    let walkthrough: String
    let accent: Color
    let onViewed: () -> Void

    @State private var hasMarkedViewed = false

    var body: some View {
        PostCard(icon: "wand.and.stars", label: "Beispiel", accent: accent) {
            Text(scenario)
                .font(.title3.bold())
            Text(walkthrough)
                .font(.body)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            guard !hasMarkedViewed else { return }
            hasMarkedViewed = true
            onViewed()
        }
    }
}

// MARK: - Feynman (voice + keyword scoring)

struct FeynmanPostView: View {
    let prompt: String
    let expectedKeywords: [String]
    let accent: Color
    let onAnswer: (PostAnswer) -> Void

    @State private var transcript = ""
    @State private var isRecording = false
    @State private var feedback: String?
    @State private var score: Int?

    @State private var recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var request: SFSpeechAudioBufferRecognitionRequest?

    var body: some View {
        PostCard(icon: "mic.fill", label: "Erkläre es", accent: accent) {
            Text(prompt)
                .font(.title3.bold())

            if !transcript.isEmpty {
                Text(transcript)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }

            if let fb = feedback, let s = score {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Score: \(s)/100")
                        .font(.caption.bold())
                        .foregroundStyle(s >= 60 ? .green : .orange)
                    Text(fb)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Button {
                    isRecording ? stopRecording() : startRecording()
                } label: {
                    Label(isRecording ? "Aufnahme stoppen" : "Erklärung aufnehmen",
                          systemImage: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isRecording ? .red : accent)
            }
        }
    }

    // MARK: - Recording

    private func startRecording() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()
        isRecording = true

        recognitionTask = recognizer?.recognitionTask(with: request) { result, _ in
            if let result {
                transcript = result.bestTranscription.formattedString
            }
        }
    }

    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        isRecording = false

        evaluate()
    }

    private func evaluate() {
        let lower = transcript.lowercased()
        let hits = expectedKeywords.filter { lower.contains($0.lowercased()) }
        let s = expectedKeywords.isEmpty ? 0 : Int(Double(hits.count) / Double(expectedKeywords.count) * 100)
        let missed = expectedKeywords.filter { !lower.contains($0.lowercased()) }

        let fb: String
        if s >= 80 {
            fb = "Sehr gut! Du hast die wichtigsten Konzepte erklärt."
        } else if s >= 50 {
            fb = "Solide. Vielleicht noch Begriffe wie: \(missed.prefix(3).joined(separator: ", "))"
        } else {
            fb = "Versuch es noch mal — denke an: \(missed.prefix(3).joined(separator: ", "))"
        }

        score = s
        feedback = fb
        onAnswer(.feynman(transcript: transcript, feedback: fb, score: s))
    }
}
```

- [ ] **Step 2: Add to Xcode project**

In Xcode: add `Hivemind/Views/FeedPostViews.swift` to the "Lern Kalender" target.

Speech recognition needs Info.plist permissions. Check if the keys exist:
```
Grep pattern: NSSpeechRecognitionUsageDescription  in: Lern Kalender
```
If they're missing, add the following to the project's Info.plist (typically embedded in `Lern Kalender.xcodeproj/project.pbxproj` under `INFOPLIST_KEY_NSSpeechRecognitionUsageDescription`):
- `NSSpeechRecognitionUsageDescription`: "Wird benötigt, um deine Erklärungen im Feynman-Modus zu verstehen."
- `NSMicrophoneUsageDescription`: "Wird benötigt, um deine Erklärungen aufzunehmen."

NOTE: Likely already present because `AIAssistantTab.swift` already uses `SFSpeechRecognizer`. If grep finds the existing keys, skip.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' build 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
cd "/Users/nilslohrmann/Lern Kalender"
git add "Lern Kalender/Hivemind/Views/FeedPostViews.swift" "Lern Kalender.xcodeproj/project.pbxproj"
git commit -m "$(cat <<'EOF'
feat(hivemind): add FeedPostViews with 5 post sub-views

Implements TextLesson, Quiz, Flashcard, Example, and Feynman post
variants. The Feynman variant uses on-device SFSpeechRecognizer with
keyword-overlap scoring (no extra API call) to give immediate
feedback.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Create `Hivemind/Views/TopicFeedView.swift`

The vertical scrollable feed view per topic.

**Files:**
- Create: `Lern Kalender/Hivemind/Views/TopicFeedView.swift`

- [ ] **Step 1: Write the file**

Write `Lern Kalender/Hivemind/Views/TopicFeedView.swift`:

```swift
import SwiftUI

struct TopicFeedView: View {
    let topic: Topic

    @Environment(\.dismiss) private var dismiss
    @State private var posts: [FeedPost] = []
    @State private var isGenerating = false
    @State private var error: String?
    @State private var dailyLimitHit = false

    private let store = TopicStore.shared

    var body: some View {
        NavigationStack {
            Group {
                if isGenerating {
                    generatingView
                } else if dailyLimitHit && posts.isEmpty {
                    dailyLimitView
                } else if posts.isEmpty {
                    emptyView
                } else {
                    feedScroll
                }
            }
            .navigationTitle(topic.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                }
            }
            .alert("Fehler", isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
        }
        .task { await loadOrGenerate() }
    }

    // MARK: - States

    private var generatingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.4)
            Text("Dein Feed wird erstellt…")
                .font(.headline)
            Text("Das dauert nur einen Moment.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray").font(.system(size: 50)).foregroundStyle(.secondary)
            Text("Keine Posts").font(.headline)
            Button("Feed generieren") { Task { await regenerate() } }
                .buttonStyle(.borderedProminent)
        }
    }

    private var dailyLimitView: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 50))
                .foregroundStyle(.purple)
            Text("Du hast alle Posts für heute durch!")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text("Komm morgen wieder für neuen Stoff.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Streak halten 🎯")
                .font(.caption.bold())
                .foregroundStyle(.orange)
        }
        .padding()
    }

    private var feedScroll: some View {
        ScrollView {
            LazyVStack(spacing: 32) {
                ForEach(posts) { post in
                    FeedPostView(post: post, topicColor: topic.color) { answer in
                        store.recordAnswer(post: post, answer: answer)
                    }
                    .padding(.top, 8)
                }

                Color.clear
                    .frame(height: 80)
                    .onAppear {
                        // Mark feed as exhausted when we reach the end (the spacer at the bottom).
                        store.markFeedExhausted(topicId: topic.id)
                    }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Loading / Generation

    private func loadOrGenerate() async {
        let progress = store.progress(for: topic.id)
        let cached = FeedGenerator.loadPosts(for: topic.id)

        // Case 1: cached posts and same-day generation → reuse.
        if !cached.isEmpty,
           let lastGen = progress.feedGeneratedDate,
           Calendar.current.isDateInToday(lastGen) {
            posts = cached
            return
        }

        // Case 2: same-day exhausted (no cache or already used).
        if let lastGen = progress.feedGeneratedDate,
           Calendar.current.isDateInToday(lastGen),
           progress.feedExhausted {
            dailyLimitHit = true
            return
        }

        // Case 3: new day or new topic → generate.
        await regenerate()
    }

    private func regenerate() async {
        isGenerating = true
        defer { isGenerating = false }

        do {
            let sourceText = topic.source.sourceText
            let generated = try await FeedGenerator.generateFeed(
                for: topic,
                sourceText: sourceText,
                previousProgress: store.progress(for: topic.id)
            )
            store.markFeedGenerated(topicId: topic.id)
            posts = generated
        } catch let err as FeedGenerationError {
            if case .dailyLimitReached = err {
                dailyLimitHit = true
            } else {
                error = err.localizedDescription
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

- [ ] **Step 2: Add to Xcode project**

In Xcode: add `Hivemind/Views/TopicFeedView.swift` to the "Lern Kalender" target.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' build 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
cd "/Users/nilslohrmann/Lern Kalender"
git add "Lern Kalender/Hivemind/Views/TopicFeedView.swift" "Lern Kalender.xcodeproj/project.pbxproj"
git commit -m "$(cat <<'EOF'
feat(hivemind): add TopicFeedView with daily-limit handling

The vertical scroll view for a topic. Lazy-renders posts via
FeedPostView, marks the feed as exhausted when the user reaches the
bottom, and routes between three states: generating, daily-limit, and
loaded.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Create `Hivemind/Views/ProfileSheetView.swift`

The sheet shown when the profile avatar is tapped — XP, Level, Badges, Subject Mastery, Streak History.

**Files:**
- Create: `Lern Kalender/Hivemind/Views/ProfileSheetView.swift`

- [ ] **Step 1: Write the file**

Write `Lern Kalender/Hivemind/Views/ProfileSheetView.swift`:

```swift
import SwiftUI

struct ProfileSheetView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore
    private let engine = LearningEngine.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    levelHeader
                    subjectMasterySection
                    badgesSection
                    Spacer(minLength: 20)
                }
                .padding(.top, 8)
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private var levelHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color(.systemGray5), lineWidth: 8).frame(width: 90, height: 90)
                Circle()
                    .trim(from: 0, to: engine.profile.levelProgress)
                    .stroke(Color.purple, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                Text("\(engine.profile.level)").font(.largeTitle.bold())
            }

            Text(engine.profile.levelTitle).font(.headline)
            Text("\(engine.profile.totalXP) XP")
                .font(.subheadline)
                .foregroundStyle(.purple)
            Text("\(engine.profile.xpForNextLevel - engine.profile.totalXP) XP bis Level \(engine.profile.level + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 24) {
                statTile(icon: "flame.fill", value: "\(engine.profile.streakDays)", label: "Tage Streak", color: .orange)
                statTile(icon: "checkmark.seal.fill", value: "\(engine.quizStats.total)", label: "Quizze", color: .green)
                statTile(icon: "rectangle.stack.fill", value: "\(engine.spacedCards.count)", label: "Karten", color: .pink)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private func statTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.headline)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var subjectMasterySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fächer").font(.headline).padding(.horizontal)

            ForEach(store.subjects) { subject in
                let mastery = engine.masteryForSubject(subject.name)
                let xp = engine.profile.xpPerSubject[subject.name] ?? 0
                let level = engine.profile.subjectLevel(for: subject.name)

                HStack(spacing: 12) {
                    Image(systemName: subject.icon)
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(subject.color.gradient, in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(subject.name).font(.subheadline.bold())
                            Spacer()
                            Text("Lv.\(level)").font(.caption.bold()).foregroundStyle(.purple)
                        }
                        ProgressView(value: mastery).tint(subject.color)
                        HStack {
                            Text("\(xp) XP").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            if mastery > 0 {
                                Text("\(Int(mastery * 100))% gemeistert")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            }
        }
    }

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Erfolge").font(.headline).padding(.horizontal)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                ForEach(Badge.allBadges) { badge in
                    let earned = engine.profile.badges.contains(where: { $0.id == badge.id })
                    VStack(spacing: 4) {
                        Image(systemName: badge.icon)
                            .font(.title2)
                            .foregroundStyle(earned ? .yellow : .secondary.opacity(0.3))
                        Text(badge.name)
                            .font(.caption2)
                            .foregroundStyle(earned ? .primary : .tertiary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
    }
}
```

- [ ] **Step 2: Add to Xcode project**

In Xcode: add `Hivemind/Views/ProfileSheetView.swift` to the "Lern Kalender" target.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' build 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
cd "/Users/nilslohrmann/Lern Kalender"
git add "Lern Kalender/Hivemind/Views/ProfileSheetView.swift" "Lern Kalender.xcodeproj/project.pbxproj"
git commit -m "$(cat <<'EOF'
feat(hivemind): add ProfileSheetView with XP, level, mastery, badges

Replaces what was previously visible at the top of the old LearnTab.
Now lives behind a tappable profile avatar so the main Hivemind tab
can stay focused on the feed/topics.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Create `Hivemind/Views/CreateTopicView.swift`

The form for creating a new topic from any of the 5 sources. Accepts an optional `parentMode` flag so parents can use the same form to assign topics.

**Files:**
- Create: `Lern Kalender/Hivemind/Views/CreateTopicView.swift`

- [ ] **Step 1: Write the file**

Write `Lern Kalender/Hivemind/Views/CreateTopicView.swift`:

```swift
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct CreateTopicView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore
    var parentMode: Bool = false
    var pairingCode: String? = nil   // required when parentMode == true

    private enum Mode: String, CaseIterable, Identifiable {
        case manual = "Thema"
        case photo = "Foto"
        case pdf = "PDF"
        case link = "Link"
        case podcast = "Podcast"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .manual: return "text.cursor"
            case .photo: return "camera.fill"
            case .pdf: return "doc.fill"
            case .link: return "link"
            case .podcast: return "headphones"
            }
        }
    }

    @State private var mode: Mode = .manual
    @State private var titleField = ""
    @State private var subjectField = ""
    @State private var manualPrompt = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoText = ""
    @State private var pdfText = ""
    @State private var pdfFilename = ""
    @State private var linkText = ""
    @State private var linkURL = ""
    @State private var isImporting = false
    @State private var showPDFPicker = false
    @State private var error: String?
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                modeSection
                detailsSection
                actionSection
            }
            .navigationTitle(parentMode ? "Topic für Kind" : "Neues Topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .alert("Fehler", isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
            .fileImporter(
                isPresented: $showPDFPicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handlePDFResult(result)
            }
        }
    }

    // MARK: - Sections

    private var modeSection: some View {
        Section {
            Picker("Quelle", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Label(m.rawValue, systemImage: m.icon).tag(m)
                }
            }
            .pickerStyle(.menu)
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        Section("Details") {
            TextField("Topic-Titel", text: $titleField)

            if !store.subjects.isEmpty {
                Picker("Fach (optional)", selection: $subjectField) {
                    Text("Keines").tag("")
                    ForEach(store.subjects) { sub in
                        Text(sub.name).tag(sub.name)
                    }
                }
            } else {
                TextField("Fach (optional)", text: $subjectField)
            }

            switch mode {
            case .manual:
                TextField("Was möchtest du lernen?", text: $manualPrompt, axis: .vertical)
                    .lineLimit(2...4)

            case .photo:
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(photoText.isEmpty ? "Bild wählen" : "Bild ändern", systemImage: "photo.on.rectangle")
                }
                if isImporting { ProgressView("Erkenne Text…") }
                if !photoText.isEmpty {
                    Text(photoText).font(.footnote).foregroundStyle(.secondary).lineLimit(4)
                }

            case .pdf:
                Button {
                    showPDFPicker = true
                } label: {
                    Label(pdfFilename.isEmpty ? "PDF wählen" : pdfFilename, systemImage: "doc.fill")
                }
                if isImporting { ProgressView("Lese PDF…") }
                if !pdfText.isEmpty {
                    Text(pdfText.prefix(200)).font(.footnote).foregroundStyle(.secondary).lineLimit(4)
                }

            case .link:
                TextField("https://…", text: $linkURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !linkText.isEmpty {
                    Text(linkText.prefix(200)).font(.footnote).foregroundStyle(.secondary).lineLimit(4)
                }

            case .podcast:
                Text("Podcast-Import kommt bald.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await loadAndOCR(item) }
        }
    }

    private var actionSection: some View {
        Section {
            Button {
                Task { await createTopic() }
            } label: {
                HStack {
                    Spacer()
                    if isCreating {
                        ProgressView()
                        Text("Topic wird erstellt…")
                    } else {
                        Label(parentMode ? "Topic dem Kind zuweisen" : "Topic erstellen",
                              systemImage: "sparkles")
                            .font(.headline)
                    }
                    Spacer()
                }
            }
            .disabled(!canSubmit || isCreating || mode == .podcast)
        }
    }

    // MARK: - Validation

    private var canSubmit: Bool {
        if titleField.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        switch mode {
        case .manual: return !manualPrompt.trimmingCharacters(in: .whitespaces).isEmpty
        case .photo: return !photoText.isEmpty
        case .pdf: return !pdfText.isEmpty
        case .link: return URL(string: linkURL) != nil
        case .podcast: return false
        }
    }

    // MARK: - Actions

    private func loadAndOCR(_ item: PhotosPickerItem) async {
        isImporting = true
        defer { isImporting = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            error = "Bild konnte nicht geladen werden."
            return
        }
        do {
            let text = try await TopicSourceImporter.extractText(from: image)
            await MainActor.run { self.photoText = text }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    private func handlePDFResult(_ result: Result<[URL], Error>) {
        isImporting = true
        defer { isImporting = false }
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            // Security-scoped resource access for files outside the sandbox.
            let needsAccess = url.startAccessingSecurityScopedResource()
            defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let text = try TopicSourceImporter.extractText(from: data)
            self.pdfText = text
            self.pdfFilename = url.lastPathComponent
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func createTopic() async {
        isCreating = true
        defer { isCreating = false }

        // For .link mode, fetch text first.
        if mode == .link, linkText.isEmpty, let url = URL(string: linkURL) {
            do {
                linkText = try await TopicSourceImporter.extractText(from: url)
            } catch {
                self.error = error.localizedDescription
                return
            }
        }

        let source: TopicSource = {
            switch mode {
            case .manual: return .manual(prompt: manualPrompt)
            case .photo: return .photoOCR(text: photoText)
            case .pdf: return .pdf(filename: pdfFilename, text: pdfText)
            case .link: return .webLink(url: URL(string: linkURL)!, text: linkText)
            case .podcast: return .manual(prompt: titleField) // unreachable
            }
        }()

        let topic = Topic(
            title: titleField,
            subject: subjectField.isEmpty ? nil : subjectField,
            iconName: "sparkles",
            colorHex: "#7C3AED",
            source: source,
            assignedByParent: parentMode
        )

        if parentMode, let pairingCode {
            await CloudKitService.shared.assignTopicToChild(topic, pairingCode: pairingCode)
        } else {
            TopicStore.shared.addTopic(topic)
        }

        dismiss()
    }
}
```

- [ ] **Step 2: Add to Xcode project**

In Xcode: add `Hivemind/Views/CreateTopicView.swift` to the "Lern Kalender" target.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' build 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
cd "/Users/nilslohrmann/Lern Kalender"
git add "Lern Kalender/Hivemind/Views/CreateTopicView.swift" "Lern Kalender.xcodeproj/project.pbxproj"
git commit -m "$(cat <<'EOF'
feat(hivemind): add CreateTopicView with 5 source modes

Manual prompt, photo OCR, PDF import, web link scrape, and a podcast
placeholder. Parent mode reuses the same form and routes the topic
through CloudKitService.assignTopicToChild instead of the local store.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Create `Hivemind/Views/DiscoverView.swift`

A category-based browse + customize sheet. Tapping a category creates a discover-mode topic that the user can immediately scroll.

**Files:**
- Create: `Lern Kalender/Hivemind/Views/DiscoverView.swift`

- [ ] **Step 1: Write the file**

Write `Lern Kalender/Hivemind/Views/DiscoverView.swift`:

```swift
import SwiftUI

struct DiscoverCategory: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let colorHex: String
    let suggestions: [String]
}

enum DiscoverCatalog {
    static let all: [DiscoverCategory] = [
        DiscoverCategory(name: "Naturwissenschaften", icon: "leaf.fill", colorHex: "#10B981",
            suggestions: ["Photosynthese", "Newtons Gesetze", "DNA-Struktur", "Evolution", "Plattentektonik"]),
        DiscoverCategory(name: "Sprachen", icon: "globe", colorHex: "#0EA5E9",
            suggestions: ["Englische Zeitformen", "Französische Aussprache", "Spanische Verben", "Lateinische Wurzeln"]),
        DiscoverCategory(name: "Geschichte", icon: "building.columns.fill", colorHex: "#F59E0B",
            suggestions: ["Römisches Reich", "Französische Revolution", "Industrielle Revolution", "Kalter Krieg"]),
        DiscoverCategory(name: "Mathematik", icon: "function", colorHex: "#8B5CF6",
            suggestions: ["Bruchrechnung", "Quadratische Gleichungen", "Geometrie", "Wahrscheinlichkeit"]),
        DiscoverCategory(name: "Musik", icon: "music.note", colorHex: "#EC4899",
            suggestions: ["Notenlesen", "Akkorde", "Musikepochen", "Instrumentenkunde"]),
        DiscoverCategory(name: "Sport", icon: "figure.run", colorHex: "#EF4444",
            suggestions: ["Trainingslehre", "Fußball-Regeln", "Anatomie der Muskeln"]),
        DiscoverCategory(name: "Allgemeinwissen", icon: "lightbulb.fill", colorHex: "#F97316",
            suggestions: ["Kritisches Denken", "Logik-Rätsel", "Welt-Geographie", "Berühmte Erfindungen"])
    ]
}

struct DiscoverView: View {
    @Environment(\.dismiss) private var dismiss
    var onTopicCreated: (Topic) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(DiscoverCatalog.all) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: category.icon)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background((Color(hex: category.colorHex) ?? .purple).gradient, in: RoundedRectangle(cornerRadius: 8))
                                Text(category.name).font(.headline)
                            }
                            .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(category.suggestions, id: \.self) { suggestion in
                                        Button {
                                            createDiscoverTopic(category: category, suggestion: suggestion)
                                        } label: {
                                            Text(suggestion)
                                                .font(.subheadline.bold())
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background((Color(hex: category.colorHex) ?? .purple).opacity(0.15), in: Capsule())
                                                .foregroundStyle(Color(hex: category.colorHex) ?? .purple)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Entdecken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }

    private func createDiscoverTopic(category: DiscoverCategory, suggestion: String) {
        let topic = Topic(
            title: suggestion,
            subject: nil,
            iconName: category.icon,
            colorHex: category.colorHex,
            source: .manual(prompt: suggestion),
            isDiscover: true
        )
        TopicStore.shared.addTopic(topic)
        onTopicCreated(topic)
        dismiss()
    }
}
```

- [ ] **Step 2: Add to Xcode project**

In Xcode: add `Hivemind/Views/DiscoverView.swift` to the "Lern Kalender" target.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' build 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
cd "/Users/nilslohrmann/Lern Kalender"
git add "Lern Kalender/Hivemind/Views/DiscoverView.swift" "Lern Kalender.xcodeproj/project.pbxproj"
git commit -m "$(cat <<'EOF'
feat(hivemind): add DiscoverView with curated categories

Seven curated categories with horizontal-scroll suggestion chips. Tap
creates a discover-mode topic and dismisses, returning the new topic
to the parent view via callback so it can navigate into the feed.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: Create `Hivemind/Views/HivemindTab.swift`

The main tab view with welcome header, school topics, discover, calendar suggestions, and the profile entry.

**Files:**
- Create: `Lern Kalender/Hivemind/Views/HivemindTab.swift`

- [ ] **Step 1: Write the file**

Write `Lern Kalender/Hivemind/Views/HivemindTab.swift`:

```swift
import SwiftUI

struct HivemindTab: View {
    var store: DataStore
    @Bindable private var topicStore = TopicStore.shared

    @State private var showCreateTopic = false
    @State private var showDiscover = false
    @State private var showProfile = false
    @State private var topicToOpen: Topic?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    welcomeHeader
                    schoolTopicsSection
                    calendarSuggestionsSection
                    discoverSection
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("Lernen")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showProfile = true
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.purple)
                    }
                }
            }
            .sheet(isPresented: $showCreateTopic) {
                CreateTopicView(store: store)
            }
            .sheet(isPresented: $showDiscover) {
                DiscoverView { topic in
                    topicToOpen = topic
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileSheetView(store: store)
            }
            .sheet(item: $topicToOpen) { topic in
                TopicFeedView(topic: topic)
            }
        }
    }

    // MARK: - Welcome header

    private var welcomeHeader: some View {
        let streak = LearningEngine.shared.profile.streakDays
        return VStack(alignment: .leading, spacing: 12) {
            Text("Welcome back!")
                .font(.title.bold())
            Text("Du hast eine \(streak)-Tage-Serie")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(weekDayLabels, id: \.label) { item in
                    VStack(spacing: 4) {
                        Text(item.label)
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        ZStack {
                            Circle()
                                .fill(item.completed ? Color.purple : Color(.systemGray5))
                                .frame(width: 28, height: 28)
                            if item.completed {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(colors: [.purple.opacity(0.15), .pink.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .padding(.horizontal)
    }

    private struct WeekDayItem {
        let label: String
        let completed: Bool
    }

    private var weekDayLabels: [WeekDayItem] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today) // 1 = Sunday in en_US
        let labels = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        // Build the past 7 days ending today, but display in Mo–So order.
        var items: [WeekDayItem] = []
        for offset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -(weekday + 5 - offset) % 7, to: today) ?? today
            let key = LearnerProfile.dateKey(date)
            let xp = LearningEngine.shared.profile.dailyXPLog[key] ?? 0
            items.append(WeekDayItem(label: labels[offset], completed: xp > 0))
        }
        return items
    }

    // MARK: - School topics

    private var schoolTopicsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Deine Topics").font(.title2.bold())
                Spacer()
                Button {
                    showCreateTopic = true
                } label: {
                    Label("Neu", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.purple)
                }
            }
            .padding(.horizontal)

            if topicStore.schoolTopics.isEmpty {
                emptyTopicsCard
            } else {
                VStack(spacing: 12) {
                    ForEach(topicStore.schoolTopics) { topic in
                        TopicCard(topic: topic, progress: topicStore.progress(for: topic.id)) {
                            topicToOpen = topic
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var emptyTopicsCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(.purple)
            Text("Noch keine Topics")
                .font(.headline)
            Text("Erstelle dein erstes Topic — z. B. mit einem Foto deines Hefts.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Topic erstellen") { showCreateTopic = true }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    // MARK: - Calendar suggestions

    private var calendarSuggestionsSection: some View {
        let upcomingExams = store.entries
            .filter { $0.type == .klassenarbeit && $0.date > Date() && $0.date < Date().addingTimeInterval(14 * 86400) }
            .prefix(3)

        return Group {
            if !upcomingExams.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Aus deinem Kalender").font(.title3.bold()).padding(.horizontal)
                    ForEach(Array(upcomingExams)) { exam in
                        Button {
                            // Pre-create a topic from the exam metadata.
                            let topic = Topic(
                                title: exam.title,
                                subject: nil,
                                iconName: "doc.text.fill",
                                colorHex: "#EF4444",
                                source: .calendarSuggestion(examId: exam.id)
                            )
                            topicStore.addTopic(topic)
                            topicToOpen = topic
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar")
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(.red.gradient, in: RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exam.title).font(.subheadline.bold()).foregroundStyle(.primary)
                                    Text(exam.date, format: .dateTime.day().month().weekday(.wide))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.purple)
                            }
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - Discover

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Entdecken").font(.title3.bold())
                Spacer()
                Button("Mehr") { showDiscover = true }
                    .font(.subheadline.bold())
                    .foregroundStyle(.purple)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DiscoverCatalog.all.prefix(5)) { category in
                        Button {
                            showDiscover = true
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: category.icon)
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                Text(category.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(14)
                            .frame(width: 140, height: 100, alignment: .topLeading)
                            .background((Color(hex: category.colorHex) ?? .purple).gradient, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Topic Card

private struct TopicCard: View {
    let topic: Topic
    let progress: TopicProgress
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(topic.color.gradient)
                        .frame(width: 56, height: 56)
                    Image(systemName: topic.iconName)
                        .font(.title2)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(topic.title).font(.subheadline.bold()).foregroundStyle(.primary)
                        if topic.assignedByParent {
                            Image(systemName: "person.fill.checkmark")
                                .font(.caption2)
                                .foregroundStyle(.purple)
                        }
                    }
                    if let subject = topic.subject {
                        Text(subject).font(.caption).foregroundStyle(.secondary)
                    }
                    ProgressView(value: progress.percent(totalPosts: FeedGenerator.postsPerBatch))
                        .tint(topic.color)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Add to Xcode project**

In Xcode: add `Hivemind/Views/HivemindTab.swift` to the "Lern Kalender" target.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' build 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
cd "/Users/nilslohrmann/Lern Kalender"
git add "Lern Kalender/Hivemind/Views/HivemindTab.swift" "Lern Kalender.xcodeproj/project.pbxproj"
git commit -m "$(cat <<'EOF'
feat(hivemind): add HivemindTab main view

Welcome header with weekday streak, school topics list, calendar
suggestions for upcoming exams, and a discover carousel. Profile
avatar in the toolbar opens ProfileSheetView. Tapping a topic opens
TopicFeedView. Plus button opens CreateTopicView.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# PHASE E — INTEGRATION

## Task 15: Wire `HivemindTab` into `ContentView.swift`

Adds the new tab as a 6th student tab, with the same iPad/iPhone variants the other tabs use.

**Files:**
- Modify: `Lern Kalender/ContentView.swift`

- [ ] **Step 1: Add the iPad sidebar entry**

Edit `Lern Kalender/ContentView.swift`. In the `studentView` body, in the `NavigationSplitView` `List`, add a new `NavigationLink` between "KI" and "Statistik":

Old:
```swift
                        NavigationLink {
                            AIAssistantTab(store: store)
                        } label: {
                            Label("KI", systemImage: "sparkles")
                        }
                        NavigationLink {
                            StatisticsTab(store: store)
                        } label: {
                            Label("Statistik", systemImage: "chart.bar.fill")
                        }
```

New:
```swift
                        NavigationLink {
                            AIAssistantTab(store: store)
                        } label: {
                            Label("KI", systemImage: "sparkles")
                        }
                        NavigationLink {
                            HivemindTab(store: store)
                        } label: {
                            Label("Lernen", systemImage: "brain.head.profile")
                        }
                        NavigationLink {
                            StatisticsTab(store: store)
                        } label: {
                            Label("Statistik", systemImage: "chart.bar.fill")
                        }
```

- [ ] **Step 2: Add the iPhone TabView entry**

In the same `studentView`, in the `TabView` block, add the new tab between AIAssistantTab and StatisticsTab:

Old:
```swift
                    AIAssistantTab(store: store)
                        .tabItem { Label("KI", systemImage: "sparkles") }
                    StatisticsTab(store: store)
                        .tabItem { Label("Statistik", systemImage: "chart.bar.fill") }
```

New:
```swift
                    AIAssistantTab(store: store)
                        .tabItem { Label("KI", systemImage: "sparkles") }
                    HivemindTab(store: store)
                        .tabItem { Label("Lernen", systemImage: "brain.head.profile") }
                    StatisticsTab(store: store)
                        .tabItem { Label("Statistik", systemImage: "chart.bar.fill") }
```

- [ ] **Step 3: Pull remote topics into TopicStore on app appear**

Add a one-shot CloudKit fetch in the existing `.onAppear` block at the end of `studentView`. Find the existing `// Shared calendar entries laden` block:

Old:
```swift
            // Shared calendar entries laden
            if let link = store.familyLink, link.isActive {
                Task {
                    let shared = await CloudKitService.shared.fetchSharedCalendarEntries(pairingCode: link.pairingCode)
                    await MainActor.run { store.sharedCalendarEntries = shared }
                }
            }
```

New (append a Hivemind block right after):
```swift
            // Shared calendar entries laden
            if let link = store.familyLink, link.isActive {
                Task {
                    let shared = await CloudKitService.shared.fetchSharedCalendarEntries(pairingCode: link.pairingCode)
                    await MainActor.run { store.sharedCalendarEntries = shared }
                }
            }
            // Hivemind: pull parent-assigned topics
            if let link = store.familyLink, link.isActive {
                Task {
                    let (remoteTopics, remoteProgress) = await CloudKitService.shared.fetchTopics(pairingCode: link.pairingCode)
                    await MainActor.run {
                        TopicStore.shared.mergeRemote(topics: remoteTopics, progress: remoteProgress)
                    }
                }
            }
```

- [ ] **Step 4: Build to verify**

```bash
xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' build 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
cd "/Users/nilslohrmann/Lern Kalender"
git add "Lern Kalender/ContentView.swift"
git commit -m "$(cat <<'EOF'
feat(hivemind): wire HivemindTab into student ContentView

Adds the Lernen tab in both iPad sidebar and iPhone TabView. Pulls
parent-assigned topics from CloudKit on appear and merges them into
the local TopicStore.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 16: Add parent-side topic assignment to `ParentalControlViews.swift`

Adds a "Topic für Kind anlegen" button in the parent dashboard for each linked child.

**Files:**
- Modify: `Lern Kalender/ParentalControlViews.swift`

- [ ] **Step 1: Find a suitable insertion point**

Read the file and find the per-child detail view in `ParentalControlViews.swift`. Look for a struct named like `ChildDetailView`, `ParentDashboardView`, or similar that takes a `pairingCode` (or `link: FamilyLink`).

```
Grep pattern: struct ParentDashboardView  in: Lern Kalender/ParentalControlViews.swift
Grep pattern: pairingCode  in: Lern Kalender/ParentalControlViews.swift
```

- [ ] **Step 2: Add a "Topic für Kind anlegen" entry**

Find a section in the per-child view that already has buttons (e.g., "Motivation senden", "Lernziel setzen"). Add a new button that opens `CreateTopicView` in parent mode. The exact placement depends on the file structure.

Generic insertion (adapt section labels to match nearby code):

```swift
                Button {
                    showCreateTopicForChild = true
                } label: {
                    Label("Topic für Kind anlegen", systemImage: "brain.head.profile")
                }
```

And add the corresponding state at the top of the view:
```swift
    @State private var showCreateTopicForChild = false
```

And the sheet modifier on the view:
```swift
                .sheet(isPresented: $showCreateTopicForChild) {
                    CreateTopicView(store: store, parentMode: true, pairingCode: link.pairingCode)
                }
```

NOTE: replace `link.pairingCode` with whatever variable is in scope for the current child (might be `child.pairingCode`, `selectedLink.pairingCode`, etc.).

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' build 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED.

If build fails because the variable name is wrong, grep for similar `Button { ... }` blocks in the same file to find the right scope.

- [ ] **Step 4: Commit**

```bash
cd "/Users/nilslohrmann/Lern Kalender"
git add "Lern Kalender/ParentalControlViews.swift"
git commit -m "$(cat <<'EOF'
feat(hivemind): add parent-side topic assignment

Adds a 'Topic für Kind anlegen' entry in the per-child parent view.
Reuses CreateTopicView with parentMode=true so the topic is pushed
through CloudKitService.assignTopicToChild instead of the parent's
own local store.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 17: Wire `create_topic` AI action and final smoke test

Reconnects the AI assistant so it can create topics directly via the chat (replacing the old `create_path` action).

**Files:**
- Modify: `Lern Kalender/AIAssistantTab.swift`

- [ ] **Step 1: Add a `create_topic` action handler**

Edit `Lern Kalender/AIAssistantTab.swift`. Find the action-handler switch (where `case "create_quiz":` and `case "create_flashcards":` live, near the area where `case "create_path":` USED to be). Add a new case:

```swift
            case "create_topic":
                let subject = action["subject"] as? String ?? ""
                let topic = action["topic"] as? String ?? ""
                if !topic.isEmpty {
                    let newTopic = Topic(
                        title: topic,
                        subject: subject.isEmpty ? nil : subject,
                        iconName: "sparkles",
                        colorHex: "#7C3AED",
                        source: .manual(prompt: "Erstellt aus KI-Chat: \(topic)")
                    )
                    TopicStore.shared.addTopic(newTopic)
                }
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' build 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run a clean build to confirm zero warnings/errors**

```bash
xcodebuild -scheme "Lern Kalender" -destination 'generic/platform=iOS' clean build 2>&1 | tail -80
```

Expected: BUILD SUCCEEDED with no errors. Warnings related to existing code are acceptable, but new warnings introduced by this plan are not.

- [ ] **Step 4: Manual smoke test in the simulator**

Open the project in Xcode, choose an iPhone simulator, run (⌘R), and verify the following user flows:
1. Open the new "Lernen" tab — empty state shows.
2. Tap "+" → "Thema" → enter "Bruchrechnung" → "Topic erstellen" — feed loads.
3. Scroll a quiz post, answer it — green/red feedback shows, no crash.
4. Open profile (top-right avatar) — XP/badges show.
5. Open the "Entdecken" sheet, tap a category chip — feed opens.
6. Switch to parent mode (via existing flow) → child view should now have "Topic für Kind anlegen".

If anything crashes, capture the stack trace, identify the offending file, and create a bug-fix commit. Do not skip this manual smoke test.

- [ ] **Step 5: Commit**

```bash
cd "/Users/nilslohrmann/Lern Kalender"
git add "Lern Kalender/AIAssistantTab.swift"
git commit -m "$(cat <<'EOF'
feat(hivemind): wire create_topic AI action + final integration

The KI-Assistent can now create Hivemind topics from chat. Closes
out the migration: the old learning path system is fully replaced
by the Hivemind module.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Done

After Task 17 the entire Hivemind feature is shipped. The student sees a new Lernen tab with topics, feed, profile and discover, parents can assign topics to children, the old learning path system is gone, and CloudKit syncs everything across devices.

**Manual deployment steps for the user (one-time, after merge):**
1. Run the existing CloudKit "Schema einrichten" action from the developer settings to register the new `HivemindTopics` record type — OR let CloudKit auto-create it on first save.
2. Verify in CloudKit Dashboard that `HivemindTopics` appears, then Deploy to Production.
3. Make sure `INFOPLIST_KEY_NSSpeechRecognitionUsageDescription` and `INFOPLIST_KEY_NSMicrophoneUsageDescription` are set (Task 9 step 2).

**Things explicitly NOT in this plan (per spec — Out of Scope):**
- Image/meme generation
- Audio TTS posts
- Real podcast transcription (the importer throws `.podcastNotSupported` and the UI shows "Coming bald")
- Automated tests
- Premium paywall for Discover

If any of these become needed, write a follow-up spec + plan.
