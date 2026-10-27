//
//  PurchaseService.swift
//  Lern Kalender
//
//  Ein einziger Kauf, einmalig: schaltet die WebUntis-Anbindung und die
//  Eltern-Funktion frei. Kein Abo.
//
//  Die App war bis Version 1.1 kostenpflichtig. Wer sie damals gekauft hat,
//  behält alles — das verlangt Apple, und es ist das Mindeste. Erkannt wird
//  das an `AppTransaction.originalAppVersion`: der Build-Nummer, mit der
//  jemand die App zuerst geladen hat. Alles unter `ersterGratisBuild` hat
//  bezahlt.
//

import Foundation
import StoreKit

@MainActor
@Observable
final class PurchaseService {
    static let shared = PurchaseService()

    /// Produkt-Kennung, muss genauso in App Store Connect stehen.
    static let produktID = "lernkalender.pro"

    /// Erster Build, der gratis ausgeliefert wurde. Wer mit einem früheren
    /// Build eingestiegen ist, hat die App bezahlt und bekommt alles.
    static let ersterGratisBuild = 10

    private(set) var produkt: Product?
    private(set) var freigeschaltet = false
    private(set) var ladefehler: String?
    private(set) var laeuft = false

    /// Wurde die App früher einmal gekauft? Nur für die Anzeige im
    /// Einstellungs-Bereich, damit klar ist, warum alles offen ist.
    private(set) var altkauf = false

    private var beobachter: Task<Void, Never>?

    private init() {
        // Letzter bekannter Stand, damit die App nicht bei jedem Start
        // kurz gesperrt aussieht, bevor StoreKit geantwortet hat.
        freigeschaltet = UserDefaults.standard.bool(forKey: "proFreigeschaltet")
        altkauf = UserDefaults.standard.bool(forKey: "proAltkauf")

        beobachter = Task { [weak self] in
            for await ergebnis in StoreKit.Transaction.updates {
                guard let self else { return }
                if case .verified(let transaktion) = ergebnis {
                    await transaktion.finish()
                    await self.statusPruefen()
                }
            }
        }
    }

    // MARK: - Laden

    func produktLaden() async {
        do {
            let gefunden = try await Product.products(for: [Self.produktID])
            produkt = gefunden.first
            if produkt == nil {
                ladefehler = String(localized: "Das Produkt wurde nicht gefunden.")
            } else {
                ladefehler = nil
            }
        } catch {
            ladefehler = error.localizedDescription
        }
    }

    // MARK: - Status

    func statusPruefen() async {
        // 1. Hat jemand die App früher gekauft, als sie Geld kostete?
        if let bezahlt = await altkaufPruefen(), bezahlt {
            altkauf = true
            setzen(true)
            return
        }
        // 2. Sonst: liegt der Kauf vor?
        var gekauft = false
        for await ergebnis in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaktion) = ergebnis,
               transaktion.productID == Self.produktID,
               transaktion.revocationDate == nil {
                gekauft = true
            }
        }
        setzen(gekauft)
    }

    /// Nutzer aus der Zeit, als die App 4,99 € kostete.
    private func altkaufPruefen() async -> Bool? {
        do {
            let ergebnis = try await AppTransaction.shared
            guard case .verified(let appTransaktion) = ergebnis else { return nil }
            // originalAppVersion ist unter iOS die Build-Nummer.
            guard let build = Int(appTransaktion.originalAppVersion) else { return nil }
            return build < Self.ersterGratisBuild
        } catch {
            return nil     // offline o. ä. — dann entscheidet der Kauf-Status
        }
    }

    private func setzen(_ wert: Bool) {
        freigeschaltet = wert
        UserDefaults.standard.set(wert, forKey: "proFreigeschaltet")
        UserDefaults.standard.set(altkauf, forKey: "proAltkauf")
    }

    // MARK: - Kaufen und wiederherstellen

    enum KaufErgebnis { case gekauft, abgebrochen, ausstehend, fehler(String) }

    func kaufen() async -> KaufErgebnis {
        guard let produkt else { return .fehler(String(localized: "Das Produkt ist gerade nicht verfügbar.")) }
        laeuft = true
        defer { laeuft = false }
        do {
            switch try await produkt.purchase() {
            case .success(let pruefung):
                guard case .verified(let transaktion) = pruefung else {
                    return .fehler(String(localized: "Der Kauf konnte nicht bestätigt werden."))
                }
                await transaktion.finish()
                await statusPruefen()
                return .gekauft
            case .userCancelled:
                return .abgebrochen
            case .pending:
                return .ausstehend       // z. B. Kauf muss von Eltern freigegeben werden
            @unknown default:
                return .fehler(String(localized: "Unbekannte Antwort des App Store."))
            }
        } catch {
            return .fehler(error.localizedDescription)
        }
    }

    /// Pflicht laut Apple: ein Weg, Käufe auf einem neuen Gerät zurückzuholen.
    func wiederherstellen() async -> Bool {
        laeuft = true
        defer { laeuft = false }
        try? await AppStore.sync()
        await statusPruefen()
        return freigeschaltet
    }

    // MARK: - Was kostet was

    /// Gesperrt sind die beiden Funktionen, die Eltern betreffen oder ihnen
    /// die meiste Arbeit abnehmen. Für Schüler bleibt die App vollständig:
    /// Stundenplan, Hausaufgaben, Noten, Lerntimer, Widget und Statistik.
    enum ProFunktion: String, CaseIterable, Identifiable {
        var id: String { rawValue }

        case webuntis
        case elternAnsicht

        var titel: String {
            switch self {
            case .webuntis:      return String(localized: "Stundenplan aus WebUntis")
            case .elternAnsicht: return String(localized: "Eltern-Ansicht")
            }
        }

        var beschreibung: String {
            switch self {
            case .webuntis:
                return String(localized: "Stunden, Hausaufgaben und Vertretungen kommen automatisch — einmal verbinden, dann läuft es.")
            case .elternAnsicht:
                return String(localized: "Eltern sehen Lernzeit, Noten und den Countdown zur nächsten Arbeit, ohne nachzufragen.")
            }
        }

        var symbol: String {
            switch self {
            case .webuntis:      return "calendar.badge.clock"
            case .elternAnsicht: return "person.2.fill"
            }
        }
    }

    func erlaubt(_ funktion: ProFunktion) -> Bool { freigeschaltet }

    /// Preis in der Währung des Nutzers, sonst der deutsche Standardpreis.
    var preisText: String { produkt?.displayPrice ?? "4,99 €" }
}
