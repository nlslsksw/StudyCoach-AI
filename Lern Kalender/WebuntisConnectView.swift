import SwiftUI

// MARK: - Webuntis Connect View
//
// Setup-/Status-Sheet, das aus den Einstellungen geöffnet wird.
// Erwartet vom User: Server (z.B. "hepta"), Schulname, Benutzername,
// Passwort. Speichert Passwort im Keychain (siehe WebuntisService).

struct WebuntisConnectView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore

    private var service: WebuntisService { WebuntisService.shared }

    @State private var server: String = WebuntisService.shared.server
    @State private var school: String = WebuntisService.shared.school
    @State private var user: String = WebuntisService.shared.user
    @State private var password: String = WebuntisService.shared.password
    @State private var isTesting = false
    @State private var testMessage: String? = nil
    @State private var testIsError = false
    @State private var showingDisconnectAlert = false
    @State private var showingSchoolSearch = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "network")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                LinearGradient(colors: [.cyan, .blue],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Webuntis verbinden")
                                .font(.headline)
                            Text(service.isConfigured
                                 ? "Verbunden seit \(formattedLastSync)"
                                 : "Noch nicht verbunden")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    Button {
                        showingSchoolSearch = true
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.blue)
                            Text(school.isEmpty ? "Schule suchen" : "Andere Schule wählen")
                                .foregroundStyle(.blue)
                            Spacer()
                        }
                    }
                    HStack {
                        Text("Server")
                        Spacer()
                        TextField("z.B. hepta", text: $server)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                    }
                    HStack {
                        Text("Schule")
                        Spacer()
                        TextField("Schulname", text: $school)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                    }
                    HStack {
                        Text("Benutzer")
                        Spacer()
                        TextField("Login-Name", text: $user)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                    }
                    HStack {
                        Text("Passwort")
                        Spacer()
                        SecureField("Passwort", text: $password)
                            .multilineTextAlignment(.trailing)
                            .submitLabel(.done)
                    }
                } header: {
                    Text("Zugangsdaten")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Server findest du in der Webuntis-App unter „Konto > Profil“. Der Schulname steht oft im URL deiner Schul-Webuntis-Seite (Parameter ?school=…).")
                        Text("Lern Kalender ist ein unabhängiges Produkt und steht in keiner Verbindung zur Untis GmbH. WebUntis ist eine Marke der Untis GmbH. Deine Zugangsdaten bleiben auf diesem Gerät.")
                    }
                }

                Section {
                    Button {
                        Task { await runTest() }
                    } label: {
                        HStack {
                            if isTesting { ProgressView().padding(.trailing, 6) }
                            Text("Login testen")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave || isTesting)

                    Button {
                        Task { await runSync() }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Jetzt synchronisieren")
                                .fontWeight(.semibold)
                            Spacer()
                            if service.isSyncing { ProgressView() }
                        }
                    }
                    .disabled(!canSave || service.isSyncing)

                    if let msg = testMessage {
                        Label(msg, systemImage: testIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(testIsError ? .red : .green)
                    }
                    if let err = service.lastError, testMessage == nil {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if service.isConfigured {
                    Section {
                        Button(role: .destructive) {
                            showingDisconnectAlert = true
                        } label: {
                            Label("Verbindung trennen", systemImage: "xmark.circle")
                        }
                    } footer: {
                        Text("Entfernt nur die Zugangsdaten. Bereits importierte Stunden und Hausaufgaben bleiben erhalten.")
                    }
                }
            }
            .navigationTitle("Webuntis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { saveAndClose() }
                        .disabled(!canSave)
                }
            }
            .alert("Verbindung trennen?", isPresented: $showingDisconnectAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Trennen", role: .destructive) {
                    service.disconnect()
                    server = ""; school = ""; user = ""; password = ""
                    testMessage = nil
                }
            } message: {
                Text("Webuntis-Zugangsdaten werden vom Gerät gelöscht.")
            }
            .sheet(isPresented: $showingSchoolSearch) {
                WebuntisSchoolSearchView { picked in
                    school = picked.loginName
                    server = picked.server
                }
            }
        }
    }

    private var canSave: Bool {
        !server.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !school.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }

    private var formattedLastSync: String {
        guard let date = service.lastSync else { return "—" }
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func saveCredentials() {
        service.server = server.trimmingCharacters(in: .whitespacesAndNewlines)
        service.school = school.trimmingCharacters(in: .whitespacesAndNewlines)
        service.user = user.trimmingCharacters(in: .whitespacesAndNewlines)
        service.password = password
    }

    private func saveAndClose() {
        saveCredentials()
        dismiss()
    }

    private func runTest() async {
        saveCredentials()
        isTesting = true
        defer { isTesting = false }
        do {
            try await service.testLogin()
            testMessage = "Login erfolgreich."
            testIsError = false
        } catch {
            testMessage = (error as? WebuntisError)?.userMessage ?? error.localizedDescription
            testIsError = true
        }
    }

    private func runSync() async {
        saveCredentials()
        await service.sync(into: store)
        if let err = service.lastError {
            testMessage = err
            testIsError = true
        } else {
            testMessage = "Synchronisierung abgeschlossen."
            testIsError = false
        }
    }
}

// MARK: - School Search

/// Sucht über die öffentliche Webuntis-API nach Schulen anhand des
/// Schulnamens und liefert dem Aufrufer ein ausgewähltes Ergebnis.
struct WebuntisSchoolSearchView: View {
    @Environment(\.dismiss) private var dismiss
    var onPick: (WebuntisService.SchoolSearchResult) -> Void

    @State private var query: String = ""
    @State private var results: [WebuntisService.SchoolSearchResult] = []
    @State private var isSearching = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Schulname oder Ort eingeben…", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit { Task { await runSearch() } }
                        if isSearching { ProgressView() }
                    }
                } footer: {
                    Text("Suche fragt direkt bei Webuntis. Mindestens 3 Zeichen tippen, dann ↩ drücken.")
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if !results.isEmpty {
                    Section {
                        ForEach(results) { school in
                            Button {
                                onPick(school)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(school.displayName)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    if !school.address.isEmpty {
                                        Text(school.address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    HStack(spacing: 8) {
                                        Label(school.server, systemImage: "server.rack")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                        Text("·")
                                            .foregroundStyle(.tertiary)
                                        Text(school.loginName)
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("\(results.count) Treffer")
                    }
                }
            }
            .navigationTitle("Schule suchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Suchen") { Task { await runSearch() } }
                        .disabled(query.count < 3)
                }
            }
        }
    }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return }
        isSearching = true
        error = nil
        defer { isSearching = false }
        do {
            results = try await WebuntisService.shared.searchSchools(query: trimmed)
            if results.isEmpty { error = "Keine Schule gefunden." }
        } catch {
            self.error = (error as? WebuntisError)?.userMessage ?? error.localizedDescription
            results = []
        }
    }
}
