import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore

    @State private var showWrappedHalbjahr = false
    @State private var showWrappedJahr = false
    @State private var showingImporter = false
    @State private var importResult: (success: Bool, message: String)?
    @State private var showingImportAlert = false
    @State private var jsonURL: URL?
    @State private var gradesCSVURL: URL?
    @State private var sessionsCSVURL: URL?
    @State private var pdfURL: URL?
    @State private var showingPINSetup = false
    @State private var showingOnboarding = false
    @State private var feedCloseGesture: FeedCloseGesture = FeedCloseGesture.current

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }


    var body: some View {
        NavigationStack {
            Form {
                // Lern-Rückblick
                Section {
                    Button {
                        showWrappedHalbjahr = true
                    } label: {
                        Label("Halbjahres-Rückblick", systemImage: "sparkles")
                    }
                    Button {
                        showWrappedJahr = true
                    } label: {
                        Label("Schuljahres-Rückblick", systemImage: "star.fill")
                    }
                } header: {
                    Text("Lern-Rückblick")
                } footer: {
                    Text("Sieh dir deinen persönlichen Lern-Rückblick im Story-Format an.")
                }

                // Hilfe & Tutorial
                Section {
                    Button {
                        showingOnboarding = true
                    } label: {
                        Label("Tutorial erneut anzeigen", systemImage: "play.rectangle.fill")
                    }
                } header: {
                    Text("Hilfe")
                } footer: {
                    Text("Zeigt das Willkommens-Tutorial mit allen App-Funktionen noch einmal an.")
                }

                // Lern-Feed
                Section {
                    Picker("Feed schließen mit", selection: $feedCloseGesture) {
                        ForEach(FeedCloseGesture.allCases) { gesture in
                            Text(gesture.rawValue).tag(gesture)
                        }
                    }
                    .onChange(of: feedCloseGesture) { _, newValue in
                        FeedCloseGesture.current = newValue
                    }
                } header: {
                    Text("Lern-Feed")
                } footer: {
                    Text("Wähle, wie du den Topic-Feed schließen möchtest. Bei \"Doppel-Tap oben\" tippst du oben auf den Bildschirm zweimal kurz hintereinander.")
                }

                // Schulferien
                Section {
                    Picker("Bundesland", selection: Binding(
                        get: { store.selectedBundesland },
                        set: { store.selectedBundesland = $0 }
                    )) {
                        Text("Nicht ausgewählt").tag(nil as Bundesland?)
                        ForEach(Bundesland.allCases) { bl in
                            Text(bl.rawValue).tag(bl as Bundesland?)
                        }
                    }

                    Toggle("Ferien im Kalender anzeigen", isOn: Binding(
                        get: { store.showHolidays },
                        set: { store.showHolidays = $0 }
                    ))
                    .disabled(store.selectedBundesland == nil)
                } header: {
                    Text("Schulferien")
                } footer: {
                    Text("Wähle dein Bundesland, um Schulferien im Kalender hervorzuheben.")
                }

                // Export
                Section {
                    // JSON Backup
                    if let url = jsonURL {
                        ShareLink(item: url) {
                            Label("JSON-Backup teilen", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            jsonURL = ExportService.exportJSON(from: store)
                        } label: {
                            Label("JSON-Backup erstellen", systemImage: "doc.badge.arrow.up")
                        }
                    }

                    // CSV Noten
                    if let url = gradesCSVURL {
                        ShareLink(item: url) {
                            Label("Noten-CSV teilen", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            gradesCSVURL = ExportService.exportGradesCSV(from: store)
                        } label: {
                            Label("Noten als CSV exportieren", systemImage: "tablecells")
                        }
                    }

                    // CSV Lernzeiten
                    if let url = sessionsCSVURL {
                        ShareLink(item: url) {
                            Label("Lernzeiten-CSV teilen", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            sessionsCSVURL = ExportService.exportSessionsCSV(from: store)
                        } label: {
                            Label("Lernzeiten als CSV exportieren", systemImage: "tablecells")
                        }
                    }

                    // PDF
                    if let url = pdfURL {
                        ShareLink(item: url) {
                            Label("PDF-Bericht teilen", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            pdfURL = ExportService.exportPDF(from: store)
                        } label: {
                            Label("PDF-Bericht erstellen", systemImage: "doc.richtext")
                        }
                    }
                } header: {
                    Text("Exportieren")
                } footer: {
                    Text("Erstelle Backups oder Berichte deiner Daten.")
                }

                // Elternkontrolle
                Section {
                    NavigationLink {
                        PINGateView(store: store) {
                            ParentalSetupView(store: store)
                        }
                    } label: {
                        HStack {
                            Label("Elternkontrolle", systemImage: "person.2.fill")
                            Spacer()
                            if let link = store.familyLink, link.isActive {
                                Text("Verbunden")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                } header: {
                    Text("Familie")
                } footer: {
                    Text("Verbinde diese App mit dem Gerät eines Elternteils über iCloud.")
                }

                if store.appMode == .student && store.familyLink != nil {
                    Section {
                        if store.parentalPIN != nil {
                            HStack {
                                Label("PIN aktiv", systemImage: "lock.fill")
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            Button("PIN ändern") {
                                showingPINSetup = true
                            }
                        } else {
                            Button {
                                showingPINSetup = true
                            } label: {
                                Label("Eltern-PIN festlegen", systemImage: "lock.fill")
                            }
                        }
                    } header: {
                        Text("Sicherheit")
                    } footer: {
                        Text("Schützt die Einstellungen mit einem 4-stelligen PIN.")
                    }
                }

                // Import
                Section {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Backup importieren", systemImage: "doc.badge.arrow.down")
                    }
                } header: {
                    Text("Importieren")
                } footer: {
                    Text("Achtung: Beim Import werden alle bestehenden Daten ersetzt.")
                }

                // Rechtliches
                Section {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Datenschutz", systemImage: "lock.shield.fill")
                    }
                    NavigationLink {
                        TermsView()
                    } label: {
                        Label("Nutzungsbedingungen", systemImage: "doc.text.fill")
                    }
                    NavigationLink {
                        ImprintView()
                    } label: {
                        Label("Impressum", systemImage: "info.circle.fill")
                    }
                    Link(destination: URL(string: "https://nlslsksw.github.io/StudyCoach-AI/legal/")!) {
                        HStack {
                            Label("Alle rechtlichen Hinweise online", systemImage: "globe")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } header: {
                    Text("Rechtliches")
                } footer: {
                    Text("Datenschutz, Nutzungsbedingungen und Impressum direkt in der App.")
                }

                // App-Info
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                            .font(.subheadline.monospacedDigit())
                    }
                    HStack {
                        Label("Copyright", systemImage: "c.circle")
                        Spacer()
                        Text("© 2026 Ralf Lohrmann")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                } header: {
                    Text("Über die App")
                }
            }
            .sheet(isPresented: $showingPINSetup) {
                PINSetupView { pin in
                    store.parentalPIN = pin
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [UTType.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    importResult = ExportService.importJSON(from: url, into: store)
                    showingImportAlert = true
                case .failure:
                    importResult = (false, "Datei konnte nicht geöffnet werden.")
                    showingImportAlert = true
                }
            }
            .alert(
                importResult?.success == true ? "Import erfolgreich" : "Import fehlgeschlagen",
                isPresented: $showingImportAlert
            ) {
                Button("OK") { }
            } message: {
                Text(importResult?.message ?? "")
            }
            .fullScreenCover(isPresented: $showWrappedHalbjahr) {
                LernWrappedView(store: store, schoolYear: store.activeSchoolYear(), isHalbjahr: true)
            }
            .fullScreenCover(isPresented: $showWrappedJahr) {
                LernWrappedView(store: store, schoolYear: store.activeSchoolYear(), isHalbjahr: false)
            }
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingView()
            }
        }
    }
}
