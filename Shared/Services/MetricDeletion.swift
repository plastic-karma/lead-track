#if canImport(SwiftData)
import SwiftData

extension ModelContext {
    /// Applies the declared cascades using authoritative forward relationships,
    /// not inverse arrays, which can be empty in native SwiftData stores.
    /// Resolve every dependent before mutating so a fetch failure deletes nothing.
    func deleteMetricAndDependents(_ metric: Metric) throws {
        if hasChanges { try save() }
        var projects = try fetch(FetchDescriptor<Project>())
        var sessions = try fetch(FetchDescriptor<Session>())
        projects.removeAll { $0.metric !== metric }
        sessions.removeAll { $0.metric !== metric && $0.project?.metric !== metric }
        do {
            try transaction {
                for session in sessions {
                    delete(session)
                }
                for project in projects {
                    delete(project)
                }
                delete(metric)
                try save()
            }
        } catch {
            rollback()
            throw error
        }
    }

    /// Deletes only sessions whose forward project link names this project.
    /// Unassigned sessions and historical models with nullify rules survive.
    func deleteProjectAndDependents(_ project: Project) throws {
        if hasChanges { try save() }
        var sessions = try fetch(FetchDescriptor<Session>())
        sessions.removeAll { $0.project !== project }
        do {
            try transaction {
                for session in sessions {
                    delete(session)
                }
                delete(project)
                try save()
            }
        } catch {
            rollback()
            throw error
        }
    }
}
#endif
