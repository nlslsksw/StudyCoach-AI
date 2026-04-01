import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    @State private var store = DataStore()
    @State private var showWrapped = false
    @State private var wrappedIsHalbjahr = false
    @State private var wrappedSchoolYear: SchoolYear?
    @State private var showingMotivation = false

    var body: some View {
        Group {
            if store.appMode == .parent {
                TabView {
                    ParentDashboardView(store: store)
                        .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
                    ParentSettingsTab(store: store)
                        .tabItem { Label("Einstellungen", systemImage: "gearshape.fill") }
                }
            } else {
                TabView {
                    CalendarTab(store: store)
                        .tabItem { Label("Kalender", systemImage: "calendar") }
                    SubjectsTab(store: store)
                        .tabItem { Label("Fächer", systemImage: "book.fill") }
                    StudyLogTab(store: store)
                        .tabItem { Label("Lernzeit", systemImage: "clock.fill") }
                    StatisticsTab(store: store)
                        .tabItem { Label("Statistik", systemImage: "chart.bar.fill") }
                }
                .onAppear {
                    NotificationHelper.requestPermission()
                    if let link = store.familyLink, link.isActive {
                        Task {
                            if let goal = await CloudKitService.shared.fetchStudyGoal(pairingCode: link.pairingCode) {
                                await MainActor.run { store.studyGoal = goal }
                            }
                        }
                    }
                    // Motivations-Nachricht laden
                    if let link = store.familyLink, link.isActive {
                        Task {
                            if let msg = await CloudKitService.shared.fetchMotivationMessage(pairingCode: link.pairingCode) {
                                if store.motivationMessage == nil || store.motivationMessage?.text != msg.text {
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
                .alert("Nachricht von deinen Eltern", isPresented: $showingMotivation) {
                    Button("OK") {
                        store.motivationMessage = nil
                    }
                } message: {
                    Text(store.motivationMessage?.text ?? "")
                }
                .onChange(of: store.motivationMessage) { _, newValue in
                    if newValue != nil { showingMotivation = true }
                }
            }
        }
    }
}

// MARK: - Parent Settings Tab

struct ParentSettingsTab: View {
    var store: DataStore

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
                }

                Section {
                    Button(role: .destructive) {
                        store.familyLinks = []
                        store.familyLink = nil
                        store.appMode = nil
                        store.studyGoals = [:]
                    } label: {
                        Label("Alle Verbindungen trennen", systemImage: "xmark.circle")
                    }
                }
            }
            .navigationTitle("Einstellungen")
        }
    }
}

#Preview { ContentView() }
