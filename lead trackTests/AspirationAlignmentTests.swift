import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

struct AspirationAlignmentTests {
    private let m: ModelFixture

    init() throws {
        m = try ModelFixture()
    }

    // MARK: - Fixtures (thin wrappers over the shared ModelFixture)

    private var calendar: Calendar {
        m.calendar
    }

    private var now: Date {
        m.anchor
    }

    /// The normalized start of the calendar week `weeksAgo` weeks back.
    private func week(_ weeksAgo: Int) -> Date {
        m.week(weeksAgo)
    }

    private func makeAspiration() -> Aspiration {
        m.makeAspiration()
    }

    @discardableResult
    private func checkIn(
        _ aspiration: Aspiration,
        weeksAgo: Int,
        rating: AlignmentRating,
        createdAt: Date? = nil
    ) -> AspirationCheckIn {
        m.checkIn(aspiration, weeksAgo: weeksAgo, rating: rating, createdAt: createdAt)
    }

    private func makeAttachedMetric(_ aspiration: Aspiration) -> Metric {
        let metric = m.makeMetric()
        aspiration.metrics.append(metric)
        return metric
    }

    private func addWeeklySessions(
        _ aspiration: Aspiration,
        metric: Metric,
        weeksAgo: Int,
        count: Int
    ) {
        for index in 0 ..< count {
            let start = week(weeksAgo).addingTimeInterval(Double(index) * 3600)
            m.addDuration(600, to: metric, at: start)
        }
    }

    @Test
    func seriesIsOldestFirstWithLatestEditWinning() {
        let aspiration = makeAspiration()
        checkIn(aspiration, weeksAgo: 2, rating: .serving)
        checkIn(aspiration, weeksAgo: 1, rating: .drifting, createdAt: week(1))
        checkIn(aspiration, weeksAgo: 1, rating: .unsure, createdAt: week(1).addingTimeInterval(60))

        let series = AspirationAlignment.series(from: aspiration.checkIns)

        #expect(series.map(\.rating) == [3, 2])
        #expect(series.map(\.weekStart) == [week(2), week(1)])
    }

    @Test
    func effortSeriesBucketsSessionsByCalendarWeek() {
        let aspiration = makeAspiration()
        let metric = makeAttachedMetric(aspiration)
        addWeeklySessions(aspiration, metric: metric, weeksAgo: 2, count: 3)
        addWeeklySessions(aspiration, metric: metric, weeksAgo: 0, count: 1)

        let effort = AspirationAlignment.effortSeries(for: aspiration, weeks: 4, now: now)

        #expect(effort == [0, 3, 0, 1])
    }

    @Test
    func effortSeriesIgnoresRunningSessions() {
        let aspiration = makeAspiration()
        let metric = makeAttachedMetric(aspiration)
        let running = Session(metric: metric, startedAt: week(0))
        #if canImport(SwiftData)
        context.insert(running)
        #else
        metric.sessions.append(running)
        #endif

        let effort = AspirationAlignment.effortSeries(for: aspiration, weeks: 2, now: now)

        #expect(effort == [0, 0])
    }

    private func fallingRatings(_ aspiration: Aspiration) {
        checkIn(aspiration, weeksAgo: 5, rating: .serving)
        checkIn(aspiration, weeksAgo: 4, rating: .serving)
        checkIn(aspiration, weeksAgo: 2, rating: .unsure)
        checkIn(aspiration, weeksAgo: 1, rating: .unsure)
    }

    @Test
    func divergenceFiresOnFallingRatingsWithRisingEffort() throws {
        let aspiration = makeAspiration()
        fallingRatings(aspiration)

        let divergence = try #require(AspirationAlignment.divergence(
            alignment: AspirationAlignment.series(from: aspiration.checkIns),
            effort: [1, 1, 2, 4, 5, 6],
            now: now
        ))

        #expect(divergence.firstRating == 3)
        #expect(divergence.lastRating == 2)
        #expect(divergence.effortChangeRatio > 1)
    }

    @Test
    func divergenceStaysSilentBelowMinimumCheckIns() {
        let aspiration = makeAspiration()
        checkIn(aspiration, weeksAgo: 4, rating: .serving)
        checkIn(aspiration, weeksAgo: 2, rating: .unsure)
        checkIn(aspiration, weeksAgo: 1, rating: .drifting)

        let divergence = AspirationAlignment.divergence(
            alignment: AspirationAlignment.series(from: aspiration.checkIns),
            effort: [1, 1, 2, 4, 5, 6],
            now: now
        )

        #expect(divergence == nil)
    }

    @Test
    func divergenceStaysSilentWhenEffortFalls() {
        let aspiration = makeAspiration()
        fallingRatings(aspiration)

        let divergence = AspirationAlignment.divergence(
            alignment: AspirationAlignment.series(from: aspiration.checkIns),
            effort: [6, 5, 4, 2, 1, 1],
            now: now
        )

        #expect(divergence == nil)
    }

    @Test
    func divergenceStaysSilentWhenRatingsHold() {
        let aspiration = makeAspiration()
        for weeksAgo in 1 ... 4 {
            checkIn(aspiration, weeksAgo: weeksAgo, rating: .serving)
        }

        let divergence = AspirationAlignment.divergence(
            alignment: AspirationAlignment.series(from: aspiration.checkIns),
            effort: [1, 1, 2, 4, 5, 6],
            now: now
        )

        #expect(divergence == nil)
    }

    @Test
    func divergenceStaysSilentOnZeroEffort() {
        let aspiration = makeAspiration()
        fallingRatings(aspiration)

        let divergence = AspirationAlignment.divergence(
            alignment: AspirationAlignment.series(from: aspiration.checkIns),
            effort: [0, 0, 0, 0, 0, 0],
            now: now
        )

        #expect(divergence == nil)
    }

    // MARK: - Current week upsert target

    @Test
    func currentWeekCheckInFindsLatestThisWeekOnly() throws {
        let aspiration = makeAspiration()
        checkIn(aspiration, weeksAgo: 1, rating: .serving)
        let latest = checkIn(
            aspiration, weeksAgo: 0, rating: .unsure,
            createdAt: week(0).addingTimeInterval(120)
        )
        checkIn(aspiration, weeksAgo: 0, rating: .drifting, createdAt: week(0))

        let found = try #require(AspirationAlignment.currentWeekCheckIn(of: aspiration, now: now))

        #expect(found.ratingRaw == latest.ratingRaw)
    }

    // MARK: - Review card offer

    @Test
    func reviewOffersCheckInOnlyOnLiveUncheckedWeek() throws {
        let aspiration = makeAspiration()
        let metric = makeAttachedMetric(aspiration)
        // Real `.now` (not midnight): the week's first instant is then always
        // strictly inside the review period, whatever today's weekday is.
        addWeeklySessions(aspiration, metric: metric, weeksAgo: 0, count: 1)

        let unchecked = WeeklyReview.build(metrics: [metric], aspirations: [aspiration])
        let uncheckedWeek = try #require(unchecked.aspirationWeeks.first)
        #expect(uncheckedWeek.offersCheckIn)

        checkIn(aspiration, weeksAgo: 0, rating: .serving)
        let checked = WeeklyReview.build(
            metrics: [metric], aspirations: [aspiration], checkIns: aspiration.checkIns
        )
        let checkedWeek = try #require(checked.aspirationWeeks.first)
        #expect(!checkedWeek.offersCheckIn)

        let earlier = WeeklyReview.build(
            metrics: [metric], aspirations: [aspiration], weeksBack: 1
        )
        #expect(earlier.aspirationWeeks.allSatisfy { !$0.offersCheckIn })
    }
}

// MARK: - Divergence branches & integration

extension AspirationAlignmentTests {
    private func attachMetric(to aspiration: Aspiration) -> Metric {
        let metric = m.makeMetric(name: "Walking")
        aspiration.metrics.append(metric)
        return metric
    }

    private func addSession(_ metric: Metric, at start: Date) {
        m.addDuration(600, to: metric, at: start)
    }

    @Test
    func exactlyFlatEffortStillFires() throws {
        // The "flat or rising" contract: secondMean == firstMean must fire
        // with ratio 1 — a `>` regression would read flat as falling.
        let aspiration = makeAspiration()
        fallingRatings(aspiration)

        let divergence = try #require(AspirationAlignment.divergence(
            alignment: AspirationAlignment.series(from: aspiration.checkIns),
            effort: [2, 2, 2, 2, 2, 2],
            now: now
        ))

        #expect(divergence.effortChangeRatio == 1)
    }

    @Test
    func effortOnlyInTheSecondHalfReadsAsRatioOne() throws {
        let aspiration = makeAspiration()
        fallingRatings(aspiration)

        let divergence = try #require(AspirationAlignment.divergence(
            alignment: AspirationAlignment.series(from: aspiration.checkIns),
            effort: [0, 0, 0, 3, 3, 3],
            now: now
        ))

        #expect(divergence.effortChangeRatio == 1)
    }

    @Test
    func effortSeriesFeedsDivergenceEndToEnd() throws {
        // The real pipeline: sessions -> effortSeries(weeks: 12) ->
        // divergence, including the suffix trim of the 12-week history.
        let aspiration = makeAspiration()
        fallingRatings(aspiration)
        let metric = attachMetric(to: aspiration)
        addSession(metric, at: week(8).addingTimeInterval(3600))
        addSession(metric, at: week(5).addingTimeInterval(3600))
        addSession(metric, at: week(1).addingTimeInterval(3600))
        addSession(metric, at: week(1).addingTimeInterval(7200))

        let effort = AspirationAlignment.effortSeries(for: aspiration, weeks: 12, now: now)
        let divergence = try #require(AspirationAlignment.divergence(
            alignment: AspirationAlignment.series(from: aspiration.checkIns),
            effort: effort,
            now: now
        ))

        #expect(effort.count == 12)
        #expect(divergence.windowWeeks == 6)
        #expect(divergence.effortChangeRatio == 2)
    }
}
