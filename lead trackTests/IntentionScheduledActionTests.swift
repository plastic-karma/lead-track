import Foundation
import Testing
@testable import lead_track

// Migration graph fixtures keep the lifecycle contract visible in one suite.
// swiftlint:disable file_length
#if canImport(SwiftData)
import SwiftData

/// `a76f37a` changed the V1 model checksum without changing its 1.0.0 version
/// identifier. Reusing the frozen V2 model types with that shipped identifier
/// recreates the metadata combination migration must recognize.
private enum ShippedDisplayOrderSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        LeadTrackHistoricalSchemaV2.models
    }
}
#endif

struct IntentionScheduledActionTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        return calendar
    }

    private func date(
        _ day: Int,
        _ hour: Int = 0,
        _ minute: Int = 0
    ) -> Date {
        let components = DateComponents(
            year: 2026,
            month: 8,
            day: day,
            hour: hour,
            minute: minute
        )
        guard let date = calendar.date(from: components) else {
            preconditionFailure("Invalid fixed test date")
        }
        return date
    }

    private var week: DateInterval {
        DateInterval(start: date(3), end: date(10))
    }

    private func draft(
        title: String = "Write the opening page",
        startsAt: Date? = nil,
        endsAt: Date? = nil
    ) -> IntentionActionDraft {
        IntentionActionDraft(
            title: title,
            startsAt: startsAt ?? date(4, 9),
            endsAt: endsAt ?? date(4, 9, 30)
        )
    }
}

// MARK: - Value Rules

extension IntentionScheduledActionTests {
    @Test
    func actionsAreOptionalAndValidOnTheirIntentionsWeek() {
        #expect(IntentionActionDraft.validated([], in: week) == [])
        #expect(draft().normalized(in: week) != nil)
    }

    @Test
    func normalizationTrimsTheTitle() throws {
        let normalized = try #require(draft(title: "  Write the opening page  ").normalized(in: week))
        #expect(normalized.title == "Write the opening page")
    }

    @Test
    func blankOrBackwardActionsAreInvalid() {
        #expect(draft(title: "  \n").normalized(in: week) == nil)
        #expect(draft(startsAt: date(4, 10), endsAt: date(4, 9)).normalized(in: week) == nil)
        #expect(draft(startsAt: date(4, 10), endsAt: date(4, 10)).normalized(in: week) == nil)
        #expect(draft(startsAt: date(4, 10), endsAt: date(4, 10, 14)).normalized(in: week) == nil)
    }

    @Test
    func duplicateStableIDsRejectTheWholeSet() {
        let original = draft()
        let duplicate = IntentionActionDraft(
            id: original.id,
            title: "Another action",
            startsAt: date(5, 9),
            endsAt: date(5, 10)
        )
        #expect(IntentionActionDraft.validated([original, duplicate], in: week) == nil)
    }

    @Test
    func actionsCannotEscapeTheWeek() {
        #expect(draft(startsAt: date(2, 23), endsAt: date(3, 1)).normalized(in: week) == nil)
        #expect(draft(startsAt: date(9, 23), endsAt: date(10, 1)).normalized(in: week) == nil)
        #expect(draft(startsAt: date(9, 23), endsAt: date(10)).normalized(in: week) != nil)
        #expect(draft(startsAt: date(10), endsAt: date(10, 1)).normalized(in: week) == nil)
    }

    @Test
    func defaultActionUsesTheNextQuarterHourForThirtyMinutes() {
        let action = IntentionActionDraft.makeDefault(in: week, now: date(4, 9, 7))
        #expect(action.startsAt == date(4, 9, 15))
        #expect(action.endsAt == date(4, 9, 45))
    }

    @Test
    func defaultActionStaysInsideTheWeekAtItsBoundary() {
        let action = IntentionActionDraft.makeDefault(in: week, now: date(9, 23, 59))
        #expect(action.startsAt == date(9, 23, 30))
        #expect(action.endsAt == week.end)
    }

    @Test
    func corruptStoredRangeClampsBeforeEditing() {
        let corrupt = draft(startsAt: date(2), endsAt: date(12))
        let clamped = corrupt.clamped(in: week)
        #expect(clamped.startsAt == week.start)
        #expect(clamped.endsAt == week.end)
        #expect(clamped.normalized(in: week) != nil)
    }

    @Test
    func storedActionRoundTripsItsStableDraftIdentity() {
        let intentionID = UUID()
        let original = draft(title: "  Make the call  ")
        let stored = IntentionAction(intentionID: intentionID, draft: original)

        #expect(stored.intentionID == intentionID)
        #expect(stored.stableID == original.id)
        #expect(stored.draft.title == "Make the call")
        #expect(stored.draft.startsAt == original.startsAt)
        #expect(stored.draft.endsAt == original.endsAt)
    }

    @Test
    func markdownExportKeepsScheduledActionsWithTheirIntention() throws {
        let aspiration = Aspiration(title: "Write with courage")
        let intention = try Intention.make(
            title: "Begin the essay",
            kind: .reflective,
            aspiration: aspiration,
            createdAt: date(4),
            calendar: calendar
        )
        let intentionID = try #require(intention.stableID)
        let action = IntentionAction(intentionID: intentionID, draft: draft())
        let markdown = MarkdownExporter.buildMarkdown(
            data: MarkdownExportData(
                aspirations: [aspiration],
                intentions: [intention],
                actions: [action]
            ),
            range: .allTime,
            now: date(5),
            calendar: calendar
        )

        #expect(markdown.contains("Scheduled actions: 1"))
        #expect(markdown.contains("  - Scheduled: \"Write the opening page\""))
    }
}

// MARK: - SwiftData Lifecycle & Migration

#if canImport(SwiftData)
extension IntentionScheduledActionTests {
    @Test
    func replacingActionsPreservesEditsAndRemovesDeletedRows() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        let context = ModelContext(container)
        let intentionID = UUID()
        let first = draft(title: "First")
        let second = draft(title: "Second", startsAt: date(5, 10), endsAt: date(5, 11))
        try context.replaceIntentionActions(for: intentionID, with: [first, second])

        var edited = first
        edited.title = "Edited"
        try context.replaceIntentionActions(for: intentionID, with: [edited])
        try context.save()

        let stored = try context.intentionActions(for: intentionID)
        #expect(stored.count == 1)
        #expect(stored.first?.stableID == first.id)
        #expect(stored.first?.title == "Edited")
    }

    @Test
    func intentionPersistsWithNoScheduledActions() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        let context = ModelContext(container)
        let aspiration = Aspiration(title: "Write with courage")
        let intention = try Intention.make(
            title: "Begin the essay",
            kind: .reflective,
            aspiration: aspiration
        )
        context.insert(aspiration)
        context.insert(intention)
        try context.save()

        let verificationContext = ModelContext(container)
        let intentionID = try #require(intention.stableID)
        #expect(try verificationContext.intentionActions(for: intentionID).isEmpty)
    }

    @Test
    func deletingAnIntentionDeletesItsActions() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        let context = ModelContext(container)
        let aspiration = Aspiration(title: "Write with courage")
        let intention = try Intention.make(
            title: "Begin the essay",
            kind: .reflective,
            aspiration: aspiration
        )
        context.insert(aspiration)
        context.insert(intention)
        let intentionID = try #require(intention.stableID)
        try context.replaceIntentionActions(for: intentionID, with: [draft()])

        try context.deleteIntentionAndActions(intention)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Intention>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<IntentionAction>()).isEmpty)
    }

    @Test
    func deletingAnAspirationDeletesItsIntentionsActions() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        let context = ModelContext(container)
        let aspiration = Aspiration(title: "Write with courage")
        let intention = try Intention.make(
            title: "Begin the essay",
            kind: .reflective,
            aspiration: aspiration
        )
        context.insert(aspiration)
        context.insert(intention)
        let intentionID = try #require(intention.stableID)
        try context.replaceIntentionActions(for: intentionID, with: [draft()])

        try context.deleteAspirationAndDependents(aspiration)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<IntentionAction>()).isEmpty)
    }

    @Test
    func syntheticV1SchemaMigratesThroughV3WithItsGraphIntact() throws {
        let fixture = try migrationFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let intentionID = try writeV1Fixture(to: fixture.store)

        do {
            let container = try openV3Store(at: fixture.store)
            try verifyMigratedGraph(
                in: ModelContext(container),
                intentionID: intentionID,
                displayOrder: nil
            )
            let context = ModelContext(container)
            context.insert(IntentionAction(intentionID: intentionID, draft: draft()))
            try context.save()
        }

        let reopened = try openV3Store(at: fixture.store)
        let context = ModelContext(reopened)
        #expect(try context.intentionActions(for: intentionID).map(\.title) == [
            "Write the opening page"
        ])
    }

    @Test
    func syntheticShippedV2SchemaMigratesToV3AndKeepsItsRank() throws {
        let fixture = try migrationFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let intentionID = try writeV2Fixture(to: fixture.store)

        let container = try openV3Store(at: fixture.store)
        try verifyMigratedGraph(
            in: ModelContext(container),
            intentionID: intentionID,
            displayOrder: 4
        )
    }

    private func migrationFixtureURL() throws -> (directory: URL, store: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return (directory, directory.appendingPathComponent("migration.store"))
    }

    private func writeV1Fixture(to url: URL) throws -> UUID {
        let schema = Schema(versionedSchema: LeadTrackHistoricalSchemaV1.self)
        let config = ModelConfiguration(schema: schema, url: url, allowsSave: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let intentionID = try populateV1Fixture(in: context)
        try context.save()
        return intentionID
    }

    // A complete graph keeps every historical entity and inverse in one fixture.
    // swiftlint:disable:next function_body_length
    private func populateV1Fixture(in context: ModelContext) throws -> UUID {
        typealias HistoricalV1 = LeadTrackHistoricalSchemaV1
        let metric = HistoricalV1.Metric(name: "Reading")
        let project = HistoricalV1.Project(name: "Essay", metric: metric)
        let session = HistoricalV1.Session(
            metric: metric,
            project: project,
            startedAt: date(4, 8),
            endedAt: date(4, 9)
        )
        let aspiration = HistoricalV1.Aspiration(title: "Write with courage")
        aspiration.metrics = [metric]
        aspiration.projects = [project]
        let principle = HistoricalV1.Principle(
            text: "Pages before feeds",
            aspiration: aspiration
        )
        let intention = HistoricalV1.Intention(
            title: "Begin the essay",
            kind: .counted,
            aspiration: aspiration,
            metric: metric,
            target: 3,
            weekStart: date(3)
        )
        intention.principle = principle
        let checkIn = HistoricalV1.AspirationCheckIn(
            aspiration: aspiration,
            rating: .serving,
            weekStart: date(3),
            note: "True enough"
        )
        let moment = HistoricalV1.Moment(
            text: "Found the opening",
            aspiration: aspiration,
            occurredAt: date(4),
            metric: metric,
            project: project
        )
        moment.principle = principle
        let photoData = Data(repeating: 0xAB, count: 1_100_000)
        let photo = HistoricalV1.MomentPhoto(data: photoData, moment: moment)

        insertV1Core(metric, project, session, into: context)
        context.insert(aspiration)
        context.insert(principle)
        context.insert(intention)
        context.insert(checkIn)
        context.insert(moment)
        context.insert(photo)
        return try #require(intention.stableID)
    }

    private func insertV1Core(
        _ metric: LeadTrackHistoricalSchemaV1.Metric,
        _ project: LeadTrackHistoricalSchemaV1.Project,
        _ session: LeadTrackHistoricalSchemaV1.Session,
        into context: ModelContext
    ) {
        context.insert(metric)
        context.insert(project)
        context.insert(session)
    }

    private func writeV2Fixture(to url: URL) throws -> UUID {
        typealias HistoricalV2 = LeadTrackHistoricalSchemaV2
        let schema = Schema(versionedSchema: ShippedDisplayOrderSchema.self)
        let config = ModelConfiguration(schema: schema, url: url, allowsSave: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let aspiration = HistoricalV2.Aspiration(title: "Write with courage")
        aspiration.displayOrder = 4
        let intention = HistoricalV2.Intention(
            title: "Begin the essay",
            kind: .reflective,
            aspiration: aspiration,
            weekStart: date(3)
        )
        context.insert(aspiration)
        context.insert(intention)
        try context.save()
        return try #require(intention.stableID)
    }

    private func openV3Store(at url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: LeadTrackSchemaV3.self)
        let config = ModelConfiguration(schema: schema, url: url, allowsSave: true)
        return try ModelContainer(
            for: schema,
            migrationPlan: LeadTrackMigrationPlan.self,
            configurations: [config]
        )
    }

    private func verifyMigratedGraph(
        in context: ModelContext,
        intentionID: UUID,
        displayOrder: Int?
    ) throws {
        let aspiration = try #require(context.fetch(FetchDescriptor<Aspiration>()).first)
        let intention = try #require(context.fetch(FetchDescriptor<Intention>()).first)

        #expect(aspiration.title == "Write with courage")
        #expect(aspiration.displayOrder == displayOrder)
        #expect(intention.stableID == intentionID)
        #expect(intention.aspiration?.title == aspiration.title)

        if displayOrder == nil {
            let metric = try #require(context.fetch(FetchDescriptor<Metric>()).first)
            let project = try #require(context.fetch(FetchDescriptor<Project>()).first)
            let principle = try #require(context.fetch(FetchDescriptor<Principle>()).first)
            #expect(metric.name == "Reading")
            #expect(project.metric?.name == "Reading")
            #expect(principle.aspiration?.title == aspiration.title)
            #expect(intention.metric?.name == metric.name)
            #expect(intention.principle?.text == principle.text)
            #expect(try context.fetch(FetchDescriptor<Session>()).first?.project?.name == project.name)
            #expect(try context.fetch(FetchDescriptor<AspirationCheckIn>()).first?.note == "True enough")
            #expect(try context.fetch(FetchDescriptor<Moment>()).first?.text == "Found the opening")
            #expect(
                try context.fetch(FetchDescriptor<MomentPhoto>()).first?.data
                    == Data(repeating: 0xAB, count: 1_100_000)
            )
        }
    }
}
#endif
