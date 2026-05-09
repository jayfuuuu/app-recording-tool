import Foundation

struct AndroidService {
    private let runner: ProcessRunner
    private let adbPath: String
    private let output = OutputManager()

    init(runner: ProcessRunner, adbPath: String) {
        self.runner = runner
        self.adbPath = adbPath
    }

    // MARK: - Screen Recording

    /// Start screen recording on device. Returns the running process and remote file path.
    func startRecording(device: Device, localFolder: URL) throws -> (process: RunningProcess, remoteFile: String, localFile: URL) {
        let localFile = output.filePath(in: localFolder, type: .screenRecord)
        let remoteFile = "/sdcard/\(localFile.lastPathComponent)"

        let process = try runner.runBackground(
            adbPath,
            arguments: ["shell", "screenrecord", "--size", Constants.androidRecordingSize, remoteFile]
        )
        return (process, remoteFile, localFile)
    }

    /// Stop recording: kill process, pull file from device, clean up remote
    func stopRecording(process: RunningProcess, remoteFile: String, localFile: URL) async {
        process.terminate()
        // Wait for the file to finalize on device
        try? await Task.sleep(for: .seconds(1))

        // Pull file to local
        _ = try? await runner.run(adbPath, arguments: [
            "pull", remoteFile, localFile.deletingLastPathComponent().path
        ])

        // Clean up remote file
        _ = try? await runner.run(adbPath, arguments: [
            "shell", "rm", "-f", remoteFile
        ])
    }

    // MARK: - Log Capture

    /// Capture logs since a given time. Blocks until complete.
    func captureLog(since logStartTime: String, package: String?, device: Device, outputFile: URL) async {
        var arguments = ["logcat", "-t", logStartTime]

        if let package, !package.isEmpty {
            // Try to get PID for package-specific filtering
            if let pidResult = try? await runner.run(adbPath, arguments: ["shell", "pidof", package]),
               !pidResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let pid = pidResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                arguments.append(contentsOf: ["--pid=\(pid)"])
            }
            // If pidof fails, capture all logs (same behavior as shell script)
        }

        if let result = try? await runner.run(adbPath, arguments: arguments) {
            try? result.stdout.write(to: outputFile, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Screenshot

    func takeScreenshot(device: Device, localFolder: URL) async throws -> URL {
        let localFile = output.filePath(in: localFolder, type: .screenshot)
        let remoteFile = "/sdcard/\(localFile.lastPathComponent)"

        _ = try await runner.run(adbPath, arguments: ["shell", "screencap", "-p", remoteFile])
        _ = try await runner.run(adbPath, arguments: ["pull", remoteFile, localFile.deletingLastPathComponent().path])
        _ = try await runner.run(adbPath, arguments: ["shell", "rm", "-f", remoteFile])

        return localFile
    }

    // MARK: - Utilities

    func getOSVersion(device: Device) async -> Int {
        guard let result = try? await runner.run(adbPath, arguments: ["shell", "getprop", "ro.build.version.release"]) else {
            return 0
        }
        let versionStr = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ".").first.map(String.init) ?? "0"
        return Int(versionStr) ?? 0
    }
}
