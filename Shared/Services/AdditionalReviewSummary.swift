import Foundation

/// The numeric read for one completed additional-review period. It is kept
/// separate from `WeeklyReview`: weekly intentions, check-ins, goal seasons,
/// and the trailing-seven-day doctrine remain weekly-only.
struct AdditionalReviewSummary: Equatable {
    struct MetricTotal: Equatable, Identifiable {
        let id: String
        let name: String
        let icon: String
        let colorName: String?
        let measurementType: MeasurementType
        let unit: String?
        let total: Double
        let sessionCount: Int
        let activeDays: Int
    }

    let period: DateInterval
    let metrics: [MetricTotal]
    let totalDuration: TimeInterval
    let sessionCount: Int
    let activeDays: Int

    static func build(
        review: AdditionalReview,
        metrics: [Metric],
        periodsBack: Int = 0,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> AdditionalReviewSummary {
        let period = AdditionalReviewSchedule.period(
            for: review, periodsBack: periodsBack, now: now, calendar: calendar
        )
        let totals = metrics.unarchived.compactMap {
            metricTotal(for: $0, period: period, calendar: calendar)
        }
        return AdditionalReviewSummary(
            period: period,
            metrics: totals,
            totalDuration: totals
                .filter { $0.measurementType == .duration }
                .reduce(0) { $0 + $1.total },
            sessionCount: totals.reduce(0) { $0 + $1.sessionCount },
            activeDays: activeDays(in: metrics.unarchived, period: period, calendar: calendar)
        )
    }

    private static func metricTotal(
        for metric: Metric,
        period: DateInterval,
        calendar: Calendar
    ) -> MetricTotal? {
        let sessions = completedSessions(of: metric, in: period)
        guard !sessions.isEmpty else { return nil }
        return MetricTotal(
            id: metric.stableIdentity,
            name: metric.name,
            icon: metric.displayIcon,
            colorName: metric.colorName,
            measurementType: metric.measurementType,
            unit: metric.unit,
            total: sessions.reduce(0) { $0 + $1.trackingValue },
            sessionCount: sessions.count,
            activeDays: Set(sessions.map { calendar.startOfDay(for: $0.startedAt) }).count
        )
    }

    private static func activeDays(
        in metrics: [Metric],
        period: DateInterval,
        calendar: Calendar
    ) -> Int {
        let days = metrics.flatMap { metric in
            completedSessions(of: metric, in: period).map {
                calendar.startOfDay(for: $0.startedAt)
            }
        }
        return Set(days).count
    }

    private static func completedSessions(
        of metric: Metric,
        in period: DateInterval
    ) -> [Session] {
        metric.sessions.filter {
            !$0.isRunning && $0.startedAt >= period.start && $0.startedAt < period.end
        }
    }
}
