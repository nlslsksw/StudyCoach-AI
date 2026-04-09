# Datenschutzerklärung — Lern Kalender

**Stand:** 2026-04-09
**Anbieter:** Ralf Lohrmann

Diese Datenschutzerklärung informiert dich darüber, welche Daten die App **Lern Kalender** verarbeitet, wo sie gespeichert werden und wer Zugriff hat.

---

## 1. Verantwortlich

Ralf Lohrmann
[Adresse einsetzen]
E-Mail: [Kontakt-E-Mail einsetzen]

---

## 2. Welche Daten verarbeitet die App?

### 2.1 Lokale Daten (auf deinem Gerät)

Die folgenden Daten werden ausschließlich lokal auf deinem iPhone/iPad gespeichert (in den Standard-Speicherbereichen, die iOS für Apps bereitstellt — `UserDefaults`, `iCloud Key-Value Store`, lokales Dateisystem):

- **Schul-Kalendereinträge** (Lerntage, Klassenarbeiten, Erinnerungen)
- **Fächer** und Schuljahre
- **Lernzeiten** und Lernstatistiken
- **Noten**
- **Karteikarten** und Quiz-Ergebnisse
- **Topics und Lern-Feed-Inhalte** des Hivemind-Bereichs
- **App-Einstellungen**

### 2.2 iCloud-Synchronisation

Wenn du die App mit deinem iCloud-Account verwendest, werden die genannten Daten zusätzlich automatisch über deinen privaten iCloud-Account zwischen deinen Geräten synchronisiert. Apple ist in diesem Fall der Auftragsverarbeiter. Wir haben keinen Zugriff auf diese Daten — sie liegen ausschließlich in deinem iCloud-Speicher und sind durch deinen Apple-Account geschützt.

### 2.3 Familien-Funktion (Eltern ↔ Kind)

Wenn du die Familien-Funktion aktivierst und ein Eltern- mit einem Kind-Gerät verbindest:

- Beim Verbinden wird ein 6-stelliger **Pairing-Code** generiert.
- Bestimmte Lerndaten des Kindes (Lernzeit, Noten, Streak, Topics, Klassenarbeiten) werden in die **öffentliche CloudKit-Datenbank** des App-Anbieters geschrieben, damit das Eltern-Gerät sie abrufen kann.
- Diese Daten sind nur über den geheimen Pairing-Code abrufbar — andere Nutzer haben keinen Zugriff.
- Eltern können **Topics**, **Lernziele** und **Motivationsnachrichten** an das Kind senden, die ebenfalls über CloudKit übertragen werden.

Du kannst die Familien-Verbindung jederzeit in den Einstellungen wieder trennen.

### 2.4 KI-Funktionen (Beta)

Die KI-Funktionen der App (KI-Assistent, Lern-Feed-Generierung, Quiz-/Karteikarten-Erstellung, Lernplan aus Foto) verwenden den externen Anbieter **Groq, Inc.** ([https://groq.com](https://groq.com)). Wenn du die KI nutzt, werden die folgenden Daten an Groq übertragen:

- Deine **Eingabetexte** (Frage, Topic-Name, OCR-Text)
- Bei Foto-Lernplänen: der per Vision-Framework **erkannte Text** (das Bild selbst verlässt dein Gerät nicht)
- Optional: Anweisungen wie Sprache, Antwort-Stil

Groq verarbeitet diese Daten gemäß seiner eigenen Datenschutzbestimmungen ([https://groq.com/privacy-policy/](https://groq.com/privacy-policy/)).

**Wichtig:** Speichere oder sende **keine sensiblen persönlichen Daten** über die KI-Funktionen.

Die KI-Funktion ist optional und erfordert einen eigenen API-Schlüssel, den du in den Einstellungen hinterlegst.

### 2.5 Spracheingabe

Wenn du die Spracheingabe nutzt (im KI-Assistenten oder im Feynman-Modus), wird das **Apple Speech Recognition Framework** verwendet. Apple verarbeitet die Spracheingabe gemäß seinen Datenschutzbestimmungen.

### 2.6 Foto-Auswahl

Beim Erstellen eines Lernplans oder Topics aus einem Foto wird das ausgewählte Bild **lokal mit dem Apple Vision Framework** verarbeitet (OCR). Das Bild verlässt dein Gerät nicht. Nur der erkannte Text wird an die KI gesendet.

---

## 3. Was wir NICHT tun

- ❌ **Kein Tracking** — die App nutzt keine Tracking-Frameworks (Google Analytics, Facebook SDK, AppsFlyer, etc.).
- ❌ **Keine Werbung**.
- ❌ **Keine Verkäufe an Dritte**.
- ❌ **Kein Profil-Building**.
- ❌ **Keine Standortdaten** werden erhoben.
- ❌ **Kein Zugriff auf Kontakte, Kalender (System-Kalender), Erinnerungen oder Mediathek** außerhalb der Foto-Auswahl, die du selbst auslöst.

---

## 4. Berechtigungen

Die App fragt nur folgende Berechtigungen ab — und nur wenn du die jeweilige Funktion verwendest:

- **Mikrofon** — für die Spracheingabe im KI-Assistenten und Feynman-Modus
- **Spracherkennung** — für dieselbe Funktion
- **Fotos** — wenn du ein Bild für einen Lernplan oder ein Topic auswählst
- **Mitteilungen** — für Lern-Erinnerungen und Eltern-Benachrichtigungen

---

## 5. Speicherdauer

- **Lokale Daten** bleiben auf deinem Gerät, bis du sie löschst oder die App deinstallierst.
- **iCloud-Daten** bleiben in deinem iCloud-Account, bis du sie löschst.
- **CloudKit-Daten der Familien-Funktion** werden gelöscht, wenn du die Familien-Verbindung trennst.
- **KI-Eingaben bei Groq** unterliegen den Speicherrichtlinien von Groq.

---

## 6. Deine Rechte (DSGVO)

Als Nutzer in der EU/EWR hast du nach der DSGVO folgende Rechte:

- **Auskunft** über deine gespeicherten Daten
- **Berichtigung** falscher Daten
- **Löschung** deiner Daten
- **Einschränkung** der Verarbeitung
- **Datenübertragbarkeit**
- **Widerspruch** gegen die Verarbeitung
- **Beschwerde** bei einer Aufsichtsbehörde

Da die meisten Daten lokal auf deinem Gerät liegen, kannst du sie selbst über die Einstellungen der App oder die iOS-Einstellungen verwalten. Für CloudKit-Daten der Familien-Funktion wende dich an die unter Punkt 1 angegebene E-Mail-Adresse.

---

## 7. Kinder

Die App ist für Schüler aller Altersstufen geeignet. Für Kinder unter 16 Jahren empfehlen wir die Nutzung mit Einwilligung der Eltern. Die Familien-Funktion gibt Eltern Einblick in den Lernfortschritt ihres Kindes.

---

## 8. Änderungen

Diese Datenschutzerklärung kann bei Änderungen der App aktualisiert werden. Die jeweils aktuelle Version ist in der App unter **Einstellungen → Datenschutz** verlinkt.

---

## 9. Kontakt

Bei Fragen zum Datenschutz: [Kontakt-E-Mail einsetzen]
