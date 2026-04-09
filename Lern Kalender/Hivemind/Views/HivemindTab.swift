import SwiftUI

struct HivemindTab: View {
    var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @Bindable private var topicStore = TopicStore.shared

    @State private var showCreateTopic = false
    @State private var showDiscover = false
    @State private var showProfile = false
    @State private var showBetaInfo = false
    @State private var topicToOpen: Topic?
    @State private var topicToDelete: Topic?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    welcomeHeader
                    schoolTopicsSection
                    discoverSection
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
                .frame(maxWidth: 700)   // iPad: cap content width so topics don't stretch
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Lernen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.purple)
                    }
                    .accessibilityLabel("Schließen")
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showBetaInfo = true
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.purple)
                    }
                    .accessibilityLabel("Beta-Info anzeigen")
                    Button {
                        showProfile = true
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.purple)
                    }
                    .accessibilityLabel("Profil öffnen")
                }
            }
            .sheet(isPresented: $showBetaInfo) {
                BetaInfoView()
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
            .fullScreenCover(item: $topicToOpen) { topic in
                TopicFeedView(topic: topic)
            }
            .alert("Topic löschen?", isPresented: Binding(
                get: { topicToDelete != nil },
                set: { if !$0 { topicToDelete = nil } }
            ), presenting: topicToDelete) { topic in
                Button("Abbrechen", role: .cancel) { topicToDelete = nil }
                Button("Löschen", role: .destructive) {
                    topicStore.deleteTopic(id: topic.id)
                    topicToDelete = nil
                }
            } message: { topic in
                Text("\"\(topic.title)\" und alle generierten Posts werden gelöscht.")
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
                        .contextMenu {
                            Button(role: .destructive) {
                                topicToDelete = topic
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
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
