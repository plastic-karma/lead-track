import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

/// Plain data copied out of SwiftData while its owning context is alive.
struct FavoriteMetricControlState {
    let stableID: String
    let name: String
    let icon: String
    let colorName: String?
    let action: FavoriteMetricControlAction
}

enum FavoriteMetricControlAction {
    case start
    case stop
    case logOne
    case markDone
    case clearDone
    case unavailable

    var label: String {
        switch self {
        case .start: "Start"
        case .stop: "Stop"
        case .logOne: "Log +1"
        case .markDone: "Mark Done"
        case .clearDone: "Clear Done"
        case .unavailable: "Unavailable"
        }
    }

    var hint: LocalizedStringResource {
        switch self {
        case .start: "Start Timer"
        case .stop: "Stop Timer"
        case .logOne: "Log One"
        case .markDone: "Mark Done"
        case .clearDone: "Clear Done"
        case .unavailable: "Unavailable"
        }
    }
}

/// Supplies the latest action label and identity for one configured metric.
/// The provider runs in the widget extension and reads the app-group store.
struct FavoriteMetricControlProvider: AppIntentControlValueProvider {
    func previewValue(
        configuration: SelectFavoriteMetricIntent
    ) -> FavoriteMetricControlState {
        sampleState
    }

    func currentValue(
        configuration: SelectFavoriteMetricIntent
    ) async throws -> FavoriteMetricControlState {
        guard let entity = configuration.metric,
              let id = UUID(uuidString: entity.id)
        else { return unconfiguredState }
        guard let container = SharedModelContainer.shared else {
            return unavailableState(for: entity)
        }
        let context = ModelContext(container)
        guard let metric = try Metric.find(stableID: id, in: context),
              metric.isControlEligible
        else { return unavailableState(for: entity) }
        return try withExtendedLifetime(context) {
            try state(for: metric, stableID: entity.id, in: context)
        }
    }
}

// MARK: - Provider states

extension FavoriteMetricControlProvider {
    private func state(
        for metric: Metric,
        stableID: String,
        in context: ModelContext
    ) throws -> FavoriteMetricControlState {
        try FavoriteMetricControlState(
            stableID: stableID,
            name: metric.name,
            icon: metric.displayIcon,
            colorName: metric.colorName,
            action: action(for: metric, in: context)
        )
    }

    private func action(
        for metric: Metric,
        in context: ModelContext
    ) throws -> FavoriteMetricControlAction {
        switch metric.measurementType {
        case .duration:
            return SessionService.storedRunningSession(for: metric, in: context) == nil
                ? .start : .stop
        case .count:
            return .logOne
        case .binary:
            return try SessionService.isBinaryDayDone(for: metric, in: context)
                ? .clearDone : .markDone
        }
    }

    private func unavailableState(
        for entity: FavoriteMetricEntity
    ) -> FavoriteMetricControlState {
        FavoriteMetricControlState(
            stableID: "",
            name: entity.name,
            icon: entity.icon,
            colorName: nil,
            action: .unavailable
        )
    }

    private var unconfiguredState: FavoriteMetricControlState {
        FavoriteMetricControlState(
            stableID: "",
            name: "Choose Metric",
            icon: "star",
            colorName: nil,
            action: .unavailable
        )
    }

    private var sampleState: FavoriteMetricControlState {
        FavoriteMetricControlState(
            stableID: "6B1E1D2A-0000-4000-8000-000000000001",
            name: "Reading",
            icon: "book",
            colorName: "sage",
            action: .start
        )
    }
}

/// One gallery item can be placed repeatedly, each instance configured to a
/// different favorite. Its button reflects the next action: start/stop a
/// timer, add one to a count, or mark/clear today's binary metric.
struct FavoriteMetricControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetKinds.favoriteMetricControl,
            provider: FavoriteMetricControlProvider()
        ) { state in
            ControlWidgetButton(
                state.name,
                action: MetricControlIntent(metricID: state.stableID)
            ) { _ in
                Label(state.action.label, systemImage: state.icon)
                    .controlWidgetActionHint(state.action.hint)
            }
            .tint(MetricColor.color(named: state.colorName))
        }
        .displayName("Metric Action")
        .description("Start or stop a timer, log +1, or mark a favorite metric done.")
        .promptsForUserConfiguration()
    }
}
