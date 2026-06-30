import SwiftUI

/// One metric's page in the weekly review pager: identity, the week's total
/// with its week-over-week change, a labeled day strip, and the metric's own
/// insights. The metric color stays on the data ink — bars and the change
/// arrow — while the chrome stays monochrome, matching the dashboard cards.
struct MetricWeekCard: View {
    let week: WeeklyReview.MetricWeek
    /// First day of the review period, anchoring the day-strip labels.
    let weekStart: Date

    /// Insights beyond this start repeating the card's own numbers.
    private static let maxInsights = 3

    private var tint: Color {
        MetricColor.color(named: week.colorName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            totalRow
            WeekBarsView(
                values: week.dailySeries,
                labels: WeekBarsView.weekdayLabels(
                    from: weekStart, count: WeeklyReview.periodDays
                ),
                tint: tint
            )
            .frame(height: 56)
            insightRows
            Spacer(minLength: 0)
            footer
        }
        .cardSurface()
    }
}

// MARK: - Header & Total

extension MetricWeekCard {
    private var header: some View {
        HStack(spacing: 12) {
            MetricIcon(systemName: week.icon, tint: tint)
            Text(week.name)
                .font(.headline)
            Spacer()
            if week.streak > 0 {
                streakBadge
            }
        }
    }

    private var streakBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.caption2)
            Text("\(week.streak)")
                .font(.caption.bold())
                .monospacedDigit()
        }
        .foregroundStyle(.secondary)
        .accessibilityLabel("\(week.streak) day streak")
    }

    private var totalRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(
                ValueFormatter.format(
                    week.total,
                    type: week.measurementType,
                    unit: week.unit
                )
            )
            .numeralStyle(.value)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            changeLine
        }
    }

    private var changeLine: some View {
        HStack(spacing: 5) {
            Image(systemName: changeSymbol)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
            Text(changeText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var changeSymbol: String {
        switch week.change {
        case .up: "arrow.up.right"
        case .down: "arrow.down.right"
        case .flat: "equal"
        case .noBaseline: "sparkles"
        }
    }

    private var changeText: String {
        switch week.change {
        case let .up(ratio):
            "\(Self.percent(ratio))% vs last week"
        case let .down(ratio):
            "\(Self.percent(ratio))% vs last week"
        case .flat:
            "about level with last week"
        case .noBaseline:
            "nothing logged the week before"
        }
    }

    private static func percent(_ ratio: Double) -> Int {
        Int((abs(ratio) * 100).rounded())
    }
}

// MARK: - Insights & Footer

extension MetricWeekCard {
    @ViewBuilder
    private var insightRows: some View {
        let insights = week.insights.prefix(Self.maxInsights)
        if !insights.isEmpty {
            Divider()
            ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                insightRow(insight)
            }
        }
    }

    private func insightRow(_ insight: Insight) -> some View {
        HStack(spacing: 10) {
            Image(systemName: insight.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.headline)
                    .font(.subheadline)
                Text(insight.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        Text(footerText)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var footerText: String {
        let days = week.activeDays == 1 ? "1 day" : "\(week.activeDays) days"
        var parts = [
            ValueFormatter.sessions(week.sessionCount),
            "\(days) active"
        ]
        if let hits = week.goalDaysHit {
            parts.append("goal hit \(hits)/\(WeeklyReview.periodDays)")
        }
        return parts.joined(separator: " · ")
    }
}
