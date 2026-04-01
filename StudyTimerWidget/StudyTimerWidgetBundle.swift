//
//  StudyTimerWidgetBundle.swift
//  StudyTimerWidget
//
//  Created by Nils on 01.04.26.
//

import WidgetKit
import SwiftUI

@main
struct StudyTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        StudyTimerWidget()
        StudyTimerWidgetControl()
        StudyTimerWidgetLiveActivity()
    }
}
