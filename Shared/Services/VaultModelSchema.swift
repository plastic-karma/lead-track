import Foundation

extension Aspiration: VaultModel {
    static var vaultKind: VaultKind {
        .aspiration
    }

    static let vaultFields: [VaultModelField<Aspiration>] = [
        .init("title", \.title), .init("icon", \.icon), .init("color_name", \.colorName),
        .init("created_at", \.createdAt), .init("archived_at", \.archivedAt),
        .init("display_order", \.displayOrder)
    ]

    static func emptyVaultModel() -> Aspiration {
        Aspiration(title: "")
    }

    var vaultBody: String {
        get { detail }
        set { detail = newValue }
    }

    var vaultLabel: String {
        title
    }
}

extension Metric: VaultModel {
    static var vaultKind: VaultKind {
        .metric
    }

    static let vaultFields: [VaultModelField<Metric>] = [
        .init("name", \.name), .init("measurement_type", \.measurementType), .init("unit", \.unit),
        .init("icon", \.icon), .init("color_name", \.colorName), .init("created_at", \.createdAt),
        .init("daily_goal", \.dailyGoal), .init("weekly_goal", \.weeklyGoal),
        .init("excluded_weekdays", \.excludedWeekdays),
        .init("goal_season_started_at", \.goalSeasonStartedAt),
        .init("goal_season_weeks", \.goalSeasonWeeks), .init("goal_season_note", \.goalSeasonNote),
        .init("binary_goal_retired_at", \.binaryGoalRetiredAt), .init("count_log_style", \.countLogStyleRaw),
        .init("archived_at", \.archivedAt), .init("is_favorite", \.isFavorite)
    ]

    static func emptyVaultModel() -> Metric {
        Metric(name: "")
    }

    var vaultBody: String {
        get { metricDescription ?? "" }
        set { metricDescription = newValue.isEmpty ? nil : newValue }
    }

    var vaultLabel: String {
        name
    }
}

extension Project: VaultModel {
    static var vaultKind: VaultKind {
        .project
    }

    static let vaultFields: [VaultModelField<Project>] = [
        .init("name", \.name), .init("status", \.status), .init("started_at", \.startedAt),
        .init("finished_at", \.finishedAt), .init("is_default", \.isDefault)
    ]

    static func emptyVaultModel() -> Project {
        Project(name: "")
    }

    var vaultLabel: String {
        name
    }
}

extension Session: VaultModel {
    static var vaultKind: VaultKind {
        .session
    }

    static let vaultFields: [VaultModelField<Session>] = [
        .init("started_at", \.startedAt), .init("ended_at", \.endedAt),
        .init("value", \.value), .init("countdown_duration", \.countdownDuration)
    ]

    static func emptyVaultModel() -> Session {
        Session()
    }

    var vaultLabel: String {
        "\((metric ?? project?.metric)?.name ?? "Data") · \(startedAt.formatted(.iso8601))"
    }
}

extension Principle: VaultModel {
    static var vaultKind: VaultKind {
        .principle
    }

    static let vaultFields: [VaultModelField<Principle>] = [.init("created_at", \.createdAt)]
    static func emptyVaultModel() -> Principle {
        Principle(text: "", aspiration: nil)
    }

    var vaultBody: String {
        get { text }
        set { text = newValue }
    }

    var vaultLabel: String {
        String(text.prefix(100))
    }
}

extension Intention: VaultModel {
    static var vaultKind: VaultKind {
        .intention
    }

    static let vaultFields: [VaultModelField<Intention>] = [
        .init("title", \.title), .init("kind", \.kindRaw), .init("derived_mode", \.derivedModeRaw),
        .init("per_day", \.perDay), .init("target", \.target), .init("week_start", \.weekStart),
        .init("tick_dates", \.tickDates), .init("outcome", \.outcomeRaw), .init("closed_at", \.closedAt),
        .init("promotion_dismissed", \.promotionDismissed),
        .init("created_at", \.createdAt)
    ]

    static func emptyVaultModel() -> Intention {
        Intention(title: "", kind: .reflective, aspiration: nil, weekStart: .distantPast)
    }

    var vaultLabel: String {
        title
    }
}

extension AspirationCheckIn: VaultModel {
    static var vaultKind: VaultKind {
        .checkIn
    }

    static let vaultFields: [VaultModelField<AspirationCheckIn>] = [
        .init("week_start", \.weekStart),
        .init("rating", \.ratingRaw),
        .init("created_at", \.createdAt)
    ]

    static func emptyVaultModel() -> AspirationCheckIn {
        AspirationCheckIn(aspiration: nil, rating: .unsure, weekStart: .distantPast)
    }

    var vaultBody: String {
        get { note }
        set { note = newValue }
    }

    var vaultLabel: String {
        "Check-in · \(weekStart.formatted(.iso8601))"
    }
}

extension Moment: VaultModel {
    static var vaultKind: VaultKind {
        .moment
    }

    static let vaultFields: [VaultModelField<Moment>] = [
        .init("occurred_at", \.occurredAt), .init("created_at", \.createdAt),
        .init("latitude", \.latitude), .init("longitude", \.longitude), .init("place_name", \.placeName)
    ]

    static func emptyVaultModel() -> Moment {
        Moment(text: "", aspiration: nil)
    }

    var vaultBody: String {
        get { text }
        set { text = newValue }
    }

    var vaultLabel: String {
        String(text.prefix(100))
    }
}

extension MomentPhoto: VaultModel {
    static var vaultKind: VaultKind {
        .photo
    }

    static let vaultFields: [VaultModelField<MomentPhoto>] = [.init("sort_index", \.sortIndex)]
    static func emptyVaultModel() -> MomentPhoto {
        MomentPhoto(data: Data())
    }

    var vaultLabel: String {
        "Photo \(sortIndex)"
    }
}
