import SwiftUI

@main
struct MobileRecorderApp: App {
    @State private var appState = AppState()
    @State private var deviceService: DeviceDetectionService
    @State private var settings = UserSettings()
    private let hotkeyService = HotkeyService()

    init() {
        let service = DeviceDetectionService()
        service.startPolling()
        _deviceService = State(initialValue: service)

        NotificationService.requestPermission()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
                .environment(deviceService)
                .environment(settings)
                .onAppear {
                    registerHotkeys()
                    if !settings.setupCompleted {
                        showSetupWindow()
                    }
                }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: appState.menuBarIcon)
                if let time = appState.menuBarText {
                    Text(time)
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.menu)
    }

    private func showSetupWindow() {
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
                // Refresh device detection after setup
                deviceService.startPolling()
            }
            .environment(settings)
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func registerHotkeys() {
        hotkeyService.register(
            onToggleRecording: { [appState] in
                Task {
                    if appState.isRecording {
                        await appState.stopRecording()
                    } else {
                        await appState.startRecording()
                    }
                }
            },
            onScreenshot: { [appState] in
                Task { await appState.takeScreenshot() }
            }
        )
    }
}
