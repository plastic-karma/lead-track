import Foundation
import Testing
@testable import lead_track

struct MetricNotificationRouteTests {
    @Test
    func metadataRoundTripsStableID() {
        let metricID = UUID()
        let userInfo = MetricNotificationRoute.userInfo(for: metricID)

        #expect(MetricNotificationRoute.metricID(from: userInfo) == metricID)
    }

    @Test
    func metadataRejectsMissingAndMalformedIDs() {
        #expect(MetricNotificationRoute.metricID(from: [:]) == nil)
        #expect(MetricNotificationRoute.metricID(from: ["metricStableID": "not-a-uuid"]) == nil)
    }
}
