import SwiftUI

struct TopicFeedView: View {
    let topic: Topic

    @Environment(\.dismiss) private var dismiss
    @State private var posts: [FeedPost] = []
    @State private var isGenerating = false
    @State private var error: String?
    @State private var dailyLimitHit = false
    @State private var currentPostId: UUID?

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

            // Top overlay (X + topic title + post counter)
            VStack {
                topOverlay
                Spacer()
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
        .task { await loadOrGenerate() }
    }

    // MARK: - Top overlay

    private var topOverlay: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.bold())
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(topic.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !posts.isEmpty, let currentId = currentPostId,
                   let idx = posts.firstIndex(where: { $0.id == currentId }) {
                    Text("\(idx + 1) / \(posts.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            // Symmetrical placeholder so the title stays centered
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
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
        GeometryReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(posts) { post in
                        FeedPostView(post: post, topicColor: topic.color) { answer in
                            store.recordAnswer(post: post, answer: answer)
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .id(post.id)
                    }

                    // End-of-feed marker
                    endOfFeedView
                        .frame(width: proxy.size.width, height: proxy.size.height)
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
