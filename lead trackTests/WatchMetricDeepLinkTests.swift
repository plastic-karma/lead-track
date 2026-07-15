import Foundation
import Testing
@testable import lead_track

struct WatchMetricDeepLinkTests {
    @Test
    func urlRoundTripsThroughMetricID() throws {
        let id = UUID()
        let url = try #require(WatchMetricDeepLink.url(metricID: id))

        #expect(WatchMetricDeepLink.metricID(from: url) == id)
    }

    @Test
    func rejectsForeignScheme() throws {
        let url = try #require(URL(string: "https://metric/\(UUID().uuidString)"))

        #expect(WatchMetricDeepLink.metricID(from: url) == nil)
    }

    @Test
    func rejectsWrongHost() throws {
        let url = try #require(URL(string: "leadstone://aspiration/\(UUID().uuidString)"))

        #expect(WatchMetricDeepLink.metricID(from: url) == nil)
    }

    @Test
    func rejectsNonUUIDPath() throws {
        let url = try #require(URL(string: "leadstone://metric/not-a-uuid"))

        #expect(WatchMetricDeepLink.metricID(from: url) == nil)
    }
}
