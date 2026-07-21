import Foundation
import Testing
@testable import lead_track

struct RecentPhotoWindowTests {
    @Test
    func boundsAreHalfOpenLikeTheWeeklyReview() {
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        let end = Date(timeIntervalSinceReferenceDate: 2000)
        let window = RecentPhotoWindow(start: start, end: end)

        #expect(window.contains(start))
        #expect(window.contains(end.addingTimeInterval(-0.001)))
        #expect(!window.contains(start.addingTimeInterval(-0.001)))
        #expect(!window.contains(end))
    }

    @Test
    func absentCreationDateIsNotAssumedRecent() {
        let window = RecentPhotoWindow(
            start: Date(timeIntervalSinceReferenceDate: 1000),
            end: Date(timeIntervalSinceReferenceDate: 2000)
        )

        #expect(!window.contains(nil))
    }

    @Test
    func futurePhotoStaysOutsideTheReviewedPeriod() {
        let end = Date(timeIntervalSinceReferenceDate: 2000)
        let window = RecentPhotoWindow(
            start: Date(timeIntervalSinceReferenceDate: 1000),
            end: end
        )

        #expect(!window.contains(end.addingTimeInterval(60)))
    }
}
