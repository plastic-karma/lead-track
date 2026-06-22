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
    let runningSince: Date?
    let todayTotal: TimeInterval
    let countdownDuration: TimeInterval?

    var isRunning: Bool {
        runningSince != nil
    }

    var displayColor: Color {
        MetricColor.color(named: colorName)
    }

    /// The range a running countdown animates across, or nil when counting up.
    var countdownInterval: ClosedRange<Date>? {
        guard let since = runningSince, let target = countdownDuration, target > 0 else { return nil }
        return since ... since.addingTimeInterval(target)
    }
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
        guard let uuid = UUID(uuidString: id),
              let container = try? SharedModelContainer.create()
        else { return nil }
        return try? Metric.find(stableID: uuid, in: ModelContext(container))
    }

    private func makeState(for metric: Metric) -> TimerMetricState {
        TimerMetricState(
            stableID: metric.stableID?.uuidString ?? "",
            name: metric.name,
            icon: metric.displayIcon,
            colorName: metric.colorName,
            runningSince: SessionService.activeSession(for: metric)?.startedAt,
            todayTotal: SessionStatistics.todayTotal(from: metric.sessions),
            countdownDuration: metric.countdownDuration
        )
    }

    private var sampleState: TimerMetricState {
        TimerMetricState(
            stableID: "",
            name: "Reading",
            icon: "book",
            colorName: "sage",
            runningSince: nil,
            todayTotal: 1200,
            countdownDuration: nil
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

    private func header(_ metric: TimerMetricState) -> some View {
        HStack(spacing: 6) {
            Image(systemName: metric.icon)
                .foregroundStyle(metric.displayColor)
            Text(metric.name)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func timeDisplay(_ metric: TimerMetricState) -> some View {
        if let since = metric.runningSince {
            Text(liveTimer: metric.countdownInterval, countingUpFrom: since)
                .roundedDigits(.title, weight: .semibold)
                .foregroundStyle(metric.displayColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        } else {
            todayTotal(metric.todayTotal)
        }
    }

    private func todayTotal(_ total: TimeInterval) -> some View {
        VStack(spacing: 2) {
            Text(DurationFormatter.format(total))
                .roundedDigits(.title2, weight: .semibold)
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
            .tint(metric.displayColor)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else {
            Button(intent: StartTimerIntent(metricID: metric.stableID)) {
                buttonLabel("Start", icon: "play.fill")
            }
            .tint(metric.displayColor)
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
