import SwiftUI
import WidgetKit

@main
struct TimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimerActivityLiveActivity()
        ScoreboardWidget()
    }
}
