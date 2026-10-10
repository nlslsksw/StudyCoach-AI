//
//  PaywallView.swift
//  Lern Kalender
//
//  Erscheint, wenn jemand WebUntis oder die Eltern-Ansicht öffnet, ohne
//  freigeschaltet zu haben. Sagt klar, was es kostet und was man dafür
//  bekommt — keine Dringlichkeits-Tricks, keine künstliche Verknappung.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kauf = PurchaseService.shared
    @State private var meldung: String?
    @State private var zeigeDank = false

    /// Von welcher Funktion aus die Seite geöffnet wurde — die steht oben.
    var ausloeser: PurchaseService.ProFunktion = .elternAnsicht

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    kopf

                    VStack(spacing: 14) {
                        ForEach(PurchaseService.ProFunktion.allCases, id: \.self) { f in
                            FunktionsZeile(funktion: f, hervorgehoben: f == ausloeser)
                        }
                    }
                    .padding(.horizontal)

                    kaufBereich

                    Text("Einmal kaufen, dauerhaft freigeschaltet. Kein Abo, keine Werbung, kein Konto.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    if let meldung {
                        Text(meldung)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    rechtliches
                }
                .padding(.vertical, 24)
            }
            .navigationTitle("Freischalten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .task {
                await kauf.produktLaden()
                await kauf.statusPruefen()
            }
            .onChange(of: kauf.freigeschaltet) { _, neu in
                if neu { zeigeDank = true }
            }
            .alert("Freigeschaltet", isPresented: $zeigeDank) {
                Button("Weiter") { dismiss() }
            } message: {
                Text("WebUntis und die Eltern-Ansicht stehen jetzt bereit.")
            }
        }
    }

    private var kopf: some View {
        VStack(spacing: 10) {
            Image(systemName: ausloeser.symbol)
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text(ausloeser.titel)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(ausloeser.beschreibung)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var kaufBereich: some View {
        VStack(spacing: 12) {
            Button {
                Task { await kaufen() }
            } label: {
                HStack {
                    if kauf.laeuft { ProgressView().tint(.white) }
                    Text(kauf.laeuft ? "Einen Moment…" : "Für \(kauf.preisText) freischalten")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(kauf.laeuft || kauf.produkt == nil)
            .padding(.horizontal, 24)

            Button("Käufe wiederherstellen") {
                Task {
                    let ok = await kauf.wiederherstellen()
                    meldung = ok ? nil : "Es wurde kein früherer Kauf gefunden."
                }
            }
            .font(.footnote)
            .disabled(kauf.laeuft)

            if kauf.produkt == nil, kauf.ladefehler != nil {
                Text("Der App Store antwortet gerade nicht. Versuch es später noch einmal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    private var rechtliches: some View {
        HStack(spacing: 18) {
            Link("Datenschutz", destination: URL(string: "https://niraki.eu/apps/lern-kalender/datenschutz")!)
            Link("Nutzungsbedingungen", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func kaufen() async {
        meldung = nil
        switch await kauf.kaufen() {
        case .gekauft:     break               // der Alert übernimmt
        case .abgebrochen: break               // kein Fehler, nichts sagen
        case .ausstehend:
            meldung = "Der Kauf wartet noch auf eine Freigabe."
        case .fehler(let text):
            meldung = text
        }
    }
}

private struct FunktionsZeile: View {
    let funktion: PurchaseService.ProFunktion
    let hervorgehoben: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: funktion.symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(funktion.titel).font(.headline)
                Text(funktion.beschreibung)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(hervorgehoben ? Color.accentColor : .clear, lineWidth: 1.5)
                )
        )
    }
}

/// Kleines Schloss-Abzeichen für gesperrte Einträge in Listen.
struct ProAbzeichen: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(5)
            .background(Color(.tertiarySystemFill), in: Circle())
            .accessibilityLabel("Kostenpflichtig")
    }
}
