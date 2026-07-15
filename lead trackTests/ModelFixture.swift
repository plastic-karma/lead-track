import Foundation
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// The shared dual-platform model fixture behind the aspiration suites: on
/// Apple platforms models sync through an in-memory ModelContext; the Linux
/// overlay compiles them as plain classes and wires the relationship arrays
/// directly. One implementation replaces four drifting per-suite copies —
/// suites keep thin wrappers so call sites read the same as before.
struct ModelFixture {
    let calendar = Calendar.current
    /// Midnight today, captured once per suite so a mid-test midnight can't
    /// split fixtures from assertions.
    let anchor = Calendar.current.startOfDay(for: .now)

    #if canImport(SwiftData)
    let context: ModelContext

    init() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        context = ModelContext(container)
    }
    #else
    init() throws {}
    #endif

    /// Midnight `daysAgo` days back — sessions placed at a day's first
    /// instant never land after "now".
    func day(_ daysAgo: Int) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: anchor)!
    }

    /// The normalized start of the calendar week `weeksAgo` weeks back.
    func week(_ weeksAgo: Int) -> Date {
        let current = Intention.weekStart(containing: anchor, calendar: calendar)
        return calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: current)!
    }

    func makeAspiration(_ title: String = "Grow wiser") -> Aspiration {
        let aspiration = Aspiration(title: title)
        insert(aspiration)
        return aspiration
    }

    func makeMetric(
        name: String = "Reading",
        type: MeasurementType = .duration,
        unit: String? = nil
    ) -> Metric {
        let metric = Metric(name: name, measurementType: type, unit: unit)
        insert(metric)
        return metric
    }

    func makeProject(_ name: String, of metric: Metric) -> Project {
        let project = Project(name: name, metric: metric)
        #if canImport(SwiftData)
        context.insert(project)
        #else
        metric.projects.append(project)
        #endif
        return project
    }

    func addDuration(
        _ seconds: TimeInterval,
        to metric: Metric,
        project: Project? = nil,
        at start: Date
    ) {
        register(
            Session(
                metric: metric, project: project,
                startedAt: start, endedAt: start.addingTimeInterval(seconds)
            ),
            metric: metric, project: project
        )
    }

    func addCount(
        _ value: Double,
        to metric: Metric,
        project: Project? = nil,
        at start: Date
    ) {
        register(
            Session(metric: metric, project: project, startedAt: start, value: value),
            metric: metric, project: project
        )
    }

    func register(_ session: Session, metric: Metric, project: Project? = nil) {
        #if canImport(SwiftData)
        context.insert(session)
        #else
        metric.sessions.append(session)
        project?.sessions.append(session)
        #endif
    }

    @discardableResult
    func checkIn(
        _ aspiration: Aspiration,
        weeksAgo: Int,
        rating: AlignmentRating,
        createdAt: Date? = nil
    ) -> AspirationCheckIn {
        let row = AspirationCheckIn(
            aspiration: aspiration,
            rating: rating,
            weekStart: week(weeksAgo),
            createdAt: createdAt ?? week(weeksAgo)
        )
        #if canImport(SwiftData)
        context.insert(row)
        #else
        aspiration.checkIns.append(row)
        #endif
        return row
    }

    #if canImport(SwiftData)
    private func insert(_ model: some PersistentModel) {
        context.insert(model)
    }
    #else
    private func insert(_ model: AnyObject) {}
    #endif
}
