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
    /// When set, the header folds the card to its one line and back; the
    /// chevron says which way. Nil leaves the card always open (the bare
    /// ledger has no header to fold from).
    var collapse: Binding<Bool>?

    /// One group's heading: the aspiration's name in its own ink, or gray for
    /// the unaligned group (nil color, no icon).
    struct Header {
        let title: String
        let icon: String?
        let colorName: String?
    }

    var body: some View {
        let collapsed = collapse?.wrappedValue ?? false
        return VStack(spacing: 0) {
            if let header {
                headerRow(header)
                if !collapsed { Divider() }
            }
            if !collapsed {
                ForEach(weeks) { week in
                    linkedRow(week.id) {
                        LedgerActiveMetricRow(
                            name: week.name, icon: week.icon, colorName: week.colorName,
                            total: ValueFormatter.format(week.total, type: week.measurementType, unit: week.unit),
                            change: week.change
                        )
                    }
                    divider(after: week.id)
                }
                ForEach(quiet) { metric in
                    linkedRow(metric.id) {
                        LedgerQuietMetricRow(name: metric.name, icon: metric.icon)
                    }
                    divider(after: metric.id)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background { Theme.cardShape() }
    }
}

// MARK: - Header

extension MetricLedgerCard {
    /// A plain heading with no fold affordance, or a button that toggles the
    /// card's fold when a `collapse` binding is present.
    @ViewBuilder
    private func headerRow(_ header: Header) -> some View {
        if let collapse {
            Button {
                withAnimation(.snappy) { collapse.wrappedValue.toggle() }
            } label: {
                headerLabel(header, collapsed: collapse.wrappedValue, foldable: true)
            }
            .buttonStyle(.plain)
            .accessibilityHint(collapse.wrappedValue ? "Expand" : "Collapse")
        } else {
            headerLabel(header, collapsed: false, foldable: false)
        }
    }

    private func headerLabel(_ header: Header, collapsed: Bool, foldable: Bool) -> some View {
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
            if foldable {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(collapsed ? 0 : 180))
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
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
}

private struct LedgerActiveMetricRow: View {
    let name: String
    let icon: String
    let colorName: String?
    let total: String
    let change: WeeklyReview.WeekChange

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(MetricColor.color(named: colorName))
                .frame(width: 24)
            Text(name)
                .font(.subheadline)
            Spacer(minLength: 8)
            Text(total)
                .numeralStyle(.stat)
                .lineLimit(1)
            LedgerChangeBadge(change: change, colorName: colorName)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

private struct LedgerQuietMetricRow: View {
    let name: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(name)
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

private struct LedgerChangeBadge: View {
    let change: WeeklyReview.WeekChange
    let colorName: String?

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: changeSymbol(change))
                .font(.caption2.weight(.bold))
                .foregroundStyle(changeTint)
            if let text = changePercent(change) {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(minWidth: 44, alignment: .trailing)
        .accessibilityLabel(changeDescription(change))
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
    private var changeTint: AnyShapeStyle {
        if case .up = change {
            return AnyShapeStyle(MetricColor.color(named: colorName))
        }
        return AnyShapeStyle(.secondary)
    }

    private func changePercent(_ change: WeeklyReview.WeekChange) -> String? {
        switch change {
        case let .up(ratio), let .down(ratio):
            abs(ratio).formatted(.percent.precision(.fractionLength(0)).rounded(rule: .toNearestOrAwayFromZero))
        case .flat, .noBaseline:
            nil
        }
    }

    private func changeDescription(_ change: WeeklyReview.WeekChange) -> String {
        switch change {
        case let .up(ratio):
            "up \(Int((abs(ratio) * 100).rounded()).formatted()) percent vs last week"
        case let .down(ratio):
            "down \(Int((abs(ratio) * 100).rounded()).formatted()) percent vs last week"
        case .flat:
            "about level with last week"
        case .noBaseline:
            "nothing logged the week before"
        }
    }
}
