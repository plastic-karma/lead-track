import Testing
@testable import lead_track

struct MetricDescriptionTests {
    @Test
    func newMetricHasNoDescription() {
        let metric = Metric(name: "Reading")
        #expect(metric.metricDescription == nil)
    }

    @Test
    func metricRetainsItsDescription() {
        let metric = Metric(name: "Reading", metricDescription: "The classics, slowly")
        #expect(metric.metricDescription == "The classics, slowly")
    }

    @Test
    func normalizingTrimsSurroundingWhitespace() {
        #expect(Metric.normalizedDescription("  deep work  ") == "deep work")
    }

    @Test
    func normalizingBlankInputBecomesNil() {
        #expect(Metric.normalizedDescription("") == nil)
        #expect(Metric.normalizedDescription("   \n\t ") == nil)
    }
}
