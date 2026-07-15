import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct TimerActivityLiveActivity: Widget {
    private typealias ActivityContext = ActivityViewContext<TimerActivityAttributes>

    var body: some WidgetConfiguration {
        ActivityConfiguration(
            for: TimerActivityAttributes.self
        ) { context in
            lockScreenView(context)
        } dynamicIsland: { context in
            dynamicIsland(context)
        }
    }

    private func dynamicIsland(_ context: ActivityContext) -> DynamicIsland {
        DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                metricIcon(context)
            }
            DynamicIslandExpandedRegion(.center) {
                expandedCenter(context)
            }
            DynamicIslandExpandedRegion(.trailing) {
                expandedTimer(context)
            }
            DynamicIslandExpandedRegion(.bottom) {
                stopButton(context)
            }
        } compactLeading: {
            metricIcon(context)
        } compactTrailing: {
            compactTimer(context)
        } minimal: {
            metricIcon(context)
        }
    }
}

// MARK: - Island Pieces

extension TimerActivityLiveActivity {
    private func metricIcon(_ context: ActivityContext) -> some View {
        Image(systemName: context.attributes.icon)
            .foregroundStyle(context.attributes.displayColor)
    }

    private func expandedCenter(_ context: ActivityContext) -> some View {
        TimerActivityNames(
            metricName: context.attributes.metricName,
            projectName: context.attributes.projectName,
            projectFont: .caption
        )
    }

    private func expandedTimer(_ context: ActivityContext) -> some View {
        Text(liveTimer: countdown(context), countingUpFrom: context.state.startedAt)
            .roundedDigits(.title3)
            .foregroundStyle(context.attributes.displayColor)
    }

    private func compactTimer(_ context: ActivityContext) -> some View {
        Text(liveTimer: countdown(context), countingUpFrom: context.state.startedAt)
            .monospacedDigit()
            .fontDesign(.rounded)
            .foregroundStyle(context.attributes.displayColor)
    }

    private func countdown(_ context: ActivityContext) -> ClosedRange<Date>? {
        context.attributes.countdownInterval(startedAt: context.state.startedAt)
    }

    private func stopButton(_ context: ActivityContext) -> some View {
        Button(intent: StopTimerIntent()) {
            Label("Stop", systemImage: "stop.fill")
                .frame(maxWidth: .infinity)
        }
        .tint(context.attributes.displayColor)
    }
}

// MARK: - Lock Screen

extension TimerActivityLiveActivity {
    private func lockScreenView(_ context: ActivityContext) -> some View {
        HStack {
            Image(systemName: context.attributes.icon)
                .font(.title2)
                .foregroundStyle(context.attributes.displayColor)
            TimerActivityNames(
                metricName: context.attributes.metricName,
                projectName: context.attributes.projectName,
                projectFont: .subheadline
            )
            Spacer()
            Text(liveTimer: countdown(context), countingUpFrom: context.state.startedAt)
                .roundedDigits(.title)
                .foregroundStyle(context.attributes.displayColor)
            Button(intent: StopTimerIntent()) {
                Label("Stop", systemImage: "stop.fill")
                    .labelStyle(.iconOnly)
                    .font(.title2)
            }
            .tint(context.attributes.displayColor)
        }
        .padding()
    }
}

// MARK: - Names

/// The metric and project names for the lock screen and the expanded island.
/// A Live Activity is readable on the locked lock screen, and what the user
/// tracks can be highly personal, so the names are marked
/// `.privacySensitive()` — and when the system redacts private content the
/// block swaps to a generic "Timer running" label instead of leaving
/// pill-shaped hints of the real text.
private struct TimerActivityNames: View {
    @Environment(\.redactionReasons) private var redactionReasons
    let metricName: String
    let projectName: String?
    let projectFont: Font

    var body: some View {
        VStack(alignment: .leading) {
            if redactionReasons.contains(.privacy) {
                Text("Timer running")
                    .font(.headline)
            } else {
                Text(metricName)
                    .font(.headline)
                    .privacySensitive()
                if let projectName {
                    Text(projectName)
                        .font(projectFont)
                        .foregroundStyle(.secondary)
                        .privacySensitive()
                }
            }
        }
    }
}
