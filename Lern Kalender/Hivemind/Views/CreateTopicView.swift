import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct CreateTopicView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore
    var parentMode: Bool = false
    var pairingCode: String? = nil   // required when parentMode == true

    private enum Mode: String, CaseIterable, Identifiable {
        case manual = "Thema"
        case photo = "Foto"
        case pdf = "PDF"
        case link = "Link"
        case podcast = "Podcast"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .manual: return "text.cursor"
            case .photo: return "camera.fill"
            case .pdf: return "doc.fill"
            case .link: return "link"
            case .podcast: return "headphones"
            }
        }
    }

    @State private var mode: Mode = .manual
    @State private var titleField = ""
    @State private var subjectField = ""
    @State private var manualPrompt = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoText = ""
    @State private var pdfText = ""
    @State private var pdfFilename = ""
    @State private var linkText = ""
    @State private var linkURL = ""
    @State private var isImporting = false
    @State private var showPDFPicker = false
    @State private var error: String?
    @State private var isCreating = false
    @State private var showValidation = false

    var body: some View {
        NavigationStack {
            Form {
                modeSection
                detailsSection
                actionSection
            }
            .navigationTitle(parentMode ? "Topic für Kind" : "Neues Topic")
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
            } message: { Text(error ?? "") }
            .fileImporter(
                isPresented: $showPDFPicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handlePDFResult(result)
            }
        }
    }

    // MARK: - Sections

    private var modeSection: some View {
        Section {
            Picker("Quelle", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Label(m.rawValue, systemImage: m.icon).tag(m)
                }
            }
            .pickerStyle(.menu)
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        Section("Details") {
            TextField("Topic-Titel", text: $titleField)

            if !store.subjects.isEmpty {
                Picker("Fach (optional)", selection: $subjectField) {
                    Text("Keines").tag("")
                    ForEach(store.subjects) { sub in
                        Text(sub.name).tag(sub.name)
                    }
                }
            } else {
                TextField("Fach (optional)", text: $subjectField)
            }

            switch mode {
            case .manual:
                TextField("Was möchtest du lernen?", text: $manualPrompt, axis: .vertical)
                    .lineLimit(2...4)

            case .photo:
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(photoText.isEmpty ? "Bild wählen" : "Bild ändern", systemImage: "photo.on.rectangle")
                }
                if isImporting { ProgressView("Erkenne Text…") }
                if !photoText.isEmpty {
                    Text(photoText).font(.footnote).foregroundStyle(.secondary).lineLimit(4)
                }

            case .pdf:
                Button {
                    showPDFPicker = true
                } label: {
                    Label(pdfFilename.isEmpty ? "PDF wählen" : pdfFilename, systemImage: "doc.fill")
                }
                if isImporting { ProgressView("Lese PDF…") }
                if !pdfText.isEmpty {
                    Text(pdfText.prefix(200)).font(.footnote).foregroundStyle(.secondary).lineLimit(4)
                }

            case .link:
                TextField("https://…", text: $linkURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !linkText.isEmpty {
                    Text(linkText.prefix(200)).font(.footnote).foregroundStyle(.secondary).lineLimit(4)
                }

            case .podcast:
                Text("Podcast-Import kommt bald.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await loadAndOCR(item) }
        }
    }

    private var actionSection: some View {
        Section {
            Button {
                if !canSubmit {
                    showValidation = true
                } else {
                    Task { await createTopic() }
                }
            } label: {
                HStack {
                    Spacer()
                    if isCreating {
                        ProgressView()
                        Text("Topic wird erstellt…")
                    } else {
                        Label(parentMode ? "Topic dem Kind zuweisen" : "Topic erstellen",
                              systemImage: "sparkles")
                            .font(.headline)
                    }
                    Spacer()
                }
            }
            .disabled(isCreating || mode == .podcast)
            .alert("Fehlende Angaben", isPresented: $showValidation) {
                Button("OK") { }
            } message: {
                if titleField.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Bitte gib einen Topic-Titel ein.")
                } else {
                    Text("Bitte fülle die Quelle aus (Thema, Foto, PDF oder Link).")
                }
            }
        }
    }

    // MARK: - Validation

    private var canSubmit: Bool {
        if titleField.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        switch mode {
        case .manual: return !manualPrompt.trimmingCharacters(in: .whitespaces).isEmpty
        case .photo: return !photoText.isEmpty
        case .pdf: return !pdfText.isEmpty
        case .link: return URL(string: linkURL) != nil
        case .podcast: return false
        }
    }

    // MARK: - Actions

    private func loadAndOCR(_ item: PhotosPickerItem) async {
        isImporting = true
        defer { isImporting = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            error = "Bild konnte nicht geladen werden."
            return
        }
        do {
            let text = try await TopicSourceImporter.extractText(from: image)
            await MainActor.run { self.photoText = text }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    private func handlePDFResult(_ result: Result<[URL], Error>) {
        isImporting = true
        defer { isImporting = false }
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            // Security-scoped resource access for files outside the sandbox.
            let needsAccess = url.startAccessingSecurityScopedResource()
            defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let text = try TopicSourceImporter.extractText(from: data)
            self.pdfText = text
            self.pdfFilename = url.lastPathComponent
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func createTopic() async {
        isCreating = true
        defer { isCreating = false }

        // For .link mode, fetch text first.
        if mode == .link, linkText.isEmpty, let url = URL(string: linkURL) {
            do {
                linkText = try await TopicSourceImporter.extractText(from: url)
            } catch {
                self.error = error.localizedDescription
                return
            }
        }

        let source: TopicSource = {
            switch mode {
            case .manual: return .manual(prompt: manualPrompt)
            case .photo: return .photoOCR(text: photoText)
            case .pdf: return .pdf(filename: pdfFilename, text: pdfText)
            case .link: return .webLink(url: URL(string: linkURL)!, text: linkText)
            case .podcast: return .manual(prompt: titleField) // unreachable
            }
        }()

        let topic = Topic(
            title: titleField,
            subject: subjectField.isEmpty ? nil : subjectField,
            iconName: "sparkles",
            colorHex: "#7C3AED",
            source: source,
            assignedByParent: parentMode
        )

        if parentMode, let pairingCode {
            await CloudKitService.shared.assignTopicToChild(topic, pairingCode: pairingCode)
        } else {
            TopicStore.shared.addTopic(topic)
        }

        dismiss()
    }
}
