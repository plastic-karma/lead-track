import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// The lived record a principle wears: ticks and qualifying sessions light
/// their weeks, reflective intentions and closure outcomes never do, other
/// principles' machinery is ignored, and the last-lived caption names the
/// latest activity's intention.
struct PrincipleLivingTests {
    private let calendar = Calendar.current

    #if canImport(SwiftData)
    private let context: ModelContext

    init() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        context = ModelContext(container)
    }
    #endif

    // MARK: - Fixtures

    /// Start of the current calendar week — the strip's final dot.
    private var weekStart: Date {
        Intention.weekStart(containing: .now, calendar: calendar)
    }

    /// Midnight `weeks` before the current week's start, so every fixture
    /// lands squarely inside one calendar week.
    private func weeksAgo(_ weeks: Int) -> Date {
        calendar.date(byAdding: .weekOfYear, value: -weeks, to: weekStart)!
    }

    private func makeAspiration() -> Aspiration {
        let aspiration = Aspiration(title: "A writer's life")
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        return aspiration
    }

    private func makePrinciple(_ text: String = "Pages before feeds.", of aspiration: Aspiration) -> Principle {
        let principle = Principle(text: text, aspiration: aspiration)
        #if canImport(SwiftData)
        context.insert(principle)
        #endif
        return principle
    }

    private func makeMetric() -> Metric {
        let metric = Metric(name: "Writing", measurementType: .duration, unit: nil)
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        return metric
    }

    private func addSession(to metric: Metric, at start: Date, running: Bool = false) {
        let session = Session(
            metric: metric, project: nil, startedAt: start,
            endedAt: running ? nil : start.addingTimeInterval(600), value: nil
        )
        #if canImport(SwiftData)
        context.insert(session)
        #else
        metric.sessions.append(session)
        #endif
    }

    /// A counted intention serving `principle`, born (and tickable) in the
    /// week containing `createdAt`.
    private func serving(
        _ principle: Principle?,
        of aspiration: Aspiration,
        title: String = "Write before checking email",
        createdAt: Date? = nil
    ) throws -> Intention {
        let intention = try Intention.make(
            title: title, kind: .counted, aspiration: aspiration,
            target: 3, createdAt: createdAt ?? weekStart, calendar: calendar
        )
        intention.principle = principle
        #if canImport(SwiftData)
        context.insert(intention)
        #endif
        return intention
    }

    private func record(for principle: Principle, in intentions: [Intention]) -> PrincipleLiving.Record {
        PrincipleLiving.record(for: principle, in: intentions, now: .now, calendar: calendar)
    }
}

// MARK: - Ticks

extension PrincipleLivingTests {
    @Test
    func tickLightsItsWeekAndCaptionsTheDay() throws {
        let aspiration = makeAspiration()
        let principle = makePrinciple(of: aspiration)
        let intention = try serving(principle, of: aspiration)
        #expect(intention.tick(at: weekStart, calendar: calendar))

        let record = record(for: principle, in: [intention])
        #expect(record.weeks.count == PrincipleLiving.historyWeeks)
        #expect(record.weeks.last == true)
        #expect(record.livedCount == 1)
        #expect(record.lastLived == weekStart)
        #expect(record.lastLivedVia == "Write before checking email")
    }

    @Test
    func backdatedIntentionLightsItsOwnWeek() throws {
        let aspiration = makeAspiration()
        let principle = makePrinciple(of: aspiration)
        let past = try serving(principle, of: aspiration, createdAt: weeksAgo(3))
        #expect(past.tick(at: weeksAgo(3), calendar: calendar))

        let record = record(for: principle, in: [past])
        #expect(record.weeks[PrincipleLiving.historyWeeks - 4] == true)
        #expect(record.livedCount == 1)
        #expect(record.weeks.last == false)
    }

    @Test
    func multipleTicksInOneWeekLightItOnce() throws {
        let aspiration = makeAspiration()
        let principle = makePrinciple(of: aspiration)
        let intention = try serving(principle, of: aspiration)
        #expect(intention.tick(at: weekStart, calendar: calendar))
        #expect(intention.tick(at: weekStart.addingTimeInterval(86400), calendar: calendar))

        #expect(record(for: principle, in: [intention]).livedCount == 1)
    }
}

// MARK: - Kinds & outcomes

extension PrincipleLivingTests {
    @Test
    func reflectiveIntentionContributesNothingEvenClosedDone() throws {
        let aspiration = makeAspiration()
        let principle = makePrinciple(of: aspiration)
        let reflective = try Intention.make(
            title: "Notice when I avoid the page", kind: .reflective,
            aspiration: aspiration, createdAt: weekStart, calendar: calendar
        )
        reflective.principle = principle
        #if canImport(SwiftData)
        context.insert(reflective)
        #endif
        reflective.close(outcome: .done)

        let record = record(for: principle, in: [reflective])
        #expect(record.weeks.allSatisfy { !$0 })
        #expect(record.lastLived == nil)
        #expect(record.lastLivedVia == nil)
    }

    @Test
    func derivedIntentionCountsCompletedSessionsOnly() throws {
        let aspiration = makeAspiration()
        let principle = makePrinciple(of: aspiration)
        let metric = makeMetric()
        let derived = try Intention.make(
            title: "Deep work on the essay", kind: .derived, aspiration: aspiration,
            derivedMode: .sessionCount, metric: metric, target: 3,
            createdAt: weekStart, calendar: calendar
        )
        derived.principle = principle
        #if canImport(SwiftData)
        context.insert(derived)
        #endif
        addSession(to: metric, at: weekStart, running: true)
        #expect(record(for: principle, in: [derived]).livedCount == 0)

        addSession(to: metric, at: weekStart)
        let record = record(for: principle, in: [derived])
        #expect(record.weeks.last == true)
        #expect(record.lastLivedVia == "Deep work on the essay")
    }

    @Test
    func derivedSessionsOutsideTheIntentionsWeekDoNotCount() throws {
        let aspiration = makeAspiration()
        let principle = makePrinciple(of: aspiration)
        let metric = makeMetric()
        let derived = try Intention.make(
            title: "Deep work", kind: .derived, aspiration: aspiration,
            derivedMode: .sessionCount, metric: metric, target: 3,
            createdAt: weekStart, calendar: calendar
        )
        derived.principle = principle
        #if canImport(SwiftData)
        context.insert(derived)
        #endif
        addSession(to: metric, at: weeksAgo(2))

        #expect(record(for: principle, in: [derived]).livedCount == 0)
    }
}

// MARK: - Scoping & caption

extension PrincipleLivingTests {
    @Test
    func otherPrinciplesAndUntaggedIntentionsAreIgnored() throws {
        let aspiration = makeAspiration()
        let held = makePrinciple(of: aspiration)
        let other = makePrinciple("Write what scares me.", of: aspiration)
        let servingOther = try serving(other, of: aspiration, title: "Essay drafts")
        let untagged = try serving(nil, of: aspiration, title: "Morning pages")
        #expect(servingOther.tick(at: weekStart, calendar: calendar))
        #expect(untagged.tick(at: weekStart, calendar: calendar))

        let record = record(for: held, in: [servingOther, untagged])
        #expect(record.livedCount == 0)
        #expect(record.lastLived == nil)
    }

    @Test
    func lastLivedNamesTheLatestActivitysIntention() throws {
        let aspiration = makeAspiration()
        let principle = makePrinciple(of: aspiration)
        let earlier = try serving(principle, of: aspiration, title: "Old vow", createdAt: weeksAgo(2))
        let later = try serving(principle, of: aspiration, title: "New vow")
        #expect(earlier.tick(at: weeksAgo(2), calendar: calendar))
        #expect(later.tick(at: weekStart, calendar: calendar))

        let record = record(for: principle, in: [earlier, later])
        #expect(record.livedCount == 2)
        #expect(record.lastLived == weekStart)
        #expect(record.lastLivedVia == "New vow")
    }

    @Test
    func neverLivedReadsAsTwelveHollowWeeks() {
        let aspiration = makeAspiration()
        let principle = makePrinciple(of: aspiration)

        let record = record(for: principle, in: [])
        #expect(record.weeks == Array(repeating: false, count: PrincipleLiving.historyWeeks))
        #expect(record.livedCount == 0)
        #expect(record.lastLived == nil)
    }
}
