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

struct MetricSnapshot: Equatable, Identifiable {
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
    let metrics: [MetricSnapshot]
    let loadFailed: Bool
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if loadFailed {
            ScoreboardPlaceholder(icon: "exclamationmark.triangle", title: "Couldn't load data")
        } else if metrics.isEmpty {
            ScoreboardPlaceholder(icon: "chart.bar", title: "No metrics yet")
        } else {
            VStack(spacing: 8) {
                ForEach(metrics.prefix(family == .systemSmall ? 2 : 4)) { metric in
                    ScoreboardMetricRow(metric: metric, showsGoals: family != .systemSmall)
                }
            }
        }
    }
}

private struct ScoreboardPlaceholder: View {
    let icon: String
    let title: String

    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Metric Row

private struct ScoreboardMetricRow: View {
    let metric: MetricSnapshot
    let showsGoals: Bool

    var body: some View {
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
            if showsGoals {
                goalRings
            }
            ScoreboardStreakBadge(days: metric.streak, tint: metric.displayColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        // The row shows exactly what the optional biometric app lock guards —
        // names, goal progress, streaks — so it is marked privacy-sensitive:
        // the system redacts it wherever it hides private data (a locked lock
        // screen or StandBy). On the unlocked Home Screen widgets remain
        // visible by design; the app lock gates the app, not the widget.
        .privacySensitive()
    }

    @ViewBuilder
    private var goalRings: some View {
        if let goal = metric.dailyGoal, !metric.isRestDay {
            ScoreboardMiniRing(
                current: metric.todayTotal,
                goal: goal,
                label: "D",
                tint: metric.displayColor
            )
        }
        if let goal = metric.weeklyGoal {
            ScoreboardMiniRing(
                current: metric.weeklyTotal,
                goal: goal,
                label: "W",
                tint: metric.displayColor
            )
        }
    }

    private var accessibilitySummary: String {
        var parts = [metric.name]
        if let goal = metric.dailyGoal, goal > 0 {
            parts.append(
                metric.isRestDay
                    ? "rest day"
                    : "\(goalPercent(metric.todayTotal, of: goal).formatted()) percent of daily goal"
            )
        }
        if let goal = metric.weeklyGoal, goal > 0 {
            parts.append("\(goalPercent(metric.weeklyTotal, of: goal).formatted()) percent of weekly goal")
        }
        parts.append("\(metric.streak.formatted()) day streak")
        return parts.joined(separator: ", ")
    }

    private func goalPercent(_ current: TimeInterval, of goal: TimeInterval) -> Int {
        Int((min(current / goal, 1) * 100).rounded())
    }
}

private struct ScoreboardMiniRing: View {
    let current: TimeInterval
    let goal: TimeInterval
    let label: String
    let tint: Color
    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 10

    var body: some View {
        RingGauge(
            fraction: goal > 0 ? min(current / goal, 1.0) : 0,
            tint: tint,
            lineWidth: 3
        ) {
            Text(label)
                .font(.system(size: labelSize).bold())
                .foregroundStyle(tint)
        }
        .frame(width: 26, height: 26)
    }
}

private struct ScoreboardStreakBadge: View {
    let days: Int
    let tint: Color
    @ScaledMetric(relativeTo: .caption2) private var iconSize: CGFloat = 11

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.system(size: iconSize))
            Text(days, format: .number)
                .roundedDigits(.caption, weight: .bold)
        }
        .foregroundStyle(days > 0 ? tint : Color.secondary)
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
            ScoreboardWidgetView(metrics: entry.metrics, loadFailed: entry.loadFailed)
                .containerBackground(.fill, for: .widget)
        }
        .configurationDisplayName("Scoreboard")
        .description("Today's progress across your metrics.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
