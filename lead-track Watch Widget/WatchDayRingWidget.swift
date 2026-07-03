import SwiftUI
import WidgetKit

struct WatchDayRingEntry: TimelineEntry {
    let date: Date
    let summary: GoalSummary
}

/// Shows how many of today's goals are met, from the cached snapshot.
struct WatchDayRingProvider: TimelineProvider {
    func placeholder(in _: Context) -> WatchDayRingEntry {
        WatchDayRingEntry(date: .now, summary: GoalSummary(met: 2, total: 5))
    }

    func getSnapshot(
        in _: Context,
        completion: @escaping (WatchDayRingEntry) -> Void
    ) {
        let snapshot = WatchSnapshotCache.load()
        completion(WatchDayRingEntry(
            date: .now,
            summary: ComplicationProgress.dailySummary(in: snapshot, at: .now)
        ))
    }

    func getTimeline(
        in _: Context,
        completion: @escaping (Timeline<WatchDayRingEntry>) -> Void
    ) {
        let snapshot = WatchSnapshotCache.load()
        let running = ComplicationProgress.metrics(in: snapshot, at: .now)
            .contains { $0.hasActiveTarget && $0.isRunning }
        let dates = ComplicationTimeline.entryDates(from: .now, hasRunningTimer: running)
        let entries = dates.map { date in
            WatchDayRingEntry(
                date: date,
                summary: ComplicationProgress.dailySummary(in: snapshot, at: date)
            )
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Widget View

struct WatchDayRingWidgetView: View {
    let entry: WatchDayRingEntry

    var body: some View {
        content
            .containerBackground(.clear, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        if entry.summary.hasGoals {
            ringView
        } else {
            emptyView
        }
    }

    private var ringView: some View {
        Gauge(
            value: Double(entry.summary.met),
            in: 0 ... Double(max(entry.summary.total, 1))
        ) {
            Image(systemName: "target")
        } currentValueLabel: {
            Text("\(entry.summary.met)/\(entry.summary.total)")
                .roundedDigits(.body, weight: .semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(MetricColor.copper.color)
        .widgetAccentable()
    }

    private var emptyView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "target")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Widget Definition

struct WatchDayRingWidget: Widget {
    let kind = "WatchDayRingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: WatchDayRingProvider()
        ) { entry in
            WatchDayRingWidgetView(entry: entry)
        }
        .configurationDisplayName("Day Ring")
        .description("How many of today's goals are met.")
        .supportedFamilies([.accessoryCircular])
    }
}
