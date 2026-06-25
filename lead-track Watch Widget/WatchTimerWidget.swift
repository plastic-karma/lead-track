import SwiftUI
import WidgetKit

struct WatchTimerEntry: TimelineEntry {
    let date: Date
    let running: WatchMetricSnapshot?

    var relevance: TimelineEntryRelevance? {
        TimelineEntryRelevance(score: running == nil ? 0 : 100)
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
    let entry: WatchTimerEntry

    var body: some View {
        content
            .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        if let metric = entry.running, let since = metric.runningSince {
            runningView(metric, since: since)
        } else {
            idleView
        }
    }

    @ViewBuilder
    private func runningView(
        _ metric: WatchMetricSnapshot,
        since: Date
    ) -> some View {
        if family == .accessoryInline {
            Text("\(metric.name) \(Text(liveTimer: metric.countdownInterval, countingUpFrom: since))")
        } else {
            rectangularView(metric, since: since)
        }
    }

    private func rectangularView(
        _ metric: WatchMetricSnapshot,
        since: Date
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: metric.icon ?? "clock")
                Text(metric.name)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.headline)
            Text(liveTimer: metric.countdownInterval, countingUpFrom: since)
                .roundedDigits(.title3, weight: .semibold)
                .foregroundStyle(metric.displayColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var idleView: some View {
        if family == .accessoryInline {
            Text("No timer running")
        } else {
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
}

// MARK: - Widget Definition

struct WatchTimerWidget: Widget {
    let kind = "WatchTimerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: WatchTimerProvider()
        ) { entry in
            WatchTimerWidgetView(entry: entry)
        }
        .configurationDisplayName("Active Timer")
        .description("Shows the currently running timer.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}
