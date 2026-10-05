import Foundation

enum VaultModelValidation {
    static func validate(_ models: VaultModels) throws {
        for metric in models.metrics {
            try validateMetric(metric)
        }
        for project in models.projects {
            try validateProject(project)
        }
        try validateSessions(models)
        for intention in models.intentions {
            try validateIntention(intention)
        }
        for moment in models.moments {
            try validateMoment(moment)
        }
        for photo in models.photos {
            try require(photo.sortIndex >= 0, "Negative photo order")
        }
        for checkIn in models.checkIns {
            try require(checkIn.rating != nil, "Check-in rating must be 1–3")
        }
        try validateUniqueness(models)
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw VaultError.invalid(message) }
    }

    private static func positive(_ value: Double?) -> Bool {
        value.map { $0 > 0 } ?? true
    }

    private static func validateMetric(_ value: Metric) throws {
        try require(positive(value.dailyGoal) && positive(value.weeklyGoal), "Goals must be positive")
        try require(CountLogStyle(rawValue: value.countLogStyleRaw) != nil, "Unknown count log style")
        if let raw = value.healthSourceRaw {
            guard let source = HealthDataSource(rawValue: raw)
            else { throw VaultError.invalid("Unknown Health source") }
            try require(source.measurementType == value.measurementType, "Health source measurement type mismatch")
        }
        try require(value.excludedWeekdays.allSatisfy { (1 ... 7).contains($0) }, "Invalid excluded weekday")
        try require(Set(value.excludedWeekdays).count == value.excludedWeekdays.count, "Duplicate excluded weekdays")
        try require((1 ... ReminderSchedule.maxPerDay).contains(value.reminderRandomCount), "Invalid reminder count")
        try require(value.reminderTimes.count <= ReminderSchedule.maxPerDay, "Too many reminders")
        if value.reminderUsesRandom {
            try require(value.reminderRandomStart != nil && value.reminderRandomEnd != nil, "Missing reminder window")
        }
        if let weeks = value.goalSeasonWeeks {
            try require(GoalSeason.lengthChoices.contains(weeks), "Invalid goal season length")
        }
    }

    private static func validateProject(_ value: Project) throws {
        if let finished = value.finishedAt {
            try require(finished >= value.startedAt, "Project ends before it starts")
        }
    }

    private static func validateSessions(_ models: VaultModels) throws {
        var runningMetrics = Set<UUID>()
        for value in models.sessions {
            let metric = try validateSession(value)
            guard value.isRunning, let metric else { continue }
            guard let id = metric.stableID else { throw VaultError.invalid("Session metric requires an identity") }
            try require(runningMetrics.insert(id).inserted, "Multiple running timers for a metric")
        }
    }

    private static func validateSession(_ value: Session) throws -> Metric? {
        let project = value.project
        let projectMetric = project?.metric
        let metric = value.metric ?? projectMetric
        if project != nil {
            try require(projectMetric === metric, "Session project belongs to another metric")
        }
        try validateSessionValues(value)
        // Unassigned records retain their data; no measurement type or owner is guessed.
        guard let metric else { return nil }
        if value.isRunning { try require(metric.measurementType == .duration, "Only duration metrics can run timers") }
        if value.countdownDuration != nil {
            try require(metric.measurementType == .duration, "Only duration metrics can have countdowns")
        }
        if metric.measurementType == .count {
            try require(value.value != nil, "Count data points require a value")
        }
        if metric.measurementType == .binary {
            try require(value.value == 1, "Binary sessions must have value 1")
        }
        return metric
    }

    private static func validateSessionValues(_ value: Session) throws {
        if let ended = value.endedAt { try require(ended >= value.startedAt, "Session ends before it starts") }
        try require(
            CSVImporter.isSane(
                started: value.startedAt,
                ended: value.endedAt,
                value: value.value,
                now: .now
            ),
            "Session values must be nonnegative and timestamps cannot be in the future"
        )
        try require(
            value.countdownDuration.map { $0.isFinite && $0 > 0 } ?? true,
            "Countdown must be finite and positive"
        )
    }

    private static func validateIntention(_ value: Intention) throws {
        guard let kind = IntentionKind(rawValue: value.kindRaw)
        else { throw VaultError.invalid("Unknown intention kind") }
        if let raw = value.derivedModeRaw {
            try require(DerivedMode(rawValue: raw) != nil, "Unknown derived mode")
        }
        if let raw = value.outcomeRaw {
            try require(IntentionOutcome(rawValue: raw) != nil && value.closedAt != nil, "Invalid intention outcome")
        }
        if let principle = value.principle {
            try require(principle.aspiration === value.aspiration, "Intention principle belongs to another aspiration")
        }
        try require(value.predecessorID != value.stableID, "An intention cannot renew itself")
        if kind == .derived, value.metric == nil {
            // Deleting a metric deliberately leaves historical intentions with a removed source.
            try validateRemovedSource(value)
        } else {
            try require(
                Intention.isValidShape(
                    kind: kind,
                    derivedMode: value.derivedMode,
                    metric: value.metric,
                    perDay: value.perDay,
                    target: value.target
                ),
                "Invalid intention shape"
            )
        }
        try require(kind == .counted || value.tickDates.isEmpty, "Only counted intentions can have ticks")
        try validateQuestion(value)
    }

    private static func validateRemovedSource(_ value: Intention) throws {
        guard let mode = value.derivedMode else { throw VaultError.invalid("Missing derived mode") }
        if value.perDay {
            try require(mode == .sessionCount && value.target == nil, "Invalid per-day intention")
        } else {
            guard let target = value.target else { throw VaultError.invalid("Missing intention target") }
            try require(target > 0 && (mode == .valueSum || target.rounded() == target), "Invalid intention target")
        }
    }

    private static func validateQuestion(_ value: Intention) throws {
        let parts = [value.questionText != nil, value.questionWindowStart != nil, value.questionWindowEnd != nil]
        try require(parts.allSatisfy { $0 } || parts.allSatisfy { !$0 }, "Incomplete intention question")
    }

    private static func validateMoment(_ value: Moment) throws {
        try require(value.occurredAt <= .now, "Moment occurrence cannot be in the future")
        try require((value.latitude == nil) == (value.longitude == nil), "Incomplete moment coordinates")
        if let latitude = value.latitude { try require((-90 ... 90).contains(latitude), "Invalid latitude") }
        if let longitude = value.longitude { try require((-180 ... 180).contains(longitude), "Invalid longitude") }
        if let principle = value.principle {
            try require(principle.aspiration === value.aspiration, "Moment principle belongs to another aspiration")
        }
        if let project = value.project, let metric = value.metric {
            try require(project.metric === metric, "Moment provenance project/metric mismatch")
        }
    }

    private static func validateUniqueness(_ models: VaultModels) throws {
        for metric in models.metrics {
            try require(
                metric.projects.lazy.filter { $0.isDefault && $0.status == .active }.prefix(2).count <= 1,
                "Multiple default projects for a metric"
            )
        }
        var checkIns = Set<String>()
        for value in models.checkIns {
            let key = "\(value.aspiration?.stableID?.uuidString ?? "")/\(value.weekStart.timeIntervalSince1970)"
            try require(checkIns.insert(key).inserted, "Duplicate aspiration check-in week")
        }
    }
}
