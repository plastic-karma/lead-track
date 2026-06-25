import SwiftUI

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(CompletionAlertSettings.soundKey, store: CompletionAlertSettings.store) private var timerSound = true
    @AppStorage(CompletionAlertSettings.hapticKey, store: CompletionAlertSettings.store) private var timerHaptic = true

    var body: some View {
        NavigationStack {
            List {
                timerCompletionSection
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
}
