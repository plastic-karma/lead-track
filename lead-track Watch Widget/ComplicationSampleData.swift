import Foundation

/// Fabricated `ComplicationMetricProgress` fixtures shared by the widget
/// placeholders (Daily Goals and Metric Progress), so complication pickers
/// preview something realistic before real data exists.
extension ComplicationMetricProgress {
    static let sample = ComplicationMetricProgress(
        id: UUID(),
        name: "Read",
        icon: "book",
        colorName: nil,
        measurementType: .duration,
        unit: nil,
        todayTotal: 1350,
        dailyGoal: 1800,
        isRestDay: false,
        isRunning: false
    )

    /// Three fabricated rows for the Daily Goals placeholder.
    static let sampleLines = [
        sample,
        ComplicationMetricProgress(
            id: UUID(),
            name: "Run",
            icon: "figure.run",
            colorName: "sage",
            measurementType: .count,
            unit: "km",
            todayTotal: 2,
            dailyGoal: 5,
            isRestDay: false,
            isRunning: false
        ),
        ComplicationMetricProgress(
            id: UUID(),
            name: "Stretch",
            icon: "figure.cooldown",
            colorName: "teal",
            measurementType: .binary,
            unit: nil,
            todayTotal: 1,
            dailyGoal: nil,
            isRestDay: false,
            isRunning: false
        )
    ]
}
