# Elternkontrolle Redesign - Spec

## Zusammenfassung

Komplette Überarbeitung der Elternkontrolle: Mehrere Kinder, besseres Dashboard, PIN-Schutz, Push-Benachrichtigungen, Motivations-Nachrichten, Wochenbericht, Eltern können Klassenarbeiten eintragen.

## 1. Datenmodell-Änderungen

### FamilyLink erweitern
```swift
struct FamilyLink: Codable, Identifiable {
    var id = UUID()
    var pairingCode: String
    var childName: String
    var isActive: Bool = true
    var linkedDate: Date = Date()
}
```

### DataStore: Array statt Single
- `familyLink: FamilyLink?` → `familyLinks: [FamilyLink]`
- `studyGoal: StudyGoal?` → `studyGoals: [String: StudyGoal]` (Key = pairingCode)
- Neue Property: `parentalPIN: String?` (gespeichert im Keychain)
- Migration: bestehender `familyLink` wird in `familyLinks` Array übernommen

### Neue Models
```swift
struct MotivationMessage: Codable, Identifiable {
    var id = UUID()
    var text: String
    var date: Date = Date()
    var pairingCode: String
}
```

### AppMode bleibt
- `.student` und `.parent` wie bisher
- Kind-Gerät behält `appMode = .student` und speichert seinen eigenen `familyLink`

## 2. Kind-Seite: Verbindung trennen entfernen

### ParentalSetupView
- "Verbindung trennen"-Button entfernen wenn `store.appMode == .student`
- Kind sieht nur: Status "Verbunden", seinen Pairing-Code, ShareLink
- Disconnect nur möglich wenn `appMode == .parent` oder nach PIN-Eingabe

## 3. PIN-Schutz

### Ablauf
- Elternteil legt 4-stelligen PIN fest beim ersten Pairing auf dem Kind-Gerät
- PIN wird im Keychain gespeichert (nicht in UserDefaults)
- PIN-Abfrage vor: Einstellungen öffnen, Elternkontrolle-Bereich, App-Modus ändern

### PINEntryView
- Neuer View mit 4 Kreisen, Number-Pad
- Bei Ersteinrichtung: PIN zweimal eingeben zur Bestätigung
- 3 Fehlversuche → 30 Sekunden Sperre

## 4. Eltern-Dashboard (ParentDashboardView)

### Layout
- Oben: ScrollView horizontal mit Kind-Tabs + "+" Button
- Darunter: ScrollView vertikal mit Sektionen pro ausgewähltem Kind

### Sektionen pro Kind
1. **Lernziel-Fortschritt** — Tages- und Wochenbalken (wie GoalProgressView)
2. **Heute gelernt** — Liste der heutigen Sessions (Fach, Dauer, Uhrzeit)
3. **Wochenübersicht** — 7 Tage als Kacheln mit Minutenzahl + Farbe
4. **Noten** — Alle Noten: Datum, Fach, Note, Typ (schriftlich/mündlich), Durchschnitt pro Fach
5. **Klassenarbeiten** — Anstehende Termine + "+" Button zum Hinzufügen
6. **Lernziele** — Inline Stepper für Tages-/Wochenziel (kein separater Tab)

### Datenquelle
- Alle Daten über `CloudKitService` via `pairingCode` des ausgewählten Kindes
- Pull-to-Refresh + automatisches Laden bei Tab-Wechsel

## 5. Eltern können Klassenarbeiten eintragen

### AddExamView (Sheet)
- Felder: Fach (TextField), Titel (TextField), Datum (DatePicker)
- Speichern → CloudKit Record mit pairingCode
- Neuer CloudKit Record Type: `SharedCalendarEntry`

### Kind-Seite
- `CalendarTab.onAppear`: SharedCalendarEntries vom CloudKit laden
- Anzeige im Kalender als normaler Eintrag mit speziellem Icon (z.B. person.2.fill overlay)

## 6. Push-Benachrichtigungen für Eltern

### Trigger (Kind-Seite)
- Nach Speichern einer StudySession → CloudKit Notification an Eltern-Gerät
- Nach Eintragen einer Note → CloudKit Notification

### Empfang (Eltern-Seite)
- CloudKit Subscription auf Änderungen pro pairingCode (bereits teilweise vorhanden)
- Local Notification mit Inhalt: "Max hat 45 Minuten Mathe gelernt" / "Neue Note: Englisch 2,0"

### CloudKitService Erweiterungen
- `sendActivityNotification()` erweitern für Session- und Noten-Events
- Eltern-App registriert sich für Remote Notifications

## 7. Motivations-Nachrichten

### Eltern-Seite
- TextField im Dashboard pro Kind: "Nachricht an [Name]..."
- Senden → CloudKit Record `MotivationMessage`
- Letzte gesendete Nachricht wird angezeigt

### Kind-Seite
- Bei App-Start: Prüfe ob neue MotivationMessage vorhanden
- Anzeige als Banner/Alert oben in der App
- "Gelesen"-Markierung nach Tippen

## 8. Wochenbericht

### Verfügbarkeit
- Freitag 00:00 bis Sonntag 23:59
- Button im Dashboard: "Wochenbericht anzeigen" (nur in diesem Zeitraum sichtbar)

### WeeklyReportView (Sheet)
- Pro Kind eine Sektion:
  - Gesamtlernzeit der Woche
  - Lernzeit pro Fach (Balkendiagramm)
  - Neue Noten dieser Woche
  - Lernziel-Fortschritt (%)
  - Aktuelle Serie
  - Vergleich zur Vorwoche ("↑ 15% mehr als letzte Woche" / "↓ 10% weniger")
- Scrollbar wenn mehrere Kinder

## 9. Betroffene Dateien

| Datei | Änderungen |
|-------|-----------|
| `Models.swift` | FamilyLink erweitern, MotivationMessage hinzufügen |
| `DataStore.swift` | familyLinks Array, studyGoals Dict, PIN-Keychain, Migration |
| `ParentalControlViews.swift` | Kompletter Umbau: Dashboard, PIN, Multi-Kind, Exam-Add |
| `ContentView.swift` | ParentDashboardView mit Tabs, ParentSettingsTab Anpassung |
| `CloudKitService.swift` | SharedCalendarEntry, MotivationMessage, erweiterte Subscriptions |
| `CalendarTab.swift` | Shared Entries laden und anzeigen |
| `SettingsView.swift` | PIN-Gate vor Einstellungen |
| Neue Datei: `PINEntryView.swift` | PIN-Eingabe View |
| Neue Datei: `WeeklyReportView.swift` | Wochenbericht View |

## 10. Reihenfolge

1. Datenmodell + Migration (Models.swift, DataStore.swift)
2. PIN-Schutz (PINEntryView.swift, SettingsView.swift)
3. Kind-Seite: Disconnect entfernen (ParentalControlViews.swift)
4. Multi-Kind Pairing (ParentalControlViews.swift, ContentView.swift)
5. Dashboard Redesign (ParentalControlViews.swift)
6. Lernziele inline (ParentalControlViews.swift)
7. Klassenarbeiten eintragen + Sync (CloudKitService.swift, CalendarTab.swift)
8. Push-Benachrichtigungen (CloudKitService.swift)
9. Motivations-Nachrichten (CloudKitService.swift, ParentalControlViews.swift)
10. Wochenbericht (WeeklyReportView.swift)
