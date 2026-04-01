import ActivityKit
import Foundation

struct StudyTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var isPaused: Bool
        var elapsedAtPause: Int
        var effectiveStartDate: Date
    }

    var subject: String
}
