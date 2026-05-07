import Foundation
import AppKit

@Observable
class AppState {
    // MARK: - State
    var selectedDevice: Device?
    var recordingStatus: String?
    var recentSessions: [RecordingSession] = []

    /// Active recordings keyed by device ID — supports multi-device
    var activeRecordings: [String: RecordingSession] = [:]

    /// Timer tick counter to drive elapsed time updates in UI
    var timerTick: UInt = 0
    private var timerTask: Task<Void, Never>?

    // MARK: - Services
    private let runner = ProcessRunner()
    private let output = OutputManager()

    // MARK: - Computed

    var isRecording: Bool { !activeRecordings.isEmpty }

    var menuBarIcon: String {
        isRecording ? "record.circle.fill" : "record.circle"
    }

    /// Text shown next to the menubar icon (recording timer)
    var menuBarText: String? {
        guard let oldest = activeRecordings.values.min(by: { $0.startTime < $1.startTime }) else {
            return nil
        }
        // Access timerTick to trigger re-evaluation
        _ = timerTick
        return oldest.elapsedTimeFormatted
    }

    var canRecord: Bool {
        guard let device = selectedDevice else { return false }
        return activeRecordings[device.id] == nil
    }

    func isDeviceRecording(_ device: Device) -> Bool {
        activeRecordings[device.id] != nil
    }

    // MARK: - Recording Timer

    private func startTimer() {
        guard timerTask == nil else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run { [weak self] in
                    self?.timerTick &+= 1
                }
            }
        }
    }

    private func stopTimerIfNeeded() {
        if activeRecordings.isEmpty {
            timerTask?.cancel()
            timerTask = nil
        }
    }

    // MARK: - Recording

    func startRecording(device: Device? = nil, package: String? = nil) async {
        let target = device ?? selectedDevice
        guard let target else { return }
        guard activeRecordings[target.id] == nil else { return }

        do {
            let folder = try output.createSessionFolder(platform: target.platform)
            var session = RecordingSession(device: target, folderURL: folder, startTime: Date())
            session.package = package

            await MainActor.run { recordingStatus = "Starting..." }

            switch target.platform {
            case .android:
                guard let adbPath = ToolLocator.findAdb() else { return }
                let android = AndroidService(runner: runner, adbPath: adbPath)

                session.androidLogStartTime = Self.logTimestamp()

                let (process, remoteFile, localFile) = try android.startRecording(device: target, localFolder: folder)
                session.recordingProcess = process
                session.androidRemoteFile = remoteFile
                session.androidLocalFile = localFile

            case .ios:
                guard let idbPath = ToolLocator.findIdb() else { return }
                let ios = IOSService(runner: runner, idbPath: idbPath)

                let (process, _) = try await ios.startRecording(device: target, localFolder: folder)
                session.recordingProcess = process

                let logFile = output.filePath(in: folder, type: .log)
                session.logProcess = try ios.startLogCapture(device: target, outputFile: logFile)
            }

            let readySession = session
            await MainActor.run {
                activeRecordings[target.id] = readySession
                recordingStatus = "Recording \(target.displayName)..."
                startTimer()
            }

        } catch {
            await MainActor.run {
                recordingStatus = "Error: \(error.localizedDescription)"
            }
        }
    }

    func stopRecording(device: Device? = nil) async {
        let target = device ?? selectedDevice
        guard let target else { return }
        guard var session = activeRecordings[target.id] else { return }

        await MainActor.run { recordingStatus = "Stopping \(target.displayName)..." }

        switch target.platform {
        case .android:
            if let adbPath = ToolLocator.findAdb(),
               let process = session.recordingProcess,
               let remoteFile = session.androidRemoteFile,
               let localFile = session.androidLocalFile {
                let android = AndroidService(runner: runner, adbPath: adbPath)
                await android.stopRecording(process: process, remoteFile: remoteFile, localFile: localFile)

                let logFile = output.filePath(in: session.folderURL, type: .log)
                let logStart = session.androidLogStartTime ?? Self.logTimestamp()
                await android.captureLog(since: logStart, package: session.package, device: target, outputFile: logFile)
            }

        case .ios:
            if let process = session.recordingProcess,
               let idbPath = ToolLocator.findIdb() {
                let ios = IOSService(runner: runner, idbPath: idbPath)
                await ios.stopRecording(process: process)
            }
            session.logProcess?.terminate()
        }

        let platformName = target.platform.displayName

        session.isRecording = false
        session.recordingProcess = nil
        session.logProcess = nil
        let completed = session

        await MainActor.run {
            activeRecordings.removeValue(forKey: target.id)
            recordingStatus = nil
            recentSessions.insert(completed, at: 0)
            if recentSessions.count > 10 {
                recentSessions = Array(recentSessions.prefix(10))
            }
            stopTimerIfNeeded()
        }

        NotificationService.recordingStopped(platform: platformName)
    }

    func stopAllRecordings() async {
        let deviceIds = Array(activeRecordings.keys)
        for id in deviceIds {
            if let session = activeRecordings[id] {
                await stopRecording(device: session.device)
            }
        }
    }

    // MARK: - Screenshot

    func takeScreenshot(device: Device? = nil) async {
        let target = device ?? selectedDevice
        guard let target else { return }

        do {
            let folder: URL
            if let session = activeRecordings[target.id] {
                folder = session.folderURL
            } else {
                folder = try output.createSessionFolder(platform: target.platform)
            }

            switch target.platform {
            case .android:
                guard let adbPath = ToolLocator.findAdb() else { return }
                let android = AndroidService(runner: runner, adbPath: adbPath)
                _ = try await android.takeScreenshot(device: target, localFolder: folder)

            case .ios:
                guard let idbPath = ToolLocator.findIdb() else { return }
                let ios = IOSService(runner: runner, idbPath: idbPath)
                _ = try await ios.takeScreenshot(device: target, localFolder: folder)
            }

            NotificationService.screenshotTaken(platform: target.platform.displayName)
            await MainActor.run { recordingStatus = "Screenshot saved" }
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run { if recordingStatus == "Screenshot saved" { recordingStatus = nil } }

        } catch {
            await MainActor.run { recordingStatus = "Screenshot failed" }
        }
    }

    // MARK: - Folder

    func openSessionFolder(_ session: RecordingSession) {
        NSWorkspace.shared.open(session.folderURL)
    }

    func openOutputFolder() {
        guard let device = selectedDevice else { return }
        let url = Constants.outputBasePath
            .appendingPathComponent(device.platform.recorderFolderName)
        NSWorkspace.shared.open(url)
    }

    // MARK: - Cleanup

    func cleanup() async {
        for (_, session) in activeRecordings {
            session.recordingProcess?.terminate()
            session.logProcess?.terminate()
        }
        activeRecordings.removeAll()
        timerTask?.cancel()

        if let idbPath = ToolLocator.findIdb() {
            let ios = IOSService(runner: runner, idbPath: idbPath)
            await ios.cleanup()
        }
    }

    // MARK: - Helpers

    private static func logTimestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = Constants.logTimestampFormat
        return f.string(from: Date())
    }
}
