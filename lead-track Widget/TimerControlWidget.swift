import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

struct TimerControlEntry: TimelineEntry {
    let date: Date
    let metric: TimerMetricState?
    /// True when the shared store failed to open or fetch — rendered as its
    /// own state so a broken store never impersonates "unconfigured".
    var loadFailed = false
}

/// A snapshot of the configured metric used to render the Timer Control widget.
struct TimerMetricState: Equatable {
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

    /// The fill behind the widget's white-labelled start/stop buttons.
    var prominentColor: Color {
        MetricColor.prominentColor(named: colorName)
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
        entry(for: configuration)
    }

    func timeline(
        for configuration: SelectMetricIntent,
        in context: Context
    ) async -> Timeline<TimerControlEntry> {
        Timeline(
            entries: [entry(for: configuration)],
            policy: .after(WidgetTimeline.nextUpdate())
        )
    }
}

// MARK: - Data Loading

extension TimerControlProvider {
    private func entry(for configuration: SelectMetricIntent) -> TimerControlEntry {
        guard let id = configuration.metric?.id,
              let uuid = UUID(uuidString: id)
        else { return TimerControlEntry(date: .now, metric: nil) }
        guard let container = SharedModelContainer.shared else {
            return TimerControlEntry(date: .now, metric: nil, loadFailed: true)
        }
        // The value snapshot is taken while the context that owns the model
        // is still alive: a PersistentModel must never outlive its context,
        // and reading one that did is undefined behavior.
        let context = ModelContext(container)
        do {
            guard let metric = try Metric.find(stableID: uuid, in: context) else {
                return TimerControlEntry(date: .now, metric: nil)
            }
            return withExtendedLifetime(context) {
                TimerControlEntry(date: .now, metric: makeState(for: metric, id: id))
            }
        } catch {
            StoreLog.error("Timer widget metric fetch failed: \(error)")
            return TimerControlEntry(date: .now, metric: nil, loadFailed: true)
        }
    }

    /// `id` is the already-validated stable ID the metric was found by —
    /// re-deriving it here with an empty-string fallback would silently map
    /// onto StopTimerIntent's "stop every timer" sentinel.
    private func makeState(for metric: Metric, id: String) -> TimerMetricState {
        let running = SessionService.activeSession(for: metric)
        return TimerMetricState(
            stableID: id,
            name: metric.name,
            icon: metric.displayIcon,
            colorName: metric.colorName,
            runningSince: running?.startedAt,
            todayTotal: SessionStatistics.todayTotal(from: metric.sessions),
            countdownDuration: running?.countdownDuration
        )
    }

    private var sampleState: TimerMetricState {
        TimerMetricState(
            stableID: "6B1E1D2A-0000-4000-8000-000000000001",
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
    let metric: TimerMetricState?
    let loadFailed: Bool

    var body: some View {
        if let metric {
            TimerControlContent(metric: metric)
        } else if loadFailed {
            TimerControlPlaceholder(
                icon: "exclamationmark.triangle",
                title: "Couldn't load data",
                message: "Open LeadStone to refresh."
            )
        } else {
            TimerControlPlaceholder(
                icon: "timer",
                title: "Choose a metric",
                message: "Touch and hold, then tap Edit Widget."
            )
        }
    }
}

private struct TimerControlPlaceholder: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct TimerControlContent: View {
    let metric: TimerMetricState

    var body: some View {
        VStack(spacing: 10) {
            TimerControlHeader(name: metric.name, icon: metric.icon, tint: metric.displayColor)
            Spacer(minLength: 0)
            TimerControlTime(
                runningSince: metric.runningSince,
                countdownInterval: metric.countdownInterval,
                todayTotal: metric.todayTotal,
                tint: metric.displayColor
            )
            Spacer(minLength: 0)
            TimerControlButton(
                metricID: metric.stableID,
                isRunning: metric.isRunning,
                tint: metric.prominentColor
            )
        }
    }
}

private struct TimerControlHeader: View {
    let name: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(name)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
    }
}

private struct TimerControlTime: View {
    let runningSince: Date?
    let countdownInterval: ClosedRange<Date>?
    let todayTotal: TimeInterval
    let tint: Color

    var body: some View {
        if let since = runningSince {
            Text(liveTimer: countdownInterval, countingUpFrom: since)
                .roundedDigits(.title, weight: .semibold)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        } else {
            total
        }
    }

    private var total: some View {
        VStack(spacing: 2) {
            Text(DurationFormatter.format(todayTotal))
                .roundedDigits(.title2, weight: .semibold)
            Text("today")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Control Button

private struct TimerControlButton: View {
    let metricID: String
    let isRunning: Bool
    let tint: Color

    var body: some View {
        if isRunning {
            Button(intent: StopTimerIntent(metricID: metricID)) {
                buttonLabel("Stop", icon: "stop.fill")
            }
            .tint(tint)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else {
            Button(intent: StartTimerIntent(metricID: metricID)) {
                buttonLabel("Start", icon: "play.fill")
            }
            .tint(tint)
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
            TimerControlWidgetView(metric: entry.metric, loadFailed: entry.loadFailed)
                .containerBackground(.fill, for: .widget)
        }
        .configurationDisplayName("Timer Control")
        .description("Start and stop one metric's timer with a big button.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
