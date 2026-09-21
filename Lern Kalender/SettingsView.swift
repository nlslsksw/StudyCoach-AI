import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore

    @State private var showingImporter = false
    @State private var importResult: (success: Bool, message: String)?
    @State private var showingImportAlert = false
    @State private var jsonURL: URL?
    @State private var gradesCSVURL: URL?
    @State private var sessionsCSVURL: URL?
    @State private var pdfURL: URL?
    @State private var showingPINSetup = false
    @State private var showingOnboarding = false
    @State private var showingWrappedHalbjahr = false
    @State private var showingWrappedJahr = false
    @State private var showingWebuntis = false
    @State private var selectedTheme: AppTheme = ThemeStore.current
    @State private var selectedAccent: AppAccent = ThemeStore.accent
    @State private var devCode: String = ""
    @State private var devUnlocked: Bool = false
    @State private var devFreezeCount: Double = 0
    @State private var dailyReminderEnabled: Bool = NotificationHelper.dailyReminderEnabled
    @State private var dailyReminderTime: Date = {
        var comps = DateComponents()
        comps.hour = NotificationHelper.dailyReminderHour
        comps.minute = NotificationHelper.dailyReminderMinute
        return Calendar.current.date(from: comps) ?? Date()
    }()

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }


    var body: some View {
        NavigationStack {
            Form {
                // Hilfe & Rückblick
                Section {
                    Button {
                        showingOnboarding = true
                    } label: {
                        Label("Tutorial erneut anzeigen", systemImage: "play.rectangle.fill")
                    }
                    let available = WrappedTrigger.availableWrapped(store: store)
                    if available.halbjahr {
                        Button {
                            showingWrappedHalbjahr = true
                        } label: {
                            Label("Halbjahres-Rückblick", systemImage: "sparkles")
                        }
                    }
                    if available.jahr {
                        Button {
                            showingWrappedJahr = true
                        } label: {
                            Label("Schuljahres-Rückblick", systemImage: "star.fill")
                        }
                    }
                } header: {
                    Text("Hilfe & Rückblick")
                } footer: {
                    Text("Tutorial oder deinen persönlichen Lern-Rückblick im Story-Format noch einmal ansehen.")
                }

                // Tägliche Lernzeit-Erinnerung
                Section {
                    Toggle("Tägliche Erinnerung", isOn: $dailyReminderEnabled)
                        .onChange(of: dailyReminderEnabled) { _, newValue in
                            NotificationHelper.dailyReminderEnabled = newValue
                            NotificationHelper.refreshDailyReminder()
                        }
                    if dailyReminderEnabled {
                        DatePicker("Uhrzeit",
                                   selection: $dailyReminderTime,
                                   displayedComponents: .hourAndMinute)
                            .environment(\.locale, Locale(identifier: "de_DE"))
                            .onChange(of: dailyReminderTime) { _, newValue in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                NotificationHelper.dailyReminderHour = comps.hour ?? 18
                                NotificationHelper.dailyReminderMinute = comps.minute ?? 0
                                NotificationHelper.refreshDailyReminder()
                            }
                    }
                } header: {
                    Text("Lern-Erinnerung")
                } footer: {
                    Text("Du bekommst täglich zur gewählten Zeit eine Mitteilung. Wenn du an dem Tag schon Lernzeit eingetragen hast, wird die Erinnerung für heute übersprungen.")
                }

                // Erscheinungsbild
                Section {
                    Picker("Modus", selection: $selectedTheme) {
                        ForEach(AppTheme.allCases) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    .onChange(of: selectedTheme) { _, new in
                        ThemeStore.current = new
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Akzentfarbe")
                            .font(.subheadline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(AppAccent.allCases) { accent in
                                    Button {
                                        selectedAccent = accent
                                        ThemeStore.accent = accent
                                    } label: {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [accent.color, accent.color.opacity(0.7)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 34, height: 34)
                                            .overlay(
                                                Circle()
                                                    .stroke(.white, lineWidth: 2)
                                                    .opacity(selectedAccent == accent ? 1 : 0)
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(accent.color, lineWidth: 2)
                                                    .padding(-2)
                                                    .opacity(selectedAccent == accent ? 1 : 0)
                                            )
                                            .shadow(color: accent.color.opacity(0.3), radius: 4, x: 0, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Erscheinungsbild")
                } footer: {
                    Text("AMOLED ist ein tiefes Schwarz für OLED-iPhones — spart Akku.")
                }

                // Webuntis
                Section {
                    Button {
                        showingWebuntis = true
                    } label: {
                        HStack {
                            Image(systemName: "network")
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(
                                    LinearGradient(colors: [.cyan, .blue],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(WebuntisService.shared.isConfigured ? "Webuntis verbunden" : "Mit Webuntis verbinden")
                                    .foregroundStyle(.primary)
                                if WebuntisService.shared.isConfigured {
                                    Text(WebuntisService.shared.school)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if WebuntisService.shared.isConfigured {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                } header: {
                    Text("Webuntis")
                } footer: {
                    Text("Holt Stundenplan und Hausaufgaben automatisch aus Webuntis. Zugangsdaten werden lokal im Gerät gespeichert (Passwort im Keychain).")
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

                // Entwickler — nur in Debug-Builds, versteckt hinter Code 222
                #if DEBUG
                Section {
                    if !devUnlocked {
                        HStack {
                            Image(systemName: "hammer.fill")
                                .foregroundStyle(.secondary)
                            SecureField("Entwickler-Code", text: $devCode)
                                .keyboardType(.numberPad)
                                .onChange(of: devCode) { _, new in
                                    if new == "222" {
                                        devUnlocked = true
                                        devFreezeCount = Double(store.streakState.freezeCount)
                                    }
                                }
                        }
                    } else {
                        HStack {
                            Image(systemName: "snowflake")
                                .foregroundStyle(.cyan)
                            Text("Streak-Eis")
                            Spacer()
                            Text("\(Int(devFreezeCount))")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.cyan)
                        }
                        Stepper(value: $devFreezeCount, in: 0...9999, step: 1) {
                            Text("Anzahl Eis")
                        }
                        .onChange(of: devFreezeCount) { _, new in
                            store.streakState.freezeCount = Int(new)
                        }
                        HStack(spacing: 8) {
                            Button("+10") { devFreezeCount = min(devFreezeCount + 10, 9999) }
                                .buttonStyle(.bordered)
                            Button("+100") { devFreezeCount = min(devFreezeCount + 100, 9999) }
                                .buttonStyle(.bordered)
                            Button("Reset", role: .destructive) { devFreezeCount = 0 }
                                .buttonStyle(.bordered)
                        }
                        Button("Entwicklermodus sperren") {
                            devUnlocked = false
                            devCode = ""
                        }
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(devUnlocked ? "Entwickler-Modus" : "Entwickler")
                } footer: {
                    if !devUnlocked {
                        Text("Nur für Entwicklungstests. Wenn du den Code nicht kennst, ignorier diesen Abschnitt.")
                    } else {
                        Text("Änderungen wirken sofort — auch über iCloud auf anderen Geräten.")
                    }
                }
                #endif

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
            .sheet(isPresented: $showingWebuntis) {
                WebuntisConnectView(store: store)
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
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingView()
            }
            .fullScreenCover(isPresented: $showingWrappedHalbjahr) {
                LernWrappedView(store: store, schoolYear: store.activeSchoolYear(), isHalbjahr: true)
            }
            .fullScreenCover(isPresented: $showingWrappedJahr) {
                LernWrappedView(store: store, schoolYear: store.activeSchoolYear(), isHalbjahr: false)
            }
        }
    }
}
