import SwiftUI
import PhotosUI
import QuickLook
import UniformTypeIdentifiers
import Pow

// MARK: - ContentView

struct ContentView: View {
    @State private var store = DataStore()
    @State private var showWrapped = false
    @State private var wrappedIsHalbjahr = false
    @State private var wrappedSchoolYear: SchoolYear?
    @State private var showingMotivation = false
    @State private var showingOnboarding = !OnboardingTracker.hasCompleted
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var currentTheme: AppTheme = ThemeStore.current
    @State private var currentAccent: AppAccent = ThemeStore.accent

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
        .preferredColorScheme(currentTheme.colorScheme)
        .tint(currentAccent.color)
        .background(currentTheme == .amoled ? Color.black : Color.clear)
        .onReceive(NotificationCenter.default.publisher(for: .appThemeChanged)) { _ in
            currentTheme = ThemeStore.current
            currentAccent = ThemeStore.accent
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
        triggerWebuntisAutoSyncIfDue()
    }

    /// Synchronisiert mit Webuntis im Hintergrund, wenn die App gestartet
    /// wird und der letzte Sync mehr als 60 Minuten her ist (Throttle).
    private func triggerWebuntisAutoSyncIfDue() {
        guard WebuntisService.shared.isConfigured else { return }
        let last = WebuntisService.shared.lastSync ?? .distantPast
        if Date().timeIntervalSince(last) < 60 * 60 { return }
        Task { await WebuntisService.shared.sync(into: store) }
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
    @State private var showingAddHomework = false
    @State private var showingAllHomework = false
    @State private var homeworkToEdit: Homework? = nil
    @State private var showingTimetable = false

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
                VStack(spacing: AppSpacing.lg) {
                    heroHeader
                        .padding(.horizontal)
                        .padding(.top, AppSpacing.sm)
                        .tiltCard()

                    // Stimmung des Tages
                    moodPicker
                        .padding(.horizontal)

                    // Streak-Karte
                    StreakCard(
                        title: "Aktuelle Serie",
                        value: store.currentStreak(),
                        icon: "flame.fill",
                        color: .orange,
                        freezeCount: store.streakState.freezeCount
                    )
                    .padding(.horizontal)

                    // Quick-Actions
                    quickActionsRow
                        .padding(.horizontal)

                    // Stundenplan heute
                    timetableTodaySection
                        .padding(.horizontal)

                    // Hausaufgaben
                    if !store.homework.isEmpty || !store.openHomework().isEmpty {
                        homeworkSection
                            .padding(.horizontal)
                    }

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

                    Spacer(minLength: 24)
                }
                .padding(.top, 4)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Heute").font(.headline)
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
            .sheet(isPresented: $showingAddHomework) {
                AddHomeworkView(store: store)
            }
            .sheet(item: $homeworkToEdit) { hw in
                AddHomeworkView(store: store, editing: hw)
            }
            .sheet(isPresented: $showingAllHomework) {
                NavigationStack {
                    HomeworkListView(store: store)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Fertig") { showingAllHomework = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingTimetable) {
                TimetableView(store: store)
            }
        }
    }

    /// Hero-Header oben im Today-Tab: Gradient-Card mit Begrüßung, Datum
    /// und heutiger Lernzeit. Tap öffnet die ausführliche Lernzeit-Liste.
    private var heroHeader: some View {
        let gradientColors: [Color] = [Color.blue, Color.purple, Color.indigo]
        return Button {
            showingAllSessions = true
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(greeting)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(todayString)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Spacer()
                    Image(systemName: "sun.max.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    AnimatedNumber(value: todayMinutes,
                                   font: .system(size: 44, weight: .bold, design: .rounded),
                                   color: .white)
                    Text("min")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(todaySessions.isEmpty ? "Heute noch nichts" : "\(todaySessions.count) \(todaySessions.count == 1 ? "Eintrag" : "Einträge")")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                        if todayMinutes > 0 {
                            Text(formatHoursMinutes(todayMinutes))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                }
            }
            .appHeroCard(gradientColors)
            // Shine-Sweep läuft einmal beim Erscheinen UND wenn sich die
            // Lernzeit ändert (z.B. neuer Eintrag).
            .changeEffect(.shine.delay(0.3), value: heroAppearTrigger)
            .changeEffect(.shine.delay(0.1), value: todayMinutes)
        }
        .buttonStyle(.plain)
        .onAppear { heroAppearTrigger += 1 }
    }

    private var quickActionsRow: some View {
        HStack(spacing: 10) {
            quickActionTile(icon: "plus.circle.fill", title: "Eintragen", color: .blue) {
                showingAddSession = true
            }
            quickActionTile(icon: "timer", title: "Timer", color: .green) {
                showingTimer = true
            }
            quickActionTile(icon: "checklist", title: "HA", color: .orange) {
                showingAddHomework = true
            }
            if store.aiAllowed {
                quickActionTile(icon: "sparkles", title: "KI", color: .purple) {
                    showingAI = true
                }
            }
        }
    }

    @State private var quickActionTapCounters: [String: Int] = [:]
    @State private var heroAppearTrigger: Int = 0
    @State private var todayMood: Mood? = MoodStore.mood(for: Date())

    private func quickActionTile(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            quickActionTapCounters[title, default: 0] += 1
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        LinearGradient(colors: [color, color.opacity(0.8)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                    // Spray + Pulse beim Tippen — fühlt sich klickig an.
                    .changeEffect(
                        .spray(origin: UnitPoint(x: 0.5, y: 0.5)) {
                            Image(systemName: icon).foregroundStyle(color)
                        },
                        value: quickActionTapCounters[title, default: 0]
                    )
                    .changeEffect(
                        .pulse(shape: RoundedRectangle(cornerRadius: 11, style: .continuous),
                               drawingMode: .stroke, count: 1),
                        value: quickActionTapCounters[title, default: 0]
                    )
                    .changeEffect(.feedback(hapticImpact: .light),
                                  value: quickActionTapCounters[title, default: 0])
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
            )
        }
        .buttonStyle(QuickActionButtonStyle())
    }

    private var moodPicker: some View {
        HStack(spacing: 6) {
            ForEach(Mood.allCases) { mood in
                Button {
                    todayMood = mood
                    MoodStore.set(mood, for: Date())
                } label: {
                    VStack(spacing: 2) {
                        Text(mood.emoji)
                            .font(.title3)
                            .scaleEffect(todayMood == mood ? 1.25 : 1.0)
                        if todayMood == mood {
                            Text(mood.label)
                                .font(.caption2.bold())
                                .foregroundStyle(mood.color)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        todayMood == mood
                        ? AnyShapeStyle(mood.color.opacity(0.18))
                        : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(todayMood == mood ? mood.color : Color.clear, lineWidth: 1.5)
                    )
                    .animation(AppAnimation.snappy, value: todayMood)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Sanftes Tap-Feedback für Quick-Action-Tiles.
    private struct QuickActionButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                .animation(AppAnimation.snappy, value: configuration.isPressed)
        }
    }

    private var timetableTodaySection: some View {
        let slots = store.todaySlots()
        let visible = Array(slots.prefix(4))
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Stundenplan heute")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                if slots.count > visible.count {
                    Text("\(slots.count - visible.count) weitere")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button {
                    showingTimetable = true
                } label: {
                    Text(slots.isEmpty ? "Pflegen" : "Woche")
                        .font(.caption.bold())
                }
            }
            .padding(.horizontal, 4)

            if visible.isEmpty {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.tertiary)
                    Text("Kein Stundenplan für heute. Tippe „Pflegen“, um Stunden anzulegen.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                )
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { idx, slot in
                        TimetableSlotRow(store: store, slot: slot, compact: true)
                        if idx < visible.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                )
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            }
        }
    }

    private var homeworkSection: some View {
        let open = store.openHomework()
        let visible = Array(open.prefix(5))
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Hausaufgaben")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                if open.count > visible.count {
                    Text("\(open.count - visible.count) weitere")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button {
                    showingAllHomework = true
                } label: {
                    Text("Alle")
                        .font(.caption.bold())
                }
            }
            .padding(.horizontal, 4)

            if visible.isEmpty {
                Text("Keine offenen Hausaufgaben — gut gemacht!")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, hw in
                        HomeworkRow(
                            store: store,
                            homework: hw,
                            onTap: { homeworkToEdit = hw }
                        )
                        if index < visible.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                )
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            }
        }
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
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
}

// MARK: - Homework Row

struct HomeworkRow: View {
    var store: DataStore
    let homework: Homework
    var onTap: (() -> Void)? = nil

    private var dueLabel: String {
        let cal = Calendar.current
        let now = Date()
        let due = homework.dueDate
        if cal.isDateInToday(due) { return "Heute" }
        if cal.isDateInYesterday(due) { return "Gestern" }
        if cal.isDateInTomorrow(due) { return "Morgen" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: due)).day ?? 0
        if days < 0 { return "vor \(-days) Tg." }
        if days <= 7 {
            let f = DateFormatter()
            f.locale = Locale(identifier: "de_DE")
            f.dateFormat = "EEEE"
            return f.string(from: due)
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "d. MMM"
        return f.string(from: due)
    }

    private var isOverdue: Bool {
        !homework.isDone && homework.dueDate < Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 10) {
                Button {
                    store.toggleHomeworkDone(homework)
                } label: {
                    Image(systemName: homework.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(homework.isDone ? .green : .secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                        // Springt sichtbar, sobald abgehakt — der eigentliche
                        // Spray-Effekt darunter wird mit dem .ping- und .pop-
                        // Combo deutlich sichtbarer.
                        .changeEffect(
                            .spray(origin: UnitPoint(x: 0.5, y: 0.5)) {
                                Group {
                                    Image(systemName: "sparkle").foregroundStyle(.green)
                                    Image(systemName: "checkmark").foregroundStyle(.mint)
                                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                                }
                                .font(.system(size: 16))
                            },
                            value: homework.isDone
                        )
                        .changeEffect(.pulse(shape: Circle(), drawingMode: .stroke, count: 2), value: homework.isDone)
                        .changeEffect(.feedback(hapticImpact: .medium), value: homework.isDone)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(homework.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(homework.isDone ? .secondary : .primary)
                        .strikethrough(homework.isDone, color: .secondary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(store.colorForSubject(homework.subject))
                            .frame(width: 7, height: 7)
                        Text(homework.subject)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(dueLabel)
                            .font(.caption)
                            .foregroundStyle(isOverdue ? .red : .secondary)
                        if !homework.attachmentRelativePaths.isEmpty {
                            Image(systemName: "paperclip")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.deleteHomework(homework)
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add / Edit Homework

struct AddHomeworkView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore
    var editing: Homework? = nil

    @State private var subject: String = ""
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var dueDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var attachments: [String] = []
    @State private var showValidation = false
    @State private var showingPhotoPicker = false
    @State private var showingDocPicker = false
    @State private var pickedPhotos: [PhotosPickerItem] = []
    @State private var previewingPath: String? = nil

    init(store: DataStore, editing: Homework? = nil, initialSubject: String? = nil) {
        self.store = store
        self.editing = editing
        if let hw = editing {
            _subject = State(initialValue: hw.subject)
            _title = State(initialValue: hw.title)
            _notes = State(initialValue: hw.notes)
            _dueDate = State(initialValue: hw.dueDate)
            _attachments = State(initialValue: hw.attachmentRelativePaths)
        } else if let pre = initialSubject {
            _subject = State(initialValue: pre)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Fach") {
                    if !store.subjects.isEmpty {
                        Picker("Fach", selection: $subject) {
                            Text("Auswählen…").tag("")
                            ForEach(store.subjects) { sub in
                                Text(sub.name).tag(sub.name)
                            }
                        }
                    } else {
                        TextField("Fach (z.B. Mathe)", text: $subject)
                    }
                }
                Section("Aufgabe") {
                    TextField("Was ist zu tun?", text: $title)
                    TextField("Notizen (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("Fällig") {
                    DatePicker("Datum", selection: $dueDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "de_DE"))
                    HStack(spacing: 8) {
                        quickDateButton("Heute", offset: 0)
                        quickDateButton("Morgen", offset: 1)
                        quickDateButton("In 3 Tg.", offset: 3)
                        quickDateButton("Nächste Woche", offset: 7)
                    }
                }
                attachmentSection
                if editing != nil {
                    Section {
                        Button(role: .destructive) {
                            if let hw = editing {
                                store.deleteHomework(hw)
                                dismiss()
                            }
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "Neue Hausaufgabe" : "Hausaufgabe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                }
            }
            .alert("Fehlende Angaben", isPresented: $showValidation) {
                Button("OK") { }
            } message: {
                Text("Bitte gib Fach und Aufgabe an.")
            }
            .photosPicker(isPresented: $showingPhotoPicker,
                          selection: $pickedPhotos,
                          maxSelectionCount: 10,
                          matching: .images)
            .onChange(of: pickedPhotos) { _, items in
                Task { await importPhotos(items) }
            }
            .fileImporter(
                isPresented: $showingDocPicker,
                allowedContentTypes: [.pdf, .plainText, .rtf, .data, .image],
                allowsMultipleSelection: true
            ) { result in
                handleDocPicker(result)
            }
            .sheet(item: Binding(
                get: { previewingPath.map { PreviewItem(path: $0) } },
                set: { previewingPath = $0?.path }
            )) { item in
                QuickLookView(url: AttachmentStore.url(forRelativePath: item.path))
            }
        }
    }

    private var attachmentSection: some View {
        Section {
            if attachments.isEmpty {
                Text("Keine Anhänge")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachments, id: \.self) { path in
                            attachmentThumb(path)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            HStack(spacing: 12) {
                Button {
                    showingPhotoPicker = true
                } label: {
                    Label("Foto", systemImage: "photo")
                        .font(.subheadline)
                }
                Button {
                    showingDocPicker = true
                } label: {
                    Label("Datei", systemImage: "doc")
                        .font(.subheadline)
                }
            }
        } header: {
            Text("Anhänge")
        } footer: {
            Text("Bilder oder Dokumente (PDF, Text, …). Werden lokal auf deinem Gerät gespeichert.")
        }
    }

    private func attachmentThumb(_ path: String) -> some View {
        let url = AttachmentStore.url(forRelativePath: path)
        let isImage = AttachmentStore.isImage(path)
        return VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Button {
                    previewingPath = path
                } label: {
                    Group {
                        if isImage, let img = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            VStack(spacing: 4) {
                                Image(systemName: "doc.fill")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Text((path as NSString).pathExtension.uppercased())
                                    .font(.caption2.bold())
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .frame(width: 72, height: 72)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    AttachmentStore.delete(relativePath: path)
                    attachments.removeAll { $0 == path }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .offset(x: 6, y: -6)
            }
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let ext = "jpg"
                if let path = AttachmentStore.save(data: data, fileExtension: ext) {
                    await MainActor.run { attachments.append(path) }
                }
            }
        }
        await MainActor.run { pickedPhotos.removeAll() }
    }

    private func handleDocPicker(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            let needsStop = url.startAccessingSecurityScopedResource()
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) {
                let ext = url.pathExtension.isEmpty ? "dat" : url.pathExtension
                if let path = AttachmentStore.save(data: data, fileExtension: ext) {
                    attachments.append(path)
                }
            }
        }
    }

    private func quickDateButton(_ label: String, offset: Int) -> some View {
        Button(label) {
            dueDate = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func save() {
        let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSubject.isEmpty || trimmedTitle.isEmpty {
            showValidation = true
            return
        }
        if var hw = editing {
            hw.subject = trimmedSubject
            hw.title = trimmedTitle
            hw.notes = notes
            hw.dueDate = dueDate
            hw.attachmentRelativePaths = attachments
            store.updateHomework(hw)
        } else {
            var hw = Homework(subject: trimmedSubject, title: trimmedTitle, notes: notes, dueDate: dueDate)
            hw.attachmentRelativePaths = attachments
            store.addHomework(hw)
        }
        dismiss()
    }
}

private struct PreviewItem: Identifiable {
    let path: String
    var id: String { path }
}

// QuickLook für Attachments
struct QuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}

// MARK: - Homework List

struct HomeworkListView: View {
    var store: DataStore
    @State private var homeworkToEdit: Homework? = nil
    @State private var showingAdd = false
    @State private var showDone = false

    private var sections: [(label: String, items: [Homework])] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let endOfWeek = cal.date(byAdding: .day, value: 7, to: today) ?? today
        let open = store.openHomework()

        let overdue = open.filter { $0.dueDate < today }
        let todayItems = open.filter { cal.isDate($0.dueDate, inSameDayAs: today) }
        let weekItems = open.filter { $0.dueDate > today && $0.dueDate <= endOfWeek }
        let later = open.filter { $0.dueDate > endOfWeek }
        let done = store.homework.filter { $0.isDone }.sorted { $0.dueDate > $1.dueDate }

        var result: [(String, [Homework])] = []
        if !overdue.isEmpty { result.append(("Überfällig", overdue)) }
        if !todayItems.isEmpty { result.append(("Heute", todayItems)) }
        if !weekItems.isEmpty { result.append(("Diese Woche", weekItems)) }
        if !later.isEmpty { result.append(("Später", later)) }
        if showDone && !done.isEmpty { result.append(("Erledigt", done)) }
        return result
    }

    var body: some View {
        Group {
            if store.homework.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("Keine Hausaufgaben")
                        .foregroundStyle(.secondary)
                    Button { showingAdd = true } label: {
                        Label("Hausaufgabe hinzufügen", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sections, id: \.label) { section in
                        Section(section.label) {
                            ForEach(section.items) { hw in
                                HomeworkRow(store: store, homework: hw, onTap: { homeworkToEdit = hw })
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                    Toggle("Erledigte anzeigen", isOn: $showDone)
                        .font(.caption)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Hausaufgaben")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddHomeworkView(store: store)
        }
        .sheet(item: $homeworkToEdit) { hw in
            AddHomeworkView(store: store, editing: hw)
        }
    }
}

// MARK: - Timetable Slot Row

struct TimetableSlotRow: View {
    var store: DataStore
    let slot: TimetableSlot
    var compact: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        let color = store.colorForSubject(slot.subject)
        Button {
            onTap?()
        } label: {
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    Text(slot.startTime)
                        .font(.caption2.monospacedDigit().bold())
                    Text(slot.endTime)
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 44)

                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.subject)
                        .font(.subheadline.bold())
                    HStack(spacing: 6) {
                        if !slot.room.isEmpty {
                            Label(slot.room, systemImage: "mappin.circle")
                                .labelStyle(.titleAndIcon)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if !slot.teacher.isEmpty {
                            Text(slot.teacher)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                Spacer()
                if !compact {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, compact ? 10 : 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Timetable View (Wochen-Grid wie Webuntis)

struct TimetableView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore

    @State private var weekOffset: Int = 0  // 0 = aktuelle, +1 = nächste etc.
    @State private var showingAddSlot = false
    @State private var slotToEdit: TimetableSlot? = nil
    @State private var slotToShow: TimetableSlot? = nil
    @State private var addInitialWeekday: Int = 1

    private let weekdayShort = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    /// Welche Wochentage gezeigt werden — wir blenden Sa/So aus, wenn dort nichts ist.
    private var visibleWeekdays: [Int] {
        let hasWeekend = (6...7).contains { !store.slotsFor(weekday: $0).isEmpty }
        return Array(1...(hasWeekend ? 7 : 5))
    }

    /// Eindeutige Time-Slots, sortiert nach Startzeit.
    private var timeSlots: [TimeSlotInfo] {
        var seen = Set<String>()
        var result: [TimeSlotInfo] = []
        for s in store.timetable.sorted(by: { $0.startTime < $1.startTime }) {
            let key = "\(s.startTime)|\(s.endTime)"
            if !seen.contains(key) {
                seen.insert(key)
                result.append(TimeSlotInfo(startTime: s.startTime, endTime: s.endTime, lesson: s.lesson))
            }
        }
        // Lesson-Nummern neu durchnummerieren (1..n), falls Webuntis-Daten
        // unstimmig waren.
        return result.enumerated().map { idx, t in
            TimeSlotInfo(startTime: t.startTime, endTime: t.endTime, lesson: idx + 1)
        }
    }

    /// Datum der ersten Spalte (Montag) in der gewählten Woche.
    private var weekStart: Date {
        let cal = Calendar(identifier: .iso8601)
        let today = cal.startOfDay(for: Date())
        let interval = cal.dateInterval(of: .weekOfYear, for: today) ?? DateInterval(start: today, duration: 0)
        let offset = cal.date(byAdding: .weekOfYear, value: weekOffset, to: interval.start) ?? interval.start
        return offset
    }

    private var weekNumber: Int {
        Calendar(identifier: .iso8601).component(.weekOfYear, from: weekStart)
    }
    private var monthShort: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "LLL"
        return f.string(from: weekStart)
    }

    private func relativeSyncString(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                weekNavBar
                HStack {
                    Text("KW \(weekNumber) · \(monthShort)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                    Spacer()
                    if let last = WebuntisService.shared.lastSync {
                        Text("Aktualisiert \(relativeSyncString(last))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 4)

                if store.timetable.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .navigationTitle("Stundenplan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            addInitialWeekday = 1
                            showingAddSlot = true
                        } label: {
                            Label("Stunde hinzufügen", systemImage: "plus")
                        }
                        if WebuntisService.shared.isConfigured {
                            Button {
                                Task { await WebuntisService.shared.sync(into: store) }
                            } label: {
                                Label("Aus Webuntis aktualisieren", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddSlot) {
                AddTimetableSlotView(store: store, initialWeekday: addInitialWeekday)
            }
            .sheet(item: $slotToEdit) { slot in
                AddTimetableSlotView(store: store, editing: slot)
            }
            .sheet(item: $slotToShow) { slot in
                TimetableSlotDetailView(store: store, slot: slot)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    /// Wählt das richtige Sheet: Webuntis-Slots → Detail (read-only),
    /// lokal angelegte Slots → Edit-Form.
    private func openSlot(_ slot: TimetableSlot) {
        if slot.sourceId != nil {
            slotToShow = slot
        } else {
            slotToEdit = slot
        }
    }

    // MARK: – Header

    private var weekNavBar: some View {
        // Webuntis zeigt nur diese + nächste Woche → wir limitieren auf 0...1.
        HStack(spacing: 8) {
            Button {
                withAnimation(AppAnimation.snappy) {
                    weekOffset = max(0, weekOffset - 1)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.semibold)
                    .frame(width: 32, height: 32)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .opacity(weekOffset == 0 ? 0.35 : 1)
            }
            .buttonStyle(.plain)
            .disabled(weekOffset == 0)

            HStack(spacing: 0) {
                weekTab(label: "Diese Woche", offset: 0)
                weekTab(label: "Nächste Woche", offset: 1)
            }
            .padding(2)
            .background(Color(.tertiarySystemFill), in: Capsule())
            .frame(maxWidth: .infinity)

            Button {
                withAnimation(AppAnimation.snappy) {
                    weekOffset = min(1, weekOffset + 1)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .fontWeight(.semibold)
                    .frame(width: 32, height: 32)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .opacity(weekOffset == 1 ? 0.35 : 1)
            }
            .buttonStyle(.plain)
            .disabled(weekOffset == 1)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)

        // KW-Label darunter
        // (in separater HStack im Caller? — wir hängen es direkt ans Nav-Bar)
    }

    private func weekTab(label: String, offset: Int) -> some View {
        Button {
            withAnimation(AppAnimation.snappy) { weekOffset = offset }
        } label: {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(
                    weekOffset == offset
                    ? AnyShapeStyle(LinearGradient(colors: [.blue, .purple],
                                                   startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Color.clear),
                    in: Capsule()
                )
                .foregroundStyle(weekOffset == offset ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Kein Stundenplan vorhanden")
                .foregroundStyle(.secondary)
            if WebuntisService.shared.isConfigured {
                Button {
                    Task { await WebuntisService.shared.sync(into: store) }
                } label: {
                    Label("Aus Webuntis laden", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
            }
            Button {
                addInitialWeekday = 1
                showingAddSlot = true
            } label: {
                Label("Manuell anlegen", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: – Grid

    private var grid: some View {
        let cal = Calendar(identifier: .iso8601)
        let days = visibleWeekdays
        let dayDates: [Date] = days.map {
            cal.date(byAdding: .day, value: $0 - 1, to: weekStart) ?? weekStart
        }
        let today = cal.startOfDay(for: Date())
        let timeColumnWidth: CGFloat = 50

        return ScrollView {
            VStack(spacing: 0) {
                // Header-Zeile mit Wochentagen
                HStack(alignment: .top, spacing: 4) {
                    Color.clear.frame(width: timeColumnWidth)
                    ForEach(Array(days.enumerated()), id: \.offset) { idx, wd in
                        VStack(spacing: 2) {
                            Text(weekdayShort[wd - 1] + ".")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text("\(cal.component(.day, from: dayDates[idx]))")
                                .font(.title3.bold())
                                .foregroundStyle(cal.isDate(dayDates[idx], inSameDayAs: today) ? Color.orange : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                }

                Divider()

                // Zeit-Slot-Reihen
                ForEach(Array(timeSlots.enumerated()), id: \.offset) { _, time in
                    HStack(alignment: .top, spacing: 4) {
                        // Zeit-Spalte
                        VStack(spacing: 2) {
                            Text(time.startTime)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text("\(time.lesson)")
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text(time.endTime)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(width: timeColumnWidth, alignment: .center)
                        .padding(.vertical, 8)

                        // Tag-Zellen — nach konkretem Datum, sonst weekday-Fallback.
                        // Mehrere Slots zur gleichen Zeit (Ausfall + Vertretung)
                        // werden untereinander gestapelt.
                        ForEach(Array(days.enumerated()), id: \.offset) { idx, wd in
                            let slots = store.slotsFor(date: dayDates[idx])
                                .filter { $0.startTime == time.startTime }
                            cell(for: slots, on: wd)
                        }
                    }
                    Divider().opacity(0.4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 20)
        }
    }

    /// Rendert eine Zelle: leer (Add-Tap), eine Karte oder gestapelte Karten
    /// für Ausfall+Vertretung an der gleichen Stunde.
    private func cell(for slots: [TimetableSlot], on weekday: Int) -> some View {
        Group {
            if slots.isEmpty {
                Button {
                    addInitialWeekday = weekday
                    showingAddSlot = true
                } label: {
                    Color.clear.frame(maxWidth: .infinity, minHeight: 56)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else if slots.count == 1, let slot = slots.first {
                Button { openSlot(slot) } label: {
                    TimetableCardView(store: store, slot: slot)
                }
                .buttonStyle(.plain)
            } else {
                // Ausfall + Vertretung übereinander, Ausfall zuerst (oben).
                let sorted = slots.sorted { l, r in
                    if l.isCancelled != r.isCancelled { return l.isCancelled }
                    return l.subject < r.subject
                }
                VStack(spacing: 2) {
                    ForEach(sorted) { slot in
                        Button { openSlot(slot) } label: {
                            TimetableCardView(store: store, slot: slot)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TimeSlotInfo: Hashable {
    let startTime: String
    let endTime: String
    let lesson: Int
}

// MARK: – Card im Webuntis-Look

struct TimetableCardView: View {
    var store: DataStore
    let slot: TimetableSlot

    private var displayColor: Color {
        if slot.isCancelled { return .red }
        if slot.isSubstitution { return .green }
        return store.colorForSubject(slot.subject)
    }

    private var abbreviation: String {
        String(slot.subject.uppercased().prefix(4))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(displayColor)
                    .frame(width: 4)
                VStack(alignment: .leading, spacing: 1) {
                    Text(abbreviation)
                        .font(.caption2.bold())
                        .foregroundStyle(.primary)
                        .strikethrough(slot.isCancelled, color: .red)
                        .lineLimit(1)
                    if !slot.teacher.isEmpty {
                        Text(slot.teacher)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .strikethrough(slot.isCancelled, color: .red.opacity(0.6))
                            .lineLimit(1)
                    }
                    if !slot.room.isEmpty {
                        Text(slot.room)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .strikethrough(slot.isCancelled, color: .red.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 4)
                .padding(.vertical, 5)
                .padding(.trailing, 3)
                Spacer(minLength: 0)
            }

            // Info-Badge unten rechts (i im grauen Kreis), wenn Info vorliegt.
            if !slot.info.isEmpty {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white, .gray)
                    .padding(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(
            backgroundColor,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .opacity(slot.isCancelled ? 0.7 : 1)
    }

    private var backgroundColor: Color {
        if slot.isCancelled { return Color.red.opacity(0.10) }
        if slot.isSubstitution { return Color.green.opacity(0.18) }
        return store.colorForSubject(slot.subject).opacity(0.18)
    }
}

// MARK: - Add / Edit Timetable Slot

struct AddTimetableSlotView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore
    var editing: TimetableSlot? = nil

    @State private var weekday: Int = 1
    @State private var lesson: Int = 1
    @State private var startTime: Date = AddTimetableSlotView.timeAt(8, 0)
    @State private var endTime: Date = AddTimetableSlotView.timeAt(8, 45)
    @State private var subject: String = ""
    @State private var room: String = ""
    @State private var teacher: String = ""

    private let weekdayNames = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]

    init(store: DataStore, editing: TimetableSlot? = nil, initialWeekday: Int? = nil) {
        self.store = store
        self.editing = editing
        if let s = editing {
            _weekday = State(initialValue: s.weekday)
            _lesson = State(initialValue: s.lesson)
            _startTime = State(initialValue: Self.parseTime(s.startTime) ?? Self.timeAt(8, 0))
            _endTime = State(initialValue: Self.parseTime(s.endTime) ?? Self.timeAt(8, 45))
            _subject = State(initialValue: s.subject)
            _room = State(initialValue: s.room)
            _teacher = State(initialValue: s.teacher)
        } else if let wd = initialWeekday {
            _weekday = State(initialValue: wd)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tag & Stunde") {
                    Picker("Wochentag", selection: $weekday) {
                        ForEach(1...7, id: \.self) { wd in
                            Text(weekdayNames[wd - 1]).tag(wd)
                        }
                    }
                    Stepper("Stunde \(lesson)", value: $lesson, in: 1...12)
                }
                Section("Zeit") {
                    DatePicker("Von", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Bis", selection: $endTime, displayedComponents: .hourAndMinute)
                }
                Section("Fach") {
                    if !store.subjects.isEmpty {
                        Picker("Fach", selection: $subject) {
                            Text("Auswählen…").tag("")
                            ForEach(store.subjects) { sub in
                                Text(sub.name).tag(sub.name)
                            }
                        }
                    } else {
                        TextField("Fach", text: $subject)
                    }
                    TextField("Raum (optional)", text: $room)
                    TextField("Lehrer:in (optional)", text: $teacher)
                }
                if editing != nil {
                    Section {
                        Button(role: .destructive) {
                            if let s = editing {
                                store.deleteSlot(s)
                                dismiss()
                            }
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "Neue Stunde" : "Stunde")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .disabled(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if var s = editing {
            s.weekday = weekday
            s.lesson = lesson
            s.startTime = Self.timeString(startTime)
            s.endTime = Self.timeString(endTime)
            s.subject = trimmed
            s.room = room
            s.teacher = teacher
            store.updateSlot(s)
        } else {
            let s = TimetableSlot(
                weekday: weekday, lesson: lesson,
                startTime: Self.timeString(startTime),
                endTime: Self.timeString(endTime),
                subject: trimmed, room: room, teacher: teacher
            )
            store.addSlot(s)
        }
        dismiss()
    }

    static func timeAt(_ hour: Int, _ minute: Int) -> Date {
        var comps = DateComponents()
        comps.hour = hour; comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }

    static func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func parseTime(_ string: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.date(from: string)
    }
}

// MARK: - Timetable Slot Detail (read-only Anzeige aller Webuntis-Daten)

struct TimetableSlotDetailView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore
    let slot: TimetableSlot

    private var dateLabel: String {
        guard let d = slot.date else {
            let names = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
            return names[max(0, min(6, slot.weekday - 1))]
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE, d. MMMM yyyy"
        return f.string(from: d)
    }

    private var statusBadge: (text: String, color: Color)? {
        if slot.isCancelled { return ("Ausfall", .red) }
        if slot.isSubstitution { return ("Vertretung", .green) }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Hero
                    VStack(alignment: .leading, spacing: 8) {
                        if let badge = statusBadge {
                            Text(badge.text)
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(badge.color, in: Capsule())
                        }
                        Text(slot.subject)
                            .font(.title.bold())
                            .strikethrough(slot.isCancelled, color: .red)
                        if let orig = slot.originalSubject, !orig.isEmpty, orig != slot.subject {
                            Text("statt \(orig)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(dateLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(slot.startTime) – \(slot.endTime) · Stunde \(slot.lesson)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        store.colorForSubject(slot.subject).opacity(0.15),
                        in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    )

                    // Detail-Liste
                    VStack(spacing: 0) {
                        detailRow(icon: "person.fill", label: "Lehrer:in", value: slot.teacher)
                        detailRow(icon: "mappin.circle.fill", label: "Raum", value: slot.room)
                        if !slot.info.isEmpty {
                            detailRow(icon: "info.circle.fill", label: "Info",
                                      value: slot.info, multiline: true)
                        }
                        if let sid = slot.sourceId {
                            detailRow(icon: "number", label: "Webuntis-ID",
                                      value: sid, mono: true)
                        }
                    }
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    )
                }
                .padding()
            }
            .navigationTitle("Stunde")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func detailRow(icon: String, label: String, value: String,
                           multiline: Bool = false, mono: Bool = false) -> some View {
        if !value.isEmpty {
            HStack(alignment: multiline ? .top : .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(mono ? .caption.monospaced() : .subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            Divider().padding(.leading, 44)
        }
    }
}
