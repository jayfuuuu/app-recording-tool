import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(DeviceDetectionService.self) private var deviceService
    @Environment(UserSettings.self) private var settings

    var body: some View {
        // Device list
        Section("Connected Devices") {
            if deviceService.devices.isEmpty {
                Text("No devices detected")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(deviceService.devices) { device in
                    Button {
                        appState.selectedDevice = device
                    } label: {
                        HStack {
                            if appState.selectedDevice == device {
                                Image(systemName: "checkmark")
                            }
                            Text(device.displayName)
                            if appState.isDeviceRecording(device) {
                                Text("REC")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
        }

        Divider()

        // Recording controls for selected device
        Section {
            if let device = appState.selectedDevice, appState.isDeviceRecording(device) {
                Button("Stop Recording (\(device.name))") {
                    Task { await appState.stopRecording(device: device) }
                }
                .keyboardShortcut("r")
            } else {
                Button("Start Recording") {
                    handleStartRecording()
                }
                .disabled(!appState.canRecord)
                .keyboardShortcut("r")
            }

            if appState.activeRecordings.count > 1 {
                Button("Stop All Recordings") {
                    Task { await appState.stopAllRecordings() }
                }
            }

            Button("Take Screenshot") {
                Task { await appState.takeScreenshot() }
            }
            .disabled(appState.selectedDevice == nil)
            .keyboardShortcut("s")

            Button("Live Log Viewer") {
                openLogViewer()
            }
            .disabled(appState.selectedDevice == nil)
            .keyboardShortcut("l")
        }

        // Active recordings
        if !appState.activeRecordings.isEmpty {
            Divider()
            Section("Active Recordings") {
                ForEach(Array(appState.activeRecordings.values), id: \.id) { session in
                    // Access timerTick to trigger updates
                    let _ = appState.timerTick
                    Button {
                        Task { await appState.stopRecording(device: session.device) }
                    } label: {
                        HStack {
                            Image(systemName: "record.circle.fill")
                                .foregroundStyle(.red)
                            Text("\(session.device.name) — \(session.elapsedTimeFormatted)")
                            Text("(click to stop)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }

        // Status
        if let status = appState.recordingStatus {
            Text(status)
                .foregroundStyle(.secondary)
        }

        Divider()

        // Recent sessions
        if !appState.recentSessions.isEmpty {
            Section("Recent Sessions") {
                ForEach(appState.recentSessions) { session in
                    Button(session.displayName) {
                        appState.openSessionFolder(session)
                    }
                }
            }

            Divider()
        }

        // Utilities
        Button("Open Output Folder") {
            appState.openOutputFolder()
        }
        .disabled(appState.selectedDevice == nil)

        Divider()

        // Tool availability
        Section {
            HStack {
                Circle()
                    .fill(deviceService.adbAvailable ? .green : .red)
                    .frame(width: 8, height: 8)
                Text("adb")
            }
            HStack {
                Circle()
                    .fill(deviceService.idbAvailable ? .green : .red)
                    .frame(width: 8, height: 8)
                Text("idb")
            }
        }

        Divider()

        Button("Preferences...") {
            openPreferences()
        }
        .keyboardShortcut(",")

        Button("Quit") {
            Task {
                await appState.cleanup()
                NSApplication.shared.terminate(nil)
            }
        }
        .keyboardShortcut("q")
    }

    // MARK: - Actions

    private func handleStartRecording() {
        guard let device = appState.selectedDevice else { return }
        if device.platform == .android {
            openPackageInput()
        } else {
            Task { await appState.startRecording() }
        }
    }

    private func openLogViewer() {
        guard let device = appState.selectedDevice else { return }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Log Viewer — \(device.displayName)"
        window.center()
        window.contentView = NSHostingView(rootView: LogViewerView(device: device))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openPackageInput() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Android Log Filter"
        window.center()
        window.contentView = NSHostingView(
            rootView: PackageInputView()
                .environment(settings)
                .environment(appState)
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openPreferences() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.center()
        window.contentView = NSHostingView(
            rootView: PreferencesView()
                .environment(settings)
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
