import SwiftUI

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(CompletionAlertSettings.soundKey, store: CompletionAlertSettings.store) private var timerSound = true
    @AppStorage(CompletionAlertSettings.hapticKey, store: CompletionAlertSettings.store) private var timerHaptic = true
    @AppStorage(MomentRediscoveryPreferences.enabledKey) private var momentRediscovery = false

    var body: some View {
        NavigationStack {
            List {
                timerCompletionSection
                rediscoverySection
                Section {
                    NavigationLink {
                        AppLockSettingsView()
                    } label: {
                        Label("Privacy & Security", systemImage: "lock")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var timerCompletionSection: some View {
        Section {
            Toggle("Sound", isOn: $timerSound)
            Toggle("Vibration", isOn: $timerHaptic)
        } header: {
            Text("Timer Completion")
        } footer: {
            Text("Plays a sound and vibrates when a countdown reaches zero.")
        }
    }

    private var rediscoverySection: some View {
        Section {
            Toggle("Rediscover older Moments", isOn: $momentRediscovery)
        } header: {
            Text("Moment Rediscovery")
        } footer: {
            Text("Off unless you choose it. Occasionally shows one older Moment from an active aspiration "
                + "relevant to the period you are reviewing, only inside the app. Uses your saved words and photos, "
                + "never generated text, notifications, or Watch. Choices are stored on this device. "
                + "Hide a suggestion or exclude a sensitive Moment without deleting it. "
                + "Explore this period remains available when rediscovery is off.")
        }
    }
}
