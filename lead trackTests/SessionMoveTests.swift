import Foundation
import SwiftData
import Testing
@testable import lead_track

@MainActor
struct SessionMoveTests {
    private func makeContext() throws -> ModelContext {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        return ModelContext(container)
    }

    private func makeMetric(
        _ name: String = "Reading",
        in context: ModelContext
    ) -> Metric {
        let metric = Metric(name: name, measurementType: .count)
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

    private func makeSession(
        for metric: Metric,
        project: Project?,
        in context: ModelContext
    ) -> Session {
        let session = Session(
            metric: metric,
            project: project,
            startedAt: .now,
            endedAt: .now,
            value: 1
        )
        context.insert(session)
        return session
    }

    @Test
    func movesTopLevelSessionIntoProject() throws {
        let context = try makeContext()
        let metric = makeMetric(in: context)
        let project = makeProject("Book", for: metric, in: context)
        let session = makeSession(for: metric, project: nil, in: context)

        let moved = SessionService.move(session, to: project)

        #expect(moved)
        #expect(session.project === project)
    }

    @Test
    func movesSessionBetweenProjects() throws {
        let context = try makeContext()
        let metric = makeMetric(in: context)
        let first = makeProject("A", for: metric, in: context)
        let second = makeProject("B", for: metric, in: context)
        let session = makeSession(for: metric, project: first, in: context)

        SessionService.move(session, to: second)

        #expect(session.project === second)
    }

    @Test
    func movesSessionBackToTopLevel() throws {
        let context = try makeContext()
        let metric = makeMetric(in: context)
        let project = makeProject("A", for: metric, in: context)
        let session = makeSession(for: metric, project: project, in: context)

        SessionService.move(session, to: nil)

        #expect(session.project == nil)
    }

    @Test
    func rejectsProjectFromAnotherMetric() throws {
        let context = try makeContext()
        let reading = makeMetric("Reading", in: context)
        let running = makeMetric("Running", in: context)
        let foreignProject = makeProject("Marathon", for: running, in: context)
        let session = makeSession(for: reading, project: nil, in: context)

        let moved = SessionService.move(session, to: foreignProject)

        #expect(!moved)
        #expect(session.project == nil)
    }
}
