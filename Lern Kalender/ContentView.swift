import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    @State private var store = DataStore()
    @State private var showWrapped = false
    @State private var wrappedIsHalbjahr = false
    @State private var wrappedSchoolYear: SchoolYear?
    @State private var showingMotivation = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if store.appMode == .parent {
                parentView
            } else {
                studentView
            }
        }
    }

    // MARK: - Parent View

    @ViewBuilder
    private var parentView: some View {
        if horizontalSizeClass == .regular {
            // iPad: Sidebar
            NavigationSplitView {
                List {
                    NavigationLink {
                        ParentDashboardView(store: store)
                    } label: {
                        Label("Dashboard", systemImage: "chart.bar.fill")
                    }
                    NavigationLink {
                        ParentSettingsTab(store: store)
                    } label: {
                        Label("Einstellungen", systemImage: "gearshape.fill")
                    }
                }
                .navigationTitle("Lern Kalender")
            } detail: {
                ParentDashboardView(store: store)
            }
        } else {
            // iPhone: TabView
            TabView {
                ParentDashboardView(store: store)
                    .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
                ParentSettingsTab(store: store)
                    .tabItem { Label("Einstellungen", systemImage: "gearshape.fill") }
            }
        }
    }

    // MARK: - Student View

    @ViewBuilder
    private var studentView: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad: Sidebar
                NavigationSplitView {
                    List {
                        NavigationLink {
                            CalendarTab(store: store)
                        } label: {
                            Label("Kalender", systemImage: "calendar")
                        }
                        NavigationLink {
                            SubjectsTab(store: store)
                        } label: {
                            Label("Fächer", systemImage: "book.fill")
                        }
                        NavigationLink {
                            StudyLogTab(store: store)
                        } label: {
                            Label("Lernzeit", systemImage: "clock.fill")
                        }
                        NavigationLink {
                            AIAssistantTab(store: store)
                        } label: {
                            Label("KI", systemImage: "sparkles")
                        }
                        NavigationLink {
                            HivemindTab(store: store)
                        } label: {
                            Label("Lernen", systemImage: "brain.head.profile")
                        }
                        NavigationLink {
                            StatisticsTab(store: store)
                        } label: {
                            Label("Statistik", systemImage: "chart.bar.fill")
                        }
                    }
                    .navigationTitle("Lern Kalender")
                } detail: {
                    CalendarTab(store: store)
                }
            } else {
                // iPhone: TabView
                TabView {
                    CalendarTab(store: store)
                        .tabItem { Label("Kalender", systemImage: "calendar") }
                    SubjectsTab(store: store)
                        .tabItem { Label("Fächer", systemImage: "book.fill") }
                    StudyLogTab(store: store)
                        .tabItem { Label("Lernzeit", systemImage: "clock.fill") }
                    AIAssistantTab(store: store)
                        .tabItem { Label("KI", systemImage: "sparkles") }
                    HivemindTab(store: store)
                        .tabItem { Label("Lernen", systemImage: "brain.head.profile") }
                    StatisticsTab(store: store)
                        .tabItem { Label("Statistik", systemImage: "chart.bar.fill") }
                }
            }
        }
        .onAppear {
            NotificationHelper.requestPermission()
            // Kind-Daten beim Start zu CloudKit synchen
            store.syncToCloudIfNeeded()
            if let link = store.familyLink, link.isActive {
                Task {
                    if let goal = await CloudKitService.shared.fetchStudyGoal(pairingCode: link.pairingCode) {
                        await MainActor.run { store.studyGoal = goal }
                    }
                }
            }
            // Motivations-Nachricht laden (nur neue anzeigen)
            if let link = store.familyLink, link.isActive {
                Task {
                    if let msg = await CloudKitService.shared.fetchMotivationMessage(pairingCode: link.pairingCode) {
                        let lastSeenId = UserDefaults.standard.string(forKey: "lastSeenMotivationId")
                        if lastSeenId != msg.id.uuidString {
                            await MainActor.run { store.motivationMessage = msg }
                        }
                    }
                }
            }
            // Shared calendar entries laden
            if let link = store.familyLink, link.isActive {
                Task {
                    let shared = await CloudKitService.shared.fetchSharedCalendarEntries(pairingCode: link.pairingCode)
                    await MainActor.run { store.sharedCalendarEntries = shared }
                }
            }
            // Hivemind: pull parent-assigned topics
            if let link = store.familyLink, link.isActive {
                Task {
                    let (remoteTopics, remoteProgress) = await CloudKitService.shared.fetchTopics(pairingCode: link.pairingCode)
                    await MainActor.run {
                        TopicStore.shared.mergeRemote(topics: remoteTopics, progress: remoteProgress)
                    }
                }
            }
            // Lern-Wrapped automatisch anzeigen
            if let trigger = WrappedTrigger.shouldShowWrapped(store: store) {
                wrappedSchoolYear = trigger.schoolYear
                wrappedIsHalbjahr = trigger.isHalbjahr
                showWrapped = true
                WrappedTrigger.markAsShown(store: store, isHalbjahr: trigger.isHalbjahr)
            }
        }
        .fullScreenCover(isPresented: $showWrapped) {
            LernWrappedView(store: store, schoolYear: wrappedSchoolYear, isHalbjahr: wrappedIsHalbjahr)
        }
        .overlay(alignment: .top) {
            if showingMotivation, let msg = store.motivationMessage {
                HStack(spacing: 12) {
                    Text(msg.text)
                        .font(.system(size: 50))
                    Text("Von deinen Eltern")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture {
                    dismissMotivation()
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        dismissMotivation()
                    }
                }
            }
        }
        .onChange(of: store.motivationMessage) { _, newValue in
            if newValue != nil {
                withAnimation { showingMotivation = true }
            }
        }
    }

    private func dismissMotivation() {
        if let msg = store.motivationMessage {
            UserDefaults.standard.set(msg.id.uuidString, forKey: "lastSeenMotivationId")
        }
        withAnimation { showingMotivation = false }
        store.motivationMessage = nil
    }
}

// MARK: - Parent Settings Tab

struct ParentSettingsTab: View {
    var store: DataStore
    @State private var showingLeaveAlert = false
    @State private var showingAddChild = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Verbundene Kinder") {
                    if store.familyLinks.isEmpty {
                        Text("Keine Kinder verbunden")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.familyLinks) { link in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(link.childName.isEmpty ? "Kind" : link.childName)
                                        .font(.headline)
                                    Text("Code: \(link.pairingCode)")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .onDelete { offsets in
                            store.familyLinks.remove(atOffsets: offsets)
                            if store.familyLinks.isEmpty {
                                store.appMode = nil
                            }
                        }
                    }

                    Button {
                        showingAddChild = true
                    } label: {
                        Label("Kind hinzufügen", systemImage: "plus.circle")
                    }
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { store.aiAllowed },
                        set: { store.aiAllowed = $0 }
                    )) {
                        Label("KI-Assistent erlauben", systemImage: "sparkles")
                    }
                } header: {
                    Text("KI-Assistent")
                } footer: {
                    Text("Erlaubt dem Kind den KI-Lernassistenten zu nutzen. Standardmäßig aktiviert.")
                }

                Section {
                    Button(role: .destructive) {
                        showingLeaveAlert = true
                    } label: {
                        Label("Elternmodus verlassen", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } footer: {
                    Text("Du wirst zur normalen Ansicht zurückgeleitet. Verbindungen bleiben bestehen.")
                }
            }
            .navigationTitle("Einstellungen")
            .sheet(isPresented: $showingAddChild) {
                ParentPairingView(store: store)
            }
            .alert("Elternmodus verlassen?", isPresented: $showingLeaveAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Verlassen", role: .destructive) {
                    store.familyLinks = []
                    store.familyLink = nil
                    store.appMode = nil
                    store.studyGoals = [:]
                }
            } message: {
                Text("Möchtest du den Elternmodus wirklich verlassen? Alle Verbindungen werden getrennt.")
            }
        }
    }
}

#Preview { ContentView() }
