import Foundation
import Testing
@testable import lead_track

struct InsightCopyTests {
    @Test
    func headlinesReadWithoutTheMetricName() {
        #expect(
            Insight.timeOfDayMode(bucket: .morning, ratio: 0.6, sessionCount: 6)
                .headline == "Mostly a morning thing"
        )
        #expect(
            Insight.activeDaysChange(currentDays: 5, previousDays: 2)
                .headline == "Active on more days"
        )
        #expect(
            Insight.goalHitRateChange(currentHits: 4, previousHits: 1)
                .headline == "Hitting the goal more often"
        )
    }

    @Test
    func volumeHeadlineFollowsTheDirection() {
        let up = Insight.volumeChange(
            measurementType: .duration, unit: nil,
            currentTotal: 1200, previousTotal: 600,
            currentCount: 3, previousCount: 2
        )
        let down = Insight.volumeChange(
            measurementType: .duration, unit: nil,
            currentTotal: 300, previousTotal: 600,
            currentCount: 2, previousCount: 3
        )
        #expect(up.headline == "Up this week")
        #expect(down.headline == "Down this week")
    }

    @Test
    func activeDaysDetailComparesWeeks() {
        #expect(
            Insight.activeDaysChange(currentDays: 5, previousDays: 2)
                .detail == "5/7 days vs 2/7 last week"
        )
    }

    @Test
    func streakSaverDetailTracksTheDetectorConstants() {
        // The copy derives its figures from MeasureHealth's thresholds, so
        // tuning a constant can never leave the shipped words describing a
        // detector that no longer exists.
        let detail = Insight.streakSaver(occurrences: 2, streak: 12).detail

        #expect(detail.contains("2 evenings"))
        #expect(detail.contains("\(MeasureHealth.lookbackDays / 7) weeks"))
        #expect(detail.contains("\(Int(MeasureHealth.saverValueShare * 100))% of"))
        #expect(detail.contains("after 9 pm"))
        #expect(detail.hasSuffix("?"))
    }
}
