import Foundation
import Testing
@testable import lead_track

struct ComplicationTimelineTests {
    private let calendar = Calendar.current

    private var nextMidnight: Date {
        let today = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }

    /// Noon today — far from both midnights, so a live window never
    /// crosses a day boundary unless a test builds one that does.
    private var noon: Date {
        calendar.startOfDay(for: .now).addingTimeInterval(12 * 3600)
    }

    @Test
    func idleTimelineIsNowAndNextMidnight() {
        let dates = ComplicationTimeline.entryDates(
            from: noon, hasRunningTimer: false, calendar: calendar
        )

        #expect(dates == [noon, nextMidnight])
    }

    @Test
    func runningTimerEmitsSpacedStepsWithoutMidnight() {
        let dates = ComplicationTimeline.entryDates(
            from: noon, hasRunningTimer: true, calendar: calendar
        )

        let expected = (0 ... ComplicationTimeline.liveSteps).map {
            noon.addingTimeInterval(Double($0) * ComplicationTimeline.liveSpacing)
        }
        #expect(dates == expected)
        #expect(!dates.contains(nextMidnight))
    }

    @Test
    func liveWindowCrossingMidnightClipsToIt() {
        let start = nextMidnight.addingTimeInterval(-900)

        let dates = ComplicationTimeline.entryDates(
            from: start, hasRunningTimer: true, calendar: calendar
        )

        #expect(dates == [start, start.addingTimeInterval(600), nextMidnight])
    }

    @Test
    func liveStepLandingOnMidnightIsReplacedByIt() {
        let start = nextMidnight.addingTimeInterval(-600)

        let dates = ComplicationTimeline.entryDates(
            from: start, hasRunningTimer: true, calendar: calendar
        )

        #expect(dates == [start, nextMidnight])
    }

    @Test
    func datesAreStrictlyAscending() {
        for running in [false, true] {
            let dates = ComplicationTimeline.entryDates(
                from: noon, hasRunningTimer: running, calendar: calendar
            )
            #expect(dates == dates.sorted())
            #expect(Set(dates).count == dates.count)
        }
    }
}
