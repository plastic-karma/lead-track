import Foundation
import SwiftData
import Testing
@testable import lead_track

/// Every recording entry point commits its own write. The Today rings, day
/// dial, and cluster arrangement derive from `metric.sessions`, and observers
/// of that to-many relationship only re-render once the context saves — so a
/// recording left to SwiftData's autosave keeps a met goal looking unmet for
/// many seconds. `hasChanges == false` right after the call is the contract;
/// a sibling context proves the write reached the store.
@MainActor
struct RecordingCommitTests {
    private let container: ModelContainer
    private let context: ModelContext

    init() throws {
        container = try SharedModelContainer.create(inMemoryOnly: true)
        context = ModelContext(container)
    }

    private func makeMetric(type: MeasurementType = .duration) throws -> Metric {
        let metric = Metric(name: "Focus", measurementType: type)
        context.insert(metric)
        try context.save()
        return metric
    }

    /// What a context opened fresh against the same store can see — only
    /// saved state reaches it.
    private func storedSessionCount() throws -> Int {
        try ModelContext(container).fetchCount(FetchDescriptor<Session>())
    }

    @Test
    func startSessionCommitsImmediately() throws {
        let metric = try makeMetric()

        SessionService.startSession(for: metric, in: context)

        #expect(!context.hasChanges)
        #expect(try storedSessionCount() == 1)
    }

    @Test
    func stopSessionCommitsImmediately() throws {
        let metric = try makeMetric()
        let session = SessionService.startSession(for: metric, in: context)

        SessionService.stopSession(session)

        #expect(!context.hasChanges)
        let stored = try ModelContext(container).fetch(FetchDescriptor<Session>())
        #expect(stored.count == 1)
        #expect(stored.allSatisfy { !$0.isRunning })
    }

    @Test
    func logCountCommitsImmediately() throws {
        let metric = try makeMetric(type: .count)

        SessionService.logCount(3, for: metric, in: context)

        #expect(!context.hasChanges)
        #expect(try storedSessionCount() == 1)
    }

    @Test
    func logDurationCommitsImmediately() throws {
        let metric = try makeMetric()

        SessionService.logDuration(600, startedAt: .now, for: metric, in: context)

        #expect(!context.hasChanges)
        #expect(try storedSessionCount() == 1)
    }

    @Test
    func toggleBinaryDayCommitsBothWays() throws {
        let metric = try makeMetric(type: .binary)

        #expect(SessionService.toggleBinaryDay(for: metric, in: context))
        #expect(!context.hasChanges)
        #expect(try storedSessionCount() == 1)

        #expect(!SessionService.toggleBinaryDay(for: metric, in: context))
        #expect(!context.hasChanges)
        #expect(try storedSessionCount() == 0)
    }

    @Test
    func storedTimerStateSeesSiblingContextSave() throws {
        let metric = try makeMetric()
        let sibling = ModelContext(container)
        let siblingMetric = try #require(
            sibling.fetch(FetchDescriptor<Metric>()).first
        )

        SessionService.startSession(for: siblingMetric, in: sibling)

        #expect(
            SessionService.storedRunningSession(for: metric, in: context) != nil
        )
    }

    @Test
    func binaryToggleSeesSiblingContextSave() throws {
        let metric = try makeMetric(type: .binary)
        let sibling = ModelContext(container)
        let siblingMetric = try #require(
            sibling.fetch(FetchDescriptor<Metric>()).first
        )
        #expect(SessionService.toggleBinaryDay(for: siblingMetric, in: sibling))

        #expect(try SessionService.isBinaryDayDone(for: metric, in: context))
        #expect(!SessionService.toggleBinaryDay(for: metric, in: context))
        #expect(try storedSessionCount() == 0)
    }
}
