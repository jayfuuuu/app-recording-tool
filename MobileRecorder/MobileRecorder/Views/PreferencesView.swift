import SwiftUI

struct PreferencesView: View {
    @Environment(UserSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Output") {
                HStack {
                    TextField("Output Path", text: $settings.outputBasePath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            settings.outputBasePath = url.path
                        }
                    }
                }
            }

            Section("Recording") {
                TextField("Android Resolution", text: $settings.androidRecordingSize)
                    .textFieldStyle(.roundedBorder)
                Text("Format: WIDTHxHEIGHT (e.g. 480x800)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Device Detection") {
                HStack {
                    Text("Polling Interval")
                    Slider(value: $settings.pollingInterval, in: 1...10, step: 1)
                    Text("\(Int(settings.pollingInterval))s")
                        .monospacedDigit()
                        .frame(width: 30)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 280)
        .navigationTitle("Preferences")
    }
}
