import SwiftUI

struct TopicFeedView: View {
    let topic: Topic

    @Environment(\.dismiss) private var dismiss
    @State private var posts: [FeedPost] = []
    @State private var isGenerating = false
    @State private var error: String?
    @State private var dailyLimitHit = false

    private let store = TopicStore.shared

    var body: some View {
        NavigationStack {
            Group {
                if isGenerating {
                    generatingView
                } else if dailyLimitHit && posts.isEmpty {
                    dailyLimitView
                } else if posts.isEmpty {
                    emptyView
                } else {
                    feedScroll
                }
            }
            .navigationTitle(topic.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                }
            }
            .alert("Fehler", isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
        }
        .task { await loadOrGenerate() }
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

    private var feedScroll: some View {
        ScrollView {
            LazyVStack(spacing: 32) {
                ForEach(posts) { post in
                    FeedPostView(post: post, topicColor: topic.color) { answer in
                        store.recordAnswer(post: post, answer: answer)
                    }
                    .padding(.top, 8)
                }

                Color.clear
                    .frame(height: 80)
                    .onAppear {
                        // Mark feed as exhausted when we reach the end (the spacer at the bottom).
                        store.markFeedExhausted(topicId: topic.id)
                    }
            }
            .padding(.vertical)
        }
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
