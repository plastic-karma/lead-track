import Foundation
import Testing
@testable import lead_track

struct ValueFormatterTests {
    @Test
    func formatDurationUsesTimeFormat() {
        let result = ValueFormatter.format(
            3661, type: .duration
        )
        #expect(result == "1h 01m")
    }

    @Test
    func formatCountWithUnit() {
        let result = ValueFormatter.format(
            42, type: .count, unit: "pages"
        )
        #expect(result == "42 pages")
    }

    @Test
    func formatCountWithoutUnit() {
        let result = ValueFormatter.format(
            42, type: .count
        )
        #expect(result == "42")
    }

    @Test
    func formatCountPreservesFractions() {
        // Expected value goes through the same locale-aware style the
        // formatter uses, so the assertion is independent of the host
        // locale's decimal separator.
        let expected = 3.7.formatted(.number.precision(.fractionLength(0 ... 2)))
        let result = ValueFormatter.format(
            3.7, type: .count, unit: "items"
        )
        #expect(result == "\(expected) items")
    }

    @Test
    func formatCountRoundsToTwoFractionDigits() {
        let expected = 3.749.formatted(.number.precision(.fractionLength(0 ... 2)))
        #expect(ValueFormatter.format(3.749, type: .count) == expected)
    }

    @Test
    func formatCountKeepsWholeValuesBare() {
        #expect(ValueFormatter.format(5, type: .count) == "5")
        #expect(ValueFormatter.formatShort(5, type: .count) == "5")
    }

    @Test
    func formatShortPreservesFractions() {
        let expected = 0.5.formatted(.number.precision(.fractionLength(0 ... 2)))
        #expect(ValueFormatter.formatShort(0.5, type: .count) == expected)
    }

    @Test
    func formatBinaryShowsDayCount() {
        #expect(ValueFormatter.format(0, type: .binary) == "0 days")
        #expect(ValueFormatter.format(1, type: .binary) == "1 day")
        #expect(ValueFormatter.format(3, type: .binary) == "3 days")
    }

    @Test
    func formatShortBinaryIsInteger() {
        #expect(ValueFormatter.formatShort(1, type: .binary) == "1")
        #expect(ValueFormatter.formatShort(4, type: .binary) == "4")
    }

    @Test
    func chartLabelForBinary() {
        #expect(ValueFormatter.chartLabel(type: .binary, unit: nil) == "days")
    }

    @Test
    func chartValuePassesThroughBinary() {
        #expect(ValueFormatter.chartValue(1, type: .binary) == 1)
    }

    @Test
    func chartValueConvertsDurationToMinutes() {
        #expect(ValueFormatter.chartValue(120, type: .duration) == 2.0)
    }

    @Test
    func chartValuePassesThroughCount() {
        #expect(ValueFormatter.chartValue(42, type: .count) == 42)
    }

    @Test
    func chartLabelForDuration() {
        #expect(ValueFormatter.chartLabel(type: .duration, unit: nil) == "min")
    }

    @Test
    func chartLabelForCountWithUnit() {
        #expect(ValueFormatter.chartLabel(type: .count, unit: "pages") == "pages")
    }

    @Test
    func chartLabelForCountWithoutUnit() {
        #expect(ValueFormatter.chartLabel(type: .count, unit: nil) == "count")
    }

    @Test
    func sessionsLabelInflects() {
        #expect(ValueFormatter.sessions(1) == "1 session")
        #expect(ValueFormatter.sessions(3) == "3 sessions")
    }

    @Test
    func daysLabelInflects() {
        #expect(ValueFormatter.days(1) == "1 day")
        #expect(ValueFormatter.days(3) == "3 days")
    }
}
