import SwiftUI
import Speech
import AVFoundation

// MARK: - Dispatcher

struct FeedPostView: View {
    let post: FeedPost
    let topicColor: Color
    let onAnswer: (PostAnswer) -> Void

    var body: some View {
        switch post.type {
        case let .textLesson(title, body):
            TextLessonPostView(title: title, bodyText: body, accent: topicColor, onViewed: { onAnswer(.viewed) })
        case let .quizCard(question, options, correctIndex, explanation):
            QuizPostView(question: question, options: options, correctIndex: correctIndex, explanation: explanation, accent: topicColor, onAnswer: onAnswer)
        case let .flashcard(front, back):
            FlashcardPostView(front: front, back: back, accent: topicColor, onAnswer: onAnswer)
        case let .example(scenario, walkthrough):
            ExamplePostView(scenario: scenario, walkthrough: walkthrough, accent: topicColor, onViewed: { onAnswer(.viewed) })
        case let .feynman(prompt, expectedKeywords):
            FeynmanPostView(prompt: prompt, expectedKeywords: expectedKeywords, accent: topicColor, onAnswer: onAnswer)
        }
    }
}

// MARK: - Full-screen container

private struct FullScreenPost<Content: View>: View {
    let icon: String
    let label: String
    let accent: Color
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            // Subtle topic-tinted gradient background — full edge-to-edge.
            LinearGradient(
                colors: [
                    accent.opacity(0.22),
                    accent.opacity(0.05),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 24) {
                // Type label badge — placed below the back button.
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.body.bold())
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(accent.gradient, in: Circle())
                    Text(label)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(1.2)
                }
                .padding(.top, 70)   // sits below the back button

                content
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 60)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Text Lesson

struct TextLessonPostView: View {
    let title: String
    let bodyText: String
    let accent: Color
    let onViewed: () -> Void

    @State private var hasMarkedViewed = false

    var body: some View {
        FullScreenPost(icon: "lightbulb.fill", label: "Lektion", accent: accent) {
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(bodyText)
                .font(.title3)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)

            Spacer()
        }
        .onAppear {
            guard !hasMarkedViewed else { return }
            hasMarkedViewed = true
            onViewed()
        }
    }
}

// MARK: - Quiz

struct QuizPostView: View {
    let question: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
    let accent: Color
    let onAnswer: (PostAnswer) -> Void

    @State private var selected: Int?

    var body: some View {
        FullScreenPost(icon: "questionmark.circle.fill", label: "Quiz", accent: accent) {
            Text(question)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                ForEach(Array(options.enumerated()), id: \.offset) { idx, option in
                    Button {
                        guard selected == nil else { return }
                        withAnimation(.spring(response: 0.4)) {
                            selected = idx
                        }
                        onAnswer(.quiz(selectedIndex: idx, correct: idx == correctIndex))
                    } label: {
                        HStack(spacing: 14) {
                            Text(letter(for: idx))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(badgeColor(idx).gradient, in: Circle())
                            Text(option)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            if let s = selected {
                                if idx == correctIndex {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green).font(.title3)
                                } else if idx == s {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red).font(.title3)
                                }
                            }
                        }
                        .padding(16)
                        .background(answerBackground(idx), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16).stroke(answerBorder(idx), lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(selected != nil)
                }
            }
            .padding(.top, 4)

            if selected != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selected == correctIndex ? "Richtig!" : "Nicht ganz.")
                        .font(.headline)
                        .foregroundStyle(selected == correctIndex ? .green : .orange)
                    Text(explanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()
        }
    }

    private func letter(for idx: Int) -> String {
        ["A", "B", "C", "D"][min(idx, 3)]
    }

    private func badgeColor(_ idx: Int) -> Color {
        guard let s = selected else { return accent }
        if idx == correctIndex { return .green }
        if idx == s { return .red }
        return .secondary
    }

    private func answerBackground(_ idx: Int) -> Color {
        guard let s = selected else { return Color(.secondarySystemBackground) }
        if idx == correctIndex { return .green.opacity(0.18) }
        if idx == s { return .red.opacity(0.18) }
        return Color(.secondarySystemBackground)
    }

    private func answerBorder(_ idx: Int) -> Color {
        guard let s = selected else { return .clear }
        if idx == correctIndex { return .green }
        if idx == s { return .red }
        return .clear
    }
}

// MARK: - Flashcard

struct FlashcardPostView: View {
    let front: String
    let back: String
    let accent: Color
    let onAnswer: (PostAnswer) -> Void

    @State private var flipped = false
    @State private var answered = false

    var body: some View {
        FullScreenPost(icon: "rectangle.on.rectangle", label: "Karteikarte", accent: accent) {
            Spacer()

            VStack(spacing: 24) {
                Text(flipped ? back : front)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(28)
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(.secondarySystemBackground))
                            .shadow(color: accent.opacity(0.2), radius: 16, y: 6)
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4)) { flipped.toggle() }
                    }

                if !flipped {
                    Label("Tippe zum Umdrehen", systemImage: "hand.tap.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if !answered {
                    HStack(spacing: 12) {
                        Button {
                            answered = true
                            onAnswer(.flashcard(known: false))
                        } label: {
                            Label("Wusste ich nicht", systemImage: "xmark")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)

                        Button {
                            answered = true
                            onAnswer(.flashcard(known: true))
                        } label: {
                            Label("Wusste ich", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                } else {
                    Text("Gespeichert ✓")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Example

struct ExamplePostView: View {
    let scenario: String
    let walkthrough: String
    let accent: Color
    let onViewed: () -> Void

    @State private var hasMarkedViewed = false

    var body: some View {
        FullScreenPost(icon: "wand.and.stars", label: "Beispiel", accent: accent) {
            Text(scenario)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(walkthrough)
                .font(.title3)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)

            Spacer()
        }
        .onAppear {
            guard !hasMarkedViewed else { return }
            hasMarkedViewed = true
            onViewed()
        }
    }
}

// MARK: - Feynman (voice + keyword scoring)

struct FeynmanPostView: View {
    let prompt: String
    let expectedKeywords: [String]
    let accent: Color
    let onAnswer: (PostAnswer) -> Void

    @State private var transcript = ""
    @State private var isRecording = false
    @State private var feedback: String?
    @State private var score: Int?

    @State private var recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var request: SFSpeechAudioBufferRecognitionRequest?

    var body: some View {
        FullScreenPost(icon: "mic.fill", label: "Erkläre es", accent: accent) {
            Text(prompt)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !transcript.isEmpty {
                Text(transcript)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            }

            if let fb = feedback, let s = score {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: s >= 60 ? "checkmark.seal.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(s >= 60 ? .green : .orange)
                        Text("Score: \(s)/100")
                            .font(.headline)
                            .foregroundStyle(s >= 60 ? .green : .orange)
                    }
                    Text(fb)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            }

            Spacer()

            if feedback == nil {
                Button {
                    isRecording ? stopRecording() : startRecording()
                } label: {
                    HStack {
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        Text(isRecording ? "Aufnahme stoppen" : "Erklärung aufnehmen")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background((isRecording ? Color.red : accent).gradient, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Recording

    private func startRecording() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()
        isRecording = true

        recognitionTask = recognizer?.recognitionTask(with: request) { result, _ in
            if let result {
                transcript = result.bestTranscription.formattedString
            }
        }
    }

    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        isRecording = false

        evaluate()
    }

    private func evaluate() {
        let lower = transcript.lowercased()
        let hits = expectedKeywords.filter { lower.contains($0.lowercased()) }
        let s = expectedKeywords.isEmpty ? 0 : Int(Double(hits.count) / Double(expectedKeywords.count) * 100)
        let missed = expectedKeywords.filter { !lower.contains($0.lowercased()) }

        let fb: String
        if s >= 80 {
            fb = "Sehr gut! Du hast die wichtigsten Konzepte erklärt."
        } else if s >= 50 {
            fb = "Solide. Vielleicht noch Begriffe wie: \(missed.prefix(3).joined(separator: ", "))"
        } else {
            fb = "Versuch es noch mal — denke an: \(missed.prefix(3).joined(separator: ", "))"
        }

        score = s
        feedback = fb
        onAnswer(.feynman(transcript: transcript, feedback: fb, score: s))
    }
}
