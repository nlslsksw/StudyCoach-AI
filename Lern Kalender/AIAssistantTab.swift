import SwiftUI
import PhotosUI
import Vision
import Speech
import AVFoundation

// MARK: - AI Assistant Tab

struct AIAssistantTab: View {
    var store: DataStore

    var body: some View {
        Group {
            if !store.aiAllowed {
                aiBlockedView
            } else if AIService.shared.hasAPIKey {
                AIChatView(store: store)
            } else {
                AISetupView(store: store)
            }
        }
        .onAppear {
            // Refresh parental flag every time the KI tab is shown.
            Self.refreshAIAllowed(store: store)
        }
    }

    /// Refresh the parental AI-allowed flag from CloudKit.
    static func refreshAIAllowed(store: DataStore) {
        guard let link = store.familyLink, link.isActive else { return }
        Task {
            if let allowed = await CloudKitService.shared.fetchAIAllowed(pairingCode: link.pairingCode) {
                await MainActor.run { store.aiAllowed = allowed }
            }
        }
    }

    private var aiBlockedView: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("KI-Assistent gesperrt")
                    .font(.title3.bold())
                Text("Ein Elternteil hat den KI-Assistenten deaktiviert. Bitte frage deine Eltern, ob sie ihn in den Einstellungen aktivieren können.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            }
            .navigationTitle("KI-Assistent")
        }
    }
}

// MARK: - Chat Models

struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    var role: String // "user" or "assistant"
    var text: String
    var date: Date = Date()
    var quizId: UUID?
    var flashcardSetId: UUID?
    var actionResults: [ActionResult]?
}

struct ActionResult: Identifiable, Codable {
    var id = UUID()
    var icon: String
    var color: String // "blue", "green", "pink", "orange", "purple"
    var title: String
    var detail: String
    var destination: String // "calendar", "grades", "subjects", "studylog"

    var swiftColor: Color {
        switch color {
        case "green": return .green
        case "pink": return .pink
        case "orange": return .orange
        case "purple": return .purple
        default: return .blue
        }
    }
}

struct ChatSession: Identifiable, Codable {
    var id = UUID()
    var title: String
    var messages: [ChatMessage]
    var date: Date = Date()
}

// MARK: - Chat History Manager

@Observable
final class ChatHistory {
    static let shared = ChatHistory()
    var sessions: [ChatSession] = []

    private let key = "chatHistory"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ChatSession].self, from: data) {
            sessions = decoded
        }
    }

    func save() {
        // Keep max 20 sessions
        if sessions.count > 20 { sessions = Array(sessions.prefix(20)) }
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func addSession(_ session: ChatSession) {
        sessions.insert(session, at: 0)
        save()
    }

    func deleteSession(_ session: ChatSession) {
        sessions.removeAll { $0.id == session.id }
        save()
    }
}

// MARK: - AI Chat View

struct AIChatView: View {
    var store: DataStore
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var showingPlusSheet = false
    @State private var showingSidebar = false
    @State private var showingStudyPlan = false
    @State private var showingSettings = false
    @State private var showingContent = false
    @State private var showingHivemind = false
    @State private var showingBetaInfo = false
    @State private var quizToPlay: SavedQuiz?
    @State private var flashcardsToPlay: SavedFlashcardSet?
    @State private var navigateToTab: String?
    @FocusState private var inputFocused: Bool
    @State private var isRecording = false
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingPhotoPicker = false

    private let history = ChatHistory.shared

    private let suggestions: [(title: String, subtitle: String)] = [
        ("Erkläre Bruchrechnung", "einfach und mit Beispielen"),
        ("Quiz: Fotosynthese", "5 Fragen mit Antworten"),
        ("Fasse zusammen", "die wichtigsten Punkte"),
        ("Hilf mir bei Mathe", "Gleichungen lösen lernen")
    ]

    var body: some View {
        ZStack {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat Content
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty {
                                VStack(spacing: 12) {
                                    Spacer(minLength: 100)

                                    Image(systemName: "cpu.fill")
                                        .font(.system(size: 36))
                                        .foregroundStyle(.white)
                                        .frame(width: 64, height: 64)
                                        .background(
                                            LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                                            in: RoundedRectangle(cornerRadius: 16)
                                        )

                                    Text("Willkommen!")
                                        .font(.title3.bold())
                                    Text("Ich bin dein persönlicher Lern-Assistent. Stelle mir Fragen, lass dir Themen erklären oder erstelle einen Lernplan.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 30)

                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                            }

                            ForEach(messages) { msg in
                                chatBubble(msg)
                                    .id(msg.id)
                            }

                            if isLoading {
                                HStack {
                                    TypingIndicator()
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .id("loading")
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: messages.count) { _, _ in
                        if let lastId = messages.last?.id {
                            withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                        }
                    }
                    .onChange(of: isLoading) { _, loading in
                        if loading {
                            withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
                        }
                    }
                }

                // Input Bar
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Button { showingPlusSheet = true } label: {
                            Image(systemName: "plus")
                                .font(.body.weight(.bold))
                                .foregroundStyle(.primary)
                                .frame(width: 36, height: 36)
                                .glassEffect(.regular.interactive())
                        }

                        HStack(spacing: 8) {
                            TextField("\(AIService.shared.assistantName) fragen", text: $inputText, axis: .vertical)
                                .lineLimit(1...4)
                                .focused($inputFocused)

                            if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Button { sendMessage() } label: {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.pink)
                                }
                            } else {
                                Button { toggleRecording() } label: {
                                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                                        .font(.title3)
                                        .foregroundStyle(isRecording ? .red : .secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6), in: Capsule())
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { showingSidebar = true }
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.body)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Button { showingSettings = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "cpu.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(
                                    LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                            Text(AIService.shared.assistantName)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text("1.0")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        saveCurrentChat()
                        messages = []
                        UserDefaults.standard.removeObject(forKey: "activeChat")
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.body)
                    }
                    .accessibilityLabel("Neuer Chat")
                }
                if store.aiAllowed {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingHivemind = true
                        } label: {
                            Image(systemName: "brain.head.profile")
                                .font(.body)
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(.purple.gradient, in: Circle())
                        }
                        .accessibilityLabel("Lernen-Feed öffnen")
                    }
                }
            }
            .fullScreenCover(isPresented: $showingHivemind) {
                HivemindTab(store: store)
            }
            .sheet(isPresented: $showingBetaInfo) {
                BetaInfoView()
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingPlusSheet) {
                plusMenuSheet
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingStudyPlan) {
                StudyPlanView(store: store)
            }
            .sheet(isPresented: $showingSettings) {
                aiSettingsSheet
            }
            .sheet(isPresented: $showingContent) {
                AIContentLibrary(store: store)
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhoto, matching: .images)
            .onChange(of: selectedPhoto) { _, newValue in
                guard let item = newValue else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data),
                          let cgImage = image.cgImage else { return }

                    let text = await withCheckedContinuation { continuation in
                        let request = VNRecognizeTextRequest { request, _ in
                            let observations = request.results as? [VNRecognizedTextObservation] ?? []
                            let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                            continuation.resume(returning: text)
                        }
                        request.recognitionLevel = .accurate
                        request.recognitionLanguages = ["de-DE", "en-US"]
                        try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                    }

                    if !text.isEmpty {
                        await MainActor.run {
                            inputText = "Ich habe ein Foto von meinen Aufgaben gemacht. Hier ist der erkannte Text:\n\n\(text)\n\nBitte hilf mir damit."
                            sendMessage()
                        }
                    }
                    selectedPhoto = nil
                }
            }
            .sheet(item: $quizToPlay) { quiz in
                NavigationStack {
                    QuizPlayView(quiz: quiz)
                }
            }
            .sheet(item: $flashcardsToPlay) { set in
                NavigationStack {
                    FlashcardPlayView(cardSet: set)
                }
            }
            .onAppear {
                restoreActiveChat()
                if !BetaInfoTracker.hasSeenBeta {
                    showingBetaInfo = true
                    BetaInfoTracker.hasSeenBeta = true
                }
            }
            .sheet(isPresented: Binding(
                get: { navigateToTab != nil },
                set: { if !$0 { navigateToTab = nil } }
            )) {
                NavigationStack {
                    Group {
                        switch navigateToTab {
                        case "calendar":
                            CalendarTab(store: store)
                        case "studylog":
                            StudyLogTab(store: store)
                        case "subjects":
                            SubjectsTab(store: store)
                        default:
                            StatisticsTab(store: store)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fertig") { navigateToTab = nil }
                        }
                    }
                }
            }
            .allowsHitTesting(!showingSidebar)
        }

        // Sidebar Overlay
        if showingSidebar {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { showingSidebar = false }
                }
                .transition(.opacity)

            HStack(spacing: 0) {
                sidebarContent
                    .frame(width: UIScreen.main.bounds.width * 0.82)
                    .background(Color(.systemBackground))
                    .transition(.move(edge: .leading))

                Spacer()
            }
            .ignoresSafeArea()
        }
        } // ZStack
    }

    // MARK: - AI Settings Sheet

    private var aiSettingsSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingSettings = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingBetaInfo = true
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "cpu.fill")
                                .font(.title)
                                .foregroundStyle(.pink)
                                .frame(width: 50, height: 50)
                                .background(Color.pink.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(AIService.shared.assistantName)
                                        .font(.headline)
                                    Text("BETA")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.purple, in: Capsule())
                                }
                                Text("Version 1.0 — Powered by \(settingsProvider.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Section {
                    Picker("Anbieter", selection: $settingsProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .onChange(of: settingsProvider) { _, val in
                        AIService.shared.selectedProvider = val
                        settingsModel = AIService.shared.selectedModel
                    }
                } header: {
                    Text("KI-Anbieter")
                } footer: {
                    if settingsProvider == .backend {
                        Text("Kostenlos — kein eigener API-Key nötig. Powered by Groq.")
                    } else {
                        Text("Eigener API-Key von \(settingsProvider.displayName) erforderlich.")
                    }
                }

                if settingsProvider != .backend {
                    Section("API-Key") {
                        HStack {
                            Image(systemName: "key.fill").foregroundStyle(.orange)
                            SecureField(settingsProvider.keyPlaceholder, text: $providerKeyInput)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        if AIService.shared.apiKey(for: settingsProvider) != nil {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                Text("API-Key gespeichert")
                                Spacer()
                                Button("Entfernen") {
                                    AIService.shared.setApiKey(nil, for: settingsProvider)
                                }
                                .foregroundStyle(.red)
                                .font(.caption)
                            }
                        } else {
                            Button {
                                let trimmed = providerKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    AIService.shared.setApiKey(trimmed, for: settingsProvider)
                                    providerKeyInput = ""
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("Key speichern")
                                }
                            }
                            .disabled(providerKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }

                Section("Modell") {
                    Picker("KI-Modell", selection: $settingsModel) {
                        ForEach(settingsProvider.models, id: \.id) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                    .onChange(of: settingsModel) { _, val in AIService.shared.selectedModel = val }
                }

                Section("Sprache & Stil") {
                    Picker("Antwort-Sprache", selection: $settingsLanguage) {
                        ForEach(AIService.availableLanguages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                    .onChange(of: settingsLanguage) { _, val in AIService.shared.language = val }

                    Picker("Antwort-Stil", selection: $settingsStyle) {
                        ForEach(AIService.availableStyles, id: \.0) { style in
                            Text(style.1).tag(style.0)
                        }
                    }
                    .onChange(of: settingsStyle) { _, val in AIService.shared.responseStyle = val }
                }

                Section("Personalisierung") {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Lern-Assistent", text: $settingsName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .onChange(of: settingsName) { _, val in AIService.shared.assistantName = val }
                    }

                    Toggle("Vorschläge anzeigen", isOn: $settingsSuggestions)
                        .onChange(of: settingsSuggestions) { _, val in AIService.shared.suggestionsEnabled = val }
                }

                Section("Verlauf") {
                    Picker("Chat-Kontext", selection: $settingsHistoryLimit) {
                        Text("5 Nachrichten").tag(5)
                        Text("10 Nachrichten").tag(10)
                        Text("20 Nachrichten (Standard)").tag(20)
                        Text("50 Nachrichten").tag(50)
                    }
                    .onChange(of: settingsHistoryLimit) { _, val in AIService.shared.chatHistoryLimit = val }

                    Button(role: .destructive) {
                        showingDeleteHistory = true
                    } label: {
                        Label("Gesamten Verlauf löschen", systemImage: "trash")
                    }
                }

                Section("Datenschutz") {
                    Label("Texte werden an den KI-Anbieter (\(settingsProvider.displayName)) gesendet", systemImage: "arrow.up.right.circle")
                        .font(.caption)
                    Label("Keine persönlichen Daten übertragen", systemImage: "shield.checkered")
                        .font(.caption)
                    Label("KI kann Fehler machen", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                    Label("Minderjährige: Nur mit Eltern-Zustimmung", systemImage: "person.2")
                        .font(.caption)
                }


            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { showingSettings = false }
                }
            }
            .alert("Key entfernen?", isPresented: $showingDeleteKey) {
                Button("Abbrechen", role: .cancel) { }
                Button("Entfernen", role: .destructive) {
                    AIService.shared.setApiKey(nil, for: settingsProvider)
                    settingsProvider = .backend
                    AIService.shared.selectedProvider = .backend
                    showingSettings = false
                }
            } message: {
                Text("Der API-Key wird gelöscht. Du musst ihn erneut eingeben, um den KI-Assistenten zu nutzen.")
            }
            .alert("Verlauf löschen?", isPresented: $showingDeleteHistory) {
                Button("Abbrechen", role: .cancel) { }
                Button("Löschen", role: .destructive) {
                    ChatHistory.shared.sessions = []
                    ChatHistory.shared.save()
                }
            } message: {
                Text("Alle gespeicherten Chats werden unwiderruflich gelöscht.")
            }
        }
    }

    @State private var showingDeleteKey = false
    @State private var showingDeleteHistory = false
    @State private var settingsProvider = AIService.shared.selectedProvider
    @State private var settingsModel = AIService.shared.selectedModel
    @State private var settingsLanguage = AIService.shared.language
    @State private var settingsStyle = AIService.shared.responseStyle
    @State private var settingsName = AIService.shared.assistantName
    @State private var settingsSuggestions = AIService.shared.suggestionsEnabled
    @State private var settingsHistoryLimit = AIService.shared.chatHistoryLimit
    @State private var providerKeyInput = ""

    // MARK: - Plus Menu Sheet

    private var plusMenuSheet: some View {
        NavigationStack {
            List {
                Button {
                    showingPlusSheet = false
                    showingPhotoPicker = true
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Foto senden").font(.subheadline.bold()).foregroundStyle(.primary)
                            Text("Aufgaben fotografieren und analysieren").font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "camera.fill").foregroundStyle(.blue)
                    }
                }

                Button {
                    showingPlusSheet = false
                    showingStudyPlan = true
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lernplan erstellen").font(.subheadline.bold()).foregroundStyle(.primary)
                            Text("Foto von Aufgaben -> Lernplan").font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "doc.text.viewfinder").foregroundStyle(.pink)
                    }
                }

                Button {
                    showingPlusSheet = false
                    inputText = "Erkläre mir "
                    inputFocused = true
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Thema erklären").font(.subheadline.bold()).foregroundStyle(.primary)
                            Text("Lass dir etwas verständlich erklären").font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "lightbulb.fill").foregroundStyle(.orange)
                    }
                }

                Button {
                    showingPlusSheet = false
                    inputText = "Erstelle ein Quiz zu "
                    inputFocused = true
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quiz erstellen").font(.subheadline.bold()).foregroundStyle(.primary)
                            Text("Teste dein Wissen").font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "questionmark.circle.fill").foregroundStyle(.purple)
                    }
                }

                Button {
                    showingPlusSheet = false
                    inputText = "Fasse zusammen: "
                    inputFocused = true
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Zusammenfassung").font(.subheadline.bold()).foregroundStyle(.primary)
                            Text("Fasse Notizen zusammen").font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "doc.plaintext").foregroundStyle(.green)
                    }
                }

                Button {
                    showingPlusSheet = false
                    inputText = "Erstelle einen Lernpfad zu "
                    inputFocused = true
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lernpfad erstellen").font(.subheadline.bold()).foregroundStyle(.primary)
                            Text("Interaktiver Lernpfad mit Lektionen").font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "map.fill").foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle(AIService.shared.assistantName)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Sidebar Content

    @State private var searchText = ""
    @State private var isSearching = false

    private var filteredSessions: [ChatSession] {
        if searchText.isEmpty { return history.sessions }
        return history.sessions.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var sidebarContent: some View {
        List {
            // Header
            Section {
                HStack {
                    Text(AIService.shared.assistantName)
                        .font(.title2.bold())
                    Spacer()
                    Button {
                        isSearching = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular.interactive())
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // Suche
            if isSearching {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        TextField("Chats durchsuchen ...", text: $searchText)
                            .font(.body)
                        Button {
                            isSearching = false
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Aktionen
            Section {
                Button {
                    saveCurrentChat()
                    messages = []
                    UserDefaults.standard.removeObject(forKey: "activeChat")
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { showingSidebar = false }
                } label: {
                    Label("Neuer Chat", systemImage: "square.and.pencil")
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { showingSidebar = false }
                    showingContent = true
                } label: {
                    Label("Inhalte", systemImage: "tray.full")
                }
            }

            // Aktuelle Chats
            if !filteredSessions.isEmpty {
                Section("Aktuelle") {
                    ForEach(filteredSessions) { session in
                        Button {
                            messages = session.messages
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { showingSidebar = false }
                        } label: {
                            Text(session.title)
                                .lineLimit(1)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                history.deleteSession(session)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 20)
        }
    }

    // MARK: - Chat Bubble

    private func chatBubble(_ message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == "user" { Spacer(minLength: 60) }

            if message.role == "assistant" {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(
                        LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
                    .padding(.top, 2)
            }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 6) {
                if !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(message.text)
                        .font(.subheadline)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .foregroundStyle(message.role == "user" ? .white : .primary)
                        .background(
                            message.role == "user"
                                ? AnyShapeStyle(LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(Color(.systemGray6)),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                }

                // Quiz-Link
                if let quizId = message.quizId {
                    Button {
                        if let data = UserDefaults.standard.data(forKey: "savedQuizzes"),
                           let quizzes = try? JSONDecoder().decode([SavedQuiz].self, from: data),
                           let quiz = quizzes.first(where: { $0.id == quizId }) {
                            quizToPlay = quiz
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(.pink.gradient, in: RoundedRectangle(cornerRadius: 6))
                            Text("Quiz starten")
                                .font(.subheadline.bold())
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }

                // Karteikarten-Link
                if let setId = message.flashcardSetId {
                    Button {
                        if let data = UserDefaults.standard.data(forKey: "savedFlashcardSets"),
                           let sets = try? JSONDecoder().decode([SavedFlashcardSet].self, from: data),
                           let set = sets.first(where: { $0.id == setId }) {
                            flashcardsToPlay = set
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.on.rectangle")
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(.purple.gradient, in: RoundedRectangle(cornerRadius: 6))
                            Text("Karteikarten öffnen")
                                .font(.subheadline.bold())
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }

                // Action Results
                if let results = message.actionResults, !results.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(results) { result in
                            Button {
                                navigateToTab = result.destination
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: result.icon)
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                        .frame(width: 32, height: 32)
                                        .background(result.swiftColor.gradient, in: RoundedRectangle(cornerRadius: 8))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.title)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)
                                        Text(result.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("Öffnen")
                                        .font(.caption.bold())
                                        .foregroundStyle(result.swiftColor)
                                }
                                .padding(12)
                                .background(result.swiftColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                                .contentShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if message.role == "assistant" { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Actions

    private func sendMessage() {
        // Spracheingabe stoppen falls aktiv
        if isRecording { stopRecording() }

        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(role: "user", text: text))
        inputText = ""
        isLoading = true
        inputFocused = false

        let context = buildAppContext()

        Task {
            do {
                let response = try await AIService.shared.askWithActions(text, chatHistory: messages, context: context)
                await MainActor.run {
                    messages.append(ChatMessage(role: "assistant", text: response.text))
                    executeActions(response.actions)
                    autoSaveChat()
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    messages.append(ChatMessage(role: "assistant", text: "Fehler: \(error.localizedDescription)"))
                    isLoading = false
                }
            }
        }
    }

    private func buildAppContext() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())

        var parts: [String] = []
        parts.append("Heute: \(today)")

        // Fächer
        if !store.subjects.isEmpty {
            let faecher = store.subjects.map { $0.name }.joined(separator: ", ")
            parts.append("Fächer: \(faecher)")
        }

        // Heutige Lernzeiten
        let todaySessions = store.sessions(for: Date())
        if !todaySessions.isEmpty {
            let sessionTexts = todaySessions.map { "\($0.subject): \($0.minutes) min" }
            parts.append("Heute gelernt: \(sessionTexts.joined(separator: ", "))")
        } else {
            parts.append("Heute noch nicht gelernt")
        }

        // Aktuelle Serie
        parts.append("Aktuelle Lernserie: \(store.currentStreak()) Tage")

        // Alle Noten
        if !store.grades.isEmpty {
            let gradeTexts = store.grades.sorted { $0.date > $1.date }.map {
                "\($0.subject): \(String(format: "%.1f", $0.grade)) (\($0.type.rawValue))"
            }
            parts.append("Alle Noten: \(gradeTexts.joined(separator: ", "))")

            // Durchschnitte pro Fach
            let bySubject = Dictionary(grouping: store.grades, by: \.subject)
            let avgTexts = bySubject.map { subject, grades in
                let avg = grades.map(\.grade).reduce(0, +) / Double(grades.count)
                return "\(subject): Ø \(String(format: "%.1f", avg))"
            }
            parts.append("Notendurchschnitte: \(avgTexts.joined(separator: ", "))")
        }

        // Noten aus Klassenarbeiten
        let examGrades = store.entries.filter { $0.type == .klassenarbeit && $0.grade != nil }
        if !examGrades.isEmpty {
            let examTexts = examGrades.map { "\($0.title): \(String(format: "%.1f", $0.grade!))" }
            parts.append("Klassenarbeit-Noten: \(examTexts.joined(separator: ", "))")
        }

        // Anstehende Klassenarbeiten
        let upcoming = store.entries.filter { $0.type == .klassenarbeit && $0.date > Date() }.sorted { $0.date < $1.date }.prefix(3)
        if !upcoming.isEmpty {
            let examTexts = upcoming.map { "\($0.title) am \(dateFormatter.string(from: $0.date))" }
            parts.append("Anstehende Klassenarbeiten: \(examTexts.joined(separator: ", "))")
        }

        // Wochenlernzeit
        let weekMinutes = store.weeklyTotalMinutes(weekOffset: 0)
        parts.append("Lernzeit diese Woche: \(weekMinutes) Minuten")

        // Lernziel
        if let goal = store.studyGoal {
            if goal.dailyMinutesGoal > 0 { parts.append("Tagesziel: \(goal.dailyMinutesGoal) min") }
            if goal.weeklyMinutesGoal > 0 { parts.append("Wochenziel: \(goal.weeklyMinutesGoal) min") }
        }

        // Lern-Profil
        parts.append(LearningEngine.shared.learningContext())

        return parts.joined(separator: "\n")
    }

    private func executeActions(_ actions: [[String: Any]]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        var results: [ActionResult] = []

        for action in actions {
            guard let type = action["action"] as? String else { continue }

            switch type {
            case "add_session":
                let subject = action["subject"] as? String ?? ""
                let minutes = action["minutes"] as? Int ?? 30
                let dateStr = action["date"] as? String ?? ""
                let date = dateFormatter.date(from: dateStr) ?? Date()
                if !subject.isEmpty {
                    store.addSession(StudySession(subject: subject, date: date, minutes: minutes))
                    results.append(ActionResult(icon: "clock.fill", color: "blue", title: "Lernzeit eingetragen", detail: "\(minutes) min \(subject)", destination: "studylog"))
                }

            case "add_entry":
                let title = action["title"] as? String ?? ""
                let dateStr = action["date"] as? String ?? ""
                let date = dateFormatter.date(from: dateStr) ?? Date()
                let typeStr = action["type"] as? String ?? "lerntag"
                let eventType: EventType = typeStr == "klassenarbeit" ? .klassenarbeit : typeStr == "erinnerung" ? .erinnerung : .lerntag
                if !title.isEmpty {
                    store.addEntry(CalendarEntry(title: title, date: date, type: eventType))
                    results.append(ActionResult(icon: eventType.icon, color: typeStr == "klassenarbeit" ? "pink" : "blue", title: "Kalendereintrag erstellt", detail: title, destination: "calendar"))
                }

            case "add_grade":
                let subject = action["subject"] as? String ?? ""
                let grade = action["grade"] as? Double ?? 3.0
                let typeStr = action["type"] as? String ?? "schriftlich"
                let gradeType: GradeType = typeStr == "muendlich" ? .muendlich : .schriftlich
                if !subject.isEmpty {
                    store.addGrade(Grade(subject: subject, grade: grade, date: Date(), type: gradeType))
                    results.append(ActionResult(icon: "graduationcap.fill", color: "orange", title: "Note eingetragen", detail: "\(subject): \(String(format: "%.1f", grade))", destination: "grades"))
                }

            case "create_quiz":
                let subject = action["subject"] as? String ?? ""
                let topic = action["topic"] as? String ?? ""
                if !subject.isEmpty && !topic.isEmpty {
                    Task {
                        if let questions = try? await AIService.shared.generateQuiz(subject: subject, topic: topic) {
                            let quiz = SavedQuiz(title: "\(subject): \(topic)", subject: subject, questions: questions)
                            // Speichern
                            var quizzes: [SavedQuiz] = []
                            if let data = UserDefaults.standard.data(forKey: "savedQuizzes"),
                               let decoded = try? JSONDecoder().decode([SavedQuiz].self, from: data) {
                                quizzes = decoded
                            }
                            quizzes.insert(quiz, at: 0)
                            if let newData = try? JSONEncoder().encode(quizzes) {
                                UserDefaults.standard.set(newData, forKey: "savedQuizzes")
                            }
                            // Link an letzte Nachricht anhängen
                            await MainActor.run {
                                if var last = messages.last, last.role == "assistant" {
                                    messages.removeLast()
                                    last.quizId = quiz.id
                                    messages.append(last)
                                } else {
                                    var linkMsg = ChatMessage(role: "assistant", text: "Quiz erstellt!")
                                    linkMsg.quizId = quiz.id
                                    messages.append(linkMsg)
                                }
                                autoSaveChat()
                            }
                        }
                    }
                }

            case "create_flashcards":
                let subject = action["subject"] as? String ?? ""
                let topic = action["topic"] as? String ?? ""
                if !subject.isEmpty && !topic.isEmpty {
                    Task {
                        if let cards = try? await AIService.shared.generateFlashcards(subject: subject, topic: topic) {
                            let set = SavedFlashcardSet(title: "\(subject): \(topic)", subject: subject, cards: cards)
                            // Speichern
                            var sets: [SavedFlashcardSet] = []
                            if let data = UserDefaults.standard.data(forKey: "savedFlashcardSets"),
                               let decoded = try? JSONDecoder().decode([SavedFlashcardSet].self, from: data) {
                                sets = decoded
                            }
                            sets.insert(set, at: 0)
                            if let newData = try? JSONEncoder().encode(sets) {
                                UserDefaults.standard.set(newData, forKey: "savedFlashcardSets")
                            }
                            // Link an letzte Nachricht anhängen
                            await MainActor.run {
                                if var last = messages.last, last.role == "assistant" {
                                    messages.removeLast()
                                    last.flashcardSetId = set.id
                                    messages.append(last)
                                } else {
                                    var linkMsg = ChatMessage(role: "assistant", text: "Karteikarten erstellt!")
                                    linkMsg.flashcardSetId = set.id
                                    messages.append(linkMsg)
                                }
                                autoSaveChat()
                            }
                        }
                    }
                }

            case "add_subject":
                let name = action["name"] as? String ?? ""
                let icon = action["icon"] as? String ?? "book.fill"
                let color = action["color"] as? String ?? "blue"
                if !name.isEmpty && !store.subjects.contains(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                    store.addSubject(Subject(name: name, icon: icon, colorName: color))
                    results.append(ActionResult(icon: icon, color: color, title: "Fach erstellt", detail: name, destination: "subjects"))
                }

            case "create_topic":
                let subject = action["subject"] as? String ?? ""
                let topic = action["topic"] as? String ?? ""
                if !topic.isEmpty {
                    let newTopic = Topic(
                        title: topic,
                        subject: subject.isEmpty ? nil : subject,
                        iconName: "sparkles",
                        colorHex: "#7C3AED",
                        source: .manual(prompt: "Erstellt aus KI-Chat: \(topic)")
                    )
                    TopicStore.shared.addTopic(newTopic)
                    results.append(ActionResult(icon: "brain.head.profile", color: "purple", title: "Topic erstellt", detail: topic, destination: "hivemind"))
                }

            default:
                break
            }
        }

        // Action Results an letzte Nachricht anhängen
        if !results.isEmpty, var last = messages.last, last.role == "assistant" {
            messages.removeLast()
            last.actionResults = (last.actionResults ?? []) + results
            messages.append(last)
        }
    }

    private func saveCurrentChat() {
        guard !messages.isEmpty else { return }
        let title = messages.first(where: { $0.role == "user" })?.text.prefix(40).description ?? "Chat"
        let session = ChatSession(title: String(title), messages: messages)
        history.addSession(session)
    }

    private func autoSaveChat() {
        guard !messages.isEmpty else { return }
        // Aktuellen Chat als "aktiv" speichern
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: "activeChat")
        }
    }

    private func restoreActiveChat() {
        if let data = UserDefaults.standard.data(forKey: "activeChat"),
           let restored = try? JSONDecoder().decode([ChatMessage].self, from: data),
           !restored.isEmpty {
            messages = restored
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.finish()
        recognitionTask = nil
        isRecording = false
    }

    private func startRecording() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else { return }

                let audioSession = AVAudioSession.sharedInstance()
                try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = true
                request.addsPunctuation = true

                let inputNode = self.audioEngine.inputNode
                let format = inputNode.outputFormat(forBus: 0)
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                    request.append(buffer)
                }

                self.audioEngine.prepare()
                try? self.audioEngine.start()
                self.isRecording = true

                self.recognitionTask = self.speechRecognizer?.recognitionTask(with: request) { result, error in
                    DispatchQueue.main.async {
                        if let result {
                            self.inputText = result.bestTranscription.formattedString
                        }
                        if error != nil || (result?.isFinal ?? false) {
                            self.stopRecording()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var dot1 = false
    @State private var dot2 = false
    @State private var dot3 = false

    var body: some View {
        HStack(spacing: 4) {
            Circle().frame(width: 8, height: 8).opacity(dot1 ? 1 : 0.3)
            Circle().frame(width: 8, height: 8).opacity(dot2 ? 1 : 0.3)
            Circle().frame(width: 8, height: 8).opacity(dot3 ? 1 : 0.3)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) { dot1 = true }
            withAnimation(.easeInOut(duration: 0.5).repeatForever().delay(0.2)) { dot2 = true }
            withAnimation(.easeInOut(duration: 0.5).repeatForever().delay(0.4)) { dot3 = true }
        }
    }
}

// MARK: - Setup View

struct AISetupView: View {
    var store: DataStore
    @State private var apiKey = ""
    @State private var acceptedTerms = false
    @State private var showingPrivacy = false
    @State private var showingKeyInfo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero
                    ZStack {
                        AnimatedGradientBackground()
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 24))

                        VStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 44))
                                .foregroundStyle(.white)
                                .shadow(radius: 10)
                            Text("KI-Lernassistent")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("Dein persönlicher Lernhelfer")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    .padding(.horizontal)

                    // Features
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        setupCard(icon: "doc.text.viewfinder", title: "Lernpläne", color: .pink)
                        setupCard(icon: "lightbulb.fill", title: "Erklärungen", color: .orange)
                        setupCard(icon: "questionmark.circle.fill", title: "Quiz", color: .purple)
                        setupCard(icon: "doc.plaintext", title: "Zusammenfassung", color: .pink)
                    }
                    .padding(.horizontal)

                    // Datenschutz
                    Button { withAnimation { showingPrivacy.toggle() } } label: {
                        HStack {
                            Image(systemName: "shield.checkered").foregroundStyle(.purple)
                            Text("Datenschutz & Nutzung").font(.subheadline.bold())
                            Spacer()
                            Image(systemName: showingPrivacy ? "chevron.up" : "chevron.down")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    if showingPrivacy {
                        VStack(alignment: .leading, spacing: 6) {
                            privacyRow("Texte werden zur Verarbeitung an Groq gesendet")
                            privacyRow("Keine persönlichen Daten — nur Aufgabentexte")
                            privacyRow("Groq speichert keine Daten der kostenlosen Stufe")
                            privacyRow("KI kann Fehler machen — immer selbst prüfen")
                            privacyRow("Minderjährige: Nur mit Zustimmung der Eltern")
                        }
                        .padding(.horizontal, 24)
                    }

                    Toggle(isOn: $acceptedTerms) {
                        Text("Ich stimme den Datenschutzhinweisen zu").font(.subheadline)
                    }
                    .tint(.pink)
                    .padding(.horizontal)

                    if acceptedTerms {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "key.fill").foregroundStyle(.orange)
                                SecureField("Groq API-Key einfügen", text: $apiKey)
                                    .autocorrectionDisabled()
                            }
                            .padding(14)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))

                            Button {
                                let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    AIService.shared.apiKey = trimmed
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    Image(systemName: "sparkles")
                                    Text("Starten").font(.headline)
                                    Spacer()
                                }
                                .padding(.vertical, 14)
                                .foregroundStyle(.white)
                                .background(
                                    apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.pink,
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 14))

                            Button { withAnimation { showingKeyInfo.toggle() } } label: {
                                HStack {
                                    Image(systemName: "questionmark.circle")
                                    Text("Wo bekomme ich einen Key?").font(.caption)
                                }.foregroundStyle(.purple)
                            }

                            if showingKeyInfo {
                                VStack(alignment: .leading, spacing: 6) {
                                    keyStep("1", "Öffne console.groq.com")
                                    keyStep("2", "Melde dich mit Google an")
                                    keyStep("3", "Klicke auf \"API Keys\"")
                                    keyStep("4", "Erstelle einen neuen Key")
                                    keyStep("5", "Kopiere & füge ihn oben ein")
                                    Text("Komplett kostenlos!")
                                        .font(.caption).foregroundStyle(.green).padding(.leading, 28)
                                }
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 30)
                }
                .padding(.top, 8)
                .animation(.easeInOut(duration: 0.3), value: acceptedTerms)
            }
            .navigationTitle("KI-Assistent")
        }
    }

    private func setupCard(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(title).font(.caption.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
    }

    private func privacyRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "checkmark.shield.fill").font(.caption2).foregroundStyle(.purple)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func keyStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number).font(.caption.bold()).foregroundStyle(.white)
                .frame(width: 20, height: 20).background(.pink, in: Circle())
            Text(text).font(.caption)
        }
    }
}

// MARK: - Animated Gradient Background

struct AnimatedGradientBackground: View {
    @State private var move = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.05)

                Circle()
                    .fill(.pink)
                    .frame(width: geo.size.width * 0.7)
                    .blur(radius: 50)
                    .offset(
                        x: move ? geo.size.width * 0.2 : -geo.size.width * 0.2,
                        y: move ? -20 : 20
                    )

                Circle()
                    .fill(.orange)
                    .frame(width: geo.size.width * 0.6)
                    .blur(radius: 50)
                    .offset(
                        x: move ? -geo.size.width * 0.15 : geo.size.width * 0.15,
                        y: move ? 30 : -30
                    )

                Circle()
                    .fill(.purple)
                    .frame(width: geo.size.width * 0.65)
                    .blur(radius: 50)
                    .offset(
                        x: move ? geo.size.width * 0.1 : -geo.size.width * 0.1,
                        y: move ? -10 : 25
                    )
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                    move = true
                }
            }
        }
    }
}
