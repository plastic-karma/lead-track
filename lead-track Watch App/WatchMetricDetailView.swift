import SwiftUI

/// The screen a Metric Progress complication opens: today's standing for one
/// metric — its goal ring (or plain value) with a spelled-out caption, plus
/// the same tap-to-act row the list shows. Resolved live from the cached
/// snapshot, so it stays right across midnight even with the phone away.
struct WatchMetricDetailView: View {
    @Environment(WatchSyncController.self) private var sync
    let metricID: UUID

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            content(at: timeline.date)
        }
    }

    @ViewBuilder
    private func content(at date: Date) -> some View {
        if let metric = metric(at: date) {
            found(metric, at: date)
        } else {
            missing
        }
    }

    private func found(_ metric: WatchMetricSnapshot, at date: Date) -> some View {
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
    }

    private var missing: some View {
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

    /// The live metric row, rolled forward so its raw totals match the list
    /// after midnight; nil once the configured metric has been deleted.
    private func metric(at date: Date) -> WatchMetricSnapshot? {
        WatchSnapshotReducer.rolledForward(sync.snapshot, to: date)
            .metrics.first { $0.id == metricID }
    }

    /// The same goal math the complication draws, resolved for `date`.
    private func progress(at date: Date) -> ComplicationMetricProgress? {
        ComplicationProgress.metrics(in: sync.snapshot, at: date)
            .first { $0.id == metricID }
    }
}

// MARK: - Progress summary

/// The goal readout above the action row: a ring filled to today's fraction of
/// the daily goal with the value at its center, or — when no target applies
/// today — the plain value, under a caption spelling the standing out in words.
struct WatchMetricProgressSummary: View {
    let progress: ComplicationMetricProgress

    var body: some View {
        VStack(spacing: 8) {
            headline
            caption
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var headline: some View {
        if let fraction = progress.fraction {
            ring(fraction: fraction)
        } else {
            plainValue
        }
    }

    private func ring(fraction: Double) -> some View {
        ZStack {
            Circle()
                .stroke(.gray.opacity(0.25), lineWidth: 9)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    progress.displayColor,
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            center
        }
        .frame(width: 104, height: 104)
    }

    @ViewBuilder
    private var center: some View {
        if progress.measurementType == .binary {
            Image(systemName: progress.todayTotal > 0 ? "checkmark" : "circle")
                .font(.title.weight(.semibold))
                .foregroundStyle(progress.displayColor)
        } else {
            Text(valueText)
                .roundedDigits(.title2, weight: .semibold)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }

    private var plainValue: some View {
        Text(valueText)
            .roundedDigits(.largeTitle, weight: .semibold)
            .foregroundStyle(progress.displayColor)
    }

    private var caption: some View {
        Text(captionText)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Summary text

extension WatchMetricProgressSummary {
    /// Today's total in the metric's own unit — the figure the ring encloses
    /// or, target-free, stands alone.
    private var valueText: String {
        ValueFormatter.format(
            progress.todayTotal,
            type: progress.measurementType ?? .count,
            unit: progress.unit
        )
    }

    /// The standing spelled out: a rest note, a binary's done state, the goal
    /// being chased, or just today's tally when nothing is.
    private var captionText: String {
        if progress.isRestDay {
            return "Resting today"
        }
        if progress.measurementType == .binary {
            return progress.todayTotal > 0 ? "Done today" : "Not done yet"
        }
        return goalCaption
    }

    private var goalCaption: String {
        guard progress.fraction != nil, let goal = progress.dailyGoal else {
            return "\(valueText) today"
        }
        return "\(progress.percent ?? 0)% of \(goalText(goal))"
    }

    private func goalText(_ goal: Double) -> String {
        ValueFormatter.format(
            goal,
            type: progress.measurementType ?? .count,
            unit: progress.unit
        )
    }
}
