import SwiftUI

struct HivemindTab: View {
    var store: DataStore
    @Bindable private var topicStore = TopicStore.shared

    @State private var showCreateTopic = false
    @State private var showDiscover = false
    @State private var showProfile = false
    @State private var topicToOpen: Topic?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    welcomeHeader
                    schoolTopicsSection
                    calendarSuggestionsSection
                    discoverSection
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("Lernen")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showProfile = true
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.purple)
                    }
                }
            }
            .sheet(isPresented: $showCreateTopic) {
                CreateTopicView(store: store)
            }
            .sheet(isPresented: $showDiscover) {
                DiscoverView { topic in
                    topicToOpen = topic
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileSheetView(store: store)
            }
            .sheet(item: $topicToOpen) { topic in
                TopicFeedView(topic: topic)
            }
        }
    }

    // MARK: - Welcome header

    private var welcomeHeader: some View {
        let streak = LearningEngine.shared.profile.streakDays
        return VStack(alignment: .leading, spacing: 12) {
            Text("Welcome back!")
                .font(.title.bold())
            Text("Du hast eine \(streak)-Tage-Serie")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(weekDayLabels, id: \.label) { item in
                    VStack(spacing: 4) {
                        Text(item.label)
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        ZStack {
                            Circle()
                                .fill(item.completed ? Color.purple : Color(.systemGray5))
                                .frame(width: 28, height: 28)
                            if item.completed {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(colors: [.purple.opacity(0.15), .pink.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .padding(.horizontal)
    }

    private struct WeekDayItem {
        let label: String
        let completed: Bool
    }

    private var weekDayLabels: [WeekDayItem] {
        let calendar = Calendar.current
        let today = Date()
        let labels = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        // Build the past 7 days ending today, but display in Mo–So order.
        // Find the most recent Monday (or today if it's Monday).
        let weekday = calendar.component(.weekday, from: today) // 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        let daysSinceMonday = (weekday + 5) % 7   // Mon=0, Tue=1, ..., Sun=6
        guard let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) else {
            return labels.map { WeekDayItem(label: $0, completed: false) }
        }
        var items: [WeekDayItem] = []
        for offset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: offset, to: monday) ?? today
            let key = LearnerProfile.dateKey(date)
            let xp = LearningEngine.shared.profile.dailyXPLog[key] ?? 0
            items.append(WeekDayItem(label: labels[offset], completed: xp > 0))
        }
        return items
    }

    // MARK: - School topics

    private var schoolTopicsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Deine Topics").font(.title2.bold())
                Spacer()
                Button {
                    showCreateTopic = true
                } label: {
                    Label("Neu", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.purple)
                }
            }
            .padding(.horizontal)

            if topicStore.schoolTopics.isEmpty {
                emptyTopicsCard
            } else {
                VStack(spacing: 12) {
                    ForEach(topicStore.schoolTopics) { topic in
                        TopicCard(topic: topic, progress: topicStore.progress(for: topic.id)) {
                            topicToOpen = topic
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var emptyTopicsCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(.purple)
            Text("Noch keine Topics")
                .font(.headline)
            Text("Erstelle dein erstes Topic — z. B. mit einem Foto deines Hefts.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Topic erstellen") { showCreateTopic = true }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    // MARK: - Calendar suggestions

    private var calendarSuggestionsSection: some View {
        let upcomingExams = store.entries
            .filter { $0.type == .klassenarbeit && $0.date > Date() && $0.date < Date().addingTimeInterval(14 * 86400) }
            .prefix(3)

        return Group {
            if !upcomingExams.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Aus deinem Kalender").font(.title3.bold()).padding(.horizontal)
                    ForEach(Array(upcomingExams)) { exam in
                        Button {
                            // Pre-create a topic from the exam metadata.
                            let topic = Topic(
                                title: exam.title,
                                subject: nil,
                                iconName: "doc.text.fill",
                                colorHex: "#EF4444",
                                source: .calendarSuggestion(examId: exam.id)
                            )
                            topicStore.addTopic(topic)
                            topicToOpen = topic
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar")
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(.red.gradient, in: RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exam.title).font(.subheadline.bold()).foregroundStyle(.primary)
                                    Text(exam.date, format: .dateTime.day().month().weekday(.wide))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.purple)
                            }
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - Discover

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Entdecken").font(.title3.bold())
                Spacer()
                Button("Mehr") { showDiscover = true }
                    .font(.subheadline.bold())
                    .foregroundStyle(.purple)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DiscoverCatalog.all.prefix(5)) { category in
                        Button {
                            showDiscover = true
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: category.icon)
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                Text(category.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(14)
                            .frame(width: 140, height: 100, alignment: .topLeading)
                            .background((Color(hivemindHex: category.colorHex) ?? .purple).gradient, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Topic Card

private struct TopicCard: View {
    let topic: Topic
    let progress: TopicProgress
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(topic.color.gradient)
                        .frame(width: 56, height: 56)
                    Image(systemName: topic.iconName)
                        .font(.title2)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(topic.title).font(.subheadline.bold()).foregroundStyle(.primary)
                        if topic.assignedByParent {
                            Image(systemName: "person.fill.checkmark")
                                .font(.caption2)
                                .foregroundStyle(.purple)
                        }
                    }
                    if let subject = topic.subject {
                        Text(subject).font(.caption).foregroundStyle(.secondary)
                    }
                    ProgressView(value: progress.percent(totalPosts: FeedGenerator.postsPerBatch))
                        .tint(topic.color)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
