import SwiftUI

struct BetaInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    whatIsBetaSection
                    importantNoticesSection
                    worksSection
                    comingSoonSection
                    privacySection
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Beta-Info")
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
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 8) {
                Text("KI-Funktionen")
                    .font(.title.bold())
                Text("BETA")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.pink.gradient, in: Capsule())
            }

            Text("Diese Funktionen sind neu und werden noch verbessert.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - What is Beta

    private var whatIsBetaSection: some View {
        section(title: "Was bedeutet Beta?", icon: "info.circle.fill", color: .blue) {
            Text("Beta heißt: das Feature funktioniert, ist aber noch in Entwicklung. Es kann Fehler geben, Antworten können falsch sein, und die Bedienung kann sich ändern.")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Important Notices

    private var importantNoticesSection: some View {
        section(title: "Wichtige Hinweise", icon: "exclamationmark.triangle.fill", color: .orange) {
            VStack(alignment: .leading, spacing: 12) {
                bullet("KI kann Fehler machen — prüf wichtige Antworten immer selbst nach.", icon: "checkmark.shield")
                bullet("Kopiere KI-Antworten nicht 1:1 in Hausaufgaben oder Klassenarbeiten.", icon: "doc.on.clipboard")
                bullet("Antworten können bei jedem Klick anders sein, auch bei derselben Frage.", icon: "arrow.triangle.2.circlepath")
                bullet("Die KI kennt nichts Aktuelles aus den letzten Wochen.", icon: "calendar.badge.exclamationmark")
            }
        }
    }

    // MARK: - What works

    private var worksSection: some View {
        section(title: "Was schon geht", icon: "checkmark.circle.fill", color: .green) {
            VStack(alignment: .leading, spacing: 10) {
                feature("Chat mit der KI", subtitle: "Fragen, Erklärungen, Lerntipps")
                feature("KI-Lernpläne aus Foto", subtitle: "Heft fotografieren → Lernplan im Kalender")
                feature("Quiz & Karteikarten generieren", subtitle: "Aus jedem Thema, automatisch")
                feature("Lern-Feed (Hivemind)", subtitle: "TikTok-Style Topics mit Mikro-Lektionen, Quiz, Feynman-Modus")
                feature("Eltern können Topics zuweisen", subtitle: "Aus dem Eltern-Dashboard heraus")
            }
        }
    }

    // MARK: - Coming soon

    private var comingSoonSection: some View {
        section(title: "Was bald kommt", icon: "hourglass", color: .purple) {
            VStack(alignment: .leading, spacing: 10) {
                feature("Bild- und Meme-Generierung", subtitle: "Visuelle Lerninhalte im Feed")
                feature("Podcast-Import", subtitle: "Folge reinwerfen → Lerninhalte daraus machen")
                feature("Audio-Posts mit Sprachausgabe", subtitle: "Lernen unterwegs ohne Bildschirm")
            }
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        section(title: "Datenschutz", icon: "lock.shield.fill", color: .teal) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Wenn du die KI nutzt, werden deine Eingaben an einen externen KI-Anbieter geschickt (Groq). Speicher dort keine sensiblen persönlichen Daten.")
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Deine Lerndaten (Topics, Karteikarten, Lernzeit) bleiben in der App und werden nur über iCloud zwischen deinen Geräten und mit deinen Eltern (wenn verbunden) geteilt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body.bold())
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(color.gradient, in: Circle())
                Text(title)
                    .font(.headline)
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func bullet(_ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.orange)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func feature(_ title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(.green.gradient, in: Circle())
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
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
