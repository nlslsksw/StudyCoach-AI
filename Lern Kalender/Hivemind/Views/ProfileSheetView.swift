import SwiftUI

struct ProfileSheetView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore
    private let engine = LearningEngine.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    levelHeader
                    subjectMasterySection
                    badgesSection
                    Spacer(minLength: 20)
                }
                .padding(.top, 8)
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private var levelHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color(.systemGray5), lineWidth: 8).frame(width: 90, height: 90)
                Circle()
                    .trim(from: 0, to: engine.profile.levelProgress)
                    .stroke(Color.purple, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                Text("\(engine.profile.level)").font(.largeTitle.bold())
            }

            Text(engine.profile.levelTitle).font(.headline)
            Text("\(engine.profile.totalXP) XP")
                .font(.subheadline)
                .foregroundStyle(.purple)
            Text("\(engine.profile.xpForNextLevel - engine.profile.totalXP) XP bis Level \(engine.profile.level + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 24) {
                statTile(icon: "flame.fill", value: "\(engine.profile.streakDays)", label: "Tage Streak", color: .orange)
                statTile(icon: "checkmark.seal.fill", value: "\(engine.quizStats.total)", label: "Quizze", color: .green)
                statTile(icon: "rectangle.stack.fill", value: "\(engine.spacedCards.count)", label: "Karten", color: .pink)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private func statTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.headline)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var subjectMasterySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fächer").font(.headline).padding(.horizontal)

            ForEach(store.subjects) { subject in
                let mastery = engine.masteryForSubject(subject.name)
                let xp = engine.profile.xpPerSubject[subject.name] ?? 0
                let level = engine.profile.subjectLevel(for: subject.name)

                HStack(spacing: 12) {
                    Image(systemName: subject.icon)
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(subject.color.gradient, in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(subject.name).font(.subheadline.bold())
                            Spacer()
                            Text("Lv.\(level)").font(.caption.bold()).foregroundStyle(.purple)
                        }
                        ProgressView(value: mastery).tint(subject.color)
                        HStack {
                            Text("\(xp) XP").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            if mastery > 0 {
                                Text("\(Int(mastery * 100))% gemeistert")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            }
        }
    }

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Erfolge").font(.headline).padding(.horizontal)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                ForEach(Badge.allBadges) { badge in
                    let earned = engine.profile.badges.contains(where: { $0.id == badge.id })
                    VStack(spacing: 4) {
                        Image(systemName: badge.icon)
                            .font(.title2)
                            .foregroundStyle(earned ? .yellow : .secondary.opacity(0.3))
                        Text(badge.name)
                            .font(.caption2)
                            .foregroundStyle(earned ? .primary : .tertiary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
    }
}
