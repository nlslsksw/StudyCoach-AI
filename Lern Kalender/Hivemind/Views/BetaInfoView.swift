import SwiftUI

struct BetaInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    noticesSection
                    worksSection
                    comingSoonSection
                    privacySection
                    Spacer(minLength: 8)
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }
            .navigationTitle("KI-Beta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Verstanden") { dismiss() }
                        .font(.subheadline.bold())
                        .foregroundStyle(.purple)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                Image(systemName: "sparkles")
                    .font(.body)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("KI-Funktionen")
                        .font(.headline)
                    Text("BETA")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.pink.gradient, in: Capsule())
                }
                Text("Neu und noch in Entwicklung")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Sections

    private var noticesSection: some View {
        section(title: "Wichtig", icon: "exclamationmark.triangle.fill", color: .orange) {
            VStack(alignment: .leading, spacing: 8) {
                bullet("KI kann Fehler machen — prüf wichtige Antworten selbst.")
                bullet("Nicht 1:1 in Hausaufgaben oder Klassenarbeiten kopieren.")
                bullet("Antworten können bei jedem Klick anders ausfallen.")
                bullet("Die KI kennt nichts Aktuelles aus den letzten Wochen.")
            }
        }
    }

    private var worksSection: some View {
        section(title: "Was schon geht", icon: "checkmark.circle.fill", color: .green) {
            VStack(alignment: .leading, spacing: 6) {
                feature("Chat mit der KI")
                feature("Lernpläne aus Foto")
                feature("Quiz & Karteikarten generieren")
                feature("Lern-Feed (Hivemind) mit Topics")
                feature("Eltern-Topics zuweisen")
            }
        }
    }

    private var comingSoonSection: some View {
        section(title: "Bald", icon: "hourglass", color: .purple) {
            VStack(alignment: .leading, spacing: 6) {
                feature("Bilder & Memes")
                feature("Podcast-Import")
                feature("Audio-Lektionen")
            }
        }
    }

    private var privacySection: some View {
        section(title: "Datenschutz", icon: "lock.shield.fill", color: .teal) {
            Text("KI-Eingaben gehen an Groq als externen Anbieter — speicher dort keine sensiblen Daten. Lerndaten bleiben in der App und werden nur über iCloud mit deinen Geräten und Eltern geteilt.")
                .font(.footnote)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Reusable section chrome

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(color.gradient, in: Circle())
                Text(title)
                    .font(.subheadline.bold())
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(.orange)
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func feature(_ title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.caption2.bold())
                .foregroundStyle(.green)
                .frame(width: 14)
            Text(title)
                .font(.footnote)
        }
    }
}

// MARK: - Auto-show on first launch helper

enum BetaInfoTracker {
    private static let key = "hivemindBetaInfoSeen"

    static var hasSeenBeta: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
