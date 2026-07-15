import SwiftUI
import WidgetKit

struct WatchMetricEntry: TimelineEntry {
    let date: Date
    /// The configured metric resolved against the cached snapshot, or nil
    /// when the complication is unconfigured or the metric was deleted.
    let progress: ComplicationMetricProgress?
    let style: MetricComplicationStyle
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
    let entry: WatchMetricEntry

    var body: some View {
        content
            .containerBackground(.clear, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        if let progress = entry.progress {
            configuredView(progress)
        } else {
            unconfiguredView
        }
    }

    /// Ring styles need a fillable fraction; without an active target (no
    /// goal, or a rest day) they degrade to the plain value, the most
    /// informative fallback.
    @ViewBuilder
    private func configuredView(_ progress: ComplicationMetricProgress) -> some View {
        if entry.style.showsRing, let fraction = progress.fraction {
            ringView(progress, fraction: fraction)
        } else {
            plainView(progress)
        }
    }

    private func ringView(
        _ progress: ComplicationMetricProgress,
        fraction: Double
    ) -> some View {
        Gauge(value: fraction, in: 0 ... 1) {
            Image(systemName: progress.icon)
        } currentValueLabel: {
            label(for: progress)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(progress.displayColor)
        .widgetAccentable()
    }

    private func plainView(_ progress: ComplicationMetricProgress) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: progress.icon)
                    .font(.caption2)
                    .foregroundStyle(progress.displayColor)
                    .widgetAccentable()
                label(for: progress)
            }
        }
    }

    /// Percent styles print goal progress while a target applies and fall
    /// back to the value otherwise; binary values read as a checkmark.
    @ViewBuilder
    private func label(for progress: ComplicationMetricProgress) -> some View {
        if entry.style.showsPercent, let percent = progress.percent {
            valueLabel("\(percent)%")
        } else if progress.measurementType == .binary {
            Image(systemName: progress.todayTotal > 0 ? "checkmark" : "minus")
                .font(.body.weight(.semibold))
        } else {
            valueLabel(valueText(for: progress))
        }
    }

    private func valueLabel(_ text: String) -> some View {
        Text(text)
            .roundedDigits(.body, weight: .semibold)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private func valueText(for progress: ComplicationMetricProgress) -> String {
        switch progress.measurementType {
        case .duration:
            DurationFormatter.compact(progress.todayTotal)
        case .count, .binary, nil:
            "\(Int(progress.todayTotal))"
        }
    }

    private var unconfiguredView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "chart.bar")
                .foregroundStyle(.secondary)
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
            WatchMetricWidgetView(entry: entry)
        }
        .configurationDisplayName("Metric Progress")
        .description("One metric's value or goal progress.")
        .supportedFamilies([.accessoryCircular])
    }
}
