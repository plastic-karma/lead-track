import Foundation
import Testing
@testable import lead_track

/// The "dismiss the Week check-in until next week" contract: a stored marker
/// silences the section for its own calendar week and for no other, off a
/// half-open week window like the rest of the intention layer.
struct WeeklyCheckInDismissalTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        if let utc = TimeZone(identifier: "UTC") {
            calendar.timeZone = utc
        }
        calendar.firstWeekday = 2
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    @Test
    func dismissalHoldsAcrossItsWeekAndClearsOutsideIt() throws {
        let anchor = try date(2026, 7, 16)
        let marker = WeeklyCheckInDismissal.marker(for: anchor, calendar: calendar)
        let week = try #require(calendar.dateInterval(of: .weekOfYear, for: anchor))
        func dismissed(on moment: Date) -> Bool {
            WeeklyCheckInDismissal.isDismissed(storedWeekStart: marker, on: moment, calendar: calendar)
        }

        // Half-open: the start and the final instant belong to the week; the
        // exclusive end already belongs to the next one.
        for inside in [week.start, anchor, week.end.addingTimeInterval(-1)] {
            #expect(dismissed(on: inside))
        }
        for outside in [week.start.addingTimeInterval(-1), week.end] {
            #expect(!dismissed(on: outside))
        }
    }

    @Test
    func unsetDefaultDismissesNothing() throws {
        let anchor = try date(2026, 7, 16)
        let dismissed = WeeklyCheckInDismissal.isDismissed(
            storedWeekStart: 0, on: anchor, calendar: calendar
        )
        #expect(!dismissed)
    }
}
