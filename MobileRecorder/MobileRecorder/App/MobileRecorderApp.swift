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
