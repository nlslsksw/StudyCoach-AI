import SwiftUI

// MARK: - Onboarding (first-launch experience)

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            kind: .image("onboarding-calendar"),
            accent: .blue,
            title: "Willkommen bei StudiCoach AI",
            subtitle: "Plane deine Schule. Trag deine Lernzeiten ein. Behalte den Überblick über alle Klassenarbeiten."
        ),
        OnboardingPage(
            kind: .image("onboarding-subjects"),
            accent: .green,
            title: "Fächer & Noten",
            subtitle: "Verwalte alle Fächer eines Schuljahres. Jedes Fach mit Noten, Lernzeit und Schnitt."
        ),
        OnboardingPage(
            kind: .image("onboarding-statistics"),
            accent: .orange,
            title: "Statistiken & Streak",
            subtitle: "Sieh deine Fortschritte. Halte deine Lern-Serie. Schau, wo du diese Woche stehst."
        ),
        OnboardingPage(
            kind: .image("onboarding-ai"),
            accent: .pink,
            title: "KI-Lern-Assistent",
            subtitle: "Sag der KI 'trag 90 Minuten Englisch ein' — sie macht es. Frage Themen ab. Lass dir Lernpläne erstellen. (Beta)"
        ),
        OnboardingPage(
            kind: .image("onboarding-hivemind"),
            accent: .purple,
            title: "Lern-Feed (Hivemind)",
            subtitle: "Scroll dich schlauer. Kurze Lektionen, Quiz, Karteikarten und Sprach-Übungen — wie ein Feed, nur lehrreich."
        ),
        OnboardingPage(
            kind: .icon("person.2.fill", colors: [.orange, .red]),
            accent: .red,
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
            .padding(.bottom, 12)

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
            .padding(.bottom, 12)

            if currentPage > 0 {
                Button("Überspringen") {
                    OnboardingTracker.markCompleted()
                    dismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)
            }
        }
        .background(Color(.systemBackground))
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)

            Group {
                switch page.kind {
                case .image(let name):
                    screenshotFrame(imageName: name, accent: page.accent)
                case .icon(let symbol, let colors):
                    iconCircle(symbol: symbol, colors: colors)
                }
            }

            VStack(spacing: 10) {
                Text(page.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(page.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 8)

            Spacer(minLength: 0)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func screenshotFrame(imageName: String, accent: Color) -> some View {
        ZStack {
            // Soft tinted background pad behind the screen
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.18), accent.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Inset screenshot styled as a phone display
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: accent.opacity(0.25), radius: 20, y: 10)
                .padding(20)
        }
        .frame(maxHeight: 460)
        .padding(.horizontal, 28)
    }

    @ViewBuilder
    private func iconCircle(symbol: String, colors: [Color]) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 180, height: 180)
                .shadow(color: colors.first?.opacity(0.4) ?? .clear, radius: 30, y: 12)
            Image(systemName: symbol)
                .font(.system(size: 80, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(maxHeight: 460)
    }
}

// MARK: - Page model

private struct OnboardingPage {
    enum Kind {
        case image(String)
        case icon(String, colors: [Color])
    }
    let kind: Kind
    let accent: Color
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
