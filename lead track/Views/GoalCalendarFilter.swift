import SwiftUI

/// What the calendar is showing: moments, one metric, one project's slice of
/// its metric, or one aspiration's attached metrics. nil (no filter) means
/// every unarchived metric's daily goals, tallied per day.
enum GoalCalendarFilter {
    case moments
    case metric(Metric)
    case project(Project)
    case aspiration(Aspiration)
}

extension GoalCalendarFilter {
    /// The name the filter chip wears.
    var title: String {
        switch self {
        case .moments: "Moments"
        case let .metric(metric): metric.name
        case let .project(project): project.name
        case let .aspiration(aspiration): aspiration.title
        }
    }

    /// The identity color the calendar wears under this filter.
    var tint: Color {
        switch self {
        case .moments: .accentColor
        case let .metric(metric): metric.displayColor
        case let .project(project): MetricColor.color(named: project.metric?.colorName)
        case let .aspiration(aspiration): aspiration.displayColor
        }
    }

    /// The deeper fill behind the calendar's white numerals
    /// (see `MetricColor.prominentColor`).
    var prominentTint: Color {
        switch self {
        case .moments: .accentColor
        case let .metric(metric): metric.prominentColor
        case let .project(project): MetricColor.prominentColor(named: project.metric?.colorName)
        case let .aspiration(aspiration): aspiration.prominentColor
        }
    }

    /// The glyph shown beside the filter's name.
    var icon: String {
        switch self {
        case .moments: "sparkles"
        case let .metric(metric): metric.displayIcon
        case let .project(project): project.metric?.displayIcon ?? "folder"
        case let .aspiration(aspiration): aspiration.displayIcon
        }
    }

    /// The single series this filter judges. An aspiration tallies its
    /// attached metrics; Moments uses its own presence-only rendering.
    var series: GoalCalendarSeries? {
        switch self {
        case .moments:
            nil
        case let .metric(metric):
            GoalCalendarSeries(
                metric: metric,
                sessions: metric.sessions,
                since: GoalCalendar.trackingStart(of: metric)
            )
        case let .project(project):
            project.metric.map {
                GoalCalendarSeries(
                    metric: $0,
                    sessions: project.sessions,
                    since: GoalCalendar.trackingStart(of: project)
                )
            }
        case .aspiration:
            nil
        }
    }

    var isMoments: Bool {
        if case .moments = self { return true }
        return false
    }
}

extension GoalCalendarFilter: Equatable {
    /// Identity comparison — two filters are the same when they point at the
    /// same model object.
    static func == (lhs: GoalCalendarFilter, rhs: GoalCalendarFilter) -> Bool {
        switch (lhs, rhs) {
        case (.moments, .moments): true
        case let (.metric(left), .metric(right)): left === right
        case let (.project(left), .project(right)): left === right
        case let (.aspiration(left), .aspiration(right)): left === right
        default: false
        }
    }
}
