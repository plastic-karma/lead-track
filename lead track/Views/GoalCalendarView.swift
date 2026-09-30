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
                GoalCalendarMonthHeader(month: monthAnchor, step: step, returnToCurrentMonth: returnToCurrentMonth)
                if let active = filter {
                    GoalCalendarFilterChip(
                        title: active.title,
                        icon: active.icon,
                        tint: active.tint,
                        clear: clearFilter
                    )
                }
                GoalCalendarGrid(
                    month: month, calendar: calendar, tint: tint, fillTint: fillTint,
                    selectedDay: $selectedDay
                )
                .gesture(monthSwipe)
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
    private func returnToCurrentMonth() {
        withAnimation(.snappy(duration: 0.25)) {
            monthAnchor = GoalCalendar.monthStart(containing: .now, calendar: calendar)
        }
    }

    private func clearFilter() {
        withAnimation(.snappy(duration: 0.2)) {
            filter = nil
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
        ToolbarItem(placement: .topBarLeading) {
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

private struct GoalCalendarMonthHeader: View {
    let month: Date
    let step: (Int) -> Void
    let returnToCurrentMonth: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            chevron("chevron.left", label: "Earlier month") { step(-1) }
            Spacer()
            Button(action: returnToCurrentMonth) {
                Text(month, format: .dateTime.month(.wide).year())
                    .font(.headline)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Current month")
            .accessibilityHint("Returns to the current month")
            Spacer()
            chevron("chevron.right", label: "Later month") { step(1) }
        }
    }

    private func chevron(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.chipFill))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct GoalCalendarFilterChip: View {
    let title: String
    let icon: String
    let tint: Color
    let clear: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title).lineLimit(1)
            Button(action: clear) {
                Image(systemName: "xmark.circle.fill")
            }
            .accessibilityLabel("Clear filter")
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(tint.opacity(0.14)))
    }
}

private struct GoalCalendarGrid: View {
    let month: GoalCalendarMonth
    let calendar: Calendar
    let tint: Color
    let fillTint: Color
    @Binding var selectedDay: Date?

    private struct Week: Identifiable {
        let id: Date
        let slots: [Slot]
    }

    private struct Slot: Identifiable {
        let column: Int
        let day: Date?

        var id: SlotID {
            day.map { .day($0) } ?? .padding(column)
        }
    }

    private var weeks: [Week] {
        month.weeks.compactMap { days in
            guard let firstDay = days.first(where: { $0 != nil }) ?? nil else { return nil }
            return Week(id: firstDay, slots: days.enumerated().map { Slot(column: $0.offset, day: $0.element) })
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            let symbols = GoalCalendar.weekdaySymbols(calendar: calendar)
            HStack(spacing: 4) {
                ForEach(0 ..< 7, id: \.self) { column in
                    Text(symbols[column])
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            VStack(spacing: 4) {
                ForEach(weeks) { week in
                    HStack(spacing: 4) {
                        ForEach(week.slots) { slot in
                            daySlot(slot.day)
                        }
                    }
                }
            }
        }
        .cardSurface()
    }

    private enum SlotID: Hashable {
        case day(Date)
        case padding(Int)
    }

    @ViewBuilder
    private func daySlot(_ day: Date?) -> some View {
        if let day {
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    selectedDay = selectedDay == day ? nil : day
                }
            } label: {
                GoalCalendarDayCell(
                    model: GoalCalendarDayCell.Model(
                        day: day, fraction: month.fraction(on: day), detail: month.cellDetail(on: day),
                        isToday: calendar.isDateInToday(day), isSelected: selectedDay == day,
                        isMuted: day > calendar.startOfDay(for: .now)
                    ),
                    tint: tint, fillTint: fillTint
                )
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(maxWidth: .infinity, minHeight: 1)
        }
    }
}
