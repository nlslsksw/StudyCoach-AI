import SwiftUI
import PhotosUI
import Vision

struct StudyPlanView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore

    @State private var step: PlanStep = .photo
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var recognizedText = ""
    @State private var subject = ""
    @State private var examDate = Date().addingTimeInterval(7 * 86400)
    @State private var planDays: [StudyPlanDay] = []
    @State private var error: String?
    @State private var isRecognizing = false

    enum PlanStep {
        case photo, confirm, generating, preview
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .photo:
                    photoStep
                case .confirm:
                    confirmStep
                case .generating:
                    generatingStep
                case .preview:
                    previewStep
                }
            }
            .navigationTitle("Lernplan erstellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
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
    }

    // MARK: - Photo Step

    private var photoStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Foto von Schulaufgaben")
                .font(.title2.bold())

            Text("Mache ein Foto von deinen Aufgaben oder wähle ein Bild aus der Galerie.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if !GeminiService.shared.hasAPIKey {
                VStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.orange)
                    Text("Kein Gemini API-Key")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                    Text("Bitte zuerst in den Einstellungen eingeben.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Bild auswählen", systemImage: "photo.on.rectangle")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if isRecognizing {
                ProgressView("Text wird erkannt...")
            }

            Spacer()
        }
        .padding()
        .onChange(of: selectedPhoto) { _, newValue in
            guard let item = newValue else { return }
            loadAndRecognize(item: item)
        }
    }

    // MARK: - Confirm Step

    private var confirmStep: some View {
        Form {
            Section {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Section("Erkannter Text") {
                TextEditor(text: $recognizedText)
                    .frame(minHeight: 120)
                    .font(.subheadline)
            }

            Section("Fach") {
                if !store.subjects.isEmpty {
                    Picker("Fach", selection: $subject) {
                        Text("Auswählen...").tag("")
                        ForEach(store.subjects) { sub in
                            Text(sub.name).tag(sub.name)
                        }
                    }
                } else {
                    TextField("Fach eingeben", text: $subject)
                }
            }

            Section("Klassenarbeit am") {
                DatePicker("Datum", selection: $examDate, in: Date()..., displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "de_DE"))
            }

            Section {
                Button {
                    generatePlan()
                } label: {
                    HStack {
                        Spacer()
                        Label("Lernplan erstellen", systemImage: "sparkles")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || subject.isEmpty)
            }
        }
    }

    // MARK: - Generating Step

    private var generatingStep: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Lernplan wird erstellt...")
                .font(.headline)
            Text("Das kann einen Moment dauern.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Preview Step

    private var previewStep: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.blue)
                    Text("Lernplan für \(subject)")
                        .font(.headline)
                }
            }

            Section("Tagesplan") {
                ForEach(planDays) { day in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if let date = day.date {
                                Text(date, format: .dateTime.weekday(.wide).day().month())
                                    .font(.caption.bold())
                                    .foregroundStyle(.blue)
                            } else {
                                Text(day.day)
                                    .font(.caption.bold())
                                    .foregroundStyle(.blue)
                            }
                            Text(day.topic)
                                .font(.subheadline)
                        }
                        Spacer()
                        Text("\(day.duration) min")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Button {
                    savePlan()
                } label: {
                    HStack {
                        Spacer()
                        Label("Im Kalender speichern", systemImage: "calendar.badge.plus")
                            .font(.headline)
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            }

            Section {
                Button {
                    step = .confirm
                } label: {
                    HStack {
                        Spacer()
                        Text("Nochmal generieren")
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadAndRecognize(item: PhotosPickerItem) {
        isRecognizing = true
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                await MainActor.run {
                    error = "Bild konnte nicht geladen werden."
                    isRecognizing = false
                }
                return
            }

            await MainActor.run { image = uiImage }

            let text = await recognizeText(in: uiImage)

            await MainActor.run {
                isRecognizing = false
                if text.isEmpty {
                    error = "Kein Text erkannt. Versuche ein deutlicheres Foto."
                } else {
                    recognizedText = text
                    step = .confirm
                }
            }
        }
    }

    private func recognizeText(in image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["de-DE", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    private func generatePlan() {
        step = .generating
        Task {
            do {
                let days = try await GeminiService.shared.generateStudyPlan(
                    text: recognizedText,
                    subject: subject,
                    examDate: examDate
                )
                await MainActor.run {
                    planDays = days
                    step = .preview
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    step = .confirm
                }
            }
        }
    }

    private func savePlan() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for day in planDays {
            if let date = dateFormatter.date(from: day.day) {
                let entry = CalendarEntry(
                    title: "\(subject): \(day.topic)",
                    date: date,
                    type: .lerntag,
                    notes: "KI-Lernplan (\(day.duration) min)"
                )
                store.addEntry(entry)
            }
        }
        dismiss()
    }
}
