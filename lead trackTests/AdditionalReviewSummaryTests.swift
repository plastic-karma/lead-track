import Foundation
import Testing
@testable import lead_track

struct AdditionalReviewSummaryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        return calendar
    }

    @Test
    func totalsOnlyCompletedSessionsInsideTheChosenPeriod() throws {
        let duration = Metric(name: "Read", measurementType: .duration)
        duration.sessions = try [
            timedSession(duration, day: date(month: 6, day: 30), seconds: 7200),
            timedSession(duration, day: date(month: 7, day: 5), seconds: 3600),
            timedSession(duration, day: date(month: 7, day: 20), seconds: 1800),
            timedSession(duration, day: date(month: 8, day: 1), seconds: 9000),
            Session(metric: duration, startedAt: date(month: 7, day: 10))
        ]
        let count = Metric(name: "Pages", measurementType: .count, unit: "pages")
        count.sessions = try [
            Session(metric: count, startedAt: date(month: 7, day: 20), value: 8)
        ]
        let review = AdditionalReview(name: "Month", cycle: .monthly)
        let summary = try AdditionalReviewSummary.build(
            review: review,
            metrics: [duration, count],
            now: date(month: 8, day: 9),
            calendar: calendar
        )

        let expectedPeriod = try DateInterval(
            start: date(month: 7, day: 1),
            end: date(month: 8, day: 1)
        )
        #expect(summary.period == expectedPeriod)
        #expect(summary.totalDuration == 5400)
        #expect(summary.sessionCount == 3)
        #expect(summary.activeDays == 2)
        #expect(summary.metrics.count == 2)
        #expect(summary.metrics.first { $0.name == "Read" }?.total == 5400)
        #expect(summary.metrics.first { $0.name == "Pages" }?.total == 8)
    }

    @Test
    func browsingBackUsesWholeEarlierPeriods() throws {
        let review = AdditionalReview(name: "Month", cycle: .monthly)
        let summary = try AdditionalReviewSummary.build(
            review: review,
            metrics: [],
            periodsBack: 1,
            now: date(month: 8, day: 9),
            calendar: calendar
        )
        let expectedPeriod = try DateInterval(
            start: date(month: 6, day: 1),
            end: date(month: 7, day: 1)
        )
        #expect(summary.period == expectedPeriod)
    }

    private func timedSession(
        _ metric: Metric,
        day: Date,
        seconds: TimeInterval
    ) -> Session {
        Session(
            metric: metric,
            startedAt: day,
            endedAt: day.addingTimeInterval(seconds)
        )
    }

    private func date(month: Int, day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(
            year: 2026, month: month, day: day
        )))
    }
}
