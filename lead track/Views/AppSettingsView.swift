import SwiftUI

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                TimerCompletionSettingsSection()
                MomentRediscoverySettingsSection()
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
}

private struct TimerCompletionSettingsSection: View {
    @AppStorage(CompletionAlertSettings.soundKey, store: CompletionAlertSettings.store) private var sound = true
    @AppStorage(CompletionAlertSettings.hapticKey, store: CompletionAlertSettings.store) private var haptic = true

    var body: some View {
        Section {
            Toggle("Sound", isOn: $sound)
            Toggle("Vibration", isOn: $haptic)
        } header: {
            Text("Timer Completion")
        } footer: {
            Text("Plays a sound and vibrates when a countdown reaches zero.")
        }
    }
}

private struct MomentRediscoverySettingsSection: View {
    @AppStorage(MomentRediscoveryPreferences.enabledKey) private var enabled = false

    var body: some View {
        Section {
            Toggle("Rediscover older Moments", isOn: $enabled)
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
