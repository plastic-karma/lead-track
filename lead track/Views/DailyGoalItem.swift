import SwiftUI

/// Shows the daily-goal ring, or a rest-day indicator when today is excluded.
struct DailyGoalItem: View {
    let label: String
    let today: TimeInterval
    let goal: TimeInterval
    let excludedWeekdays: [Int]
    var measurementType: MeasurementType = .duration
    var unit: String?

    private var isRestDay: Bool {
        let weekday = Calendar.current.component(.weekday, from: .now)
        return excludedWeekdays.contains(weekday)
    }

    var body: some View {
        if isRestDay {
            RestDayItem(label: label)
        } else {
            GoalProgressView(
                label: label,
                current: today,
                goal: goal,
                measurementType: measurementType,
                unit: unit
            )
        }
    }
}

// MARK: - Rest Day

struct RestDayItem: View {
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Image(systemName: "moon.zzz.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(height: 44)
            Text("Rest day")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
