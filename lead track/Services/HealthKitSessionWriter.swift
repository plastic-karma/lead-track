import Foundation
import HealthKit

/// Maps each `HealthExportTarget` to its HealthKit record and writes one
/// record per session interval. Strictly write-only — reading stays with
/// `HealthKitMetricReader`, and nothing broader than the one record type a
/// metric exports is ever requested.
struct HealthKitSessionWriter {
    let store: HKHealthStore

    /// The share-only types `target` needs. Requested the first time the
    /// user switches a metric's export to that target — never up front.
    static func shareTypes(for target: HealthExportTarget) -> Set<HKSampleType> {
        switch target {
        case .mindfulness: [HKCategoryType(.mindfulSession)]
        case .workout: [.workoutType()]
        }
    }

    func requestShareAccess(for target: HealthExportTarget) async throws {
        try await store.requestAuthorization(
            toShare: Self.shareTypes(for: target),
            read: []
        )
    }

    /// Unlike read access, HealthKit does reveal share denials — checking up
    /// front keeps a denied export loop from failing session by session.
    func isAuthorized(for target: HealthExportTarget) -> Bool {
        Self.shareTypes(for: target).allSatisfy {
            store.authorizationStatus(for: $0) == .sharingAuthorized
        }
    }

    /// Writes one Health record spanning `interval`.
    func write(_ interval: DateInterval, as target: HealthExportTarget) async throws {
        switch target {
        case .mindfulness: try await writeMindfulSession(interval)
        case .workout: try await writeWorkout(interval)
        }
    }
}

// MARK: - Records

extension HealthKitSessionWriter {
    private func writeMindfulSession(_ interval: DateInterval) async throws {
        let sample = HKCategorySample(
            type: HKCategoryType(.mindfulSession),
            value: HKCategoryValue.notApplicable.rawValue,
            start: interval.start,
            end: interval.end
        )
        try await store.save(sample)
    }

    /// Workouts go through `HKWorkoutBuilder` — the direct `HKWorkout`
    /// initializers are deprecated. `.other` keeps Health from guessing at
    /// an activity the metric doesn't describe.
    private func writeWorkout(_ interval: DateInterval) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        let builder = HKWorkoutBuilder(
            healthStore: store,
            configuration: configuration,
            device: .local()
        )
        try await builder.beginCollection(at: interval.start)
        try await builder.endCollection(at: interval.end)
        _ = try await builder.finishWorkout()
    }
}
