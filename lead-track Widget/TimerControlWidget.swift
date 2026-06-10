import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

struct TimerControlEntry: TimelineEntry {
    let date: Date
    let metric: TimerMetricState?
}

/// A snapshot of the configured metric used to render the Timer Control widget.
struct TimerMetricState {
    let stableID: String
    let name: String
    let icon: String
    let colorName: String?
    let isRunning: Bool
    let runningSince: Date?
    let todayTotal: TimeInterval
}

struct TimerControlProvider: AppIntentTimelineProvider {
    func placeholder(
        in context: Context
    ) -> TimerControlEntry {
        TimerControlEntry(date: .now, metric: sampleState)
    }

    func snapshot(
        for configuration: SelectMetricIntent,
        in context: Context
    ) async -> TimerControlEntry {
        TimerControlEntry(date: .now, metric: state(for: configuration))
    }

    func timeline(
        for configuration: SelectMetricIntent,
        in context: Context
    ) async -> Timeline<TimerControlEntry> {
        let entry = TimerControlEntry(
            date: .now,
            metric: state(for: configuration)
        )
        let nextUpdate = Calendar.current.date(
            byAdding: .minute, value: 15, to: .now
        ) ?? .now
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// MARK: - Data Loading

extension TimerControlProvider {
    private func state(
        for configuration: SelectMetricIntent
    ) -> TimerMetricState? {
        guard let id = configuration.metric?.id else { return nil }
        guard let metric = metric(withID: id) else { return nil }
        return makeState(for: metric)
    }

    private func metric(withID id: String) -> Metric? {
        guard let container = try? SharedModelContainer.create()
        else { return nil }
        let context = ModelContext(container)
        let metrics = (try? context.fetch(FetchDescriptor<Metric>())) ?? []
        return metrics.first { $0.stableID?.uuidString == id }
    }

    private func makeState(for metric: Metric) -> TimerMetricState {
        let running = metric.sessions.first { $0.isRunning }
        let completed = metric.sessions.filter { !$0.isRunning }
        let totals = SessionStatistics.dailyTotals(from: completed)
        return TimerMetricState(
            stableID: metric.stableID?.uuidString ?? "",
            name: metric.name,
            icon: metric.icon ?? "clock",
            colorName: metric.colorName,
            isRunning: running != nil,
            runningSince: running?.startedAt,
            todayTotal: SessionStatistics.todayTotal(from: totals)
        )
    }

    private var sampleState: TimerMetricState {
        TimerMetricState(
            stableID: "",
            name: "Reading",
            icon: "book",
            colorName: "sage",
            isRunning: false,
            runningSince: nil,
            todayTotal: 1200
        )
    }
}

// MARK: - Widget View

struct TimerControlWidgetView: View {
    let entry: TimerControlEntry

    var body: some View {
        if let metric = entry.metric {
            timerControl(metric)
        } else {
            unconfiguredView
        }
    }

    private var unconfiguredView: some View {
        VStack(spacing: 6) {
            Image(systemName: "timer")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Choose a metric")
                .font(.headline)
            Text("Touch and hold, then tap Edit Widget.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Configured Layout

extension TimerControlWidgetView {
    private func timerControl(_ metric: TimerMetricState) -> some View {
        VStack(spacing: 10) {
            header(metric)
            Spacer(minLength: 0)
            timeDisplay(metric)
            Spacer(minLength: 0)
            controlButton(metric)
        }
    }

    private func tint(for metric: TimerMetricState) -> Color {
        MetricColor.color(named: metric.colorName)
    }

    private func header(_ metric: TimerMetricState) -> some View {
        HStack(spacing: 6) {
            Image(systemName: metric.icon)
                .foregroundStyle(tint(for: metric))
            Text(metric.name)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func timeDisplay(_ metric: TimerMetricState) -> some View {
        if metric.isRunning, let since = metric.runningSince {
            Text(since, style: .timer)
                .font(.system(.title, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint(for: metric))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        } else {
            todayTotal(metric.todayTotal)
        }
    }

    private func todayTotal(_ total: TimeInterval) -> some View {
        VStack(spacing: 2) {
            Text(DurationFormatter.format(total))
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .monospacedDigit()
            Text("today")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Control Button

extension TimerControlWidgetView {
    @ViewBuilder
    private func controlButton(_ metric: TimerMetricState) -> some View {
        if metric.isRunning {
            Button(intent: StopTimerIntent(metricID: metric.stableID)) {
                buttonLabel("Stop", icon: "stop.fill")
            }
            .tint(.red)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else {
            Button(intent: StartTimerIntent(metricID: metric.stableID)) {
                buttonLabel("Start", icon: "play.fill")
            }
            .tint(tint(for: metric))
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func buttonLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }
}

// MARK: - Widget Definition

struct TimerControlWidget: Widget {
    let kind = "TimerControlWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectMetricIntent.self,
            provider: TimerControlProvider()
        ) { entry in
            TimerControlWidgetView(entry: entry)
                .containerBackground(.fill, for: .widget)
        }
        .configurationDisplayName("Timer Control")
        .description("Start and stop one metric's timer with a big button.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
