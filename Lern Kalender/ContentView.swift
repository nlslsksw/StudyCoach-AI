import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    @State private var store = DataStore()
    @State private var showWrapped = false
    @State private var wrappedIsHalbjahr = false
    @State private var wrappedSchoolYear: SchoolYear?
    @State private var showingMotivation = false
    @State private var showingOnboarding = !OnboardingTracker.hasCompleted
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if store.appMode == .parent {
                parentView
            } else {
                studentView
            }
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView()
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
                            TodayTab(store: store)
                        } label: {
                            Label("Heute", systemImage: "sun.max.fill")
                        }
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
                            StatisticsTab(store: store)
                        } label: {
                            Label("Statistik", systemImage: "chart.bar.fill")
                        }
                    }
                    .navigationTitle("Lern Kalender")
                } detail: {
                    TodayTab(store: store)
                }
            } else {
                // iPhone: TabView
                TabView {
                    TodayTab(store: store)
                        .tabItem { Label("Heute", systemImage: "sun.max.fill") }
                    CalendarTab(store: store)
                        .tabItem { Label("Kalender", systemImage: "calendar") }
                    SubjectsTab(store: store)
                        .tabItem { Label("Fächer", systemImage: "book.fill") }
                    StatisticsTab(store: store)
                        .tabItem { Label("Statistik", systemImage: "chart.bar.fill") }
                }
            }
        }
        .onAppear(perform: handleStudentAppear)
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

    // MARK: - Setup-Helpers (entschlackt aus onAppear)

    private func handleStudentAppear() {
        NotificationHelper.requestPermission()
        NotificationHelper.refreshDailyReminder()
        store.recomputeAndConsumeFreezes()
        runMotivationCleanupMigration()
        store.syncToCloudIfNeeded()
        if let link = store.familyLink, link.isActive {
            loadCloudKitData(for: link)
        }
        triggerWrappedIfDue()
    }

    /// Einmalige Migration: alte stale Motivation-Nachricht entsorgen.
    /// Vor dem Fix hatte jede gefetchte Nachricht eine neue UUID — der id-basierte
    /// lastSeen-Vergleich passte nie, dadurch poppte die alte Nachricht jedes
    /// Mal wieder auf.
    private func runMotivationCleanupMigration() {
        let key = "motivationCleanupV2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastSeenMotivationDate")
        store.motivationMessage = nil
        UserDefaults.standard.set(true, forKey: key)
    }

    private func loadCloudKitData(for link: FamilyLink) {
        Task {
            if let goal = await CloudKitService.shared.fetchStudyGoal(pairingCode: link.pairingCode) {
                await MainActor.run { store.studyGoal = goal }
            }
        }
        // Motivations-Nachricht: Vergleich über `date`, `lastSeen` wird sofort
        // beim Anzeigen gesetzt — auch wenn die App vor Dismiss geschlossen wird.
        Task {
            if let msg = await CloudKitService.shared.fetchMotivationMessage(pairingCode: link.pairingCode) {
                let lastSeen = UserDefaults.standard.double(forKey: "lastSeenMotivationDate")
                if msg.date.timeIntervalSince1970 > lastSeen {
                    UserDefaults.standard.set(msg.date.timeIntervalSince1970, forKey: "lastSeenMotivationDate")
                    await MainActor.run { store.motivationMessage = msg }
                }
            }
        }
        Task {
            let shared = await CloudKitService.shared.fetchSharedCalendarEntries(pairingCode: link.pairingCode)
            await MainActor.run { store.sharedCalendarEntries = shared }
        }
        Task {
            let (remoteTopics, remoteProgress) = await CloudKitService.shared.fetchTopics(pairingCode: link.pairingCode)
            await MainActor.run {
                TopicStore.shared.mergeRemote(topics: remoteTopics, progress: remoteProgress)
            }
        }
        Task {
            if let allowed = await CloudKitService.shared.fetchAIAllowed(pairingCode: link.pairingCode) {
                await MainActor.run { store.aiAllowed = allowed }
            }
        }
    }

    private func triggerWrappedIfDue() {
        if let trigger = WrappedTrigger.shouldShowWrapped(store: store) {
            wrappedSchoolYear = trigger.schoolYear
            wrappedIsHalbjahr = trigger.isHalbjahr
            showWrapped = true
            WrappedTrigger.markAsShown(store: store, isHalbjahr: trigger.isHalbjahr)
        }
    }

    private func dismissMotivation() {
        if let msg = store.motivationMessage {
            UserDefaults.standard.set(msg.date.timeIntervalSince1970, forKey: "lastSeenMotivationDate")
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

// MARK: - Today Tab (Dashboard)

/// Startseite mit Streak, heutiger Lernzeit, anstehenden Terminen und Quick-Actions.
/// Ersetzt den separaten "Lernzeit"-Tab und den "KI"-Tab.
struct TodayTab: View {
    var store: DataStore

    @State private var showingAddSession = false
    @State private var showingTimer = false
    @State private var showingAllSessions = false
    @State private var showingAI = false
    @State private var showingSettings = false
    @State private var showingProfile = false

    private var today: Date { Date() }
    private var todaySessions: [StudySession] { store.sessions(for: today) }
    private var todayMinutes: Int { store.totalMinutes(in: todaySessions) }
    private var todayEntries: [CalendarEntry] { store.entries(for: today) }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "Guten Morgen"
        case 11..<14: return "Hallo"
        case 14..<18: return "Guten Tag"
        default: return "Guten Abend"
        }
    }

    private var todayString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE, d. MMMM"
        return f.string(from: today)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Streak + Eis
                    HStack(spacing: 12) {
                        StreakCard(
                            title: "Aktuelle Serie",
                            value: store.currentStreak(),
                            icon: "flame.fill",
                            color: .orange,
                            freezeCount: store.streakState.freezeCount
                        )
                    }
                    .padding(.horizontal)

                    // Heutige Lernzeit
                    todayStudyCard
                        .padding(.horizontal)

                    // Quick-Actions
                    quickActionsRow
                        .padding(.horizontal)

                    // Anstehende Termine heute
                    if !todayEntries.isEmpty {
                        todayEntriesSection
                            .padding(.horizontal)
                    }

                    // Lernziel (falls gesetzt)
                    if let goal = store.studyGoal, goal.dailyMinutesGoal > 0 || goal.weeklyMinutesGoal > 0 {
                        GoalProgressView(store: store)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top, 4)
            }
            .navigationTitle(greeting)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(todayString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingAddSession) {
                AddStudySessionView(initialDate: Date(), store: store)
            }
            .fullScreenCover(isPresented: $showingTimer) {
                StudyTimerView(store: store)
            }
            .sheet(isPresented: $showingAllSessions) {
                NavigationStack {
                    StudyLogTab(store: store)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Fertig") { showingAllSessions = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingAI) {
                AIAssistantTab(store: store)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(store: store)
            }
        }
    }

    private var todayStudyCard: some View {
        Button {
            showingAllSessions = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "clock.fill")
                    .font(.title)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(formatHoursMinutes(todayMinutes))
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(.primary)
                    Text(todaySessions.isEmpty ? "Heute noch nichts gelernt" : "Heute gelernt · \(todaySessions.count) \(todaySessions.count == 1 ? "Eintrag" : "Einträge")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var quickActionsRow: some View {
        HStack(spacing: 10) {
            quickActionTile(icon: "plus.circle.fill", title: "Eintragen", color: .blue) {
                showingAddSession = true
            }
            quickActionTile(icon: "timer", title: "Timer", color: .green) {
                showingTimer = true
            }
            if store.aiAllowed {
                quickActionTile(icon: "sparkles", title: "KI", color: .purple) {
                    showingAI = true
                }
            }
        }
    }

    private func quickActionTile(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var todayEntriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heute fällig")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(todayEntries.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.type.icon)
                            .font(.subheadline)
                            .foregroundStyle(entry.type.color)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.subheadline.bold())
                            Text(entry.type.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if entry.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    if index < todayEntries.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
