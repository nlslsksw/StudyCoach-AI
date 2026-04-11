import SwiftUI

// MARK: - Generic legal document layout

struct LegalDocumentView: View {
    let title: String
    let lastUpdated: String
    let intro: String?
    let sections: [LegalSection]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(lastUpdated)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let intro {
                    Text(intro)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.title3.bold())
                            .padding(.top, 8)
                        ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, p in
                            Text(p)
                                .font(.body)
                                .foregroundStyle(.primary.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !section.bullets.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(section.bullets.enumerated()), id: \.offset) { _, b in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .foregroundStyle(.secondary)
                                        Text(b)
                                            .font(.body)
                                            .foregroundStyle(.primary.opacity(0.9))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(.leading, 4)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LegalSection: Identifiable {
    let id = UUID()
    let title: String
    var paragraphs: [String] = []
    var bullets: [String] = []
}

// MARK: - Privacy Policy

struct PrivacyPolicyView: View {
    var body: some View {
        LegalDocumentView(
            title: "Datenschutz",
            lastUpdated: "Stand: 9. April 2026",
            intro: "Diese Datenschutzerklärung informiert dich darüber, welche Daten die App Lern Kalender verarbeitet, wo sie gespeichert werden und wer Zugriff hat.",
            sections: [
                LegalSection(
                    title: "1. Verantwortlich",
                    paragraphs: [
                        "Ralf Lohrmann\nHeilbronner Straße 9\n73728 Esslingen\nDeutschland",
                        "E-Mail: geldtracker.contact@gmail.com"
                    ]
                ),
                LegalSection(
                    title: "2.1 Lokale Daten",
                    paragraphs: ["Die folgenden Daten werden ausschließlich lokal auf deinem iPhone/iPad gespeichert (UserDefaults, iCloud Key-Value Store, lokales Dateisystem):"],
                    bullets: [
                        "Schul-Kalendereinträge (Lerntage, Klassenarbeiten, Erinnerungen)",
                        "Fächer und Schuljahre",
                        "Lernzeiten und Lernstatistiken",
                        "Noten",
                        "Karteikarten und Quiz-Ergebnisse",
                        "Topics und Lern-Feed-Inhalte des Hivemind-Bereichs",
                        "App-Einstellungen"
                    ]
                ),
                LegalSection(
                    title: "2.2 iCloud-Synchronisation",
                    paragraphs: ["Wenn du die App mit deinem iCloud-Account verwendest, werden die genannten Daten zusätzlich automatisch über deinen privaten iCloud-Account zwischen deinen Geräten synchronisiert. Apple ist in diesem Fall der Auftragsverarbeiter. Wir haben keinen Zugriff auf diese Daten — sie liegen ausschließlich in deinem iCloud-Speicher und sind durch deinen Apple-Account geschützt."]
                ),
                LegalSection(
                    title: "2.3 Familien-Funktion",
                    paragraphs: ["Wenn du die Familien-Funktion aktivierst und ein Eltern- mit einem Kind-Gerät verbindest:"],
                    bullets: [
                        "Beim Verbinden wird ein 6-stelliger Pairing-Code generiert.",
                        "Bestimmte Lerndaten des Kindes (Lernzeit, Noten, Streak, Topics, Klassenarbeiten) werden in die öffentliche CloudKit-Datenbank des App-Anbieters geschrieben, damit das Eltern-Gerät sie abrufen kann.",
                        "Diese Daten sind nur über den geheimen Pairing-Code abrufbar.",
                        "Eltern können Topics, Lernziele und Motivationsnachrichten an das Kind senden."
                    ]
                ),
                LegalSection(
                    title: "2.4 KI-Funktionen",
                    paragraphs: [
                        "Die KI-Funktionen der App verwenden externe KI-Anbieter. Standardmäßig wird Groq, Inc. über unseren Backend-Server verwendet. Optional kannst du in den Einstellungen einen eigenen API-Key für Groq, OpenAI, Google Gemini oder Anthropic Claude hinterlegen.",
                        "Wenn du die KI nutzt, werden Eingabetexte, OCR-Text aus Fotos (das Bild selbst bleibt auf deinem Gerät) und optionale Anweisungen an den gewählten Anbieter übertragen. Der jeweilige Anbieter verarbeitet diese Daten gemäß seiner eigenen Datenschutzbestimmungen.",
                        "Wichtig: Speichere oder sende keine sensiblen persönlichen Daten über die KI-Funktionen."
                    ]
                ),
                LegalSection(
                    title: "3. Was wir NICHT tun",
                    bullets: [
                        "Kein Tracking — die App nutzt keine Tracking-Frameworks.",
                        "Keine Werbung.",
                        "Keine Verkäufe an Dritte.",
                        "Kein Profil-Building.",
                        "Keine Standortdaten.",
                        "Kein Zugriff auf Kontakte, System-Kalender, Erinnerungen oder Mediathek außerhalb der Foto-Auswahl, die du selbst auslöst."
                    ]
                ),
                LegalSection(
                    title: "4. Berechtigungen",
                    paragraphs: ["Die App fragt nur folgende Berechtigungen ab — und nur wenn du die jeweilige Funktion verwendest:"],
                    bullets: [
                        "Mikrofon — für die Spracheingabe",
                        "Spracherkennung — für die Spracheingabe",
                        "Fotos — wenn du ein Bild auswählst",
                        "Mitteilungen — für Erinnerungen und Eltern-Benachrichtigungen"
                    ]
                ),
                LegalSection(
                    title: "5. Speicherdauer",
                    bullets: [
                        "Lokale Daten bleiben, bis du sie löschst oder die App deinstallierst.",
                        "iCloud-Daten bleiben in deinem iCloud-Account.",
                        "CloudKit-Daten der Familien-Funktion werden beim Trennen gelöscht.",
                        "KI-Eingaben unterliegen den Datenschutzrichtlinien des gewählten Anbieters (Groq, OpenAI, Google oder Anthropic)."
                    ]
                ),
                LegalSection(
                    title: "6. Deine Rechte (DSGVO)",
                    paragraphs: ["Als Nutzer in der EU/EWR hast du nach der DSGVO folgende Rechte:"],
                    bullets: [
                        "Auskunft über deine gespeicherten Daten",
                        "Berichtigung falscher Daten",
                        "Löschung deiner Daten",
                        "Einschränkung der Verarbeitung",
                        "Datenübertragbarkeit",
                        "Widerspruch gegen die Verarbeitung",
                        "Beschwerde bei einer Aufsichtsbehörde"
                    ]
                ),
                LegalSection(
                    title: "7. Kinder",
                    paragraphs: ["Die App ist für Schüler aller Altersstufen geeignet. Für Kinder unter 16 Jahren empfehlen wir die Nutzung mit Einwilligung der Eltern."]
                ),
                LegalSection(
                    title: "8. Kontakt",
                    paragraphs: ["Bei Fragen zum Datenschutz: geldtracker.contact@gmail.com"]
                )
            ]
        )
    }
}

// MARK: - Terms of Use

struct TermsView: View {
    var body: some View {
        LegalDocumentView(
            title: "Nutzungsbedingungen",
            lastUpdated: "Stand: 9. April 2026",
            intro: nil,
            sections: [
                LegalSection(
                    title: "1. Geltungsbereich",
                    paragraphs: [
                        "Diese Nutzungsbedingungen regeln die Nutzung der mobilen App Lern Kalender (im Folgenden 'die App') des Anbieters Ralf Lohrmann, Heilbronner Straße 9, 73728 Esslingen, Deutschland.",
                        "Mit der Installation oder Nutzung der App erklärst du dich mit diesen Nutzungsbedingungen einverstanden."
                    ]
                ),
                LegalSection(
                    title: "2. Beschreibung des Dienstes",
                    paragraphs: ["Lern Kalender ist eine App zur Organisation des Schulalltags. Sie umfasst unter anderem:"],
                    bullets: [
                        "Kalender und Lernzeit-Tracking",
                        "Fächer- und Notenverwaltung",
                        "Statistiken und Auswertungen",
                        "Optionale KI-Funktionen (Lernassistent, Lernpläne, Quiz, Karteikarten, Lern-Feed)",
                        "Familien-Funktion zur Verbindung von Eltern- und Kind-Geräten"
                    ]
                ),
                LegalSection(
                    title: "3. Nutzungsrechte",
                    paragraphs: ["Der Anbieter gewährt dir das nicht-ausschließliche, nicht-übertragbare Recht, die App auf deinen kompatiblen Apple-Geräten gemäß den Apple-App-Store-Bedingungen zu nutzen. Eine kommerzielle Nutzung, Vervielfältigung oder Bearbeitung der App ist ohne ausdrückliche Zustimmung des Anbieters untersagt."]
                ),
                LegalSection(
                    title: "4. Pflichten der Nutzer",
                    paragraphs: ["Du verpflichtest dich, die App ausschließlich zu rechtmäßigen Zwecken und im Einklang mit den geltenden Gesetzen zu nutzen."],
                    bullets: [
                        "Keine sensiblen oder gesetzlich geschützten persönlichen Daten an die KI senden.",
                        "Die App nicht missbräuchlich verwenden, um andere zu schädigen.",
                        "Du bist allein verantwortlich für die Inhalte, die du in die App eingibst.",
                        "Du bist für die Sicherheit deiner API-Schlüssel selbst verantwortlich."
                    ]
                ),
                LegalSection(
                    title: "5. KI-Funktionen",
                    paragraphs: ["Folgendes ist bei der Nutzung der KI-Funktionen zu beachten:"],
                    bullets: [
                        "KI-Antworten können fehlerhaft, unvollständig oder irreführend sein.",
                        "KI-Antworten dürfen nicht ungeprüft in Hausaufgaben oder Klassenarbeiten übernommen werden.",
                        "Der Anbieter übernimmt keine Verantwortung für die Richtigkeit der KI-Inhalte.",
                        "Die App unterstützt verschiedene KI-Anbieter: Groq, OpenAI, Google Gemini und Anthropic Claude."
                    ]
                ),
                LegalSection(
                    title: "6. Familien-Funktion",
                    bullets: [
                        "Bei Minderjährigen ist die Zustimmung eines Erziehungsberechtigten erforderlich.",
                        "Eltern können den Lernfortschritt einsehen und Topics zuweisen.",
                        "Beide Seiten können die Verbindung jederzeit trennen."
                    ]
                ),
                LegalSection(
                    title: "7. Verfügbarkeit",
                    paragraphs: ["Der Anbieter ist bemüht, die App ohne Unterbrechungen verfügbar zu halten. Es besteht jedoch kein Anspruch auf eine ununterbrochene Verfügbarkeit."]
                ),
                LegalSection(
                    title: "8. Haftungsausschluss",
                    paragraphs: [
                        "Der Anbieter haftet nur für Schäden, die durch grobe Fahrlässigkeit oder Vorsatz verursacht wurden. Die Haftung für mittelbare Schäden, entgangenen Gewinn oder Folgeschäden ist ausgeschlossen, soweit dies gesetzlich zulässig ist.",
                        "Die App stellt keine Garantie für schulischen Erfolg dar."
                    ]
                ),
                LegalSection(
                    title: "9. Datenschutz",
                    paragraphs: ["Es gilt die separate Datenschutzerklärung, die in dieser App verlinkt ist."]
                ),
                LegalSection(
                    title: "10. Änderungen",
                    paragraphs: ["Der Anbieter behält sich vor, diese Nutzungsbedingungen bei Bedarf anzupassen. Wesentliche Änderungen werden dir in der App angezeigt."]
                ),
                LegalSection(
                    title: "11. Anwendbares Recht",
                    paragraphs: ["Es gilt das Recht der Bundesrepublik Deutschland. Sofern du Verbraucher mit Wohnsitz in der EU bist, gelten zusätzlich die zwingenden verbraucherschutzrechtlichen Bestimmungen deines Wohnsitzlandes."]
                ),
                LegalSection(
                    title: "12. Kontakt",
                    paragraphs: ["Bei Fragen: geldtracker.contact@gmail.com"]
                )
            ]
        )
    }
}

// MARK: - Imprint

struct ImprintView: View {
    var body: some View {
        LegalDocumentView(
            title: "Impressum",
            lastUpdated: "Stand: 9. April 2026",
            intro: nil,
            sections: [
                LegalSection(
                    title: "Anbieter (gemäß § 5 TMG)",
                    paragraphs: [
                        "Ralf Lohrmann\nHeilbronner Straße 9\n73728 Esslingen\nDeutschland"
                    ]
                ),
                LegalSection(
                    title: "Kontakt",
                    paragraphs: ["E-Mail: geldtracker.contact@gmail.com"]
                ),
                LegalSection(
                    title: "Verantwortlich für den Inhalt (§ 18 Abs. 2 MStV)",
                    paragraphs: ["Ralf Lohrmann\nHeilbronner Straße 9\n73728 Esslingen\nDeutschland"]
                ),
                LegalSection(
                    title: "Haftungsausschluss — Inhalt",
                    paragraphs: ["Der Anbieter übernimmt keine Gewähr für die Aktualität, Korrektheit, Vollständigkeit oder Qualität der bereitgestellten Informationen. Haftungsansprüche gegen den Anbieter, welche sich auf Schäden materieller oder ideeller Art beziehen, die durch die Nutzung oder Nichtnutzung der dargebotenen Informationen verursacht wurden, sind grundsätzlich ausgeschlossen, sofern seitens des Anbieters kein nachweislich vorsätzliches oder grob fahrlässiges Verschulden vorliegt."]
                ),
                LegalSection(
                    title: "Verweise und Links",
                    paragraphs: ["Bei direkten oder indirekten Verweisen auf fremde Webseiten, die außerhalb des Verantwortungsbereiches des Anbieters liegen, würde eine Haftungsverpflichtung ausschließlich in dem Fall in Kraft treten, in dem der Anbieter von den Inhalten Kenntnis hat und es ihm technisch möglich und zumutbar wäre, die Nutzung im Falle rechtswidriger Inhalte zu verhindern."]
                ),
                LegalSection(
                    title: "Urheber- und Kennzeichenrecht",
                    paragraphs: ["Der Anbieter ist bestrebt, in allen Publikationen die Urheberrechte der verwendeten Grafiken, Tondokumente, Videosequenzen und Texte zu beachten. Alle innerhalb des Internetangebotes genannten und ggf. durch Dritte geschützten Marken- und Warenzeichen unterliegen uneingeschränkt den Bestimmungen des jeweils gültigen Kennzeichenrechts und den Besitzrechten der jeweils eingetragenen Eigentümer."]
                ),
                LegalSection(
                    title: "EU-Streitschlichtung",
                    paragraphs: [
                        "Die Europäische Kommission stellt eine Plattform zur Online-Streitbeilegung (OS) bereit: https://ec.europa.eu/consumers/odr/",
                        "Wir sind nicht bereit oder verpflichtet, an Streitbeilegungsverfahren vor einer Verbraucherschlichtungsstelle teilzunehmen."
                    ]
                )
            ]
        )
    }
}
