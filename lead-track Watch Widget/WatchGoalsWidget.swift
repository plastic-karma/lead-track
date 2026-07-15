import SwiftUI
import WidgetKit

struct WatchGoalsEntry: TimelineEntry {
    let date: Date
    let lines: [ComplicationMetricProgress]

    var relevance: TimelineEntryRelevance? {
        TimelineEntryRelevance(score: lines.allSatisfy(\.isMet) ? 10 : 50)
    }
}

/// Renders goal progress from the cached snapshot; the watch app reloads
/// widget timelines whenever the snapshot changes, and the planner's
/// midnight entry resets the day even without a phone push.
struct WatchGoalsProvider: TimelineProvider {
    func placeholder(in _: Context) -> WatchGoalsEntry {
        WatchGoalsEntry(date: .now, lines: ComplicationMetricProgress.sampleLines)
    }

    func getSnapshot(
        in _: Context,
        completion: @escaping (WatchGoalsEntry) -> Void
    ) {
        let snapshot = WatchSnapshotCache.load()
        completion(WatchGoalsEntry(
            date: .now,
            lines: ComplicationProgress.goalLines(in: snapshot, at: .now)
        ))
    }

    func getTimeline(
        in _: Context,
        completion: @escaping (Timeline<WatchGoalsEntry>) -> Void
    ) {
        completion(ComplicationTimeline.timeline(
            isLive: { snapshot in
                // Only a timer that moves a rendered goal line earns the
                // pre-rendered live window; a running goal-less or rest-day
                // metric changes nothing on this face.
                ComplicationProgress.metrics(in: snapshot, at: .now)
                    .contains { $0.hasActiveTarget && $0.isRunning }
            },
            makeEntry: { date, snapshot in
                WatchGoalsEntry(
                    date: date,
                    lines: ComplicationProgress.goalLines(in: snapshot, at: date)
                )
            }
        ))
    }
}

// MARK: - Widget View

struct WatchGoalsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchGoalsEntry

    var body: some View {
        content
            .containerBackground(.clear, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        if entry.lines.isEmpty {
            emptyView
        } else if family == .accessoryRectangular {
            rectangularView
        } else {
            circularView
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                ForEach(entry.lines) { line in
                    circularRow(line)
                }
            }
            .padding(2)
        }
    }

    private func circularRow(_ line: ComplicationMetricProgress) -> some View {
        HStack(spacing: 2) {
            Image(systemName: line.icon)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(line.displayColor)
                .widgetAccentable()
            Text(line.percent.map { "\($0)%" } ?? "—")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(entry.lines) { line in
                rectangularRow(line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rectangularRow(_ line: ComplicationMetricProgress) -> some View {
        HStack(spacing: 4) {
            Image(systemName: line.icon)
                .foregroundStyle(line.displayColor)
                .widgetAccentable()
            Text(line.name)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            Text(line.percent.map { "\($0)%" } ?? "—")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.caption2)
    }

    @ViewBuilder
    private var emptyView: some View {
        if family == .accessoryRectangular {
            Text("No daily goals")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "target")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Widget Definition

struct WatchGoalsWidget: Widget {
    let kind = "WatchGoalsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: WatchGoalsProvider()
        ) { entry in
            WatchGoalsWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Goals")
        .description("Progress toward today's goals.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}
