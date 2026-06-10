import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct TimerActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(
            for: TimerActivityAttributes.self
        ) { context in
            lockScreenView(context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.icon)
                        .foregroundStyle(tint(context.attributes))
                }
                DynamicIslandExpandedRegion(.center) {
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
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .monospacedDigit()
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(tint(context.attributes))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Button(intent: StopTimerIntent()) {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.red)
                }
            } compactLeading: {
                Image(systemName: context.attributes.icon)
                    .foregroundStyle(tint(context.attributes))
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer)
                    .monospacedDigit()
                    .fontDesign(.rounded)
                    .foregroundStyle(tint(context.attributes))
            } minimal: {
                Image(systemName: context.attributes.icon)
                    .foregroundStyle(tint(context.attributes))
            }
        }
    }

    private func tint(_ attributes: TimerActivityAttributes) -> Color {
        MetricColor.color(named: attributes.colorName)
    }

    private func lockScreenView(
        _ context: ActivityViewContext<TimerActivityAttributes>
    ) -> some View {
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
            .tint(.red)
        }
        .padding()
    }
}
