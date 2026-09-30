import SwiftUI
import WidgetKit

struct WatchGoalsEntry: TimelineEntry {
    let date: Date
    let lines: [WatchGoalLine]
    private let allGoalsMet: Bool

    init(date: Date, lines: [ComplicationMetricProgress]) {
        self.date = date
        self.lines = lines.map(WatchGoalLine.init)
        allGoalsMet = lines.allSatisfy(\.isMet)
    }

    var relevance: TimelineEntryRelevance? {
        TimelineEntryRelevance(score: allGoalsMet ? 10 : 50)
    }
}

/// Prepared once per timeline entry, rather than reshaped by view construction.
struct WatchGoalLine: Equatable, Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let colorName: String?
    let percent: Int?

    init(progress: ComplicationMetricProgress) {
        id = progress.id
        name = progress.name
        icon = progress.icon
        colorName = progress.colorName
        percent = progress.percent
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
    let lines: [WatchGoalLine]

    var body: some View {
        content
            .containerBackground(.clear, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        if lines.isEmpty {
            emptyView
        } else if family == .accessoryRectangular {
            WatchGoalsRectangularContent(lines: lines)
        } else {
            WatchGoalsCircularContent(lines: lines)
        }
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

private struct WatchGoalsCircularContent: View {
    let lines: [WatchGoalLine]

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                ForEach(lines) { line in
                    WatchGoalsCircularRow(icon: line.icon, colorName: line.colorName, percent: line.percent)
                }
            }
            .padding(2)
        }
    }
}

private struct WatchGoalsCircularRow: View {
    let icon: String
    let colorName: String?
    let percent: Int?

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(MetricColor.color(named: colorName))
                .widgetAccentable()
            Text(percent.map { "\($0.formatted())%" } ?? "—")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

private struct WatchGoalsRectangularContent: View {
    let lines: [WatchGoalLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(lines) { line in
                WatchGoalsRectangularRow(
                    name: line.name,
                    icon: line.icon,
                    colorName: line.colorName,
                    percent: line.percent
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WatchGoalsRectangularRow: View {
    let name: String
    let icon: String
    let colorName: String?
    let percent: Int?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(MetricColor.color(named: colorName))
                .widgetAccentable()
            Text(name)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            Text(percent.map { "\($0.formatted())%" } ?? "—")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.caption2)
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
            WatchGoalsWidgetView(lines: entry.lines)
        }
        .configurationDisplayName("Daily Goals")
        .description("Progress toward today's goals.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}
