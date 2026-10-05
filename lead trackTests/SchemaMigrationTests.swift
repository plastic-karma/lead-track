#if canImport(SwiftData)
import Foundation
import SwiftData
import Testing
@testable import lead_track

struct SchemaMigrationTests {
    private typealias Fixture = SchemaMigrationFixture

    @Test
    func releasedV1MigratesWithoutLosingItsGraphOrExternalBlobs() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "migration.store")

        try Fixture.writeV1(at: url)
        #expect(FileManager.default.fileExists(atPath: url.path))
        try migrateAndBackfill(at: url)
        try reopenAndCheck(at: url)
    }

    private func migrateAndBackfill(at url: URL) throws {
        try autoreleasepool {
            let container = try Fixture.openV2(at: url)
            let context = ModelContext(container)
            context.autosaveEnabled = false
            try assertOriginalGraph(in: context)
            try backfillNewIDs(in: context)
            #expect(try context.fetch(FetchDescriptor<VaultSyncReceipt>()).isEmpty)
            context.insert(VaultSyncReceipt(destination: Fixture.destination, transactionID: Fixture.transactionID))
            try context.save()
        }
    }

    private func backfillNewIDs(in context: ModelContext) throws {
        let project: Project = try only(in: context)
        let session: Session = try only(in: context)
        let photo: MomentPhoto = try only(in: context)
        #expect(project.stableID == nil)
        #expect(session.stableID == nil)
        #expect(photo.stableID == nil)
        project.stableID = Fixture.projectID
        session.stableID = Fixture.sessionID
        photo.stableID = Fixture.photoID
    }

    private func reopenAndCheck(at url: URL) throws {
        try autoreleasepool {
            let container = try Fixture.openV2(at: url)
            let context = ModelContext(container)
            try assertOriginalGraph(in: context)
            let project: Project = try only(in: context)
            let session: Session = try only(in: context)
            let photo: MomentPhoto = try only(in: context)
            let receipt: VaultSyncReceipt = try only(in: context)
            #expect(project.stableID == Fixture.projectID)
            #expect(session.stableID == Fixture.sessionID)
            #expect(photo.stableID == Fixture.photoID)
            #expect(receipt.destination == Fixture.destination)
            #expect(receipt.transactionID == Fixture.transactionID)
        }
    }

    private func only<Model: PersistentModel>(in context: ModelContext) throws -> Model {
        let models = try context.fetch(FetchDescriptor<Model>())
        #expect(models.count == 1)
        return try #require(models.first)
    }

    private func assertOriginalGraph(in context: ModelContext) throws {
        try assertMetric(in: context)
        try assertTracking(in: context)
        try assertAspiration(in: context)
        try assertIntention(in: context)
        try assertPrincipleAndCheckIn(in: context)
        try assertMoment(in: context)
    }
}

private extension SchemaMigrationTests {
    func assertMetric(in context: ModelContext) throws {
        let metric: Metric = try only(in: context)
        #expect(metric.stableID == Fixture.metricID)
        #expect(metric.name == "Writing")
        #expect(metric.metricDescription == "Keep the original **description**.")
        #expect(metric.measurementType == .count)
        #expect(metric.unit == "words")
        #expect(metric.icon == "pencil")
        #expect(metric.colorName == "blue")
        #expect(metric.createdAt == Fixture.date)
        #expect(metric.dailyGoal == 500)
        #expect(metric.weeklyGoal == 2500)
        #expect(metric.reminderTime == Fixture.date)
        #expect(metric.streakAlertTime == Fixture.later)
        #expect(metric.reminderTimes == [Fixture.date, Fixture.later])
        #expect(metric.reminderRandomStart == Fixture.date)
        #expect(metric.reminderRandomEnd == Fixture.later)
        #expect(metric.reminderRandomCount == 3)
        #expect(metric.reminderUsesRandom)
        #expect(metric.excludedWeekdays == [1, 7])
        #expect(metric.aspirations.map(\.stableID) == [Fixture.aspirationID])
        #expect(metric.intentions.map(\.stableID) == [Fixture.intentionID])
        #expect(metric.moments.map(\.stableID) == [Fixture.momentID])
        #expect(metric.projects.count == 1)
        #expect(metric.sessions.count == 1)
        assertMetricSettings(metric)
    }

    func assertMetricSettings(_ metric: Metric) {
        #expect(metric.healthSourceRaw == "historical-source")
        #expect(metric.lastHealthSyncAt == Fixture.later)
        #expect(metric.healthExportRaw == "historical-export")
        #expect(metric.healthExportEnabledAt == Fixture.date)
        #expect(metric.goalSeasonStartedAt == Fixture.date)
        #expect(metric.goalSeasonWeeks == 6)
        #expect(metric.goalSeasonNote == "Finish a chapter")
        #expect(metric.binaryGoalRetiredAt == Fixture.later)
        #expect(metric.countLogStyleRaw == "incrementByOne")
        #expect(metric.archivedAt == Fixture.later)
        #expect(metric.isFavorite)
    }

    func assertTracking(in context: ModelContext) throws {
        let metric: Metric = try only(in: context)
        let project: Project = try only(in: context)
        let session: Session = try only(in: context)
        #expect(project.name == "First chapter")
        #expect(project.status == .active)
        #expect(project.startedAt == Fixture.date)
        #expect(project.finishedAt == Fixture.later)
        #expect(project.isDefault)
        #expect(project.metric === metric)
        #expect(metric.projects.first === project)
        #expect(project.aspirations.map(\.stableID) == [Fixture.aspirationID])
        #expect(project.moments.map(\.stableID) == [Fixture.momentID])
        #expect(project.sessions.count == 1)
        #expect(project.sessions.first === session)
        #expect(metric.sessions.first === session)
        #expect(session.metric === metric)
        #expect(session.project === project)
        #expect(session.startedAt == Fixture.date)
        #expect(session.endedAt == Fixture.later)
        #expect(session.value == 42.5)
        #expect(session.countdownDuration == 1800)
        #expect(session.healthExportedAt == Fixture.later)
    }

    func assertAspiration(in context: ModelContext) throws {
        let aspiration: Aspiration = try only(in: context)
        let project: Project = try only(in: context)
        #expect(aspiration.stableID == Fixture.aspirationID)
        #expect(aspiration.title == "Grow wiser")
        #expect(aspiration.detail == "Read, write, reflect.")
        #expect(aspiration.icon == "book")
        #expect(aspiration.colorName == "green")
        #expect(aspiration.imageData == Fixture.imageBytes)
        #expect(aspiration.createdAt == Fixture.date)
        #expect(aspiration.archivedAt == Fixture.later)
        #expect(aspiration.displayOrder == 4)
        #expect(aspiration.metrics.map(\.stableID) == [Fixture.metricID])
        #expect(aspiration.projects.count == 1)
        #expect(aspiration.projects.first === project)
        #expect(aspiration.principles.map(\.stableID) == [Fixture.principleID])
        #expect(aspiration.intentions.map(\.stableID) == [Fixture.intentionID])
        #expect(aspiration.checkIns.map(\.stableID) == [Fixture.checkInID])
        #expect(aspiration.moments.map(\.stableID) == [Fixture.momentID])
    }
}

private extension SchemaMigrationTests {
    func assertIntention(in context: ModelContext) throws {
        let intention: Intention = try only(in: context)
        #expect(intention.stableID == Fixture.intentionID)
        #expect(intention.title == "Write each morning")
        #expect(intention.kindRaw == "derived")
        #expect(intention.derivedModeRaw == "amount")
        #expect(intention.perDay)
        #expect(intention.target == 5)
        #expect(intention.weekStart == Fixture.date)
        #expect(intention.tickDates == [Fixture.date, Fixture.later])
        #expect(intention.metric?.stableID == Fixture.metricID)
        #expect(intention.aspiration?.stableID == Fixture.aspirationID)
        #expect(intention.principle?.stableID == Fixture.principleID)
        #expect(intention.outcomeRaw == "done")
        #expect(intention.closedAt == Fixture.later)
        #expect(intention.predecessorID == Fixture.predecessorID)
        #expect(intention.promotionDismissed)
        #expect(intention.questionText == "Did I write?")
        #expect(intention.questionWindowStart == Fixture.date)
        #expect(intention.questionWindowEnd == Fixture.later)
        #expect(intention.createdAt == Fixture.date)
    }

    func assertPrincipleAndCheckIn(in context: ModelContext) throws {
        let principle: Principle = try only(in: context)
        #expect(principle.stableID == Fixture.principleID)
        #expect(principle.text == "Pages before feeds")
        #expect(principle.createdAt == Fixture.date)
        #expect(principle.aspiration?.stableID == Fixture.aspirationID)
        #expect(principle.intentions.map(\.stableID) == [Fixture.intentionID])
        #expect(principle.moments.map(\.stableID) == [Fixture.momentID])
        let checkIn: AspirationCheckIn = try only(in: context)
        #expect(checkIn.stableID == Fixture.checkInID)
        #expect(checkIn.weekStart == Fixture.date)
        #expect(checkIn.ratingRaw == 3)
        #expect(checkIn.note == "The work serves the why.")
        #expect(checkIn.createdAt == Fixture.date)
        #expect(checkIn.aspiration?.stableID == Fixture.aspirationID)
    }

    func assertMoment(in context: ModelContext) throws {
        let moment: Moment = try only(in: context)
        let photo: MomentPhoto = try only(in: context)
        let project: Project = try only(in: context)
        #expect(moment.stableID == Fixture.momentID)
        #expect(moment.text == "A chapter kept")
        #expect(moment.occurredAt == Fixture.date)
        #expect(moment.createdAt == Fixture.later)
        #expect(moment.latitude == 48.25)
        #expect(moment.longitude == 11.5)
        #expect(moment.placeName == "The library")
        #expect(moment.aspiration?.stableID == Fixture.aspirationID)
        #expect(moment.metric?.stableID == Fixture.metricID)
        #expect(moment.project === project)
        #expect(moment.principle?.stableID == Fixture.principleID)
        #expect(moment.photos.count == 1)
        #expect(moment.photos.first === photo)
        #expect(photo.moment === moment)
        #expect(photo.sortIndex == 2)
        #expect(photo.data == Fixture.photoBytes)
    }
}
#endif
