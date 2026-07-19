import SwiftData
import SwiftUI

/// The month calendar of daily goals: a paged month grid where every day
/// wears its verdict, and a tappable day panel showing each goal's actual
/// value. Unfiltered, a day tallies how many daily goals were reached
/// ("2/3"); the toolbar filter — or the metric / project / aspiration
/// screens, which open it pre-filtered to themselves — narrows judgment to
/// one series. Chevrons and horizontal swipes page the months; tapping the
/// title returns to the current month.
struct GoalCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @Query(sort: \Aspiration.createdAt) private var aspirations: [Aspiration]
    @State private var filter: GoalCalendarFilter?
    @State private var monthAnchor: Date
    @State private var selectedDay: Date?

    private let calendar = Calendar.current

    init(filter: GoalCalendarFilter? = nil) {
        _filter = State(initialValue: filter)
        _monthAnchor = State(initialValue: GoalCalendar.monthStart(containing: .now))
    }

    var body: some View {
        NavigationStack {
            page
                .background(Theme.screenBackground.ignoresSafeArea())
                .navigationTitle("Calendar")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
    }

    private var page: some View {
        let month = GoalCalendarMonth(
            series: filter?.series,
            talliedMetrics: talliedMetrics,
            monthOf: monthAnchor,
            calendar: calendar
        )
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                monthHeader
                filterChip
                calendarCard(month)
                summaryLine(month)
                dayPanel
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    /// The metrics a tallied calendar counts: the aspiration's attachments,
    /// or every metric when no filter is set — unarchived either way,
    /// Today's convention.
    private var talliedMetrics: [Metric] {
        switch filter {
        case nil: metrics.unarchived
        case let .aspiration(aspiration): aspiration.metrics.unarchived.inDisplayOrder
        default: []
        }
    }

    private var tint: Color {
        filter?.tint ?? .accentColor
    }

    private var fillTint: Color {
        filter?.prominentTint ?? MetricColor.prominentColor(named: nil)
    }
}

// MARK: - Header & chrome

extension GoalCalendarView {
    private var monthHeader: some View {
        HStack(spacing: 10) {
            chevron("chevron.left", label: "Earlier month") { step(-1) }
            Spacer()
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    monthAnchor = GoalCalendar.monthStart(containing: .now, calendar: calendar)
                }
            } label: {
                Text(monthAnchor, format: .dateTime.month(.wide).year())
                    .font(.headline)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Current month")
            .accessibilityHint("Returns to the current month")
            Spacer()
            chevron("chevron.right", label: "Later month") { step(1) }
        }
    }

    private func chevron(
        _ symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.chipFill))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// The active filter as a wearable chip, cleared with its x.
    @ViewBuilder
    private var filterChip: some View {
        if let active = filter {
            HStack(spacing: 6) {
                Image(systemName: active.icon)
                Text(active.title)
                    .lineLimit(1)
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        filter = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .accessibilityLabel("Clear filter")
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(active.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(active.tint.opacity(0.14)))
        }
    }

    private func step(_ offset: Int) {
        withAnimation(.snappy(duration: 0.25)) {
            monthAnchor = GoalCalendar.monthStart(offset, from: monthAnchor, calendar: calendar)
            selectedDay = nil
        }
    }
}

// MARK: - Grid

extension GoalCalendarView {
    private func calendarCard(_ month: GoalCalendarMonth) -> some View {
        VStack(spacing: 8) {
            weekdayHeader
            VStack(spacing: 4) {
                ForEach(Array(month.weeks.enumerated()), id: \.offset) { _, week in
                    weekRow(week, month: month)
                }
            }
        }
        .cardSurface()
        .gesture(monthSwipe)
    }

    private var weekdayHeader: some View {
        let symbols = GoalCalendar.weekdaySymbols(calendar: calendar)
        return HStack(spacing: 4) {
            ForEach(0 ..< 7, id: \.self) { column in
                Text(symbols[column])
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func weekRow(_ week: [Date?], month: GoalCalendarMonth) -> some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 7, id: \.self) { column in
                daySlot(week[column], month: month)
            }
        }
    }

    @ViewBuilder
    private func daySlot(_ day: Date?, month: GoalCalendarMonth) -> some View {
        if let day {
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    selectedDay = selectedDay == day ? nil : day
                }
            } label: {
                GoalCalendarDayCell(
                    model: cellModel(for: day, in: month),
                    tint: tint,
                    fillTint: fillTint
                )
            }
            .buttonStyle(.plain)
        } else {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 1)
        }
    }

    private func cellModel(for day: Date, in month: GoalCalendarMonth) -> GoalCalendarDayCell.Model {
        GoalCalendarDayCell.Model(
            day: day,
            fraction: month.fraction(on: day),
            detail: month.cellDetail(on: day),
            isToday: calendar.isDateInToday(day),
            isSelected: selectedDay == day,
            isMuted: day > calendar.startOfDay(for: .now)
        )
    }

    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                step(value.translation.width < 0 ? 1 : -1)
            }
    }
}

// MARK: - Summary, panel & toolbar

extension GoalCalendarView {
    private func summaryLine(_ month: GoalCalendarMonth) -> some View {
        Text(month.summaryText)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var dayPanel: some View {
        if let day = selectedDay {
            GoalCalendarDayPanel(
                day: day,
                filter: filter,
                talliedMetrics: talliedMetrics
            )
            .transition(.opacity)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            GoalCalendarFilterMenu(
                metrics: metrics,
                aspirations: aspirations,
                filter: $filter
            )
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
        }
    }
}
