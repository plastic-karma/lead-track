import Foundation
import Observation
import SwiftData

extension SwiftDataVaultStore: VaultLocalStore {}

@MainActor
@Observable
final class ObsidianSyncService {
    static let shared = ObsidianSyncService()
    private(set) var configuration: VaultConfiguration?
    private(set) var isEnabled = false
    private(set) var isSyncing = false
    private(set) var lastSyncedAt: Date?
    private(set) var conflicts: [VaultConflict] = []
    private(set) var resolutions: [String: VaultResolution] = [:]
    private(set) var errorMessage: String?

    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var engine: VaultSyncEngine?
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private var debounce: Task<Void, Never>?
    @ObservationIgnored private var saveObserver: NSObjectProtocol?
    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var foregroundSyncPending = false
    private static let configurationKey = "obsidianVaultConfiguration"
    private static let enabledKey = "obsidianVaultEnabled"

    var unresolvedCount: Int {
        conflicts.filter { resolutions[$0.id]?.conflict != $0 }.count
    }

    func activate(context: ModelContext) {
        guard self.context == nil, !LaunchArguments.isUITest else { return }
        self.context = context
        do {
            if let data = UserDefaults.standard.data(forKey: Self.configurationKey) {
                configuration = try JSONDecoder().decode(VaultConfiguration.self, from: data)
            }
            isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
            if isEnabled { try restoreEngine() }
        } catch {
            errorMessage = error.localizedDescription
        }
        observeSaves()
    }

    func connect(configuration: VaultConfiguration, token: String) {
        guard !isSyncing else { return }
        do {
            let configuration = try configuration.validated()
            let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else { throw VaultError.invalid("Enter a GitHub repository access token.") }
            let engine = try makeEngine(configuration: configuration, token: token)
            try VaultCredentialStore.save(token)
            try UserDefaults.standard.set(JSONEncoder().encode(configuration), forKey: Self.configurationKey)
            UserDefaults.standard.set(true, forKey: Self.enabledKey)
            self.configuration = configuration
            self.engine = engine
            isEnabled = true
            conflicts = []
            resolutions = [:]
            syncNow()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() async {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: Self.enabledKey)
        debounce?.cancel()
        operation?.cancel()
        await operation?.value
        engine = nil
        conflicts = []
        resolutions = [:]
        do {
            try VaultCredentialStore.remove()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setActive(_ active: Bool) {
        isActive = active
        foregroundSyncPending = active && operation?.isCancelled == true
        if active {
            scheduleSync()
        } else {
            debounce?.cancel()
            operation?.cancel()
        }
    }

    func syncNow() {
        guard isEnabled, operation == nil else { return }
        debounce?.cancel()
        isSyncing = true
        errorMessage = nil
        operation = Task { await performSync() }
    }

    func choose(_ choice: VaultResolution.Choice, for conflict: VaultConflict) {
        guard !isSyncing, conflicts.contains(conflict) else { return }
        resolutions[conflict.id] = VaultResolution(conflict: conflict, choice: choice)
    }

    private func performSync() async {
        var needsSync = false
        defer {
            isSyncing = false
            operation = nil
            let resumeForeground = foregroundSyncPending
            foregroundSyncPending = false
            if needsSync || resumeForeground { scheduleSync() }
        }
        do {
            if engine == nil { try restoreEngine() }
            guard let engine else { throw VaultError.invalid("Reconnect GitHub to resume sync.") }
            let outcome = try await engine.synchronize(resolutions: resolutions)
            conflicts = outcome.conflicts
            lastSyncedAt = outcome.date ?? lastSyncedAt
            needsSync = outcome.needsSync
            var validResolutions: [String: VaultResolution] = [:]
            for conflict in conflicts {
                if let resolution = resolutions[conflict.id], resolution.conflict == conflict {
                    validResolutions[conflict.id] = resolution
                }
            }
            resolutions = validResolutions
        } catch is CancellationError {
            // The durable journal resumes an interrupted commit on the next sync.
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    private func restoreEngine() throws {
        guard let configuration, let token = try VaultCredentialStore.load() else {
            throw VaultError.invalid("Your records are available offline. Reconnect GitHub to resume sync.")
        }
        engine = try makeEngine(configuration: configuration, token: token)
        lastSyncedAt = try stateFile(for: configuration).load(destination: configuration.identity).lastSyncedAt
    }

    private func makeEngine(configuration: VaultConfiguration, token: String) throws -> VaultSyncEngine {
        guard let context else {
            throw VaultError.invalid("The persistent app store is unavailable. GitHub sync is disabled to protect it.")
        }
        let store = SwiftDataVaultStore(context: context) {
            SessionService.syncLiveActivity(in: context)
            let container = context.container
            Task.detached {
                await NotificationService.rescheduleAll(container: container)
            }
        }
        return try VaultSyncEngine(
            configuration: configuration,
            remote: GitHubVaultClient(configuration: configuration, token: token),
            store: store, persistence: stateFile(for: configuration)
        )
    }

    private func stateFile(for configuration: VaultConfiguration) -> VaultStateFile {
        VaultStateFile.forDestination(
            configuration.identity, in: URL.applicationSupportDirectory.appending(path: "ObsidianSync")
        )
    }

    private func observeSaves() {
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.scheduleSync() }
        }
    }

    private func scheduleSync() {
        guard isEnabled, isActive, !isSyncing, conflicts.isEmpty else { return }
        debounce?.cancel()
        debounce = Task {
            do {
                try await Task.sleep(for: .seconds(2))
                try Task.checkCancellation()
                syncNow()
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
