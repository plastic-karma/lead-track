import SwiftData
import SwiftUI

/// One dashboard card per metric: identity, today's value with a seven-day
/// sparkline, streak, optional goal progress, and the primary action
/// (start/stop timer or +1) right where the status is shown. While a timer
/// runs the value counts live and the card wears a red recording border.
struct MetricCardView: View {
    @Environment(\.modelContext) private var modelContext
    let metric: Metric
    let runningSession: Session?
    @State private var showingCountEntry = false
    @State private var quickLogTrigger = false

    var body: some View {
        content(SessionStatistics.dailyTotals(from: metric.sessions))
            .sheet(isPresented: $showingCountEntry) {
                CountEntryView(metric: metric, project: nil)
            }
            .sensoryFeedback(.increase, trigger: quickLogTrigger)
            .sensoryFeedback(trigger: runningSession != nil) { wasActive, isActive in
                if !wasActive, isActive {
                    .impact(weight: .medium)
                } else if wasActive, !isActive {
                    .success
                } else {
                    nil
                }
            }
    }

    private func content(_ totals: [DailyTotal]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            valueRow(totals)
            streakLine(totals)
            if let goal = metric.dailyGoal {
                goalBar(
                    today: SessionStatistics.todayTotal(from: totals),
                    goal: goal
                )
            }
        }
        .padding(16)
        .background(cardShape.fill(Color(.secondarySystemGroupedBackground)))
        .overlay(cardShape.strokeBorder(borderColor, lineWidth: 1.5))
    }
}

// MARK: - Card Pieces

extension MetricCardView {
    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
    }

    private var borderColor: Color {
        runningSession == nil ? .clear : .red.opacity(0.4)
    }

    private var tint: Color {
        metric.displayColor
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: metric.icon ?? "clock")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(Circle().fill(tint.opacity(0.12)))
            Text(metric.name)
                .font(.headline)
            Spacer()
            actionButton
        }
    }

    private func valueRow(_ totals: [DailyTotal]) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 16) {
            todayValue(totals)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer()
            SparklineView(
                values: SessionStatistics.trailingDailySeries(
                    days: 7, from: totals
                ),
                tint: tint
            )
            .frame(width: 92, height: 26)
        }
    }

    @ViewBuilder
    private func todayValue(_ totals: [DailyTotal]) -> some View {
        if let session = runningSession {
            Text(liveTimerStart(session, totals: totals), style: .timer)
        } else {
            Text(
                ValueFormatter.format(
                    SessionStatistics.todayTotal(from: totals),
                    type: metric.measurementType,
                    unit: metric.unit
                )
            )
        }
    }

    /// Backdates the live timer's origin by today's completed total so the
    /// counting value shows the whole day, not just the current session.
    private func liveTimerStart(
        _ session: Session,
        totals: [DailyTotal]
    ) -> Date {
        session.startedAt.addingTimeInterval(
            -SessionStatistics.todayTotal(from: totals)
        )
    }

    private func streakLine(_ totals: [DailyTotal]) -> some View {
        let streak = SessionStatistics.currentStreak(
            from: totals,
            excludedWeekdays: metric.excludedWeekdaySet
        )
        let suffix = streak > 1 ? " · \(streak) day streak" : ""
        return Text("today\(suffix)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func goalBar(
        today: TimeInterval,
        goal: TimeInterval
    ) -> some View {
        HStack(spacing: 12) {
            ProgressView(value: min(today / max(goal, 1), 1))
                .progressViewStyle(.linear)
                .tint(today >= goal ? Color.green : tint)
            Text(
                "goal \(ValueFormatter.formatShort(goal, type: metric.measurementType))"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .layoutPriority(1)
        }
    }
}

// MARK: - Actions

extension MetricCardView {
    @ViewBuilder
    private var actionButton: some View {
        if metric.measurementType == .duration {
            timerButton
        } else {
            countButton
        }
    }

    private var timerButton: some View {
        Button(action: toggleTimer) {
            actionIcon(runningSession == nil ? "play.fill" : "stop.fill")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            runningSession == nil ? "Start Timer" : "Stop Timer"
        )
    }

    /// Tap logs one unit instantly; long-press offers the custom-amount sheet.
    private var countButton: some View {
        Menu {
            Button {
                showingCountEntry = true
            } label: {
                Label("Log Custom Amount", systemImage: "square.and.pencil")
            }
        } label: {
            actionIcon("plus")
        } primaryAction: {
            logOne()
        }
        .accessibilityLabel("Log one \(metric.unit ?? "entry")")
    }

    private func actionIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(
                Circle().fill(
                    runningSession == nil ? tint : Color.red
                )
            )
    }

    private func toggleTimer() {
        withAnimation {
            if let session = runningSession {
                SessionService.stopSession(session)
            } else {
                SessionService.startSession(for: metric, in: modelContext)
            }
        }
    }

    private func logOne() {
        withAnimation {
            SessionService.logCount(1, for: metric, in: modelContext)
        }
        quickLogTrigger.toggle()
    }
}
