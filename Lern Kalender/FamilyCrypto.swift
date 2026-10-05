//
//  FamilyCrypto.swift
//  Lern Kalender
//
//  Verschlüsselung für die Familien-Verbindung.
//
//  Die Daten des Kindes (Noten, Lernzeiten, Fächer, Stundenplan) liegen in der
//  öffentlichen CloudKit-Datenbank, damit Eltern sie ohne eigenes iCloud-Konto
//  und ohne Einladungslink über einen Code abrufen können. Öffentlich heißt:
//  Jeder, der die App hat, kann die Datenbank abfragen. Deshalb verlässt kein
//  Klartext das Gerät.
//
//  So funktioniert es:
//  • Der Kopplungscode ist der Schlüssel. Er steht nur auf den beiden Geräten,
//    nie in der Cloud.
//  • Gespeichert wird allein `codeHash` = SHA-256 des Codes. Damit findet man
//    den Datensatz, kann aus ihm aber nicht auf den Code schließen.
//  • Die Nutzdaten werden mit AES-GCM verschlüsselt. Der Schlüssel entsteht per
//    HKDF aus dem Code.
//
//  Der Code hat 10 Zeichen aus 32 Zeichen (50 Bit). Durchprobieren scheidet
//  damit aus — die alten sechs Ziffern waren in Stunden durch.
//

import Foundation
import CryptoKit

enum FamilyCrypto {

    /// Crockford-Base32: ohne I, L, O und U, damit nichts verwechselt oder
    /// versehentlich zu einem Wort wird.
    static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    static let codeLength = 10

    // MARK: - Code

    /// Neuer Kopplungscode, z. B. "7F3K-9XQ2-M1".
    static func newCode() -> String {
        var zeichen = ""
        for _ in 0..<codeLength {
            var zufall: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &zufall)
            zeichen.append(alphabet[Int(zufall) % alphabet.count])
        }
        return zeichen
    }

    /// Für die Anzeige in Vierergruppen: "7F3K 9XQ2 M1".
    static func formatted(_ code: String) -> String {
        let sauber = normalize(code)
        return stride(from: 0, to: sauber.count, by: 4).map { i -> String in
            let start = sauber.index(sauber.startIndex, offsetBy: i)
            let end = sauber.index(start, offsetBy: min(4, sauber.count - i))
            return String(sauber[start..<end])
        }.joined(separator: " ")
    }

    /// Eingaben tolerant behandeln: Leerzeichen und Bindestriche raus,
    /// Kleinbuchstaben hoch, und die üblichen Verwechslungen geradebiegen.
    static func normalize(_ eingabe: String) -> String {
        var s = eingabe.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        s = s.replacingOccurrences(of: "I", with: "1")
             .replacingOccurrences(of: "L", with: "1")
             .replacingOccurrences(of: "O", with: "0")
             .replacingOccurrences(of: "U", with: "V")
        return s
    }

    /// Alte Verbindungen (sechs Ziffern) erkennen — die müssen neu gekoppelt
    /// werden, weil ihre Daten unverschlüsselt in der Cloud lagen.
    static func isLegacy(_ code: String) -> Bool {
        let s = normalize(code)
        return s.count == 6 && s.allSatisfy(\.isNumber)
    }

    static func isValid(_ code: String) -> Bool {
        let s = normalize(code)
        return s.count == codeLength && s.allSatisfy { alphabet.contains($0) }
    }

    // MARK: - Kennung in der Cloud

    /// Was als Suchschlüssel in CloudKit steht. Aus dem Hash lässt sich der
    /// Code nicht zurückrechnen.
    static func codeHash(_ code: String) -> String {
        let daten = Data(normalize(code).utf8)
        return SHA256.hash(data: daten).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Verschlüsselung

    private static func key(for code: String) -> SymmetricKey {
        let geheim = SymmetricKey(data: Data(normalize(code).utf8))
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: geheim,
            salt: Data("LernKalender.FamilyLink.v1".utf8),
            info: Data("field-encryption".utf8),
            outputByteCount: 32)
    }

    /// Verschlüsselt Daten für den Transport in die öffentliche Datenbank.
    static func seal(_ daten: Data, code: String) -> Data? {
        try? AES.GCM.seal(daten, using: key(for: code)).combined
    }

    /// Gegenstück zu `seal`. Gibt nil zurück, wenn der Code nicht passt oder
    /// der Datensatz noch aus der unverschlüsselten Zeit stammt.
    static func open(_ daten: Data, code: String) -> Data? {
        guard let box = try? AES.GCM.SealedBox(combined: daten) else { return nil }
        return try? AES.GCM.open(box, using: key(for: code))
    }

    /// Bequemlichkeit für Texte (Motivationsnachrichten).
    static func sealText(_ text: String, code: String) -> Data? {
        seal(Data(text.utf8), code: code)
    }

    static func openText(_ daten: Data, code: String) -> String? {
        guard let roh = open(daten, code: code) else { return nil }
        return String(data: roh, encoding: .utf8)
    }
}
