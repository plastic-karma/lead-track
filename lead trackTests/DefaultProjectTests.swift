import Foundation
import SwiftData
import Testing
@testable import lead_track

@MainActor
struct DefaultProjectTests {
    private func makeContext() throws -> ModelContext {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        return ModelContext(container)
    }

    private func makeMetric(
        _ type: MeasurementType,
        in context: ModelContext
    ) -> Metric {
        let metric = Metric(name: "Reading", measurementType: type)
        context.insert(metric)
        return metric
    }

    private func makeProject(
        _ name: String,
        for metric: Metric,
        in context: ModelContext
    ) -> Project {
        let project = Project(name: name, metric: metric)
        context.insert(project)
        return project
    }

    // MARK: - Single default invariant

    @Test
    func setDefaultClearsPreviousDefault() throws {
        let context = try makeContext()
        let metric = makeMetric(.count, in: context)
        let first = makeProject("A", for: metric, in: context)
        let second = makeProject("B", for: metric, in: context)

        ProjectService.setDefault(first, true)
        #expect(metric.defaultProject === first)

        ProjectService.setDefault(second, true)
        #expect(second.isDefault)
        #expect(!first.isDefault)
        #expect(metric.defaultProject === second)
    }

    @Test
    func setDefaultFalseClearsDefault() throws {
        let context = try makeContext()
        let metric = makeMetric(.count, in: context)
        let project = makeProject("A", for: metric, in: context)

        ProjectService.setDefault(project, true)
        ProjectService.setDefault(project, false)

        #expect(!project.isDefault)
        #expect(metric.defaultProject == nil)
    }

    // MARK: - Finishing

    @Test
    func finishingClearsDefault() throws {
        let context = try makeContext()
        let metric = makeMetric(.count, in: context)
        let project = makeProject("A", for: metric, in: context)
        ProjectService.setDefault(project, true)

        ProjectService.finish(project)

        #expect(!project.isDefault)
        #expect(project.status == .finished)
        #expect(metric.defaultProject == nil)
    }

    @Test
    func finishingOffersTheProjectReflectionPrompt() {
        #expect(
            ProjectService.closingMomentPrompt
                == "How have your aspirations changed through this project"
        )
    }

    @Test
    func defaultProjectIgnoresFinishedProjects() throws {
        let context = try makeContext()
        let metric = makeMetric(.count, in: context)
        let project = makeProject("A", for: metric, in: context)
        // A stale flag on a finished project must never resurface as default.
        project.isDefault = true
        project.status = .finished

        #expect(metric.defaultProject == nil)
    }

    // MARK: - Auto-assignment when recording

    @Test
    func recordingAutoAssignsDefaultProject() throws {
        let context = try makeContext()
        let metric = makeMetric(.duration, in: context)
        let project = makeProject("Deep Work", for: metric, in: context)
        ProjectService.setDefault(project, true)

        let session = SessionService.startSession(for: metric, in: context)

        #expect(session.project === project)
    }

    @Test
    func recordingWithoutDefaultStaysUnassigned() throws {
        let context = try makeContext()
        let metric = makeMetric(.duration, in: context)
        _ = makeProject("Not Default", for: metric, in: context)

        let session = SessionService.startSession(for: metric, in: context)

        #expect(session.project == nil)
    }

    @Test
    func explicitProjectOverridesDefault() throws {
        let context = try makeContext()
        let metric = makeMetric(.duration, in: context)
        let defaultProject = makeProject("Default", for: metric, in: context)
        let other = makeProject("Other", for: metric, in: context)
        ProjectService.setDefault(defaultProject, true)

        let session = SessionService.startSession(
            for: metric, project: other, in: context
        )

        #expect(session.project === other)
    }
}
