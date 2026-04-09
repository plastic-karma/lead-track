import Foundation
import Testing
@testable import lead_track

struct DurationFormatterTests {
    @Test
    func formatsSeconds() {
        #expect(DurationFormatter.format(45) == "45s")
    }

    @Test
    func formatsMinutesAndSeconds() {
        #expect(DurationFormatter.format(125) == "2m 05s")
    }

    @Test
    func formatsHoursAndMinutes() {
        #expect(DurationFormatter.format(3661) == "1h 01m")
    }

    @Test
    func formatsZero() {
        #expect(DurationFormatter.format(0) == "0s")
    }

    @Test
    func formatsExactMinute() {
        #expect(DurationFormatter.format(60) == "1m 00s")
    }

    @Test
    func formatsExactHour() {
        #expect(DurationFormatter.format(3600) == "1h 00m")
    }
}
