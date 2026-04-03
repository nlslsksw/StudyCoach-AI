# KI-Lernplan mit Google Gemini — Spec

## Zusammenfassung

Kinder können ein Foto von Schulaufgaben machen. Apple Vision erkennt den Text on-device, Google Gemini erstellt daraus einen strukturierten Lernplan, der als Kalendereinträge gespeichert wird.

## Ablauf

1. Kind tippt auf "Lernplan erstellen"
2. Foto machen oder aus Galerie wählen
3. Apple Vision (VNRecognizeTextRequest) erkennt Text on-device
4. Kind bestätigt erkannten Text, wählt Fach und Klassenarbeit-Datum
5. Text + Kontext wird an Google Gemini API gesendet
6. Gemini gibt strukturierten Lernplan zurück (JSON)
7. Kind sieht Vorschau des Plans
8. Speichern erstellt Kalendereinträge vom Typ `.lerntag` für jeden Tag

## Neue Dateien

### GeminiService.swift
- Singleton `GeminiService.shared`
- Property `apiKey: String?` — aus Keychain geladen
- `func generateStudyPlan(text: String, subject: String, examDate: Date) async throws -> [StudyPlanDay]`
- Nutzt URLSession, REST API an `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent`
- System-Prompt fordert JSON-Antwort: Array von `{day: "2026-04-05", topic: "Kapitel 3 wiederholen", duration: 30}`
- Parst JSON-Antwort in `[StudyPlanDay]`

### StudyPlanView.swift
- Haupt-View mit 4 Schritten (enum `PlanStep`: `.photo`, `.confirm`, `.generating`, `.preview`)
- **Photo-Step**: `PhotosPicker` für Galerie + Kamera-Button
- **Confirm-Step**: Erkannter Text (editierbar), Fach-Picker aus `store.subjects`, Datum-Picker für Klassenarbeit
- **Generating-Step**: ProgressView
- **Preview-Step**: Liste der Tage mit Thema und Dauer, "Speichern"-Button
- Speichern: Für jeden `StudyPlanDay` einen `CalendarEntry(title: topic, date: day, type: .lerntag)` erstellen

## Datenmodell

```swift
struct StudyPlanDay: Codable {
    var day: String  // "2026-04-05"
    var topic: String
    var duration: Int  // Minuten
}
```

Kein neues persistiertes Model nötig — der Plan wird direkt in bestehende `CalendarEntry`s umgewandelt.

## API-Key Verwaltung

- Eingabe in SettingsView: neues TextField "Gemini API-Key"
- Gespeichert im Keychain (nicht UserDefaults)
- GeminiService liest Key aus Keychain
- Ohne Key: Button "Lernplan erstellen" zeigt Hinweis, Key in Einstellungen einzugeben

## OCR (Apple Vision)

- `VNRecognizeTextRequest` mit `.accurate` Modus
- Deutsche Sprache: `recognitionLanguages = ["de-DE", "en-US"]`
- Gibt erkannten Text als String zurück
- Komplett on-device, kein Netzwerk nötig

## Gemini API Request

```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=API_KEY

{
  "contents": [{
    "parts": [{
      "text": "Du bist ein Lernplan-Assistent für Schüler. Erstelle einen Lernplan als JSON-Array.\n\nFach: Mathe\nKlassenarbeit am: 2026-04-10\nHeute ist: 2026-04-01\n\nAufgaben/Stoff:\n[erkannter Text]\n\nAntworte NUR mit einem JSON-Array: [{\"day\": \"2026-04-02\", \"topic\": \"...\", \"duration\": 30}]"
    }]
  }]
}
```

## Einstiegspunkt

- Neuer Button im CalendarTab Toolbar-Menü (beim "+")
- Label: "Lernplan erstellen" mit Icon "sparkles"
- Öffnet StudyPlanView als Sheet

## Betroffene bestehende Dateien

| Datei | Änderung |
|-------|----------|
| CalendarTab.swift | Neuer Menü-Eintrag "Lernplan erstellen" |
| SettingsView.swift | Neues Feld für Gemini API-Key |
| DataStore.swift | Methode zum Batch-Erstellen von CalendarEntries |

## Fehlerbehandlung

- Kein API-Key → Hinweis mit Link zu Einstellungen
- OCR findet keinen Text → "Kein Text erkannt. Versuche ein deutlicheres Foto."
- Gemini API Fehler → "Lernplan konnte nicht erstellt werden. Bitte versuche es erneut."
- Ungültiges JSON von Gemini → Retry einmal, dann Fehlermeldung
