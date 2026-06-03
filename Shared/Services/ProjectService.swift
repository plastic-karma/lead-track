import Foundation

enum ProjectService {
    /// Sets whether `project` is its metric's default. Because at most one
    /// active project per metric may be the default, turning this on clears
    /// the flag on every sibling project.
    static func setDefault(_ project: Project, _ isDefault: Bool) {
        if isDefault {
            for sibling in project.metric?.projects ?? [] where sibling !== project {
                sibling.isDefault = false
            }
        }
        project.isDefault = isDefault
    }

    /// Marks a project finished. A finished project can no longer be the
    /// default, so the flag is cleared.
    static func finish(_ project: Project) {
        project.status = .finished
        project.finishedAt = .now
        project.isDefault = false
    }

    static func reopen(_ project: Project) {
        project.status = .active
        project.finishedAt = nil
    }
}
