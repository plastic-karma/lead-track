import Foundation

/// Period math shared by additional-review totals and notifications. A report
/// always describes one completed half-open period, while its notification
/// lands at the beginning of the following period.
enum AdditionalReviewSchedule {
    private struct Step {
        let component: Calendar.Component
        let value: Int
    }

    static func period(
        for review: AdditionalReview,
        periodsBack: Int = 0,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DateInterval {
        let step = step(for: review)
        let boundary = boundary(for: review, containing: now, calendar: calendar)
        let offset = -max(periodsBack, 0)
        let end = advance(boundary, by: step, periods: offset, calendar: calendar)
        let start = advance(end, by: step, periods: -1, calendar: calendar)
        return DateInterval(start: start, end: end)
    }

    static func nextReviewDate(
        for review: AdditionalReview,
        after now: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        let step = step(for: review)
        var boundary = boundary(for: review, containing: now, calendar: calendar)
        if review.cycle == .custom {
            let first = advance(anchorDay(for: review, calendar: calendar), by: step, periods: 1, calendar: calendar)
            if boundary < first { boundary = first }
        }
        var candidate = fireDate(on: boundary, for: review, calendar: calendar)
        if candidate <= now {
            boundary = advance(boundary, by: step, periods: 1, calendar: calendar)
            candidate = fireDate(on: boundary, for: review, calendar: calendar)
        }
        return candidate
    }

    private static func step(for review: AdditionalReview) -> Step {
        switch review.cycle {
        case .monthly:
            Step(component: .month, value: 1)
        case .quarterly:
            Step(component: .month, value: 3)
        case .yearly:
            Step(component: .year, value: 1)
        case .custom:
            Step(
                component: review.customUnit == .days ? .day : .month,
                value: review.boundedInterval
            )
        }
    }

    private static func boundary(
        for review: AdditionalReview,
        containing date: Date,
        calendar: Calendar
    ) -> Date {
        switch review.cycle {
        case .monthly:
            monthStart(containing: date, calendar: calendar)
        case .quarterly:
            quarterStart(containing: date, calendar: calendar)
        case .yearly:
            yearStart(containing: date, calendar: calendar)
        case .custom:
            customBoundary(for: review, containing: date, calendar: calendar)
        }
    }

    private static func customBoundary(
        for review: AdditionalReview,
        containing date: Date,
        calendar: Calendar
    ) -> Date {
        let anchor = anchorDay(for: review, calendar: calendar)
        if review.customUnit == .days {
            let day = calendar.startOfDay(for: date)
            let distance = calendar.dateComponents([.day], from: anchor, to: day).day ?? 0
            let periods = floorQuotient(distance, divisor: review.boundedInterval)
            return calendar.date(
                byAdding: .day,
                value: periods * review.boundedInterval,
                to: anchor
            ) ?? anchor
        }
        return customMonthBoundary(
            anchor: anchor, interval: review.boundedInterval,
            containing: date, calendar: calendar
        )
    }

    private static func customMonthBoundary(
        anchor: Date,
        interval: Int,
        containing date: Date,
        calendar: Calendar
    ) -> Date {
        let anchorParts = calendar.dateComponents([.year, .month], from: anchor)
        let dateParts = calendar.dateComponents([.year, .month], from: date)
        let anchorIndex = monthIndex(year: anchorParts.year, month: anchorParts.month)
        let dateIndex = monthIndex(year: dateParts.year, month: dateParts.month)
        let periods = floorQuotient(dateIndex - anchorIndex, divisor: interval)
        return calendar.date(
            byAdding: .month,
            value: periods * interval,
            to: anchor
        ) ?? anchor
    }

    private static func anchorDay(
        for review: AdditionalReview,
        calendar: Calendar
    ) -> Date {
        review.customUnit == .months
            ? monthStart(containing: review.anchor, calendar: calendar)
            : calendar.startOfDay(for: review.anchor)
    }

    private static func advance(
        _ date: Date,
        by step: Step,
        periods: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            byAdding: step.component,
            value: step.value * periods,
            to: date
        ) ?? date
    }

    private static func fireDate(
        on day: Date,
        for review: AdditionalReview,
        calendar: Calendar
    ) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = review.boundedHour
        components.minute = review.boundedMinute
        return calendar.date(from: components) ?? day
    }

    private static func monthStart(containing date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private static func quarterStart(containing date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        let month = components.month ?? 1
        let quarterMonth = month - ((month - 1) % 3)
        return calendar.date(from: DateComponents(
            year: components.year, month: quarterMonth, day: 1
        )) ?? calendar.startOfDay(for: date)
    }

    private static func yearStart(containing date: Date, calendar: Calendar) -> Date {
        let year = calendar.component(.year, from: date)
        return calendar.date(from: DateComponents(year: year, month: 1, day: 1))
            ?? calendar.startOfDay(for: date)
    }

    private static func monthIndex(year: Int?, month: Int?) -> Int {
        (year ?? 0) * 12 + (month ?? 1) - 1
    }

    private static func floorQuotient(_ dividend: Int, divisor: Int) -> Int {
        let quotient = dividend / divisor
        return dividend % divisor < 0 ? quotient - 1 : quotient
    }
}
