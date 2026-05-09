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

            Section("Tools") {
                HStack {
                    Text("adb")
                    Text(settings.adbPath.isEmpty ? "Not configured" : settings.adbPath)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Browse...") {
                        browseForTool { path in settings.adbPath = path }
                    }
                    .controlSize(.small)
                }
                HStack {
                    Text("idb")
                    Text(settings.idbPath.isEmpty ? "Not configured" : settings.idbPath)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Browse...") {
                        browseForTool { path in settings.idbPath = path }
                    }
                    .controlSize(.small)
                }
                Button("Re-run Setup...") {
                    openSetup()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 380)
        .navigationTitle("Preferences")
    }

    private func browseForTool(onSelect: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the tool executable"
        panel.prompt = "Select"
        panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin")
        if panel.runModal() == .OK, let url = panel.url {
            onSelect(url.path)
        }
    }

    private func openSetup() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MobileRecorder Setup"
        window.center()
        window.contentView = NSHostingView(
            rootView: SetupView {
                window.close()
            }
            .environment(settings)
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
