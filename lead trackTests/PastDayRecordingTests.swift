import Foundation
import SwiftData
import Testing
@testable import lead_track

/// Recording onto a browsed earlier day — the contract the Today tab's
/// editable past rides on: every service entry point accepts a past `at:`
/// instant, the write lands inside that day, the living today stays
/// untouched, and the browsed day's classification flips accordingly.
@MainActor
struct PastDayRecordingTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let calendar = Calendar.current
    /// One anchor per suite, captured at init (the sibling
    /// `TodayClusterPastDayTests` anchors the same way): midnight-based
    /// instants keep a test's fixtures and assertions from splitting
    /// across a midnight crossing.
    private let anchor = Calendar.current.startOfDay(for: .now)

    init() throws {
        container = try SharedModelContainer.create(inMemoryOnly: true)
        context = ModelContext(container)
    }

    /// The browsed instant every test writes at: the start of the day two
    /// days ago, safely inside its own day.
    private var browsed: Date {
        calendar.date(byAdding: .day, value: -2, to: anchor)!
    }

    private func makeMetric(type: MeasurementType) throws -> Metric {
        let metric = Metric(name: "Focus", measurementType: type)
        context.insert(metric)
        try context.save()
        return metric
    }

    @Test
    func backdatedCountLandsOnTheBrowsedDay() throws {
        let metric = try makeMetric(type: .count)

        SessionService.logCount(2, for: metric, in: context, at: browsed)

        #expect(SessionStatistics.todayTotal(from: metric.sessions, now: browsed) == 2)
        #expect(SessionStatistics.todayTotal(from: metric.sessions) == 0)
    }

    @Test
    func backdatedDurationLandsOnTheBrowsedDay() throws {
        let metric = try makeMetric(type: .duration)

        SessionService.logDuration(600, startedAt: browsed, for: metric, in: context)

        #expect(SessionStatistics.todayTotal(from: metric.sessions, now: browsed) == 600)
        #expect(SessionStatistics.todayTotal(from: metric.sessions) == 0)
    }

    @Test
    func backdatedBinaryToggleTouchesOnlyTheBrowsedDay() throws {
        let metric = try makeMetric(type: .binary)
        #expect(SessionService.toggleBinaryDay(for: metric, in: context))

        #expect(SessionService.toggleBinaryDay(for: metric, in: context, at: browsed))
        #expect(SessionStatistics.todayTotal(from: metric.sessions, now: browsed) == 1)
        #expect(SessionStatistics.todayTotal(from: metric.sessions) == 1)

        #expect(!SessionService.toggleBinaryDay(for: metric, in: context, at: browsed))
        #expect(SessionStatistics.todayTotal(from: metric.sessions, now: browsed) == 0)
        #expect(SessionStatistics.todayTotal(from: metric.sessions) == 1)
    }

    @Test
    func backdatedLogTurnsTheBrowsedDayDone() throws {
        let metric = try makeMetric(type: .duration)
        metric.dailyGoal = 300

        SessionService.logDuration(600, startedAt: browsed, for: metric, in: context)

        #expect(TodayGrouping.metricState(metric, now: browsed) == .done)
        #expect(TodayGrouping.metricState(metric) == .needsYou)
    }
}
