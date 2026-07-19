import SwiftUI

/// What the goal calendar is judging: one metric, one project's slice of its
/// metric, or one aspiration's attached metrics. nil (no filter) means every
/// unarchived metric's daily goals, tallied per day.
enum GoalCalendarFilter {
    case metric(Metric)
    case project(Project)
    case aspiration(Aspiration)
}

extension GoalCalendarFilter {
    /// The name the filter chip wears.
    var title: String {
        switch self {
        case let .metric(metric): metric.name
        case let .project(project): project.name
        case let .aspiration(aspiration): aspiration.title
        }
    }

    /// The identity color the calendar wears under this filter.
    var tint: Color {
        switch self {
        case let .metric(metric): metric.displayColor
        case let .project(project): MetricColor.color(named: project.metric?.colorName)
        case let .aspiration(aspiration): aspiration.displayColor
        }
    }

    /// The deeper fill behind the calendar's white numerals
    /// (see `MetricColor.prominentColor`).
    var prominentTint: Color {
        switch self {
        case let .metric(metric): metric.prominentColor
        case let .project(project): MetricColor.prominentColor(named: project.metric?.colorName)
        case let .aspiration(aspiration): aspiration.prominentColor
        }
    }

    /// The glyph shown beside the filter's name.
    var icon: String {
        switch self {
        case let .metric(metric): metric.displayIcon
        case let .project(project): project.metric?.displayIcon ?? "folder"
        case let .aspiration(aspiration): aspiration.displayIcon
        }
    }

    /// The single series this filter judges, or nil for an aspiration,
    /// which tallies its attached metrics like the unfiltered calendar.
    var series: GoalCalendarSeries? {
        switch self {
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
}

extension GoalCalendarFilter: Equatable {
    /// Identity comparison — two filters are the same when they point at the
    /// same model object.
    static func == (lhs: GoalCalendarFilter, rhs: GoalCalendarFilter) -> Bool {
        switch (lhs, rhs) {
        case let (.metric(left), .metric(right)): left === right
        case let (.project(left), .project(right)): left === right
        case let (.aspiration(left), .aspiration(right)): left === right
        default: false
        }
    }
}
