import SwiftUI
import PhotosUI
import Vision

// MARK: - Content Library

struct AIContentLibrary: View {
    var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingNewQuiz = false
    @State private var showingNewFlashcards = false
    @State private var showingPhotoFlashcards = false

    @State private var savedQuizzes: [SavedQuiz] = []
    @State private var savedFlashcardSets: [SavedFlashcardSet] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Erstellen-Buttons
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        createCard(icon: "questionmark.circle.fill", title: "Quiz", color: .pink) {
                            showingNewQuiz = true
                        }
                        createCard(icon: "rectangle.on.rectangle", title: "Karten", color: .purple) {
                            showingNewFlashcards = true
                        }
                        createCard(icon: "camera.fill", title: "Foto-Vokabeln", color: .blue) {
                            showingPhotoFlashcards = true
                        }
                    }
                    .padding(.horizontal)

                    // Gespeicherte Quizze
                    if !savedQuizzes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quizze")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(savedQuizzes) { quiz in
                                NavigationLink {
                                    QuizPlayView(quiz: quiz)
                                } label: {
                                    contentRow(
                                        icon: "questionmark.circle.fill",
                                        color: .pink,
                                        title: quiz.title,
                                        subtitle: "\(quiz.questions.count) Fragen"
                                    )
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        savedQuizzes.removeAll { $0.id == quiz.id }
                                        saveAll()
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    // Gespeicherte Karteikarten
                    if !savedFlashcardSets.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Karteikarten")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(savedFlashcardSets) { set in
                                NavigationLink {
                                    FlashcardPlayView(cardSet: set)
                                } label: {
                                    contentRow(
                                        icon: "rectangle.on.rectangle",
                                        color: .purple,
                                        title: set.title,
                                        subtitle: "\(set.cards.count) Karten"
                                    )
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        savedFlashcardSets.removeAll { $0.id == set.id }
                                        saveAll()
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    if savedQuizzes.isEmpty && savedFlashcardSets.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundStyle(.tertiary)
                            Text("Noch keine Inhalte")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Erstelle Quizze oder Karteikarten mit KI")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 40)
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("Inhalte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(isPresented: $showingNewQuiz) {
                CreateQuizView(store: store) { quiz in
                    savedQuizzes.insert(quiz, at: 0)
                    saveAll()
                }
            }
            .sheet(isPresented: $showingNewFlashcards) {
                CreateFlashcardsView(store: store) { set in
                    savedFlashcardSets.insert(set, at: 0)
                    saveAll()
                }
            }
            .sheet(isPresented: $showingPhotoFlashcards) {
                PhotoFlashcardsView(store: store) { set in
                    savedFlashcardSets.insert(set, at: 0)
                    saveAll()
                }
            }
            .onAppear { loadAll() }
        }
    }

    private func createCard(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 12))
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func contentRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func loadAll() {
        if let data = UserDefaults.standard.data(forKey: "savedQuizzes"),
           let decoded = try? JSONDecoder().decode([SavedQuiz].self, from: data) {
            savedQuizzes = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "savedFlashcardSets"),
           let decoded = try? JSONDecoder().decode([SavedFlashcardSet].self, from: data) {
            savedFlashcardSets = decoded
        }
    }

    private func saveAll() {
        if let data = try? JSONEncoder().encode(savedQuizzes) {
            UserDefaults.standard.set(data, forKey: "savedQuizzes")
        }
        if let data = try? JSONEncoder().encode(savedFlashcardSets) {
            UserDefaults.standard.set(data, forKey: "savedFlashcardSets")
        }
    }
}

// MARK: - Models

struct SavedQuiz: Identifiable, Codable {
    var id = UUID()
    var title: String
    var subject: String
    var questions: [QuizQuestion]
    var date: Date = Date()
}

struct SavedFlashcardSet: Identifiable, Codable {
    var id = UUID()
    var title: String
    var subject: String
    var cards: [Flashcard]
    var date: Date = Date()
}

// MARK: - Create Quiz

struct CreateQuizView: View {
    var store: DataStore
    var onSave: (SavedQuiz) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var subject = ""
    @State private var topic = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Quiz erstellen") {
                    if !store.subjects.isEmpty {
                        Picker("Fach", selection: $subject) {
                            Text("Auswählen...").tag("")
                            ForEach(store.subjects) { sub in
                                Text(sub.name).tag(sub.name)
                            }
                        }
                    } else {
                        TextField("Fach", text: $subject)
                    }
                    TextField("Thema (z.B. Bruchrechnung)", text: $topic)
                }

                Section {
                    Button {
                        generate()
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                Text("Quiz wird erstellt...").font(.subheadline)
                            } else {
                                Label("Quiz generieren", systemImage: "sparkles").font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(subject.isEmpty || topic.isEmpty || isLoading)
                }

                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Neues Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
    }

    private func generate() {
        isLoading = true; error = nil
        Task {
            do {
                let questions = try await AIService.shared.generateQuiz(subject: subject, topic: topic)
                let quiz = SavedQuiz(title: "\(subject): \(topic)", subject: subject, questions: questions)
                await MainActor.run { onSave(quiz); dismiss() }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; isLoading = false }
            }
        }
    }
}

// MARK: - Create Flashcards

struct CreateFlashcardsView: View {
    var store: DataStore
    var onSave: (SavedFlashcardSet) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var subject = ""
    @State private var topic = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Karteikarten erstellen") {
                    if !store.subjects.isEmpty {
                        Picker("Fach", selection: $subject) {
                            Text("Auswählen...").tag("")
                            ForEach(store.subjects) { sub in
                                Text(sub.name).tag(sub.name)
                            }
                        }
                    } else {
                        TextField("Fach", text: $subject)
                    }
                    TextField("Thema", text: $topic)
                }

                Section {
                    Button {
                        generate()
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                Text("Karten werden erstellt...").font(.subheadline)
                            } else {
                                Label("Karteikarten generieren", systemImage: "sparkles").font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(subject.isEmpty || topic.isEmpty || isLoading)
                }

                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Neue Karteikarten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
    }

    private func generate() {
        isLoading = true; error = nil
        Task {
            do {
                let cards = try await AIService.shared.generateFlashcards(subject: subject, topic: topic)
                let set = SavedFlashcardSet(title: "\(subject): \(topic)", subject: subject, cards: cards)
                await MainActor.run { onSave(set); dismiss() }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; isLoading = false }
            }
        }
    }
}

// MARK: - Photo Flashcards (Foto -> Vokabeln)

struct PhotoFlashcardsView: View {
    var store: DataStore
    var onSave: (SavedFlashcardSet) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var recognizedText = ""
    @State private var subject = ""
    @State private var isRecognizing = false
    @State private var isGenerating = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Foto von Vokabeln") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(recognizedText.isEmpty ? "Foto auswählen" : "Anderes Foto", systemImage: "camera.fill")
                    }

                    if isRecognizing {
                        ProgressView("Text wird erkannt...")
                    }

                    if !recognizedText.isEmpty {
                        Text(recognizedText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(5)
                    }
                }

                if !recognizedText.isEmpty {
                    Section("Sprache") {
                        TextField("z.B. Englisch", text: $subject)
                    }

                    Section {
                        Button {
                            generateCards()
                        } label: {
                            HStack {
                                Spacer()
                                if isGenerating {
                                    ProgressView()
                                    Text("Vokabelkarten werden erstellt...").font(.subheadline)
                                } else {
                                    Label("Vokabelkarten erstellen", systemImage: "sparkles").font(.headline)
                                }
                                Spacer()
                            }
                        }
                        .disabled(subject.isEmpty || isGenerating)
                    }
                }

                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Foto-Vokabeln")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard let item = newValue else { return }
                recognizeText(from: item)
            }
        }
    }

    private func recognizeText(from item: PhotosPickerItem) {
        isRecognizing = true
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let cgImage = image.cgImage else {
                await MainActor.run { isRecognizing = false; error = "Bild konnte nicht geladen werden." }
                return
            }

            let text = await withCheckedContinuation { continuation in
                let request = VNRecognizeTextRequest { request, _ in
                    let observations = request.results as? [VNRecognizedTextObservation] ?? []
                    let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                    continuation.resume(returning: text)
                }
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["de-DE", "en-US", "fr-FR", "es-ES"]
                try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            }

            await MainActor.run {
                recognizedText = text
                isRecognizing = false
                if text.isEmpty { error = "Kein Text erkannt." }
            }
        }
    }

    private func generateCards() {
        isGenerating = true; error = nil
        Task {
            do {
                let prompt = "Erstelle Vokabelkarten aus diesem Text. Sprache: \(subject). Erkenne die Vokabeln und erstelle Karteikarten mit dem Wort auf der Vorderseite und der Übersetzung auf der Rückseite."
                let cards = try await AIService.shared.generateFlashcards(subject: subject, topic: recognizedText)
                let set = SavedFlashcardSet(title: "\(subject)-Vokabeln", subject: subject, cards: cards)
                await MainActor.run { onSave(set); dismiss() }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; isGenerating = false }
            }
        }
    }
}

// MARK: - Quiz Play View

struct QuizPlayView: View {
    let quiz: SavedQuiz
    @State private var currentIndex = 0
    @State private var selectedAnswer: Int?
    @State private var score = 0
    @State private var isFinished = false

    var body: some View {
        if isFinished {
            quizResult
        } else if currentIndex < quiz.questions.count {
            quizQuestion
        }
    }

    private var quizResult: some View {
        VStack(spacing: 20) {
            Spacer()

            let pct = Int(Double(score) / Double(max(quiz.questions.count, 1)) * 100)

            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: Double(pct) / 100)
                    .stroke(pct >= 80 ? Color.green : pct >= 50 ? Color.orange : Color.red, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                Text("\(pct)%")
                    .font(.title.bold())
            }

            Text("Quiz beendet!")
                .font(.title2.bold())

            Text("\(score) von \(quiz.questions.count) richtig")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                currentIndex = 0; selectedAnswer = nil; score = 0; isFinished = false
            } label: {
                Label("Nochmal", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)

            Spacer()
        }
        .navigationTitle(quiz.title)
    }

    private var quizQuestion: some View {
        let question = quiz.questions[currentIndex]

        return VStack(spacing: 16) {
            // Progress
            VStack(spacing: 8) {
                HStack {
                    Text("\(currentIndex + 1)/\(quiz.questions.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("\(score)")
                            .font(.caption.bold())
                    }
                }
                ProgressView(value: Double(currentIndex + 1), total: Double(quiz.questions.count))
                    .tint(.pink)
            }
            .padding(.horizontal)

            // Question
            Text(question.question)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top, 10)

            Spacer()

            // Answers
            VStack(spacing: 10) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    let letters = ["A", "B", "C", "D"]
                    let badgeColors: [Color] = [.pink, .orange, .purple, .blue]

                    Button {
                        guard selectedAnswer == nil else { return }
                        withAnimation(.spring(response: 0.3)) { selectedAnswer = index }
                        if index == question.correctIndex { score += 1 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation {
                                if currentIndex + 1 < quiz.questions.count {
                                    currentIndex += 1; selectedAnswer = nil
                                } else {
                                    isFinished = true
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(letters[min(index, 3)])
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(
                                    selectedAnswer == nil
                                        ? AnyShapeStyle(badgeColors[min(index, 3)].gradient)
                                        : AnyShapeStyle(answerBadgeColor(index: index, question: question).gradient),
                                    in: Circle()
                                )
                            Text(option)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            if let sel = selectedAnswer {
                                if index == question.correctIndex {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.green)
                                } else if index == sel {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(14)
                        .background(answerBgColor(index: index, question: question), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.separator).opacity(0.3), lineWidth: selectedAnswer == nil ? 1 : 0)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedAnswer != nil)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .navigationTitle(quiz.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func answerBadgeColor(index: Int, question: QuizQuestion) -> Color {
        guard let sel = selectedAnswer else { return .secondary }
        if index == question.correctIndex { return .green }
        if index == sel { return .red }
        return .secondary
    }

    private func answerBgColor(index: Int, question: QuizQuestion) -> Color {
        guard let sel = selectedAnswer else { return Color(.secondarySystemGroupedBackground) }
        if index == question.correctIndex { return .green.opacity(0.15) }
        if index == sel { return .red.opacity(0.15) }
        return Color(.secondarySystemGroupedBackground)
    }
}

// MARK: - Flashcard Play View

struct FlashcardPlayView: View {
    let cardSet: SavedFlashcardSet
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var knownCount = 0
    @State private var offset: CGFloat = 0

    var body: some View {
        VStack(spacing: 16) {
            // Progress
            HStack {
                Text("\(currentIndex + 1)/\(cardSet.cards.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("\(knownCount)")
                        .font(.caption.bold())
                }
            }
            .padding(.horizontal)

            ProgressView(value: Double(currentIndex), total: Double(cardSet.cards.count))
                .tint(.purple)
                .padding(.horizontal)

            Spacer()

            if currentIndex < cardSet.cards.count {
                let card = cardSet.cards[currentIndex]

                // Karteikarte
                VStack(spacing: 16) {
                    Text(isFlipped ? "Antwort" : "Frage")
                        .font(.caption.bold())
                        .foregroundStyle(isFlipped ? .green : .purple)

                    Text(isFlipped ? card.back : card.front)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .animation(.none, value: isFlipped)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
                )
                .padding(.horizontal, 20)
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if isFlipped { offset = value.translation.width }
                        }
                        .onEnded { value in
                            if isFlipped {
                                if value.translation.width > 80 {
                                    swipeCard(known: true)
                                } else if value.translation.width < -80 {
                                    swipeCard(known: false)
                                } else {
                                    withAnimation { offset = 0 }
                                }
                            }
                        }
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.4)) { isFlipped.toggle() }
                }

                if !isFlipped {
                    Text("Tippe zum Umdrehen")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    // Swipe Hinweis + Buttons
                    HStack(spacing: 30) {
                        VStack(spacing: 4) {
                            Button { swipeCard(known: false) } label: {
                                Image(systemName: "xmark")
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 50, height: 50)
                                    .background(.red.gradient, in: Circle())
                            }
                            Text("Nochmal").font(.caption2).foregroundStyle(.secondary)
                        }

                        VStack(spacing: 4) {
                            Button { swipeCard(known: true) } label: {
                                Image(systemName: "checkmark")
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 50, height: 50)
                                    .background(.green.gradient, in: Circle())
                            }
                            Text("Gewusst").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 8)

                    Text("oder wische nach links/rechts")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                // Fertig
                VStack(spacing: 16) {
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.purple)

                    Text("Geschafft!")
                        .font(.title2.bold())

                    Text("\(knownCount) von \(cardSet.cards.count) gewusst")
                        .foregroundStyle(.secondary)

                    Button {
                        currentIndex = 0; knownCount = 0; isFlipped = false
                    } label: {
                        Label("Nochmal", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
            }

            Spacer()
        }
        .navigationTitle(cardSet.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func swipeCard(known: Bool) {
        if known { knownCount += 1 }
        withAnimation(.spring(response: 0.3)) {
            offset = known ? 300 : -300
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            offset = 0
            isFlipped = false
            currentIndex += 1
        }
    }
}
