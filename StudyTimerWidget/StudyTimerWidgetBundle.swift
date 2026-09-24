import WidgetKit
import SwiftUI

@main
struct StudyTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        LernKalenderWidget()
        StudyTimerLiveActivity()
    }
}
