import Foundation
import Testing
@testable import lead_track

struct ExportRangeTests {
    private let calendar = Calendar.current

    private var today: Date {
        calendar.startOfDay(for: .now)
    }

    // MARK: - Cutoff

    @Test
    func allTimeHasNoCutoff() {
        #expect(ExportRange.allTime.cutoff() == nil)
    }

    @Test
    func last7DaysOpensSixDaysBackAtMidnight() {
        let expected = calendar.date(byAdding: .day, value: -6, to: today)
        #expect(ExportRange.last7Days.cutoff() == expected)
    }

    @Test
    func lastMonthsIsDayAlignedMonthsBack() {
        let expected = calendar.date(byAdding: .month, value: -3, to: today)
        #expect(ExportRange.lastMonths(3).cutoff() == expected)
    }

    @Test
    func lastYearsIsDayAlignedYearsBack() {
        let expected = calendar.date(byAdding: .year, value: -2, to: today)
        #expect(ExportRange.lastYears(2).cutoff() == expected)
    }

    @Test
    func yearToDateOpensOnJanuaryFirst() throws {
        let cutoff = try #require(ExportRange.yearToDate.cutoff())
        let parts = calendar.dateComponents([.year, .month, .day], from: cutoff)
        #expect(parts.year == calendar.component(.year, from: .now))
        #expect(parts.month == 1)
        #expect(parts.day == 1)
    }

    // MARK: - Labels

    @Test
    func labelsSpellTheCountAndDropItAtOne() {
        #expect(ExportRange.last7Days.label == "Last 7 Days")
        #expect(ExportRange.lastMonths(1).label == "Last Month")
        #expect(ExportRange.lastMonths(3).label == "Last 3 Months")
        #expect(ExportRange.yearToDate.label == "Year to Date")
        #expect(ExportRange.lastYears(1).label == "Last Year")
        #expect(ExportRange.lastYears(5).label == "Last 5 Years")
        #expect(ExportRange.allTime.label == "All Time")
    }

    @Test
    func fileSlugDerivesFromTheLabel() {
        #expect(ExportRange.lastMonths(3).fileSlug == "last-3-months")
        #expect(ExportRange.allTime.fileSlug == "all-time")
    }

    // MARK: - Form Selection

    @Test
    func makeResolvesEachKindAgainstItsCount() {
        #expect(ExportRange.make(.last7Days, months: 6, years: 2) == .last7Days)
        #expect(ExportRange.make(.lastMonths, months: 6, years: 2) == .lastMonths(6))
        #expect(ExportRange.make(.yearToDate, months: 6, years: 2) == .yearToDate)
        #expect(ExportRange.make(.lastYears, months: 6, years: 2) == .lastYears(2))
        #expect(ExportRange.make(.allTime, months: 6, years: 2) == .allTime)
    }
}
