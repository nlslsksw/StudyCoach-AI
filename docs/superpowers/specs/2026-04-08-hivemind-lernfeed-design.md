# Hivemind-Lernfeed: Ersatz für den Lernpfad

**Datum:** 2026-04-08
**Status:** Design — bereit für Implementation Plan
**Ersetzt:** `LearnTab.swift`, `LearnPathView.swift` und `LearningPath`/`PathStep` aus `LearningModels.swift`

---

## Ziel

Das aktuelle Duolingo-artige Lernpfad-System wird durch ein Hivemind-inspiriertes Topic+Feed-System ersetzt. Statt linearer Pfade mit gesperrten Schritten scrollt der Schüler durch einen personalisierten Feed aus KI-generierten Mikro-Lektionen, Quiz-Karten, Karteikarten, Beispiel-Anwendungen und Feynman-Voice-Übungen — alles zu einem selbst gewählten oder von den Eltern zugewiesenen Topic.

**Zielgruppe:** Schüler mit Eltern-Aufsicht (bestehende Geldtracker-Familien-Architektur).

**Kern-Idee:** Lern-Inhalte fühlen sich an wie Social-Media-Scrolling — aber jeder „Post" verankert echtes Wissen.

---

## Scope-Entscheidungen (aus dem Brainstorming)

| Thema | Entscheidung |
|---|---|
| Umfang | Kompletter `LearnTab` wird ersetzt — nicht nur die Pfad-View |
| Post-Typen | Text-Lektion, Quiz, Karteikarte, Beispiel, Feynman-Voice (keine Bilder, kein reines Audio) |
| Topic-Quellen | Topic-Name, Foto/PDF, Web-Link, Podcast, Auto-Vorschläge aus dem Schul-Kalender |
| Migration | Hartes Replace — alte `LearningPath`-Daten werden verworfen |
| Eltern | Eltern sehen Topic-Übersicht UND können Topics zuweisen |
| Persistenz | Topics + Progress in CloudKit, Feed-Posts lokal in Documents/feeds/ |
| Gamification | Streak prominent im UI, alle übrigen Stats hinter einem Profil-Icon |
| Customization | Schul-Fächer-basiert + Discover-Bereich für Allgemeinwissen |
| Generierung | Batch beim Topic-Öffnen (15 Posts), Tageslimit pro Topic |
| Tests | Keine — direkt bauen (Projekt hat keine Test-Infrastruktur) |

---

## Architektur

Neuer Ordner `Hivemind/` als isoliertes Feature-Modul. `LearningEngine`/`LearningModels` bleiben (gekürzt) für XP, Spaced Repetition, Daily Challenges und Badges. Hivemind ruft `LearningEngine` auf, niemals umgekehrt — keine Zirkular-Abhängigkeiten.

```
Lern Kalender/
├── Hivemind/                            ← NEU
│   ├── Models/
│   │   └── HivemindModels.swift         (Topic, FeedPost, PostType, TopicProgress, TopicSource, PostAnswer)
│   ├── Services/
│   │   ├── TopicStore.swift             (CloudKit-synced Topics + Progress, @Observable)
│   │   ├── FeedGenerator.swift          (Gemini-Calls, Batch-Generierung, Daily-Limit, lokale Persistenz)
│   │   └── TopicSourceImporter.swift    (Foto/PDF/Link/Podcast → Roh-Text)
│   └── Views/
│       ├── HivemindTab.swift            (Hauptansicht)
│       ├── TopicFeedView.swift          (vertikaler Post-Feed)
│       ├── FeedPostViews.swift          (5 Sub-Views: Lesson, Quiz, Card, Example, Feynman)
│       ├── CreateTopicView.swift        (Topic-Erstellung mit allen 5 Quellen)
│       ├── DiscoverView.swift           (Allgemeinwissen-Kategorien)
│       └── ProfileSheetView.swift       (XP, Level, Badges, Stats)
│
├── LearningEngine.swift                  ← BLEIBT, ohne LearningPath-Code
├── LearningModels.swift                  ← BLEIBT, ohne LearningPath/PathStep/PathStepJSON
├── LearnTab.swift                        ← LÖSCHEN
├── LearnPathView.swift                   ← LÖSCHEN
└── ContentView.swift                     ← LearnTab → HivemindTab tauschen
```

### Verantwortlichkeiten

- **`HivemindModels.swift`** — pure `Codable` Structs/Enums, keine Logik außer Computed Properties.
- **`TopicStore`** — besitzt `topics` und `topicProgress`. Hängt am `CloudKitService` für Sync. Bietet CRUD + Eltern-Zuweisung. Kennt **keine** Views und **kein** KI.
- **`FeedGenerator`** — stateless. Nimmt `Topic` (+ optionalen Quelltext) → ruft `GeminiService` → liefert `[FeedPost]`. Persistiert pro Topic lokal in `Documents/feeds/<topic-id>.json`. Verwaltet das tägliche Generierungs-Datum.
- **`TopicSourceImporter`** — wandelt UIImage / PDF-Daten / URL / Audio in sauberen Text. Nutzt die bestehende OCR aus `StudyPlanView.swift`.
- **Views** — beziehen Daten via `@Bindable` aus den Stores. Posten Aktionen zurück (Quiz beantwortet, Karte gewusst). Karteikarten werden via `LearningEngine.addCards(...)` ins bestehende Spaced-Repetition-System geschrieben. Quiz-XP via `LearningEngine.recordQuiz(...)`.

### Abhängigkeitsregel

```
Views → Stores/Services → Models
Hivemind → LearningEngine     ✓
LearningEngine → Hivemind     ✗ (verboten)
```

Damit bleibt `LearningEngine` unverändert testbar und das neue Modul ist isoliert wartbar.

---

## Datenmodelle

```swift
struct Topic: Identifiable, Codable {
    var id: UUID
    var title: String                  // "Bruchrechnung", "Roman Empire"
    var subject: String?               // optional verknüpft mit Schul-Fach
    var iconName: String               // SF Symbol
    var colorHex: String               // Karten-Farbe
    var source: TopicSource            // wie wurde es erstellt
    var createdDate: Date
    var assignedByParent: Bool         // Eltern-Badge im UI
    var isDiscover: Bool               // false = Schul-Topic, true = Discover-Topic
}

enum TopicSource: Codable {
    case manual(prompt: String)
    case photoOCR(text: String)
    case pdf(filename: String, text: String)
    case webLink(url: URL, text: String)
    case podcast(url: URL, transcript: String)
    case calendarSuggestion(examId: UUID?)
}

struct TopicProgress: Identifiable, Codable {
    var id: UUID                       // == Topic.id
    var postsViewed: Int
    var postsCorrect: Int              // bei Quiz/Karten
    var lastViewedDate: Date?
    var feedGeneratedDate: Date?       // für Tageslimit
    var feedExhausted: Bool            // alle Posts heute durch
}

struct FeedPost: Identifiable, Codable {
    var id: UUID
    var topicId: UUID
    var orderIndex: Int                // Sortier-Reihenfolge im Feed
    var type: PostType
    var isViewed: Bool
    var userAnswer: PostAnswer?
}

enum PostType: Codable {
    case textLesson(title: String, body: String)
    case quizCard(question: String, options: [String], correctIndex: Int, explanation: String)
    case flashcard(front: String, back: String)
    case example(scenario: String, walkthrough: String)
    case feynman(prompt: String, expectedKeywords: [String])
}

enum PostAnswer: Codable {
    case quiz(selectedIndex: Int, correct: Bool)
    case flashcard(known: Bool)
    case feynman(transcript: String, feedback: String, score: Int)
    case viewed
}
```

`LearningModels.swift` wird gekürzt: `LearningPath`, `PathStep`, `PathStep.StepType`, `PathStepJSON` verschwinden. `LearnerProfile`, `Badge`, `SpacedCard`, `DailyChallenge` bleiben unverändert.

---

## Datenfluss (5 Hauptszenarien)

### 1. Topic erstellen aus Foto

```
User tippt "+ Neues Topic" → CreateTopicView
  → fotografiert Heft/Buch
  → TopicSourceImporter.extractText(image)            (bestehende OCR aus StudyPlanView)
  → FeedGenerator.generateFeed(topic, sourceText)     (Gemini, Batch = 15 Posts)
  → TopicStore.addTopic(...)                          (CloudKit-Sync)
  → FeedGenerator schreibt Posts in Documents/feeds/<id>.json
  → öffnet TopicFeedView
```

### 2. Topic-Feed öffnen (existierendes Topic)

```
User tippt Topic-Karte → TopicFeedView
  → lädt Posts aus lokaler Datei
  → wenn TopicProgress.feedGeneratedDate < today und feedExhausted == true
        → "Komm morgen wieder" Screen
  → wenn Topic ohne Posts → FeedGenerator.generateFeed(...)
  → LazyVStack rendert Posts
```

### 3. Quiz-Post beantwortet

```
User tippt Antwort → FeedPostViews zeigt Feedback (richtig/falsch + Erklärung)
  → TopicStore.recordAnswer(postId, .quiz(index, correct))
  → LearningEngine.earnXP(10, subject: topic.subject)        (bestehender Code)
  → LearningEngine.recordQuiz(score: 1, total: 1, subject)   (bestehender Code)
```

### 4. Karteikarte gewusst/nicht-gewusst

```
User tippt Karte zum Umdrehen → "Wusste ich" / "Wusste ich nicht"
  → TopicStore.recordAnswer(postId, .flashcard(known))
  → LearningEngine.addCards([Flashcard(...)], subject, topic)
  → fließt automatisch ins bestehende Spaced-Repetition-System
  → erscheint später in den fälligen Karten im Profil
```

### 5. Eltern weisen Topic zu

```
Eltern öffnen ParentalControlView → "Topic für Kind anlegen"
  → CreateTopicView (Eltern-Variante)
  → assignedByParent = true
  → TopicStore.addTopic(...) → CloudKitService syncs to child
  → Kind sieht Topic mit kleinem "Eltern-Badge" oben links der Karte
```

---

## UI-Komponenten

### `HivemindTab.swift` (Hauptansicht)

- **Top-Bar:** App-Logo links, Profil-Avatar rechts (öffnet `ProfileSheetView`).
- **Welcome-Header:** „Welcome back, [Name]!" mit Streak-Indikator (Mo–So mit Häkchen).
- **„Deine Topics" Sektion:** Liste großer Karten (Bild-Hintergrund + Titel + Progress-Bar). Eltern-Topics tragen ein kleines Badge oben links. Tippen → `TopicFeedView`.
- **„+ Neues Topic" Button** (prominent unter den Topics).
- **„Discover" Sektion:** horizontale Scroll-Karten mit Vorschlägen. „Customize" Button öffnet die Kategorie-Auswahl.
- **„Aus deinem Kalender" Sektion** (wenn relevant): „Du hast Mathe-Klausur in 3 Tagen — Topic dazu erstellen?" → ein-Tap-Generierung.

### `TopicFeedView.swift`

- Vertikaler Scroll, ein Post pro Screen-Höhe, generöses Padding, viel Whitespace.
- Top-Bar: Back-Button, Topic-Titel, Share-Button.
- `LazyVStack` rendert Posts.
- Am Ende: „Du hast alle Posts für heute. Komm morgen wieder!" + Tageslimit-Info.

### `FeedPostViews.swift` (5 Sub-Views)

- **`TextLessonPostView`** — Titel + Body, schöne Typografie, optional „💡"-Icon.
- **`QuizPostView`** — Frage groß, 4 Antwort-Buttons, Feedback-Bar mit Erklärung bei Antwort.
- **`FlashcardPostView`** — Tap zum Umdrehen, „Wusste ich" / „Wusste ich nicht" Buttons.
- **`ExamplePostView`** — Szenario-Header + Walkthrough als Step-Liste.
- **`FeynmanPostView`** — Prompt + Mikrofon-Button → Voice-Eingabe → KI-Feedback (wieviele erwartete Keywords getroffen wurden).

### `CreateTopicView.swift`

Tabs oder Buttons für die 5 Quellen:
1. **Topic-Name** — TextField + „Generieren"
2. **Foto** — Kamera/Photo-Picker → OCR
3. **PDF** — DocumentPicker
4. **Link** — URL-Eingabe + WebView/Scraper
5. **Podcast** — Datei-Upload oder URL (vorerst Coming-Soon-Placeholder zulässig)

Plus: Vorschlags-Sektion „Aus deinem Kalender" mit Buttons.

### `DiscoverView.swift`

Customize-Sheet mit Kategorien (Naturwissenschaften, Sprachen, Geschichte, Musik, Sport, Allgemeinwissen, etc.). Auswahl beeinflusst die Vorschläge im „Discover"-Bereich des Tabs.

### `ProfileSheetView.swift`

Sheet mit XP/Level-Header, Badges-Grid, Quiz-Stats, Streak-Historie, Fach-Mastery — alles, was vorher direkt im LearnTab sichtbar war.

---

## Error Handling

Prinzip: niemals harte Crashes, immer freundliche Meldung, **niemals Daten verlieren**.

| Fehlerquelle | Verhalten |
|---|---|
| Gemini-Timeout / API-Fehler | Toast: „Feed konnte nicht erstellt werden, versuch's gleich nochmal". Topic bleibt erhalten, Posts können später nachgeneriert werden. |
| Gemini liefert kaputtes JSON | `FeedGenerator` retried 1× mit strikterem Prompt. Bei zweitem Fehlschlag → User-sichtbare Meldung. |
| OCR liefert keinen Text | `CreateTopicView` fragt: „Konnte nichts erkennen — versuch ein anderes Bild oder gib das Thema manuell ein." |
| PDF zu groß (>5 MB) | Hinweis bei Überschreitung. |
| Podcast-Transkription nicht verfügbar | Feature-Flag, „Coming Soon" Placeholder. |
| CloudKit nicht verfügbar (offline) | Topics werden lokal gespeichert, Sync läuft nach beim nächsten Online-Gehen (`CloudKitService` macht das schon so). |
| Daily-Limit erreicht | Friendly Screen statt Fehler: „Komm morgen wieder! 🎯" + Streak-Erinnerung. |
| Lokale Feed-Datei korrupt | Bei Decode-Fehler → Datei löschen, Topic neu generieren. |

---

## Migration

Da hartes Replace gewählt wurde: Bei der ersten Version mit Hivemind:
1. `LearningEngine.learningPaths` wird beim Laden ignoriert/gelöscht.
2. UserDefaults-Key `learningPaths` wird beim ersten Start entfernt (`UserDefaults.standard.removeObject(forKey: "learningPaths")`).
3. Bestehende `SpacedCard`s, `LearnerProfile`, `Badge`s, `DailyChallenge`s bleiben unangetastet — nur der Pfad-Teil verschwindet.

Da die App noch nicht bei externen Schülern ist (laut Brainstorming), ist Datenverlust akzeptabel.

---

## Out of Scope (für diese Iteration)

Bewusst nicht enthalten — kann später kommen:
- Bild/Meme-Generierung (zu teuer/langsam)
- Audio-Posts (TTS)
- Echte Podcast-Transkription (Whisper-Integration) — `TopicSource.podcast` ist im Modell vorgesehen, aber UI-mäßig „Coming Soon"
- Tests (kein Test-Setup im Projekt)
- Premium-Paywall für Discover-Modus

---

## Offene Punkte für den Implementation Plan

Vom Implementation Plan zu klären (nicht hier im Spec):
- Reihenfolge der Schritte (Models → Stores → Generator → Views → Integration)
- Welcher Gemini-Modell-Endpoint für Feed-Generierung
- Konkretes JSON-Schema im Gemini-Prompt
- CloudKit-Record-Type-Definitionen für `Topic` und `TopicProgress`
- Punkt für Punkt: was wird in `ContentView.swift` geändert (Tab-Verdrahtung)
- Aufräum-Schritte (welche Files löschen, welche Imports entfernen)
