import Foundation
import Testing
@testable import lead_track

struct DurationFormatterTests {
    @Test(arguments: [
        (TimeInterval(45), "45s"),
        (TimeInterval(125), "2m 05s"),
        (TimeInterval(3661), "1h 01m"),
        (TimeInterval(0), "0s"),
        (TimeInterval(60), "1m 00s"),
        (TimeInterval(3600), "1h 00m"),
        // Clock skew can hand the formatter a negative or fractional
        // duration; it clamps and truncates instead of showing "-1s".
        (TimeInterval(-30), "0s"),
        (TimeInterval(45.9), "45s")
    ])
    func formatSpellsHoursMinutesSeconds(interval: TimeInterval, expected: String) {
        #expect(DurationFormatter.format(interval) == expected)
    }

    @Test(arguments: [
        (TimeInterval(2700), "45m"),
        (TimeInterval(3600), "1h"),
        (TimeInterval(3900), "1h05"),
        (TimeInterval(59), "0m"),
        (TimeInterval(0), "0m"),
        (TimeInterval(-30), "0m")
    ])
    func compactSpellsTinyDialForms(interval: TimeInterval, expected: String) {
        #expect(DurationFormatter.compact(interval) == expected)
    }
}
