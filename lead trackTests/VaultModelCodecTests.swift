import Foundation
import Testing
@testable import lead_track

@MainActor
struct VaultModelCodecTests {
    private let instant = Date(timeIntervalSince1970: 1_750_000_000)
    private let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2])

    @Test
    func fullNineKindGraphRoundTripsBodiesFieldsAndAttachments() throws {
        let models = fixture()
        let graph = try VaultModelCodec.export(models)
        let decoded = try VaultModelCodec.materialize(graph)
        #expect(Set(graph.records.values.map(\.kind)) == Set(VaultKind.allCases))
        #expect(try VaultModelCodec.export(decoded) == graph)
        #expect(decoded.aspirations[0].detail == "Why this matters\n\nA second paragraph.\n")
        #expect(decoded.metrics[0].metricDescription == "Measure the practice.\n")
        #expect(decoded.principles[0].text == "Pages before feeds.\n")
        #expect(decoded.checkIns[0].note == "A grounded week.\n")
        #expect(decoded.moments[0].text == "Finished a difficult chapter.\n")
        #expect(decoded.aspirations[0].imageData == png)
        #expect(decoded.photos[0].data == png)
        #expect(graph.attachments.keys.allSatisfy { $0.hasPrefix("Attachments/") && $0.hasSuffix(".png") })
        #expect(decoded.projects[0].metric === decoded.metrics[0])
        #expect(decoded.sessions[0].project === decoded.projects[0])
        #expect(decoded.moments[0].principle === decoded.principles[0])
        #expect(decoded.photos[0].moment === decoded.moments[0])
        #expect(decoded.intentions[0].predecessorID == models.intentions[0].predecessorID)
        #expect(decoded.moments[0].latitude == 40.5)
    }

    @Test
    func identitiesBackfillOnceAndExistingIdentitiesSurvive() throws {
        let models = fixture()
        let preserved = models.metrics[0].stableID
        models.projects[0].stableID = nil
        models.sessions[0].stableID = nil
        models.photos[0].stableID = nil
        let first = try VaultModelCodec.export(models)
        let second = try VaultModelCodec.export(models)
        #expect(first == second)
        #expect(models.projects[0].stableID != nil)
        #expect(models.sessions[0].stableID != nil)
        #expect(models.photos[0].stableID != nil)
        #expect(models.metrics[0].stableID == preserved)
    }

    @Test
    func remoteBodyUpdatesLocalObjectWithoutChangingProtectedFlags() throws {
        let models = fixture()
        let metric = models.metrics[0]
        metric.healthExportRaw = "mindfulMinutes"
        metric.healthExportEnabledAt = instant
        metric.lastHealthSyncAt = instant
        models.sessions[0].healthExportedAt = instant
        var graph = try VaultModelCodec.export(models)
        let aspirationID = try #require(models.aspirations[0].stableID)
        let metricID = try #require(metric.stableID)
        let sessionID = try #require(models.sessions[0].stableID)
        #expect(graph.records[metricID]?.fields["health_export_raw"] == nil)
        #expect(graph.records[sessionID]?.fields["health_exported_at"] == nil)
        graph.records[aspirationID]?.body = "Edited in Obsidian\n"
        graph.records[metricID]?.fields["health_export_raw"] = .string("workout")
        graph.records[metricID]?.fields["health_export_enabled_at"] = .null
        graph.records[sessionID]?.fields["health_exported_at"] = .null
        let updated = try VaultModelCodec.apply(graph, to: models)
        #expect(updated.aspirations[0] === models.aspirations[0])
        #expect(updated.aspirations[0].detail == "Edited in Obsidian\n")
        #expect(metric.healthExportRaw == "mindfulMinutes")
        #expect(metric.healthExportEnabledAt == instant)
        #expect(metric.lastHealthSyncAt == instant)
        #expect(models.sessions[0].healthExportedAt == instant)
        let fresh = try VaultModelCodec.materialize(graph)
        #expect(fresh.metrics[0].healthExportRaw == nil)
        #expect(fresh.metrics[0].healthExportEnabledAt == nil)
        #expect(fresh.sessions[0].healthExportedAt == nil)
    }

    @Test
    func invalidImportIsRejectedBeforeAnyMutation() throws {
        let models = fixture()
        let before = try VaultModelCodec.export(models)
        var graph = before
        let aspirationID = try #require(models.aspirations[0].stableID)
        let sessionID = try #require(models.sessions[0].stableID)
        graph.records[aspirationID]?.body = "Must not be applied"
        graph.records[sessionID]?.fields["started_at"] = .string("not a date")
        #expect(throws: (any Error).self) { try VaultModelCodec.apply(graph, to: models) }
        #expect(try VaultModelCodec.export(models) == before)
        graph = before
        graph.attachments.removeAll()
        #expect(throws: (any Error).self) { try VaultModelCodec.apply(graph, to: models) }
        #expect(try VaultModelCodec.export(models) == before)
    }

    @Test
    func relationshipsResolveRenamedPathsAndRejectWrongMetric() throws {
        let models = fixture()
        var graph = try VaultModelCodec.export(models)
        let projectID = try #require(models.projects[0].stableID)
        let sessionID = try #require(models.sessions[0].stableID)
        graph.records[projectID]?.path = "Projects/My reading project.md"
        graph.records[sessionID]?.fields["project"] = .string("[[Projects/My reading project|Reading]]")
        let imported = try VaultModelCodec.materialize(graph)
        #expect(imported.sessions[0].project === imported.projects[0])
        let other = Metric(name: "Other", createdAt: instant)
        let extra = try VaultModelCodec.export(VaultModels(metrics: [other]))
        graph.records.merge(extra.records) { old, _ in old }
        graph.records[projectID]?.fields["metric"] = VaultModelLinks.linkID(other.stableID)
        #expect(throws: (any Error).self) { try VaultModelCodec.validate(graph) }
    }

    @Test
    func deletedParentDoesNotLoseReparentedChildren() throws {
        let models = fixture()
        var graph = try VaultModelCodec.export(models)
        let oldID = try #require(models.aspirations[0].stableID)
        let replacement = Aspiration(title: "New owner", createdAt: instant)
        let inserted = try VaultModelCodec.export(VaultModels(aspirations: [replacement]))
        graph.records.removeValue(forKey: oldID)
        graph.records.merge(inserted.records) { old, _ in old }
        for id in graph.records.keys where graph.records[id]?.fields["aspiration"] == VaultModelLinks.linkID(oldID) {
            graph.records[id]?.fields["aspiration"] = VaultModelLinks.linkID(replacement.stableID)
        }
        let result = try VaultModelCodec.apply(graph, to: models)
        #expect(result.aspirations.count == 1)
        #expect(result.aspirations[0].stableID == replacement.stableID)
        #expect(result.moments[0] === models.moments[0])
        #expect(result.moments[0].aspiration === result.aspirations[0])
        #expect(result.photos[0].moment === result.moments[0])
        #expect(models.aspirations[0].moments.isEmpty)
    }

    @Test
    func duplicateTimersDefaultsAndForeignPrinciplesAreRejected() throws {
        let models = fixture()
        models.sessions[0].endedAt = nil
        var graph = try VaultModelCodec.export(models)
        let sessionID = try #require(models.sessions[0].stableID)
        var duplicate = try #require(graph.records[sessionID])
        duplicate.id = UUID()
        duplicate.path = "Data/another.md"
        graph.records[duplicate.id] = duplicate
        #expect(throws: (any Error).self) { try VaultModelCodec.validate(graph) }
        graph = try VaultModelCodec.export(models)
        let projectID = try #require(models.projects[0].stableID)
        duplicate = try #require(graph.records[projectID])
        duplicate.id = UUID()
        duplicate.path = "Projects/another.md"
        graph.records[duplicate.id] = duplicate
        #expect(throws: (any Error).self) { try VaultModelCodec.validate(graph) }
        graph = try VaultModelCodec.export(models)
        let other = Aspiration(title: "Other", createdAt: instant)
        try graph.records.merge(VaultModelCodec.export(VaultModels(aspirations: [other])).records) { old, _ in old }
        let principleID = try #require(models.principles[0].stableID)
        graph.records[principleID]?.fields["aspiration"] = VaultModelLinks.linkID(other.stableID)
        #expect(throws: (any Error).self) { try VaultModelCodec.validate(graph) }
    }

    @Test
    func invalidKnownRawFieldFailsButUnknownRawSurvivesValidation() throws {
        let models = fixture()
        var graph = try VaultModelCodec.export(models)
        let id = try #require(models.metrics[0].stableID)
        graph.records[id]?.fields["custom_plugin"] = .raw("\n  nested: true\n")
        try VaultModelCodec.validate(graph)
        graph.records[id]?.fields["daily_goal"] = .raw("not-a-number")
        #expect(throws: (any Error).self) { try VaultModelCodec.validate(graph) }
    }

    @Test
    func removedOptionalPropertiesClearWithoutErasingRequiredFields() throws {
        let models = fixture()
        var graph = try VaultModelCodec.export(models)
        let id = try #require(models.metrics[0].stableID)
        graph.records[id]?.fields.removeValue(forKey: "unit")
        graph.records[id]?.fields.removeValue(forKey: "icon")
        graph.records[id]?.fields["excluded_weekdays"] = .null
        let imported = try VaultModelCodec.apply(graph, to: models)
        #expect(imported.metrics[0].unit == nil)
        #expect(imported.metrics[0].icon == nil)
        #expect(imported.metrics[0].excludedWeekdays.isEmpty)
        graph.records[id]?.fields.removeValue(forKey: "name")
        #expect(throws: (any Error).self) { try VaultModelCodec.apply(graph, to: models) }
        #expect(imported.metrics[0].name == "Reading")
    }

    @Test
    func countPointCannotTurnIntoAnElapsedDuration() throws {
        let metric = Metric(name: "Pages", measurementType: .count, createdAt: instant)
        let point = Session(metric: metric, startedAt: instant, endedAt: instant, value: 5)
        var graph = try VaultModelCodec.export(VaultModels(metrics: [metric], sessions: [point]))
        let id = try #require(point.stableID)
        graph.records[id]?.fields.removeValue(forKey: "value")
        #expect(throws: (any Error).self) { try VaultModelCodec.validate(graph) }
    }

    @Test
    func remoteMetadataCannotEnableHealthOrChangeLocalNotificationChoices() throws {
        let models = fixture()
        var graph = try VaultModelCodec.export(models)
        let id = try #require(models.metrics[0].stableID)
        graph.records[id]?.fields["health_source"] = .string("exerciseMinutes")
        graph.records[id]?.fields["reminder_time"] = .null
        graph.records[id]?.fields["reminder_times"] = .array([])
        let imported = try VaultModelCodec.materialize(graph)
        #expect(!imported.metrics[0].isHealthLinked)
        models.metrics[0].healthSourceRaw = HealthDataSource.workoutMinutes.rawValue
        _ = try VaultModelCodec.apply(graph, to: models)
        #expect(models.metrics[0].healthSourceRaw == HealthDataSource.workoutMinutes.rawValue)
        #expect(models.metrics[0].reminderTime == instant)
        #expect(models.metrics[0].reminderTimes == [instant])
    }

    private func fixture() -> VaultModels {
        let aspiration = makeAspiration()
        let metric = makeMetric()
        let project = Project(name: "Read", metric: metric, startedAt: instant)
        project.isDefault = true
        let session = Session(
            metric: metric,
            project: project,
            startedAt: instant,
            endedAt: instant.addingTimeInterval(120),
            countdownDuration: 300
        )
        let principle = Principle(text: "Pages before feeds.\n", aspiration: aspiration, createdAt: instant)
        let intention = makeIntention(aspiration, principle: principle)
        let checkIn = AspirationCheckIn(
            aspiration: aspiration,
            rating: .serving,
            weekStart: instant,
            note: "A grounded week.\n",
            createdAt: instant
        )
        let moment = makeMoment(aspiration: aspiration, metric: metric, project: project, principle: principle)
        let photo = MomentPhoto(data: png, sortIndex: 2, moment: moment)
        aspiration.metrics = [metric]
        aspiration.projects = [project]
        return VaultModels(
            aspirations: [aspiration],
            metrics: [metric],
            projects: [project],
            sessions: [session],
            principles: [principle],
            intentions: [intention],
            checkIns: [checkIn],
            moments: [moment],
            photos: [photo]
        )
    }

    private func makeAspiration() -> Aspiration {
        let aspiration = Aspiration(
            title: "Wisdom", detail: "Why this matters\n\nA second paragraph.\n",
            icon: "book", colorName: "blue", imageData: png, createdAt: instant
        )
        aspiration.displayOrder = 2
        aspiration.archivedAt = instant.addingTimeInterval(100)
        return aspiration
    }

    private func makeMoment(
        aspiration: Aspiration, metric: Metric, project: Project, principle: Principle
    ) -> Moment {
        let moment = Moment(
            text: "Finished a difficult chapter.\n", aspiration: aspiration, occurredAt: instant,
            metric: metric, project: project, latitude: 40.5, longitude: -70,
            placeName: "Home", createdAt: instant
        )
        moment.principle = principle
        return moment
    }

    private func makeMetric() -> Metric {
        let metric = Metric(
            name: "Reading",
            unit: "minutes",
            icon: "book",
            colorName: "green",
            metricDescription: "Measure the practice.\n",
            createdAt: instant
        )
        metric.dailyGoal = 600
        metric.weeklyGoal = 1800
        metric.reminderTime = instant
        metric.streakAlertTime = instant
        metric.reminderTimes = [instant]
        metric.reminderRandomStart = instant
        metric.reminderRandomEnd = instant.addingTimeInterval(3600)
        metric.reminderRandomCount = 3
        metric.reminderUsesRandom = true
        metric.excludedWeekdays = [1, 7]
        metric.goalSeasonStartedAt = instant
        metric.goalSeasonWeeks = 6
        metric.goalSeasonNote = "Deepen attention"
        metric.binaryGoalRetiredAt = instant
        metric.countLogStyleRaw = CountLogStyle.incrementByOne.rawValue
        metric.archivedAt = instant.addingTimeInterval(100)
        metric.isFavorite = true
        return metric
    }

    private func makeIntention(_ aspiration: Aspiration, principle: Principle) -> Intention {
        let intention = Intention(
            title: "Three thoughtful pages",
            kind: .counted,
            aspiration: aspiration,
            target: 3,
            weekStart: instant,
            createdAt: instant
        )
        intention.tickDates = [instant]
        intention.principle = principle
        intention.outcomeRaw = IntentionOutcome.partly.rawValue
        intention.closedAt = instant.addingTimeInterval(100)
        intention.predecessorID = UUID()
        intention.promotionDismissed = true
        intention.questionText = "What stayed with you?"
        intention.questionWindowStart = instant
        intention.questionWindowEnd = instant.addingTimeInterval(3600)
        return intention
    }
}
