import Foundation
import HealthKit

/// Maps each `HealthDataSource` to its HealthKit types and reads day totals.
/// Strictly read-only — nothing is ever written back to the Health store.
/// Values come out in the metric's canonical unit (seconds for duration
/// sources, whole counts otherwise), rounded to whole numbers so the mirror
/// can compare fetched and stored values exactly.
struct HealthKitMetricReader {
    let store: HKHealthStore

    /// The read-only types `source` needs. Requested the first time the user
    /// saves a metric for that source — never up front, and never broader
    /// than the one figure the metric mirrors.
    static func readTypes(for source: HealthDataSource) -> Set<HKObjectType> {
        switch source {
        case .activeCalories, .exerciseMinutes, .standMinutes:
            Set([quantityType(for: source)].compactMap { $0 })
        case .workoutCount, .workoutMinutes:
            [.workoutType()]
        }
    }

    func requestReadAccess(for source: HealthDataSource) async throws {
        try await store.requestAuthorization(
            toShare: [],
            read: Self.readTypes(for: source)
        )
    }

    /// Day-start → canonical total for every day in `window` holding data.
    /// Days HealthKit reports nothing for are simply absent.
    func dayTotals(
        for source: HealthDataSource,
        window: [Date],
        calendar: Calendar = .current
    ) async throws -> [Date: Double] {
        guard let interval = Self.interval(of: window, calendar: calendar)
        else { return [:] }
        switch source {
        case .activeCalories, .exerciseMinutes, .standMinutes:
            return try await quantityTotals(for: source, in: interval, calendar: calendar)
        case .workoutCount, .workoutMinutes:
            return try await workoutTotals(for: source, in: interval, calendar: calendar)
        }
    }
}

// MARK: - Quantity Sources

extension HealthKitMetricReader {
    private func quantityTotals(
        for source: HealthDataSource,
        in interval: DateInterval,
        calendar: Calendar
    ) async throws -> [Date: Double] {
        guard let quantityType = Self.quantityType(for: source) else { return [:] }
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(
                type: quantityType,
                predicate: HKQuery.predicateForSamples(
                    withStart: interval.start, end: interval.end
                )
            ),
            options: .cumulativeSum,
            anchorDate: interval.start,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: store)
        var totals: [Date: Double] = [:]
        collection.enumerateStatistics(from: interval.start, to: interval.end) { statistics, _ in
            guard let sum = statistics.sumQuantity() else { return }
            let value = sum.doubleValue(for: Self.sampleUnit(for: source))
            let day = calendar.startOfDay(for: statistics.startDate)
            totals[day] = Self.canonicalQuantity(value, for: source).rounded()
        }
        return totals
    }

    private static func quantityType(
        for source: HealthDataSource
    ) -> HKQuantityType? {
        switch source {
        case .activeCalories: HKQuantityType(.activeEnergyBurned)
        case .exerciseMinutes: HKQuantityType(.appleExerciseTime)
        case .standMinutes: HKQuantityType(.appleStandTime)
        case .workoutCount, .workoutMinutes: nil
        }
    }

    private static func sampleUnit(for source: HealthDataSource) -> HKUnit {
        source == .activeCalories ? .kilocalorie() : .minute()
    }

    /// Time-based quantities arrive in minutes but sessions store seconds,
    /// the unit every duration total in the app is computed in.
    private static func canonicalQuantity(
        _ value: Double,
        for source: HealthDataSource
    ) -> Double {
        source.measurementType == .duration ? value * 60 : value
    }
}

// MARK: - Workout Sources

extension HealthKitMetricReader {
    private func workoutTotals(
        for source: HealthDataSource,
        in interval: DateInterval,
        calendar: Calendar
    ) async throws -> [Date: Double] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [
                HKSamplePredicate.workout(
                    HKQuery.predicateForSamples(
                        withStart: interval.start, end: interval.end
                    )
                )
            ],
            sortDescriptors: []
        )
        let workouts = try await descriptor.result(for: store)
        var totals: [Date: Double] = [:]
        for workout in workouts {
            let day = calendar.startOfDay(for: workout.startDate)
            let amount = source == .workoutCount ? 1 : workout.duration
            totals[day, default: 0] += amount
        }
        return totals.mapValues { $0.rounded() }
    }
}

// MARK: - Window

extension HealthKitMetricReader {
    private static func interval(
        of window: [Date],
        calendar: Calendar
    ) -> DateInterval? {
        guard let first = window.first, let last = window.last,
              let end = calendar.date(byAdding: .day, value: 1, to: last)
        else { return nil }
        return DateInterval(start: first, end: end)
    }
}
