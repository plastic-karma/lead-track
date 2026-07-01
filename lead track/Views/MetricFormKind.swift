import Foundation

/// What the metric form's type segments select between: the three
/// hand-recorded measurement styles, plus a metric mirrored from Apple
/// Health. Health derives its measurement type from the chosen source, so
/// this is a form concept, never a stored one.
enum MetricFormKind: Hashable, CaseIterable {
    case duration
    case count
    case binary
    case health
}

extension MetricFormKind {
    /// The kind that reopens `metric` for editing; new metrics start with a
    /// timer.
    init(metric: Metric?) {
        guard let metric else {
            self = .duration
            return
        }
        self = metric.isHealthLinked ? .health : Self(metric.measurementType)
    }

    init(_ type: MeasurementType) {
        switch type {
        case .duration: self = .duration
        case .count: self = .count
        case .binary: self = .binary
        }
    }

    /// The stored measurement type for a hand-recorded kind; health metrics
    /// take theirs from the chosen `HealthDataSource` instead.
    var measurementType: MeasurementType? {
        switch self {
        case .duration: .duration
        case .count: .count
        case .binary: .binary
        case .health: nil
        }
    }
}
