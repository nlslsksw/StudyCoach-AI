# App Store Connect — Datenschutzfragen-Checkliste

Diese Liste hilft dir, die Datenschutzfragen in App Store Connect korrekt zu beantworten. Stand: 2026-09-21 (ohne KI-Funktionen).

---

## 1. Datenerhebung — "Sammelt deine App Daten von Nutzern?"

**Antwort: NEIN** — wenn die App nur lokale Speicherung + iCloud Private Database nutzen würde.

**Antwort: JA** — wegen der Familien-Funktion (CloudKit Public Database). KI-Funktionen gibt es seit 2026-09 nicht mehr; es werden keine Daten an KI-Anbieter übermittelt.

Wir sagen also **JA**, gefolgt von der Detail-Liste unten.

---

## 2. Welche Datentypen werden gesammelt?

### Kategorie: **User Content**

- ✅ **Other User Content** — Lerndaten (Lernzeiten, Noten, Klassenarbeiten, Stundenplan-Termine)
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

- **Keine.** Die App bindet keine Drittanbieter-SDKs ein und kontaktiert außer Apple (CloudKit) nur den WebUntis-Server der Schule, wenn der Nutzer die Anbindung selbst einrichtet.

---

## 5. Pflichtangaben in App Store Connect

Alle Texte (Name, Untertitel, Keywords, Beschreibung, Was ist neu, Review-Notizen) stehen aktuell in **`AppStore/store-text.md`**. Diese Datei ist die Quelle – nicht die alten Vorschläge hier.

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

**Keine KI-Sonderregeln mehr** (KI-Funktionen entfernt). Erwartete Altersfreigabe: **4+**.

---

## 7. App Review Information (für Reviewer)

### Test-Account
Da kein Login vorhanden ist, sind keine Test-Credentials nötig. Notiz im Review:
> Siehe Review-Notizen in `AppStore/store-text.md`.

### Demo-Account (falls Familien-Funktion getestet werden soll)
Hinweis im Review:
> "Die Familien-Funktion verbindet zwei Geräte über einen 6-stelligen Pairing-Code. Zum Testen kann der Reviewer im Schüler-Modus einen Code generieren, ein zweites Gerät simulieren oder die Funktion lokal testen. Es werden keine externen Login-Daten benötigt."

### Notizen
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
5. **Crashes** → vor Submission auf realem Gerät durchtesten
