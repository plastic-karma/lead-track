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
}
