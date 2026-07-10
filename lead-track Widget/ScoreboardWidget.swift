import SwiftData
import SwiftUI
import WidgetKit

struct ScoreboardEntry: TimelineEntry {
    let date: Date
    let metrics: [MetricSnapshot]
    /// True when the shared store failed to open or fetch — rendered as its
    /// own state so a broken store never impersonates "no metrics yet".
    var loadFailed = false
}

struct MetricSnapshot: Identifiable {
    let id: String
    let name: String
    let icon: String
    let colorName: String?
    let todayTotal: TimeInterval
    let dailyGoal: TimeInterval?
    let weeklyTotal: TimeInterval
    let weeklyGoal: TimeInterval?
    let streak: Int
    let isRestDay: Bool

    var displayColor: Color {
        MetricColor.color(named: colorName)
    }
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
        completion(currentEntry())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<ScoreboardEntry>) -> Void
    ) {
        completion(Timeline(
            entries: [currentEntry()],
            policy: .after(WidgetTimeline.nextUpdate())
        ))
    }

    private func currentEntry() -> ScoreboardEntry {
        guard let metrics = loadMetrics() else {
            return ScoreboardEntry(date: .now, metrics: [], loadFailed: true)
        }
        return ScoreboardEntry(date: .now, metrics: metrics)
    }
}

// MARK: - Data Loading

extension ScoreboardProvider {
    /// nil when the store can't be opened or fetched — a different statement
    /// than an empty scoreboard.
    private func loadMetrics() -> [MetricSnapshot]? {
        guard let container = SharedModelContainer.shared else { return nil }
        let context = ModelContext(container)
        // The widget renders at most four rows; limiting in the descriptor
        // keeps the memory-capped extension from faulting every metric.
        var descriptor = FetchDescriptor<Metric>(
            // Archived metrics leave the scoreboard so a live one takes
            // the slot.
            predicate: #Predicate { $0.archivedAt == nil },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        descriptor.fetchLimit = 4
        do {
            return try context.fetch(descriptor).compactMap { snapshot(for: $0) }
        } catch {
            StoreLog.error("Scoreboard metric fetch failed: \(error)")
            return nil
        }
    }

    private func snapshot(for metric: Metric) -> MetricSnapshot? {
        // Identity keys on stableID like every other surface; names are not
        // unique. The backfill mints IDs at container creation, so a nil
        // here is a brand-new row racing the fetch — skip it this refresh.
        guard let id = metric.stableID?.uuidString else { return nil }
        let totals = SessionStatistics.dailyTotals(from: metric.sessions)
        return MetricSnapshot(
            id: id,
            name: metric.name,
            icon: metric.displayIcon,
            colorName: metric.colorName,
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
                name: "Reading",
                icon: "book",
                colorName: "sage",
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
        if entry.loadFailed {
            loadFailedView
        } else if entry.metrics.isEmpty {
            emptyView
        } else {
            metricsGrid
        }
    }

    private var loadFailedView: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Couldn't load data")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                .foregroundStyle(metric.displayColor)
                .frame(width: 20)
            Text(metric.name)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            if family != .systemSmall {
                goalRings(metric)
            }
            streakBadge(metric.streak, tint: metric.displayColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary(metric))
        // The row shows exactly what the optional biometric app lock guards —
        // names, goal progress, streaks — so it is marked privacy-sensitive:
        // the system redacts it wherever it hides private data (a locked lock
        // screen or StandBy). On the unlocked Home Screen widgets remain
        // visible by design; the app lock gates the app, not the widget.
        .privacySensitive()
    }

    @ViewBuilder
    private func goalRings(
        _ metric: MetricSnapshot
    ) -> some View {
        if let goal = metric.dailyGoal, !metric.isRestDay {
            miniRing(
                current: metric.todayTotal,
                goal: goal,
                label: "D",
                tint: metric.displayColor
            )
        }
        if let goal = metric.weeklyGoal {
            miniRing(
                current: metric.weeklyTotal,
                goal: goal,
                label: "W",
                tint: metric.displayColor
            )
        }
    }

    private func miniRing(
        current: TimeInterval,
        goal: TimeInterval,
        label: String,
        tint: Color
    ) -> some View {
        RingGauge(
            fraction: goal > 0 ? min(current / goal, 1.0) : 0,
            tint: tint,
            lineWidth: 3
        ) {
            Text(label)
                .font(.system(size: ringLabelSize).bold())
                .foregroundStyle(tint)
        }
        .frame(width: 26, height: 26)
    }

    private func streakBadge(_ days: Int, tint: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.system(size: streakIconSize))
            Text("\(days)")
                .roundedDigits(.caption, weight: .bold)
        }
        .foregroundStyle(days > 0 ? tint : Color.secondary)
    }

    private func accessibilitySummary(_ metric: MetricSnapshot) -> String {
        var parts = [metric.name]
        if let goal = metric.dailyGoal, goal > 0 {
            parts.append(
                metric.isRestDay
                    ? "rest day"
                    : "\(goalPercent(metric.todayTotal, of: goal)) percent of daily goal"
            )
        }
        if let goal = metric.weeklyGoal, goal > 0 {
            parts.append("\(goalPercent(metric.weeklyTotal, of: goal)) percent of weekly goal")
        }
        parts.append("\(metric.streak) day streak")
        return parts.joined(separator: ", ")
    }

    private func goalPercent(_ current: TimeInterval, of goal: TimeInterval) -> Int {
        Int((min(current / goal, 1) * 100).rounded())
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
