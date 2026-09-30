import SwiftUI

/// The screen a Metric Progress complication opens: today's standing for one
/// metric — its goal ring (or plain value) with a spelled-out caption, plus
/// the same tap-to-act row the list shows. Resolved live from the cached
/// snapshot, so it stays right across midnight even with the phone away.
struct WatchMetricDetailView: View {
    let metricID: UUID

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            WatchMetricDetailContent(metricID: metricID, date: timeline.date)
        }
    }
}

private struct WatchMetricDetailContent: View {
    @Environment(WatchSyncController.self) private var sync
    let metricID: UUID
    let date: Date

    var body: some View {
        if let metric = metric(at: date) {
            ScrollView {
                VStack(spacing: 12) {
                    if let progress = progress(at: date) {
                        WatchMetricProgressSummary(progress: progress)
                    }
                    WatchMetricRow(metric: metric)
                }
                .padding(.horizontal, 6)
            }
            .navigationTitle(metric.name)
        } else {
            WatchMetricMissingState()
        }
    }

    /// Roll raw totals forward just like the list when opening after midnight.
    private func metric(at date: Date) -> WatchMetricSnapshot? {
        WatchSnapshotReducer.rolledForward(sync.snapshot, to: date)
            .metrics.first { $0.id == metricID }
    }

    private func progress(at date: Date) -> ComplicationMetricProgress? {
        ComplicationProgress.metrics(in: sync.snapshot, at: date)
            .first { $0.id == metricID }
    }
}

private struct WatchMetricMissingState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Metric Unavailable")
                .font(.headline)
            Text("Open LeadStone on your iPhone to sync.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Progress summary

/// The goal readout above the action row: a ring filled to today's fraction of
/// the daily goal with the value at its center, or — when no target applies
/// today — the plain value, under a caption spelling the standing out in words.
private struct WatchMetricProgressSummary: View {
    let measurementType: MeasurementType?
    let unit: String?
    let todayTotal: Double
    let dailyGoal: Double?
    let isRestDay: Bool
    let fraction: Double?
    let percent: Int?
    let displayColor: Color

    init(progress: ComplicationMetricProgress) {
        measurementType = progress.measurementType
        unit = progress.unit
        todayTotal = progress.todayTotal
        dailyGoal = progress.dailyGoal
        isRestDay = progress.isRestDay
        fraction = progress.fraction
        percent = progress.percent
        displayColor = progress.displayColor
    }

    var body: some View {
        VStack(spacing: 8) {
            WatchMetricProgressHeadline(
                fraction: fraction,
                displayColor: displayColor,
                isBinary: measurementType == .binary,
                isDone: todayTotal > 0,
                valueText: valueText
            )
            Text(captionText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}

private struct WatchMetricProgressHeadline: View {
    let fraction: Double?
    let displayColor: Color
    let isBinary: Bool
    let isDone: Bool
    let valueText: String

    var body: some View {
        if let fraction {
            ring(fraction: fraction)
        } else {
            Text(valueText)
                .roundedDigits(.largeTitle, weight: .semibold)
                .foregroundStyle(displayColor)
        }
    }

    private func ring(fraction: Double) -> some View {
        ZStack {
            Circle()
                .stroke(.gray.opacity(0.25), lineWidth: 9)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    displayColor,
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            center
        }
        .frame(width: 104, height: 104)
    }

    @ViewBuilder
    private var center: some View {
        if isBinary {
            Image(systemName: isDone ? "checkmark" : "circle")
                .font(.title.weight(.semibold))
                .foregroundStyle(displayColor)
        } else {
            Text(valueText)
                .roundedDigits(.title2, weight: .semibold)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }
}

// MARK: - Summary text

extension WatchMetricProgressSummary {
    /// Today's total in the metric's own unit — the figure the ring encloses
    /// or, target-free, stands alone.
    private var valueText: String {
        ValueFormatter.format(
            todayTotal,
            type: measurementType ?? .count,
            unit: unit
        )
    }

    /// The standing spelled out: a rest note, a binary's done state, the goal
    /// being chased, or just today's tally when nothing is.
    private var captionText: String {
        if isRestDay {
            return "Resting today"
        }
        if measurementType == .binary {
            return todayTotal > 0 ? "Done today" : "Not done yet"
        }
        return goalCaption
    }

    private var goalCaption: String {
        guard fraction != nil, let goal = dailyGoal else {
            return "\(valueText) today"
        }
        return "\((percent ?? 0).formatted())% of \(goalText(goal))"
    }

    private func goalText(_ goal: Double) -> String {
        ValueFormatter.format(
            goal,
            type: measurementType ?? .count,
            unit: unit
        )
    }
}
