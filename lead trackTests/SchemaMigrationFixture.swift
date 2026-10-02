#if canImport(SwiftData)
import Foundation
import SwiftData
@testable import lead_track

/// Writes the released model graph, not today's models with a V1 label.
/// Each open lives inside an autorelease pool so the next phase reopens disk.
enum SchemaMigrationFixture {
    static let date = Date(timeIntervalSince1970: 1_700_000_000)
    static let later = date.addingTimeInterval(3600)
    static let metricID = UUID()
    static let aspirationID = UUID()
    static let principleID = UUID()
    static let intentionID = UUID()
    static let checkInID = UUID()
    static let momentID = UUID()
    static let predecessorID = UUID()
    static let projectID = UUID()
    static let sessionID = UUID()
    static let photoID = UUID()
    static let transactionID = UUID()
    static let photoBytes = Data(repeating: 0xA7, count: 2 * 1024 * 1024)
    static let imageBytes = Data(repeating: 0x3C, count: 1024 * 1024)
    static let destination = "owner/repository/main/LeadStone"

    static func writeV1(at url: URL) throws {
        try autoreleasepool {
            let schema = Schema(versionedSchema: LeadTrackSchemaV1.self)
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            context.autosaveEnabled = false
            populate(context)
            try context.save()
        }
    }

    static func openV2(at url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: LeadTrackSchemaV2.self)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(
            for: schema,
            migrationPlan: LeadTrackMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private static func populate(_ context: ModelContext) {
        let metric = makeMetric(in: context)
        let aspiration = makeAspiration(in: context)
        let project = LeadTrackSchemaV1.Project(name: "First chapter", startedAt: date)
        context.insert(project)
        project.metric = metric
        project.finishedAt = later
        project.isDefault = true
        aspiration.metrics = [metric]
        aspiration.projects = [project]
        let session = LeadTrackSchemaV1.Session(startedAt: date)
        context.insert(session)
        session.metric = metric
        session.project = project
        session.endedAt = later
        session.value = 42.5
        session.countdownDuration = 1800
        session.healthExportedAt = later
        let principle = LeadTrackSchemaV1.Principle(text: "Pages before feeds", createdAt: date)
        context.insert(principle)
        principle.stableID = principleID
        principle.aspiration = aspiration
        addIntention(to: principle, metric: metric, in: context)
        addCheckIn(to: aspiration, in: context)
        addMoment(to: principle, project: project, in: context)
    }

    private static func makeMetric(in context: ModelContext) -> LeadTrackSchemaV1.Metric {
        let metric = LeadTrackSchemaV1.Metric(name: "Writing", measurementType: .count, createdAt: date)
        context.insert(metric)
        metric.stableID = metricID
        metric.metricDescription = "Keep the original **description**."
        metric.unit = "words"
        metric.icon = "pencil"
        metric.colorName = "blue"
        metric.dailyGoal = 500
        metric.weeklyGoal = 2500
        metric.reminderTime = date
        metric.streakAlertTime = later
        metric.reminderTimes = [date, later]
        metric.reminderRandomStart = date
        metric.reminderRandomEnd = later
        metric.reminderRandomCount = 3
        metric.reminderUsesRandom = true
        metric.excludedWeekdays = [1, 7]
        configureMetricSettings(metric)
        return metric
    }

    private static func configureMetricSettings(_ metric: LeadTrackSchemaV1.Metric) {
        metric.healthSourceRaw = "historical-source"
        metric.lastHealthSyncAt = later
        metric.healthExportRaw = "historical-export"
        metric.healthExportEnabledAt = date
        metric.goalSeasonStartedAt = date
        metric.goalSeasonWeeks = 6
        metric.goalSeasonNote = "Finish a chapter"
        metric.binaryGoalRetiredAt = later
        metric.countLogStyleRaw = "incrementByOne"
        metric.archivedAt = later
        metric.isFavorite = true
    }

    private static func makeAspiration(in context: ModelContext) -> LeadTrackSchemaV1.Aspiration {
        let aspiration = LeadTrackSchemaV1.Aspiration(title: "Grow wiser", createdAt: date)
        context.insert(aspiration)
        aspiration.stableID = aspirationID
        aspiration.detail = "Read, write, reflect."
        aspiration.icon = "book"
        aspiration.colorName = "green"
        aspiration.imageData = imageBytes
        aspiration.archivedAt = later
        aspiration.displayOrder = 4
        return aspiration
    }

    private static func addIntention(
        to principle: LeadTrackSchemaV1.Principle,
        metric: LeadTrackSchemaV1.Metric,
        in context: ModelContext
    ) {
        let intention = LeadTrackSchemaV1.Intention(
            title: "Write each morning", kindRaw: "derived", weekStart: date, createdAt: date
        )
        context.insert(intention)
        intention.stableID = intentionID
        intention.aspiration = principle.aspiration
        intention.principle = principle
        intention.metric = metric
        intention.derivedModeRaw = "amount"
        intention.perDay = true
        intention.target = 5
        intention.tickDates = [date, later]
        intention.outcomeRaw = "done"
        intention.closedAt = later
        intention.predecessorID = predecessorID
        intention.promotionDismissed = true
        intention.questionText = "Did I write?"
        intention.questionWindowStart = date
        intention.questionWindowEnd = later
    }

    private static func addCheckIn(to aspiration: LeadTrackSchemaV1.Aspiration, in context: ModelContext) {
        let checkIn = LeadTrackSchemaV1.AspirationCheckIn(ratingRaw: 3, weekStart: date, createdAt: date)
        context.insert(checkIn)
        checkIn.stableID = checkInID
        checkIn.aspiration = aspiration
        checkIn.note = "The work serves the why."
    }

    private static func addMoment(
        to principle: LeadTrackSchemaV1.Principle,
        project: LeadTrackSchemaV1.Project,
        in context: ModelContext
    ) {
        let moment = LeadTrackSchemaV1.Moment(text: "A chapter kept", occurredAt: date, createdAt: later)
        context.insert(moment)
        moment.stableID = momentID
        moment.aspiration = principle.aspiration
        moment.principle = principle
        moment.metric = project.metric
        moment.project = project
        moment.latitude = 48.25
        moment.longitude = 11.5
        moment.placeName = "The library"
        let photo = LeadTrackSchemaV1.MomentPhoto(data: photoBytes, sortIndex: 2)
        context.insert(photo)
        photo.moment = moment
    }
}
#endif
