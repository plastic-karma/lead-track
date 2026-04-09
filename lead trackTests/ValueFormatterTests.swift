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
    func formatCountTruncatesDecimals() {
        let result = ValueFormatter.format(
            3.7, type: .count, unit: "items"
        )
        #expect(result == "3 items")
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
}
