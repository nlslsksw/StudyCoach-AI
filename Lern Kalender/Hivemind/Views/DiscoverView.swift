import SwiftUI

struct DiscoverCategory: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let colorHex: String
    let suggestions: [String]
}

enum DiscoverCatalog {
    static let all: [DiscoverCategory] = [
        DiscoverCategory(name: "Naturwissenschaften", icon: "leaf.fill", colorHex: "#10B981",
            suggestions: ["Photosynthese", "Newtons Gesetze", "DNA-Struktur", "Evolution", "Plattentektonik"]),
        DiscoverCategory(name: "Sprachen", icon: "globe", colorHex: "#0EA5E9",
            suggestions: ["Englische Zeitformen", "Französische Aussprache", "Spanische Verben", "Lateinische Wurzeln"]),
        DiscoverCategory(name: "Geschichte", icon: "building.columns.fill", colorHex: "#F59E0B",
            suggestions: ["Römisches Reich", "Französische Revolution", "Industrielle Revolution", "Kalter Krieg"]),
        DiscoverCategory(name: "Mathematik", icon: "function", colorHex: "#8B5CF6",
            suggestions: ["Bruchrechnung", "Quadratische Gleichungen", "Geometrie", "Wahrscheinlichkeit"]),
        DiscoverCategory(name: "Musik", icon: "music.note", colorHex: "#EC4899",
            suggestions: ["Notenlesen", "Akkorde", "Musikepochen", "Instrumentenkunde"]),
        DiscoverCategory(name: "Sport", icon: "figure.run", colorHex: "#EF4444",
            suggestions: ["Trainingslehre", "Fußball-Regeln", "Anatomie der Muskeln"]),
        DiscoverCategory(name: "Allgemeinwissen", icon: "lightbulb.fill", colorHex: "#F97316",
            suggestions: ["Kritisches Denken", "Logik-Rätsel", "Welt-Geographie", "Berühmte Erfindungen"])
    ]
}

struct DiscoverView: View {
    @Environment(\.dismiss) private var dismiss
    var onTopicCreated: (Topic) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(DiscoverCatalog.all) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: category.icon)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background((Color(hivemindHex: category.colorHex) ?? .purple).gradient, in: RoundedRectangle(cornerRadius: 8))
                                Text(category.name).font(.headline)
                            }
                            .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(category.suggestions, id: \.self) { suggestion in
                                        Button {
                                            createDiscoverTopic(category: category, suggestion: suggestion)
                                        } label: {
                                            Text(suggestion)
                                                .font(.subheadline.bold())
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background((Color(hivemindHex: category.colorHex) ?? .purple).opacity(0.15), in: Capsule())
                                                .foregroundStyle(Color(hivemindHex: category.colorHex) ?? .purple)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Entdecken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }

    private func createDiscoverTopic(category: DiscoverCategory, suggestion: String) {
        let topic = Topic(
            title: suggestion,
            subject: nil,
            iconName: category.icon,
            colorHex: category.colorHex,
            source: .manual(prompt: suggestion),
            isDiscover: true
        )
        TopicStore.shared.addTopic(topic)
        onTopicCreated(topic)
        dismiss()
    }
}
