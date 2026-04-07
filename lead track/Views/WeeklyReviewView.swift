import SwiftData
import SwiftUI

struct WeeklyReviewView: View {
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @Environment(\.dismiss) private var dismiss
    @State private var showingSettings = false

    private var periodStart: Date {
        Calendar.current.date(
            byAdding: .day, value: -6,
            to: Calendar.current.startOfDay(for: .now)
        ) ?? .now
    }

    var body: some View {
        NavigationStack {
            List {
                overviewSection
                metricsSection
            }
            .navigationTitle("Weekly Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "bell")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                WeeklyReviewSettingsView()
            }
        }
    }
}

// MARK: - Overview

extension WeeklyReviewView {
    private var overviewSection: some View {
        Section {
            dateRangeRow
            totalTimeRow
            bestDayRow
        }
    }

    private var dateRangeRow: some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundStyle(.orange)
            Text(formattedRange)
                .font(.subheadline)
        }
    }

    private var totalTimeRow: some View {
        let total = allTotals.reduce(0) { $0 + $1.duration }
        let sessions = allSessions.count
        return HStack {
            Image(systemName: "clock")
                .foregroundStyle(.orange)
            VStack(alignment: .leading) {
                Text(DurationFormatter.format(total))
                    .font(.headline)
                Text("\(sessions) sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var bestDayRow: some View {
        let best = allTotals
            .filter { $0.date >= periodStart }
            .max(by: { $0.duration < $1.duration })
        return HStack {
            Image(systemName: "trophy")
                .foregroundStyle(.orange)
            if let best {
                VStack(alignment: .leading) {
                    Text("Best day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(
                        "\(best.date.formatted(.dateTime.weekday(.wide))) "
                            + "— \(DurationFormatter.format(best.duration))"
                    )
                    .font(.subheadline)
                }
            } else {
                Text("No sessions this week")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Per-Metric

extension WeeklyReviewView {
    @ViewBuilder
    private var metricsSection: some View {
        let summaries = metricSummaries
        if !summaries.isEmpty {
            Section("By Metric") {
                ForEach(summaries, id: \.name) { summary in
                    metricRow(summary)
                }
            }
        }
    }

    private func metricRow(
        _ summary: MetricSummary
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: summary.icon)
                .foregroundStyle(.orange)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.name).font(.subheadline)
                metricDetail(summary)
            }
            Spacer()
            if summary.streak > 0 {
                streakBadge(summary.streak)
            }
        }
    }

    private func metricDetail(
        _ summary: MetricSummary
    ) -> some View {
        HStack(spacing: 8) {
            Text(ValueFormatter.format(
                summary.duration,
                type: summary.measurementType,
                unit: summary.unit
            ))
            Text("·")
            Text("\(summary.sessionCount) sessions")
            if let hits = summary.goalDaysHit {
                Text("·")
                Text("\(hits)/7 days")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func streakBadge(_ days: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.caption2)
            Text("\(days)")
                .font(.caption.bold())
                .monospacedDigit()
        }
        .foregroundStyle(.orange)
    }
}

// MARK: - Data

extension WeeklyReviewView {
    private var allSessions: [Session] {
        metrics.flatMap(\.sessions)
            .filter { !$0.isRunning && $0.startedAt >= periodStart }
    }

    private var allTotals: [DailyTotal] {
        SessionStatistics.dailyTotals(from: allSessions)
    }

    private var formattedRange: String {
        let end = Date.now
        return "\(periodStart.formatted(.dateTime.month().day()))"
            + " — \(end.formatted(.dateTime.month().day()))"
    }

    private var metricSummaries: [MetricSummary] {
        metrics.compactMap { metric in
            let sessions = metric.sessions
                .filter { !$0.isRunning && $0.startedAt >= periodStart }
            guard !sessions.isEmpty else { return nil }
            return buildSummary(metric: metric, sessions: sessions)
        }
    }

    private func buildSummary(
        metric: Metric,
        sessions: [Session]
    ) -> MetricSummary {
        let totals = SessionStatistics.dailyTotals(from: sessions)
        let allTotals = SessionStatistics.dailyTotals(
            from: metric.sessions.filter { !$0.isRunning }
        )
        let goalHits = metric.dailyGoal.map { goal in
            totals.filter { $0.duration >= goal }.count
        }
        return MetricSummary(
            name: metric.name,
            measurementType: metric.measurementType,
            unit: metric.unit,
            icon: metric.icon ?? "clock",
            duration: totals.reduce(0) { $0 + $1.duration },
            sessionCount: sessions.count,
            streak: SessionStatistics.currentStreak(from: allTotals),
            goalDaysHit: goalHits
        )
    }
}

// MARK: - Summary Model

extension WeeklyReviewView {
    struct MetricSummary {
        let name: String
        let measurementType: MeasurementType
        let unit: String?
        let icon: String
        let duration: TimeInterval
        let sessionCount: Int
        let streak: Int
        let goalDaysHit: Int?
    }
}
