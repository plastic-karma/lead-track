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

    private func tint(_ attributes: TimerActivityAttributes) -> Color {
        MetricColor.color(named: attributes.colorName)
    }
}

// MARK: - Island Pieces

extension TimerActivityLiveActivity {
    private func metricIcon(_ context: ActivityContext) -> some View {
        Image(systemName: context.attributes.icon)
            .foregroundStyle(tint(context.attributes))
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
        Text(context.state.startedAt, style: .timer)
            .monospacedDigit()
            .font(.system(.title3, design: .rounded))
            .foregroundStyle(tint(context.attributes))
    }

    private func compactTimer(_ context: ActivityContext) -> some View {
        Text(context.state.startedAt, style: .timer)
            .monospacedDigit()
            .fontDesign(.rounded)
            .foregroundStyle(tint(context.attributes))
    }

    private func stopButton(_ context: ActivityContext) -> some View {
        Button(intent: StopTimerIntent()) {
            Label("Stop", systemImage: "stop.fill")
                .frame(maxWidth: .infinity)
        }
        .tint(tint(context.attributes))
    }
}

// MARK: - Lock Screen

extension TimerActivityLiveActivity {
    private func lockScreenView(_ context: ActivityContext) -> some View {
        HStack {
            Image(systemName: context.attributes.icon)
                .font(.title2)
                .foregroundStyle(tint(context.attributes))
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
            Text(context.state.startedAt, style: .timer)
                .monospacedDigit()
                .font(.system(.title, design: .rounded))
                .foregroundStyle(tint(context.attributes))
            Button(intent: StopTimerIntent()) {
                Image(systemName: "stop.fill")
                    .font(.title2)
            }
            .tint(tint(context.attributes))
        }
        .padding()
    }
}
