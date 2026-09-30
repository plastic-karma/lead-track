import SwiftUI
import WidgetKit

struct WatchTimerEntry: TimelineEntry {
    let date: Date
    let running: WatchTimerDisplayState?

    init(date: Date, running: WatchMetricSnapshot?) {
        self.date = date
        self.running = running.flatMap(WatchTimerDisplayState.init)
    }

    var relevance: TimelineEntryRelevance? {
        TimelineEntryRelevance(score: running == nil ? 0 : 100)
    }
}

struct WatchTimerDisplayState: Equatable {
    let name: String
    let icon: String
    let colorName: String?
    let startedAt: Date
    let countdownInterval: ClosedRange<Date>?

    init?(metric: WatchMetricSnapshot) {
        guard let startedAt = metric.runningSince else { return nil }
        name = metric.name
        icon = metric.displayIcon
        colorName = metric.colorName
        self.startedAt = startedAt
        countdownInterval = metric.countdownInterval
    }
}

/// Renders the cached snapshot the watch app maintains; the app reloads the
/// widget timeline whenever that snapshot changes, so no phone round-trip is
/// needed here.
struct WatchTimerProvider: TimelineProvider {
    func placeholder(in _: Context) -> WatchTimerEntry {
        WatchTimerEntry(date: .now, running: nil)
    }

    func getSnapshot(
        in _: Context,
        completion: @escaping (WatchTimerEntry) -> Void
    ) {
        completion(currentEntry())
    }

    func getTimeline(
        in _: Context,
        completion: @escaping (Timeline<WatchTimerEntry>) -> Void
    ) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> WatchTimerEntry {
        let metrics = WatchSnapshotCache.load().metrics
        let running = metrics.first { $0.runningSince != nil }
        return WatchTimerEntry(date: .now, running: running)
    }
}

// MARK: - Widget View

struct WatchTimerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let running: WatchTimerDisplayState?

    var body: some View {
        content
            .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        if let running {
            WatchTimerRunningContent(timer: running, isInline: family == .accessoryInline)
        } else {
            idleView
        }
    }

    @ViewBuilder
    private var idleView: some View {
        if family == .accessoryInline {
            Text("No timer running")
        } else {
            WatchTimerIdleContent()
        }
    }
}

private struct WatchTimerRunningContent: View {
    let timer: WatchTimerDisplayState
    let isInline: Bool

    var body: some View {
        if isInline {
            Text("\(timer.name) \(Text(liveTimer: timer.countdownInterval, countingUpFrom: timer.startedAt))")
        } else {
            WatchTimerRectangularContent(timer: timer)
        }
    }
}

private struct WatchTimerRectangularContent: View {
    let timer: WatchTimerDisplayState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: timer.icon)
                Text(timer.name)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.headline)
            Text(liveTimer: timer.countdownInterval, countingUpFrom: timer.startedAt)
                .roundedDigits(.title3, weight: .semibold)
                .foregroundStyle(MetricColor.color(named: timer.colorName))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WatchTimerIdleContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "timer")
                Text("LeadStone")
            }
            .font(.headline)
            Text("No timer running")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widget Definition

struct WatchTimerWidget: Widget {
    let kind = "WatchTimerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: WatchTimerProvider()
        ) { entry in
            WatchTimerWidgetView(running: entry.running)
        }
        .configurationDisplayName("Active Timer")
        .description("Shows the currently running timer.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}
