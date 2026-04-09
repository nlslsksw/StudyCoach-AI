import SwiftUI

struct TopicFeedView: View {
    let topic: Topic

    @Environment(\.dismiss) private var dismiss
    @State private var posts: [FeedPost] = []
    @State private var isGenerating = false
    @State private var error: String?
    @State private var dailyLimitHit = false
    @State private var currentPostId: UUID?
    @State private var closeGesture: FeedCloseGesture = FeedCloseGesture.current

    private let store = TopicStore.shared

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if isGenerating {
                generatingView
            } else if dailyLimitHit && posts.isEmpty {
                dailyLimitView
            } else if posts.isEmpty {
                emptyView
            } else {
                feedScroll
            }

            // Close affordance — depends on user setting
            closeAffordance
        }
        .onAppear { closeGesture = FeedCloseGesture.current }
        .alert("Fehler", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
        .task { await loadOrGenerate() }
    }

    // MARK: - Close affordance

    @ViewBuilder
    private var closeAffordance: some View {
        switch closeGesture {
        case .backButton:
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.bold())
                            .foregroundStyle(.primary)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
        case .doubleTapTop:
            VStack(spacing: 0) {
                // Invisible tap strip at the very top — no visible affordance.
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 70)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        dismiss()
                    }
                Spacer()
            }
        }
    }

    // MARK: - States

    private var generatingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.4)
            Text("Dein Feed wird erstellt…")
                .font(.headline)
            Text("Das dauert nur einen Moment.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray").font(.system(size: 50)).foregroundStyle(.secondary)
            Text("Keine Posts").font(.headline)
            Button("Feed generieren") { Task { await regenerate() } }
                .buttonStyle(.borderedProminent)
        }
    }

    private var dailyLimitView: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 50))
                .foregroundStyle(.purple)
            Text("Du hast alle Posts für heute durch!")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text("Komm morgen wieder für neuen Stoff.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Streak halten 🎯")
                .font(.caption.bold())
                .foregroundStyle(.orange)
        }
        .padding()
    }

    // MARK: - TikTok-style paging feed

    private var feedScroll: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(posts) { post in
                    FeedPostView(post: post, topicColor: topic.color) { answer in
                        store.recordAnswer(post: post, answer: answer)
                    }
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id(post.id)
                }

                // End-of-feed marker
                endOfFeedView
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id("end")
                    .onAppear {
                        store.markFeedExhausted(topicId: topic.id)
                    }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentPostId)
        .ignoresSafeArea()
    }

    private var endOfFeedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            Text("Geschafft!")
                .font(.title.bold())
            Text("Du hast alle Posts für heute durch.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Fertig") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(topic.color)
                .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Loading / Generation

    private func loadOrGenerate() async {
        let progress = store.progress(for: topic.id)
        let cached = FeedGenerator.loadPosts(for: topic.id)

        // Case 1: cached posts and same-day generation → reuse.
        if !cached.isEmpty,
           let lastGen = progress.feedGeneratedDate,
           Calendar.current.isDateInToday(lastGen) {
            posts = cached
            currentPostId = cached.first?.id
            return
        }

        // Case 2: same-day exhausted (no cache or already used).
        if let lastGen = progress.feedGeneratedDate,
           Calendar.current.isDateInToday(lastGen),
           progress.feedExhausted {
            dailyLimitHit = true
            return
        }

        // Case 3: new day or new topic → generate.
        await regenerate()
    }

    private func regenerate() async {
        isGenerating = true
        defer { isGenerating = false }

        do {
            let sourceText = topic.source.sourceText
            let generated = try await FeedGenerator.generateFeed(
                for: topic,
                sourceText: sourceText,
                previousProgress: store.progress(for: topic.id)
            )
            store.markFeedGenerated(topicId: topic.id)
            posts = generated
            currentPostId = generated.first?.id
        } catch let err as FeedGenerationError {
            if case .dailyLimitReached = err {
                dailyLimitHit = true
            } else {
                error = err.localizedDescription
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
