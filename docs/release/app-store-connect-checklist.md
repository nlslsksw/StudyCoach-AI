# App Store Connect — Datenschutzfragen-Checkliste

Diese Liste hilft dir, die Datenschutzfragen in App Store Connect korrekt zu beantworten. Stand: 2026-04-09.

---

## 1. Datenerhebung — "Sammelt deine App Daten von Nutzern?"

**Antwort: NEIN** — wenn die App nur lokale Speicherung + iCloud Private Database nutzen würde.

**Antwort: JA** — wegen der Familien-Funktion (CloudKit Public Database) und der Übermittlung von KI-Eingaben an Groq.

Wir sagen also **JA**, gefolgt von der Detail-Liste unten.

---

## 2. Welche Datentypen werden gesammelt?

### Kategorie: **User Content**

- ✅ **Other User Content** — Lerninhalte (Topics, Karteikarten, Notizen, Quiz-Ergebnisse)
  - **Linked to user?** NEIN (keine User-IDs außerhalb des privaten Pairing-Codes)
  - **Used for tracking?** NEIN
  - **Verwendung:**
    - App Functionality (für Synchronisation und Familien-Funktion)

### Kategorie: **Identifiers**

- ❌ **User ID / Device ID** — wir verwenden nur den selbst-generierten Pairing-Code, der ist kein klassischer Identifier. **Nicht ankreuzen.**

### Kategorie: **Diagnostics**

- ❌ Keine Crash-Daten, keine Performance-Daten an uns. **Nicht ankreuzen.**

### Kategorie: **Contact Info / Health / Financial / Location / Sensitive / Browsing / Search History / Purchases**

- ❌ Alles **NEIN**.

---

## 3. Datenschutzpraktiken-Detail-Antworten

Pro Datentyp musst du folgendes beantworten:

### Other User Content

| Frage | Antwort |
|---|---|
| Wird mit dem Nutzer verknüpft? | **Nein** (kein klassischer User-Identifier) |
| Wird zum Tracking verwendet? | **Nein** |
| Verwendungszweck | **App Functionality** |

---

## 4. Drittanbieter-SDKs / externe Datenübertragung

Im Bereich **Privacy → Third-Party SDKs**:

- **Groq, Inc.** — wird von der App kontaktiert (KI-Anfragen). Da Groq nicht als Apple-anerkanntes SDK eingebunden ist (nur HTTP-Calls), brauchst du es nicht als SDK angeben, aber **erwähne es in der Privacy Policy** (siehe `privacy-policy.md` Punkt 2.4).

---

## 5. Pflichtangaben in App Store Connect

### App-Informationen
- **Name:** Lern Kalender
- **Bundle ID:** Ralf-Lohrmann.Lern-Kalender
- **Kategorie:** Bildung (Education) — primary
- **Sekundäre Kategorie:** Produktivität (Productivity)

### Beschreibung (Vorschlag)

```
Lern Kalender — dein digitaler Schul-Begleiter

Plane deine Lernzeit, behalte deine Noten im Blick, lerne mit KI-Unterstützung und bleib motiviert mit deinem persönlichen Lern-Feed.

🗓 KALENDER & PLANUNG
• Lerntage, Klassenarbeiten, Erinnerungen
• Schulferien deines Bundeslandes
• Wiederkehrende Lerntage

📊 STATISTIK & FORTSCHRITT
• Übersicht über Lernzeit, Streak, Noten
• Schuljahres- und Halbjahres-Wrapped (Story-Format)
• Fach-Mastery und Erfolge

🤖 KI-LERN-ASSISTENT (Beta)
• Stelle Fragen und lass dir Themen erklären
• Erstelle Lernpläne aus Foto deiner Hefte
• Generiere Quiz und Karteikarten zu jedem Thema
• Persönlicher Lern-Feed (Hivemind) mit Mikro-Lektionen, Quiz und Feynman-Sprachübungen

👨‍👩‍👧 FAMILIEN-FUNKTION
• Eltern können den Lernfortschritt ihrer Kinder einsehen
• Lernziele setzen, Topics zuweisen, Motivationsnachrichten senden
• Sicher über iCloud verbunden

💾 DEINE DATEN GEHÖREN DIR
• Alle Daten werden auf deinem Gerät und in deinem iCloud-Account gespeichert
• Keine Werbung, kein Tracking, kein Verkauf an Dritte

Hinweise zur KI:
Die KI-Funktionen sind optional und erfordern einen kostenlosen Groq-API-Schlüssel. KI-Antworten können Fehler enthalten — bitte immer kritisch prüfen.
```

### Schlüsselwörter (max. 100 Zeichen, durch Komma getrennt)
```
Schule,Lernen,Kalender,Noten,Hausaufgaben,KI,Quiz,Karteikarten,Lernplan,Schüler
```

### Support-URL
`https://github.com/nlslksw/StudyCoach-AI/issues`

### Marketing-URL (optional)
`https://nlslksw.github.io/StudyCoach-AI/legal/index-en.html`

### Datenschutz-URL
`https://nlslksw.github.io/StudyCoach-AI/legal/privacy-en.html`

---

## 6. Altersfreigabe (Age Rating)

**Empfehlung: 12+**

Begründung in den Apple-Fragen:

- **Unrestricted Web Access:** None
- **Cartoon or Fantasy Violence:** None
- **Mature/Suggestive Themes:** None
- **Frequent/Intense Profanity or Crude Humor:** None
- **Frequent/Intense Sexual Content or Nudity:** None
- **Horror/Fear Themes:** None
- **Prolonged Graphic or Sadistic Realistic Violence:** None
- **Realistic Violence:** None
- **Frequent/Intense Mature/Suggestive Themes:** None
- **Gambling and Contests:** None
- **Medical/Treatment Information:** None
- **Alcohol, Tobacco, or Drug Use or References:** None
- **Simulated Gambling:** None

**Wichtig — Sonderregeln wegen KI:**
- **Generative AI:** App enthält generative KI-Funktionen (Groq via Chat & Lern-Feed). Apple verlangt eine angemessene Inhalts-Moderation, was technisch durch die Sicherheitsfilter von Groq's Llama-Modellen abgedeckt ist. Begründe das in den Review-Notizen.

→ **Resultierende Altersfreigabe wird wahrscheinlich 12+ oder 17+** sein, je nachdem wie streng Apple die KI-Frage bewertet.

---

## 7. App Review Information (für Reviewer)

### Test-Account
Da kein Login vorhanden ist, sind keine Test-Credentials nötig. Notiz im Review:
> "Diese App benötigt keinen Login. Die KI-Funktionen erfordern einen eigenen Groq API-Schlüssel, den Nutzer in den Einstellungen hinterlegen können (kostenlos verfügbar unter console.groq.com). Für die Review haben wir einen Test-Schlüssel hinterlegt: [Test-Schlüssel hier einfügen oder leer lassen]"

### Demo-Account (falls Familien-Funktion getestet werden soll)
Hinweis im Review:
> "Die Familien-Funktion verbindet zwei Geräte über einen 6-stelligen Pairing-Code. Zum Testen kann der Reviewer im Schüler-Modus einen Code generieren, ein zweites Gerät simulieren oder die Funktion lokal testen. Es werden keine externen Login-Daten benötigt."

### Notizen
- Die KI-Funktionen sind als **Beta** gekennzeichnet (in-app via BetaInfoView).
- Sensible Daten werden nicht an die KI geschickt — die Privacy Policy erklärt das.
- Die App verwendet die CloudKit Public Database ausschließlich für die Familien-Funktion (Kind ↔ Eltern Sync), die durch einen geheimen Pairing-Code geschützt ist.

---

## 8. Pflicht-Vorbereitungen vor Submission

- [ ] Privacy Policy unter einer öffentlichen URL hosten (z. B. GitHub Pages, Notion-Seite)
- [ ] Support-URL einrichten
- [ ] Screenshots erstellen (siehe `screenshot-shot-list.md` falls vorhanden)
- [ ] App-Icon final
- [ ] Build Number erhöhen (siehe `Lern Kalender.xcodeproj/project.pbxproj`)
- [ ] Marketing Version setzen (z. B. `1.0`)
- [ ] CloudKit-Schema in **Production** deployen (CloudKit Dashboard → Deploy)
- [ ] In Xcode: Code-Signing korrekt (Distribution Certificate + Provisioning Profile)
- [ ] TestFlight-Test mit echter Familie (Eltern + Kind)

---

## 9. Häufige Reject-Gründe vermeiden

1. **Privacy Manifest fehlt** → ✅ liegt unter `Lern Kalender/PrivacyInfo.xcprivacy`
2. **Privacy Policy URL ungültig** → vor Submission prüfen
3. **API-Key prompt unklar** → in Onboarding klar erklären
4. **KI-Inhalte ohne Disclaimer** → ✅ via BetaInfoView abgedeckt
5. **Crashes** → vor Submission auf realem Gerät durchtesten
