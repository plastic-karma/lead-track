import SwiftUI
import WidgetKit

struct WatchMetricEntry: TimelineEntry {
    let date: Date
    /// The configured metric resolved against the cached snapshot, or nil
    /// when the complication is unconfigured or the metric was deleted.
    let display: WatchMetricDisplayState?

    init(date: Date, progress: ComplicationMetricProgress?, style: MetricComplicationStyle) {
        self.date = date
        display = progress.map { WatchMetricDisplayState(progress: $0, style: style) }
    }
}

/// Presentation is prepared per entry, not formatted during view initialization.
struct WatchMetricDisplayState: Equatable {
    enum Value: Equatable {
        case text(String)
        case symbol(String)
    }

    let metricID: UUID
    let icon: String
    let colorName: String?
    let fraction: Double?
    let value: Value

    init(progress: ComplicationMetricProgress, style: MetricComplicationStyle) {
        metricID = progress.id
        icon = progress.icon
        colorName = progress.colorName
        fraction = style.showsRing ? progress.fraction : nil
        if style.showsPercent, let percent = progress.percent {
            value = .text("\(percent.formatted())%")
        } else if progress.measurementType == .binary {
            value = .symbol(progress.todayTotal > 0 ? "checkmark" : "minus")
        } else if progress.measurementType == .duration {
            value = .text(DurationFormatter.compact(progress.todayTotal))
        } else {
            value = .text(Int(progress.todayTotal).formatted())
        }
    }
}

/// Renders one configured metric from the cached snapshot.
struct WatchMetricProvider: AppIntentTimelineProvider {
    func placeholder(in _: Context) -> WatchMetricEntry {
        WatchMetricEntry(date: .now, progress: .sample, style: .percentRing)
    }

    func snapshot(
        for configuration: SelectWatchMetricIntent,
        in _: Context
    ) async -> WatchMetricEntry {
        WatchMetricEntry(
            date: .now,
            progress: resolved(configuration, in: WatchSnapshotCache.load(), at: .now),
            style: configuration.style
        )
    }

    func timeline(
        for configuration: SelectWatchMetricIntent,
        in _: Context
    ) async -> Timeline<WatchMetricEntry> {
        ComplicationTimeline.timeline(
            isLive: { snapshot in
                resolved(configuration, in: snapshot, at: .now)?.isRunning ?? false
            },
            makeEntry: { date, snapshot in
                WatchMetricEntry(
                    date: date,
                    progress: resolved(configuration, in: snapshot, at: date),
                    style: configuration.style
                )
            }
        )
    }

    /// One preconfigured pick per cached metric (capped) keeps the on-watch
    /// picker scannable; styles are refined per placement in the editor.
    /// An unconfigured fallback keeps the widget discoverable before the
    /// first sync.
    func recommendations() -> [AppIntentRecommendation<SelectWatchMetricIntent>] {
        let metrics = WatchSnapshotCache.load().metrics.prefix(8)
        guard !metrics.isEmpty else {
            return [AppIntentRecommendation(intent: SelectWatchMetricIntent(), description: "Metric")]
        }
        return metrics.map { metric in
            let intent = SelectWatchMetricIntent(
                metric: WatchMetricEntity(metric),
                style: metric.hasDailyTarget ? .percentRing : .number
            )
            return AppIntentRecommendation(intent: intent, description: "\(metric.name)")
        }
    }

    private func resolved(
        _ configuration: SelectWatchMetricIntent,
        in snapshot: WatchSnapshot,
        at date: Date
    ) -> ComplicationMetricProgress? {
        guard let id = configuration.metric?.id else { return nil }
        return ComplicationProgress.metrics(in: snapshot, at: date)
            .first { $0.id == id }
    }
}

// MARK: - Widget View

struct WatchMetricWidgetView: View {
    let display: WatchMetricDisplayState?

    var body: some View {
        content
            .containerBackground(.clear, for: .widget)
            // Nil leaves the default launch; a configured face opens its metric.
            .widgetURL(display.flatMap { WatchMetricDeepLink.url(metricID: $0.metricID) })
    }

    @ViewBuilder
    private var content: some View {
        if let display {
            if let fraction = display.fraction {
                WatchMetricRing(
                    fraction: fraction,
                    icon: display.icon,
                    tint: MetricColor.color(named: display.colorName),
                    value: display.value
                )
            } else {
                WatchMetricPlainValue(
                    icon: display.icon,
                    tint: MetricColor.color(named: display.colorName),
                    value: display.value
                )
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "chart.bar")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct WatchMetricRing: View {
    let fraction: Double
    let icon: String
    let tint: Color
    let value: WatchMetricDisplayState.Value

    var body: some View {
        Gauge(value: fraction, in: 0 ... 1) {
            Image(systemName: icon)
        } currentValueLabel: {
            WatchMetricValueLabel(value: value)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(tint)
        .widgetAccentable()
    }
}

private struct WatchMetricPlainValue: View {
    let icon: String
    let tint: Color
    let value: WatchMetricDisplayState.Value

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(tint)
                    .widgetAccentable()
                WatchMetricValueLabel(value: value)
            }
        }
    }
}

private struct WatchMetricValueLabel: View {
    let value: WatchMetricDisplayState.Value

    var body: some View {
        switch value {
        case let .symbol(icon):
            Image(systemName: icon)
                .font(.body.weight(.semibold))
        case let .text(text):
            Text(text)
                .roundedDigits(.body, weight: .semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }
}

// MARK: - Widget Definition

struct WatchMetricWidget: Widget {
    let kind = "WatchMetricWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectWatchMetricIntent.self,
            provider: WatchMetricProvider()
        ) { entry in
            WatchMetricWidgetView(display: entry.display)
        }
        .configurationDisplayName("Metric Progress")
        .description("One metric's value or goal progress.")
        .supportedFamilies([.accessoryCircular])
    }
}
