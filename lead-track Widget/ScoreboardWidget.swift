import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

struct ScoreboardEntry: TimelineEntry {
    let date: Date
    let metrics: [MetricSnapshot]
}

struct MetricSnapshot: Identifiable {
    let id: String
    let stableID: String
    let name: String
    let icon: String
    let measurementType: MeasurementType
    let isRunning: Bool
    let todayTotal: TimeInterval
    let dailyGoal: TimeInterval?
    let weeklyTotal: TimeInterval
    let weeklyGoal: TimeInterval?
    let streak: Int
    let isRestDay: Bool
}

struct ScoreboardProvider: TimelineProvider {
    func placeholder(
        in context: Context
    ) -> ScoreboardEntry {
        ScoreboardEntry(date: .now, metrics: sampleMetrics)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (ScoreboardEntry) -> Void
    ) {
        completion(
            ScoreboardEntry(
                date: .now,
                metrics: loadMetrics()
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<ScoreboardEntry>) -> Void
    ) {
        let entry = ScoreboardEntry(
            date: .now,
            metrics: loadMetrics()
        )
        let nextUpdate = Calendar.current.date(
            byAdding: .minute, value: 15, to: .now
        ) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Data Loading

extension ScoreboardProvider {
    private func loadMetrics() -> [MetricSnapshot] {
        guard let container = try? SharedModelContainer.create()
        else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Metric>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        guard let metrics = try? context.fetch(descriptor)
        else { return [] }
        return metrics.prefix(4).map { metric in
            snapshot(for: metric, context: context)
        }
    }

    private func snapshot(
        for metric: Metric,
        context: ModelContext
    ) -> MetricSnapshot {
        let sessions = (metric.sessions)
            .filter { !$0.isRunning }
        let totals = SessionStatistics.dailyTotals(
            from: sessions
        )
        return MetricSnapshot(
            id: metric.name,
            stableID: metric.stableID?.uuidString ?? "",
            name: metric.name,
            icon: metric.icon ?? "clock",
            measurementType: metric.measurementType,
            isRunning: metric.sessions.contains(where: \.isRunning),
            todayTotal: SessionStatistics.todayTotal(from: totals),
            dailyGoal: metric.dailyGoal,
            weeklyTotal: SessionStatistics.currentWeekTotal(
                from: totals
            ),
            weeklyGoal: metric.weeklyGoal,
            streak: SessionStatistics.currentStreak(
                from: totals, excludedWeekdays: metric.excludedWeekdaySet
            ),
            isRestDay: !metric.isGoalDay(on: .now)
        )
    }

    private var sampleMetrics: [MetricSnapshot] {
        [
            MetricSnapshot(
                id: "sample",
                stableID: "",
                name: "Reading",
                icon: "book",
                measurementType: .duration,
                isRunning: false,
                todayTotal: 1200,
                dailyGoal: 1800,
                weeklyTotal: 9000,
                weeklyGoal: 18000,
                streak: 5,
                isRestDay: false
            )
        ]
    }
}

// MARK: - Widget Views

struct ScoreboardWidgetView: View {
    let entry: ScoreboardEntry
    @Environment(\.widgetFamily) var family
    @ScaledMetric(relativeTo: .caption2) private var ringLabelSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption2) private var streakIconSize: CGFloat = 11

    var body: some View {
        if entry.metrics.isEmpty {
            emptyView
        } else {
            metricsGrid
        }
    }

    private var emptyView: some View {
        VStack {
            Image(systemName: "chart.bar")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No metrics yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var metricsGrid: some View {
        VStack(spacing: 8) {
            ForEach(visibleMetrics) { metric in
                metricRow(metric)
            }
        }
    }

    private var visibleMetrics: [MetricSnapshot] {
        switch family {
        case .systemSmall:
            Array(entry.metrics.prefix(2))
        default:
            Array(entry.metrics.prefix(4))
        }
    }
}

// MARK: - Metric Row

extension ScoreboardWidgetView {
    private func metricRow(
        _ metric: MetricSnapshot
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: metric.icon)
                .font(.body)
                .foregroundStyle(.orange)
                .frame(width: 20)
            Text(metric.name)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            if family != .systemSmall {
                goalRings(metric)
            }
            streakBadge(metric.streak)
            actionButton(metric)
        }
    }

    @ViewBuilder
    private func goalRings(
        _ metric: MetricSnapshot
    ) -> some View {
        if let goal = metric.dailyGoal, !metric.isRestDay {
            miniRing(
                current: metric.todayTotal,
                goal: goal,
                label: "D"
            )
        }
        if let goal = metric.weeklyGoal {
            miniRing(
                current: metric.weeklyTotal,
                goal: goal,
                label: "W"
            )
        }
    }

    private func miniRing(
        current: TimeInterval,
        goal: TimeInterval,
        label: String
    ) -> some View {
        let fraction = goal > 0
            ? min(current / goal, 1.0) : 0
        let color: Color = current >= goal ? .green : .orange
        return ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 3)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: 3, lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
            Text(label)
                .font(.system(size: ringLabelSize).bold())
                .foregroundStyle(color)
        }
        .frame(width: 26, height: 26)
    }

    private func streakBadge(_ days: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.system(size: streakIconSize))
            Text("\(days)")
                .font(.caption.bold())
                .monospacedDigit()
        }
        .foregroundStyle(days > 0 ? .orange : .secondary)
    }
}

// MARK: - Action Button

extension ScoreboardWidgetView {
    @ViewBuilder
    private func actionButton(_ metric: MetricSnapshot) -> some View {
        if metric.measurementType == .count {
            Button(intent: LogEntryIntent(metricID: metric.stableID)) {
                actionIcon("plus", tint: .orange)
            }
            .buttonStyle(.plain)
        } else if metric.isRunning {
            Button(intent: StopTimerIntent(metricID: metric.stableID)) {
                actionIcon("stop.fill", tint: .red)
            }
            .buttonStyle(.plain)
        } else {
            Button(intent: StartTimerIntent(metricID: metric.stableID)) {
                actionIcon("play.fill", tint: .green)
            }
            .buttonStyle(.plain)
        }
    }

    private func actionIcon(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.body)
            .foregroundStyle(tint)
            .frame(width: 26, height: 26)
    }
}

// MARK: - Widget Definition

struct ScoreboardWidget: Widget {
    let kind = "ScoreboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: ScoreboardProvider()
        ) { entry in
            ScoreboardWidgetView(entry: entry)
                .containerBackground(.fill, for: .widget)
        }
        .configurationDisplayName("Scoreboard")
        .description("Today's progress across your metrics.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
