import ActivityKit
import SwiftUI
import WidgetKit

struct StudyTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var isPaused: Bool
        var elapsedAtPause: Int
        var effectiveStartDate: Date
    }

    var subject: String
}

struct StudyTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyTimerAttributes.self) { context in
            // Lock Screen Banner
            HStack(spacing: 16) {
                Image(systemName: "book.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.subject)
                        .font(.headline)

                    if context.state.isPaused {
                        Text("Pausiert")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("Lernt gerade...")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                if context.state.isPaused {
                    Text(formatSeconds(context.state.elapsedAtPause))
                        .font(.system(.title, design: .rounded, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                } else {
                    Text(context.state.effectiveStartDate, style: .timer)
                        .font(.system(.title, design: .rounded, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.green)
                }
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.8))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "book.fill")
                            .foregroundStyle(.blue)
                        Text(context.attributes.subject)
                            .font(.headline)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isPaused {
                        Text(formatSeconds(context.state.elapsedAtPause))
                            .font(.system(.title2, design: .rounded, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                    } else {
                        Text(context.state.effectiveStartDate, style: .timer)
                            .font(.system(.title2, design: .rounded, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.green)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isPaused {
                        Label("Pausiert", systemImage: "pause.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Label("Lernt gerade", systemImage: "play.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            } compactLeading: {
                Image(systemName: "book.fill")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                if context.state.isPaused {
                    Text(formatSeconds(context.state.elapsedAtPause))
                        .font(.system(.caption, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                } else {
                    Text(context.state.effectiveStartDate, style: .timer)
                        .font(.system(.caption, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.green)
                }
            } minimal: {
                Image(systemName: "book.fill")
                    .foregroundStyle(.blue)
            }
        }
    }
}

private func formatSeconds(_ totalSeconds: Int) -> String {
    let h = totalSeconds / 3600
    let m = (totalSeconds % 3600) / 60
    let s = totalSeconds % 60
    if h > 0 {
        return String(format: "%d:%02d:%02d", h, m, s)
    }
    return String(format: "%02d:%02d", m, s)
}
