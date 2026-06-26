import SwiftUI

/// One aspiration's summary at the top of the weekly review: the lifetime effort
/// poured into it leads (continuity, never a target), then what landed this
/// week, the week's rhythm, and a tap-through to the full detail. Mirrors the
/// dashboard cards' restraint — the identity color rides the data ink while the
/// chrome stays quiet.
struct AspirationWeekCard: View {
    let week: WeeklyReview.AspirationWeek
    /// First day of the review period, anchoring the day-strip labels.
    let weekStart: Date

    private var tint: Color {
        MetricColor.color(named: week.colorName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            lifetimeLine
            thisWeekLine
            WeekBarsView(
                values: week.dailySeries,
                labels: WeekBarsView.weekdayLabels(
                    from: weekStart, count: WeeklyReview.periodDays
                ),
                tint: tint
            )
            .frame(height: 44)
            footer
        }
        .cardSurface()
    }
}

// MARK: - Pieces

extension AspirationWeekCard {
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: week.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.chipFill))
            Text(week.title)
                .font(.headline)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var lifetimeLine: some View {
        if !week.lifetimeSummary.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(week.lifetimeSummary)
                    .numeralStyle(.value)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("poured in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var thisWeekLine: some View {
        HStack(spacing: 6) {
            Text("This week")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(thisWeekText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var thisWeekText: String {
        week.totals.isEmpty
            ? "—"
            : week.totals.map(\.text).joined(separator: " · ")
    }

    private var footer: some View {
        Text("\(ValueFormatter.sessions(week.sessionCount)) · \(week.activeDays) days active")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
