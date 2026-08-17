import SwiftUI

/// The card under the grid for a tapped day: goal modes show actual values
/// and verdicts; Moments mode shows the day's testimony itself without a
/// score or count.
struct GoalCalendarDayPanel: View {
    let day: Date
    let filter: GoalCalendarFilter?
    /// The metrics a tallied day lists, in display order.
    let talliedMetrics: [Metric]
    /// The day's testimonies when the calendar is in Moments mode.
    let moments: [Moment]

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(day, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline.weight(.semibold))
                .padding(.bottom, 4)
            rowList
        }
        .cardSurface()
    }

    private var isToday: Bool {
        calendar.isDateInToday(day)
    }
}

// MARK: - Rows

extension GoalCalendarDayPanel {
    /// One goal row's resolved facts.
    private struct PanelRow: Identifiable {
        let id: String
        let icon: String
        let name: String
        let tint: Color
        let metric: Metric
        let outcome: GoalCalendar.DayOutcome
    }

    @ViewBuilder
    private var rowList: some View {
        if filter?.isMoments == true {
            momentRows
        } else {
            goalRows
        }
    }

    @ViewBuilder
    private var goalRows: some View {
        let rows = panelRows
        if rows.isEmpty {
            emptyLine("Nothing tracked this day.")
        }
        ForEach(rows) { row in
            rowView(row)
            if row.id != rows.last?.id {
                Divider().padding(.leading, 40)
            }
        }
    }

    @ViewBuilder
    private var momentRows: some View {
        if moments.isEmpty {
            emptyLine("Nothing kept this day.")
        }
        ForEach(moments) { moment in
            momentRow(moment)
            if moment !== moments.last {
                Divider().padding(.leading, 40)
            }
        }
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
    }

    private func momentRow(_ moment: Moment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            momentIcon(moment)
            momentText(moment)
            Spacer(minLength: 8)
            if !moment.photos.isEmpty {
                Image(systemName: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(momentAccessibilityText(moment))
    }

    private func momentIcon(_ moment: Moment) -> some View {
        let aspiration = moment.aspiration
        return MetricIcon(
            systemName: aspiration?.displayIcon ?? "sparkles",
            tint: aspiration?.displayColor ?? .accentColor,
            size: 30
        )
        .accessibilityHidden(true)
    }

    private func momentText(_ moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(moment.text)
                .font(.subheadline)
                .lineLimit(4)
            Text(momentMeta(moment))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func momentMeta(_ moment: Moment) -> String {
        let time = moment.occurredAt.formatted(date: .omitted, time: .shortened)
        let principle = moment.principle.map { "lives “\($0.text)”" }
        return [time, moment.aspiration?.title, moment.placeLabel, principle]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func momentAccessibilityText(_ moment: Moment) -> String {
        var parts = [moment.text, momentMeta(moment)]
        if !moment.photos.isEmpty { parts.append("Has photos") }
        return parts.joined(separator: ", ")
    }

    private var panelRows: [PanelRow] {
        if let filter, let series = filter.series {
            return [seriesRow(series, filter: filter)]
        }
        return talliedMetrics.compactMap(talliedRow)
    }

    private func seriesRow(
        _ series: GoalCalendarSeries,
        filter: GoalCalendarFilter
    ) -> PanelRow {
        PanelRow(
            id: "series",
            icon: filter.icon,
            name: filter.title,
            tint: filter.tint,
            metric: series.metric,
            outcome: GoalCalendar.dayOutcome(
                for: series.metric,
                sessions: series.sessions,
                on: day,
                since: series.since,
                calendar: calendar
            )
        )
    }

    /// A tallied metric's row — or nil for a day it neither carried a goal
    /// nor logged anything, so quiet metrics don't pad the card.
    private func talliedRow(for metric: Metric) -> PanelRow? {
        let outcome = GoalCalendar.dayOutcome(
            for: metric,
            sessions: metric.sessions,
            on: day,
            calendar: calendar
        )
        guard outcome.verdict != .free || outcome.value > 0 else { return nil }
        return PanelRow(
            id: metric.stableID?.uuidString ?? metric.name,
            icon: metric.displayIcon,
            name: metric.name,
            tint: metric.displayColor,
            metric: metric,
            outcome: outcome
        )
    }

    private func rowView(_ row: PanelRow) -> some View {
        HStack(spacing: 10) {
            MetricIcon(systemName: row.icon, tint: row.tint, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(valueLine(for: row))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            verdictBadge(row.outcome.verdict, tint: row.tint)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Value lines

extension GoalCalendarDayPanel {
    private func valueLine(for row: PanelRow) -> String {
        if row.metric.measurementType == .binary {
            return binaryLine(done: row.outcome.value > 0)
        }
        return quantityValueLine(for: row)
    }

    private func binaryLine(done: Bool) -> String {
        if done { return "Done" }
        return isToday ? "Not yet" : "Not done"
    }

    private func quantityValueLine(for row: PanelRow) -> String {
        if row.outcome.value <= 0 { return nothingText }
        guard let goal = row.metric.dailyGoal, row.outcome.verdict != .free else {
            return ValueFormatter.format(
                row.outcome.value,
                type: row.metric.measurementType,
                unit: row.metric.unit
            )
        }
        return quantityLine(row.outcome.value, goal: goal, metric: row.metric)
    }

    private var nothingText: String {
        isToday ? "Nothing yet" : "Nothing logged"
    }

    /// "45m of 1h" / "12 of 20 pages" — the actual value against the goal.
    private func quantityLine(
        _ value: Double,
        goal: Double,
        metric: Metric
    ) -> String {
        if metric.measurementType == .duration {
            return "\(DurationFormatter.compact(value)) of \(DurationFormatter.compact(goal))"
        }
        let goalPart = ValueFormatter.format(goal, type: .count, unit: metric.unit)
        return "\(ValueFormatter.formatShort(value, type: .count)) of \(goalPart)"
    }

    @ViewBuilder
    private func verdictBadge(_ verdict: GoalCalendar.Verdict, tint: Color) -> some View {
        switch verdict {
        case .met:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(tint)
        case .missed:
            Image(systemName: "circle")
                .foregroundStyle(.tertiary)
        case .rest:
            Image(systemName: "moon.zzz.fill")
                .foregroundStyle(.secondary)
        case .free:
            EmptyView()
        }
    }
}
