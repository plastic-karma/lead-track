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
        VStack(alignment: .leading) {
            Text(context.attributes.metricName)
                .font(.headline)
            if let project = context.attributes.projectName {
                Text(project)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
            VStack(alignment: .leading) {
                Text(context.attributes.metricName)
                    .font(.headline)
                if let project = context.attributes.projectName {
                    Text(project)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(liveTimer: countdown(context), countingUpFrom: context.state.startedAt)
                .roundedDigits(.title)
                .foregroundStyle(context.attributes.displayColor)
            Button(intent: StopTimerIntent()) {
                Image(systemName: "stop.fill")
                    .font(.title2)
            }
            .tint(context.attributes.displayColor)
        }
        .padding()
    }
}
