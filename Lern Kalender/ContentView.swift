import SwiftUI
import PhotosUI
import QuickLook
import UniformTypeIdentifiers

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
    @State private var showingAddHomework = false
    @State private var showingAllHomework = false
    @State private var homeworkToEdit: Homework? = nil

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
        }
    }

    /// Hero-Header oben im Today-Tab: Gradient-Card mit Begrüßung, Datum
    /// und heutiger Lernzeit. Tap öffnet die ausführliche Lernzeit-Liste.
    private var heroHeader: some View {
        let gradientColors: [Color] = [Color.blue, Color.purple]
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

    private func quickActionTile(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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

    /// Sanftes Tap-Feedback für Quick-Action-Tiles.
    private struct QuickActionButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                .animation(AppAnimation.snappy, value: configuration.isPressed)
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
                        .font(.title3)
                        .foregroundStyle(homework.isDone ? .green : .secondary)
                        .frame(width: 28)
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
