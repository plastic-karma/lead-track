import SwiftData
import SwiftUI

/// A recording route independent of the cluster expansion map. Historical
/// logs use the browsed day; opening or closing it never unfolds a cluster.
struct TodayLogButton: View {
    let daysBack: Int
    @State private var showingLog = false

    var body: some View {
        Button { showingLog = true } label: {
            Label("Log Effort", systemImage: "square.and.pencil")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .prominentCapsuleButtonStyle()
        .tint(MetricColor.copper.prominentColor)
        .sheet(isPresented: $showingLog) {
            TodayLogView(day: daysBack == 0 ? nil : TodayGrouping.day(back: daysBack))
        }
    }
}

private struct TodayLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<Metric> { $0.archivedAt == nil && $0.healthSourceRaw == nil },
        sort: \Metric.createdAt
    ) private var metrics: [Metric]
    let day: Date?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(metrics) { metric in
                        TodayLogMetricRow(metric: metric, day: day)
                    }
                } header: {
                    Text(day ?? .now, format: .dateTime.weekday(.wide).month(.wide).day().year())
                }
            }
            .navigationTitle("Log Effort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct TodayLogMetricRow: View {
    @Environment(\.modelContext) private var modelContext
    let metric: Metric
    let day: Date?
    @State private var showingEntry = false
    @State private var quickLogTrigger = false

    var body: some View {
        Button(action: record) {
            HStack(spacing: 12) {
                MetricIcon(systemName: metric.displayIcon, tint: metric.displayColor, size: 30)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.name)
                        .font(.headline)
                    Text(actionTitle)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 8)
                Image(systemName: isDone ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEntry) {
            if metric.measurementType == .duration {
                DurationEntryView(metric: metric, project: nil, day: day)
            } else {
                CountEntryView(metric: metric, project: nil, day: day)
            }
        }
        .sensoryFeedback(.increase, trigger: quickLogTrigger)
    }

    private var isDone: Bool {
        metric.measurementType == .binary && recorder.isDoneToday
    }

    private var actionTitle: String {
        switch metric.measurementType {
        case .duration: "Log Time"
        case .count: metric.logsOneUnitImmediately ? "Log +1" : "Log Amount"
        case .binary: isDone ? "Done · Tap to Undo" : "Mark Done"
        }
    }

    private var recorder: MetricRecorder {
        MetricRecorder(
            metric: metric, runningSession: nil, modelContext: modelContext, day: day
        ) {
            quickLogTrigger.toggle()
        }
    }

    private func record() {
        switch metric.measurementType {
        case .binary:
            recorder.toggleDone()
        case .count where metric.logsOneUnitImmediately:
            recorder.logOne()
        default:
            showingEntry = true
        }
    }
}
