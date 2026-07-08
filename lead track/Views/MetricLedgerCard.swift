import SwiftUI

/// The metrics as a ledger: one quiet row per metric inside a single card —
/// identity, the week's total, and how it compares to the week before at
/// the right edge, gains wearing the metric's color. The metrics that
/// stayed quiet sit dimmed at the bottom of the same ledger. Each row
/// drills into its metric; everything beyond the total waits behind that
/// tap, so the review's metric zone reads in one breath.
///
/// With a `header` it becomes one aspiration's compact group on the Week tab —
/// the aspiration's identity over its metrics' weeks — so the Week tab groups
/// by aspiration the way Today does. Without one it stays the bare ledger.
struct MetricLedgerCard: View {
    /// The aspiration identity drawn atop the card, turning the ledger into one
    /// compact group; nil renders the plain ledger.
    var header: Header?
    let weeks: [WeeklyReview.MetricWeek]
    let quiet: [WeeklyReview.QuietMetric]
    /// Maps a row back to its model for the drill-in link; rows that no
    /// longer resolve render without navigation.
    var metric: (String) -> Metric?

    /// One group's heading: the aspiration's name in its own ink, or gray for
    /// the unaligned group (nil color, no icon).
    struct Header {
        let title: String
        let icon: String?
        let colorName: String?
    }

    var body: some View {
        VStack(spacing: 0) {
            if let header {
                headerRow(header)
                Divider()
            }
            ForEach(weeks) { week in
                linkedRow(week.id) { activeRow(week) }
                divider(after: week.id)
            }
            ForEach(quiet) { metric in
                linkedRow(metric.id) { quietRow(metric) }
                divider(after: metric.id)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Theme.cardShape())
    }
}

// MARK: - Header

extension MetricLedgerCard {
    private func headerRow(_ header: Header) -> some View {
        HStack(spacing: 8) {
            if let icon = header.icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(MetricColor.color(named: header.colorName))
            }
            Text(header.title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .kerning(0.5)
                .foregroundStyle(headerTint(header))
                .lineLimit(1)
            Spacer(minLength: 8)
        }
        .padding(.vertical, 10)
    }

    /// The unaligned group's gray heading is itself the gentle nudge; an
    /// aspiration wears its own color.
    private func headerTint(_ header: Header) -> Color {
        header.colorName == nil ? .secondary : MetricColor.color(named: header.colorName)
    }
}

// MARK: - Rows

extension MetricLedgerCard {
    @ViewBuilder
    private func linkedRow(_ id: String, @ViewBuilder content: () -> some View) -> some View {
        if let metric = metric(id) {
            NavigationLink(value: metric) {
                content()
            }
            .buttonStyle(.plain)
        } else {
            content()
        }
    }

    /// A hairline between neighbors only — the card's own edges frame the
    /// first and last rows.
    @ViewBuilder
    private func divider(after id: String) -> some View {
        if id != (quiet.last?.id ?? weeks.last?.id) {
            Divider()
        }
    }

    private func activeRow(_ week: WeeklyReview.MetricWeek) -> some View {
        HStack(spacing: 10) {
            Image(systemName: week.icon)
                .font(.subheadline)
                .foregroundStyle(MetricColor.color(named: week.colorName))
                .frame(width: 24)
            Text(week.name)
                .font(.subheadline)
            Spacer(minLength: 8)
            Text(ValueFormatter.format(week.total, type: week.measurementType, unit: week.unit))
                .numeralStyle(.stat)
                .lineLimit(1)
            changeBadge(week)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private func quietRow(_ metric: WeeklyReview.QuietMetric) -> some View {
        HStack(spacing: 10) {
            Image(systemName: metric.icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(metric.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("quiet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 11)
        .opacity(0.55)
        .contentShape(Rectangle())
    }
}

// MARK: - Week-over-week badge

extension MetricLedgerCard {
    private func changeBadge(_ week: WeeklyReview.MetricWeek) -> some View {
        HStack(spacing: 3) {
            Image(systemName: changeSymbol(week.change))
                .font(.caption2.weight(.bold))
                .foregroundStyle(changeTint(week))
            if let text = changePercent(week.change) {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(minWidth: 44, alignment: .trailing)
        .accessibilityLabel(changeDescription(week.change))
    }

    private func changeSymbol(_ change: WeeklyReview.WeekChange) -> String {
        switch change {
        case .up: "arrow.up.right"
        case .down: "arrow.down.right"
        case .flat: "equal"
        case .noBaseline: "sparkles"
        }
    }

    /// A gain wears the metric's color; everything else stays gray — the
    /// ledger notes without ever scolding.
    private func changeTint(_ week: WeeklyReview.MetricWeek) -> AnyShapeStyle {
        if case .up = week.change {
            return AnyShapeStyle(MetricColor.color(named: week.colorName))
        }
        return AnyShapeStyle(.secondary)
    }

    private func changePercent(_ change: WeeklyReview.WeekChange) -> String? {
        switch change {
        case let .up(ratio), let .down(ratio):
            "\(Int((abs(ratio) * 100).rounded()))%"
        case .flat, .noBaseline:
            nil
        }
    }

    private func changeDescription(_ change: WeeklyReview.WeekChange) -> String {
        switch change {
        case let .up(ratio):
            "up \(Int((abs(ratio) * 100).rounded())) percent vs last week"
        case let .down(ratio):
            "down \(Int((abs(ratio) * 100).rounded())) percent vs last week"
        case .flat:
            "about level with last week"
        case .noBaseline:
            "nothing logged the week before"
        }
    }
}
