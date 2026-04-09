import Foundation
import Testing
@testable import lead_track

struct CSVExporterTests {
    // MARK: - Escape

    @Test
    func escapePlainText() {
        #expect(CSVExporter.escape("hello") == "hello")
    }

    @Test
    func escapeTextWithComma() {
        #expect(CSVExporter.escape("a,b") == "\"a,b\"")
    }

    @Test
    func escapeTextWithQuotes() {
        #expect(CSVExporter.escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
    }

    @Test
    func escapeTextWithNewline() {
        #expect(CSVExporter.escape("line1\nline2") == "\"line1\nline2\"")
    }

    @Test
    func escapeEmptyString() {
        #expect(CSVExporter.escape("") == "")
    }

    // MARK: - Build CSV

    @Test
    func buildCSVIncludesHeader() {
        let csv = CSVExporter.buildCSV(from: [])
        #expect(csv.hasPrefix("Metric,Project,Date,Start,End,"))
    }

    @Test
    func buildCSVIncludesSessionRow() {
        let now = Date.now
        let session = Session(
            startedAt: now,
            endedAt: now.addingTimeInterval(60)
        )
        let csv = CSVExporter.buildCSV(from: [session])
        let lines = csv.components(separatedBy: "\n")
        #expect(lines.count == 2)
    }

    // MARK: - Cutoff Date

    @Test
    func cutoffDateForAllReturnsNil() {
        #expect(CSVExporter.cutoffDate(for: .all) == nil)
    }

    @Test
    func cutoffDateForLast7DaysIsNotNil() {
        #expect(CSVExporter.cutoffDate(for: .last7Days) != nil)
    }

    // MARK: - Filter by Scope

    @Test
    func filterByScopeAllReturnsEverything() {
        let s1 = Session(startedAt: .now, endedAt: .now)
        let s2 = Session(startedAt: .now, endedAt: .now)
        let result = CSVExporter.filterByScope(
            [s1, s2], scope: .all
        )
        #expect(result.count == 2)
    }

    // MARK: - Filter by Time

    @Test
    func filterByTimeWithNilCutoffReturnsAll() {
        let s1 = Session(startedAt: .distantPast, endedAt: .now)
        let result = CSVExporter.filterByTime(
            [s1], cutoff: nil
        )
        #expect(result.count == 1)
    }

    @Test
    func filterByTimeExcludesOldSessions() {
        let old = Session(
            startedAt: .distantPast,
            endedAt: .distantPast
        )
        let recent = Session(
            startedAt: .now,
            endedAt: .now
        )
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -7, to: .now
        )
        let result = CSVExporter.filterByTime(
            [old, recent], cutoff: cutoff
        )
        #expect(result.count == 1)
    }
}
