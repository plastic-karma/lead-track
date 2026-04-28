import Testing
@testable import lead_track

struct CSVImporterTests {
    @Test
    func headerConstantIsExpected() {
        #expect(
            CSVImporter.expectedHeader
                == "Metric,Project,Date,Start,End,Duration (s),Value,Type"
        )
    }
}
