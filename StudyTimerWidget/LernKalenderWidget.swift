//
//  LernKalenderWidget.swift
//  Zeigt auf dem Home-Bildschirm, was heute ansteht: gelernte Zeit, Lern-Serie,
//  nächste Klassenarbeit und offene Hausaufgaben.
//

import WidgetKit
import SwiftUI

struct LernEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct LernProvider: TimelineProvider {
    func placeholder(in context: Context) -> LernEntry {
        var demo = WidgetSnapshot()
        demo.minutesToday = 45
        demo.streakDays = 12
        demo.goalMinutes = 45
        demo.nextExamTitle = "Mathe Klassenarbeit"
        demo.nextExamDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())
        demo.openHomework = 2
        return LernEntry(date: Date(), snapshot: demo)
    }

    func getSnapshot(in context: Context, completion: @escaping (LernEntry) -> Void) {
        completion(LernEntry(date: Date(), snapshot: context.isPreview ? placeholder(in: context).snapshot : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LernEntry>) -> Void) {
        let entry = LernEntry(date: Date(), snapshot: WidgetSnapshot.load())
        // bis Mitternacht gültig – danach ist „heute" ein anderer Tag
        let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

private func daysUntil(_ date: Date) -> Int {
    let cal = Calendar.current
    return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
}

private func formatMinutes(_ m: Int) -> String {
    m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
}

struct LernKalenderWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: LernEntry

    private var snap: WidgetSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .systemMedium: medium
        default: small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "clock.fill").font(.caption2).foregroundStyle(.blue)
                Text("Heute").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if snap.streakDays > 0 {
                    Text("\(snap.streakDays)🔥").font(.caption2.bold()).foregroundStyle(.orange)
                }
            }
            Text(formatMinutes(snap.minutesToday))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
            if snap.goalMinutes > 0 {
                ProgressView(value: min(Double(snap.minutesToday) / Double(snap.goalMinutes), 1))
                    .tint(snap.minutesToday >= snap.goalMinutes ? .green : .blue)
            }
            Spacer(minLength: 0)
            if let title = snap.nextExamTitle, let date = snap.nextExamDate {
                let d = daysUntil(date)
                Text(title).font(.caption2.bold()).lineLimit(1)
                Text(d <= 0 ? "heute" : (d == 1 ? "morgen" : "in \(d) Tagen"))
                    .font(.caption2)
                    .foregroundStyle(d <= 3 ? .red : .secondary)
            } else if snap.openHomework > 0 {
                Text("\(snap.openHomework) Hausaufgaben offen").font(.caption2).foregroundStyle(.orange).lineLimit(2)
            }
        }
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Heute gelernt").font(.caption).foregroundStyle(.secondary)
                Text(formatMinutes(snap.minutesToday))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                if snap.goalMinutes > 0 {
                    ProgressView(value: min(Double(snap.minutesToday) / Double(snap.goalMinutes), 1))
                        .tint(snap.minutesToday >= snap.goalMinutes ? .green : .blue)
                    Text("Ziel: \(snap.goalMinutes) min").font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
                if snap.streakDays > 0 {
                    Label("\(snap.streakDays) Tage Serie", systemImage: "flame.fill")
                        .font(.caption2.bold()).foregroundStyle(.orange)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                if let title = snap.nextExamTitle, let date = snap.nextExamDate {
                    let d = daysUntil(date)
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Nächste Arbeit", systemImage: "doc.text.fill")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text(title).font(.subheadline.bold()).lineLimit(2)
                        Text(d <= 0 ? "heute" : (d == 1 ? "morgen" : "in \(d) Tagen"))
                            .font(.caption.bold())
                            .foregroundStyle(d <= 3 ? .red : .orange)
                    }
                } else {
                    Label("Keine Arbeit in Sicht", systemImage: "checkmark.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if snap.openHomework > 0 {
                    Label("\(snap.openHomework) Hausaufgaben", systemImage: "checklist")
                        .font(.caption2).foregroundStyle(.orange)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct LernKalenderWidget: Widget {
    let kind = "LernKalenderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LernProvider()) { entry in
            LernKalenderWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Lernzeit & nächste Arbeit")
        .description("Zeigt die heute gelernte Zeit, deine Serie und die nächste Klassenarbeit.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
