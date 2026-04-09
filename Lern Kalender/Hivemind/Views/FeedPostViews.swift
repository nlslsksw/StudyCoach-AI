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

// MARK: - Common card chrome

private struct PostCard<Content: View>: View {
    let icon: String
    let label: String
    let accent: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(accent.gradient, in: Circle())
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal)
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
        PostCard(icon: "lightbulb.fill", label: "Lektion", accent: accent) {
            Text(title)
                .font(.title3.bold())
            Text(bodyText)
                .font(.body)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
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
        PostCard(icon: "questionmark.circle.fill", label: "Quiz", accent: accent) {
            Text(question)
                .font(.title3.bold())

            VStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.offset) { idx, option in
                    Button {
                        guard selected == nil else { return }
                        selected = idx
                        onAnswer(.quiz(selectedIndex: idx, correct: idx == correctIndex))
                    } label: {
                        HStack {
                            Text(option).font(.subheadline)
                            Spacer()
                            if let s = selected {
                                if idx == correctIndex {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                } else if idx == s {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(answerBackground(idx), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14).stroke(answerBorder(idx), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(selected != nil)
                }
            }

            if selected != nil {
                Text(explanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private func answerBackground(_ idx: Int) -> Color {
        guard let s = selected else { return Color(.tertiarySystemGroupedBackground) }
        if idx == correctIndex { return .green.opacity(0.15) }
        if idx == s { return .red.opacity(0.15) }
        return Color(.tertiarySystemGroupedBackground)
    }

    private func answerBorder(_ idx: Int) -> Color {
        guard let s = selected else { return Color(.separator).opacity(0.3) }
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
        PostCard(icon: "rectangle.on.rectangle", label: "Karteikarte", accent: accent) {
            Text(flipped ? back : front)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding(.vertical, 12)
                .onTapGesture { withAnimation(.spring(response: 0.4)) { flipped.toggle() } }

            if !flipped {
                Text("Tippe zum Umdrehen")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if !answered {
                HStack(spacing: 12) {
                    Button {
                        answered = true
                        onAnswer(.flashcard(known: false))
                    } label: {
                        Label("Wusste ich nicht", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button {
                        answered = true
                        onAnswer(.flashcard(known: true))
                    } label: {
                        Label("Wusste ich", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            } else {
                Text("Gespeichert ✓")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
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
        PostCard(icon: "wand.and.stars", label: "Beispiel", accent: accent) {
            Text(scenario)
                .font(.title3.bold())
            Text(walkthrough)
                .font(.body)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
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
        PostCard(icon: "mic.fill", label: "Erkläre es", accent: accent) {
            Text(prompt)
                .font(.title3.bold())

            if !transcript.isEmpty {
                Text(transcript)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }

            if let fb = feedback, let s = score {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Score: \(s)/100")
                        .font(.caption.bold())
                        .foregroundStyle(s >= 60 ? .green : .orange)
                    Text(fb)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Button {
                    isRecording ? stopRecording() : startRecording()
                } label: {
                    Label(isRecording ? "Aufnahme stoppen" : "Erklärung aufnehmen",
                          systemImage: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isRecording ? .red : accent)
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
