import SwiftUI

// MARK: - Onboarding (first-launch experience)

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "calendar",
            iconColors: [.blue, .cyan],
            title: "Willkommen im Lern Kalender",
            subtitle: "Plane deine Schule. Tracke deine Lernzeit. Behalte den Überblick."
        ),
        OnboardingPage(
            icon: "chart.bar.fill",
            iconColors: [.green, .mint],
            title: "Statistiken & Streak",
            subtitle: "Sieh deine Fortschritte. Halte deine Lern-Serie. Erhalte einen Schuljahres-Wrapped."
        ),
        OnboardingPage(
            icon: "sparkles",
            iconColors: [.pink, .purple],
            title: "KI-Lern-Assistent (Beta)",
            subtitle: "Stelle Fragen, erstelle Lernpläne aus Foto, generiere Quiz und Karteikarten. KI kann Fehler machen — prüf Antworten selbst."
        ),
        OnboardingPage(
            icon: "brain.head.profile",
            iconColors: [.purple, .indigo],
            title: "Lern-Feed (Hivemind)",
            subtitle: "Scroll dich schlauer. Kurze Lektionen, Quiz, Karteikarten und Sprach-Übungen — wie ein Feed, nur lehrreich."
        ),
        OnboardingPage(
            icon: "person.2.fill",
            iconColors: [.orange, .red],
            title: "Familie & Eltern",
            subtitle: "Eltern können Lernfortschritte einsehen, Topics zuweisen und motivieren. Sicher über iCloud verbunden."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { idx, page in
                    pageView(page).tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .indexViewStyle(.page(backgroundDisplayMode: .never))

            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { idx in
                    Capsule()
                        .fill(idx == currentPage ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: idx == currentPage ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.4), value: currentPage)
                }
            }
            .padding(.bottom, 16)

            // Bottom button
            Button {
                if currentPage < pages.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    OnboardingTracker.markCompleted()
                    dismiss()
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "Weiter" : "Loslegen")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            if currentPage > 0 {
                Button("Überspringen") {
                    OnboardingTracker.markCompleted()
                    dismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
            }
        }
        .background(Color(.systemBackground))
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient(colors: page.iconColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 140, height: 140)
                    .shadow(color: page.iconColors.first?.opacity(0.4) ?? .clear, radius: 30, y: 12)
                Image(systemName: page.icon)
                    .font(.system(size: 64, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Page model

private struct OnboardingPage {
    let icon: String
    let iconColors: [Color]
    let title: String
    let subtitle: String
}

// MARK: - Tracker

enum OnboardingTracker {
    private static let key = "didCompleteOnboarding"

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: key)
    }
}
