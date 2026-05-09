import Foundation

struct IOSService {
    private let runner: ProcessRunner
    private let idbPath: String
    private let output = OutputManager()

    init(runner: ProcessRunner, idbPath: String) {
        self.runner = runner
        self.idbPath = idbPath
    }

    // MARK: - Screen Recording

    /// Start screen recording. Returns the running process and local file path.
    /// Important: iOS recording must be stopped with SIGINT (not SIGTERM).
    func startRecording(device: Device, localFolder: URL) async throws -> (process: RunningProcess, localFile: URL) {
        let localFile = output.filePath(in: localFolder, type: .screenRecord)

        let process = try runner.runBackground(
            idbPath,
            arguments: ["record", "video", "--udid", device.id, localFile.path]
        )

        // idb needs startup time before recording is active
        try await Task.sleep(for: .seconds(3))

        return (process, localFile)
    }

    /// Stop recording: send SIGINT and wait for process to finalize the file
    func stopRecording(process: RunningProcess) async {
        process.interrupt() // SIGINT, not SIGTERM
        _ = await process.waitForExit()
    }

    // MARK: - Log Capture

    /// Start streaming logs as a background process
    func startLogCapture(device: Device, outputFile: URL) throws -> RunningProcess {
        return try runner.runBackground(
            idbPath,
            arguments: ["log", "--udid", device.id],
            outputFile: outputFile
        )
    }

    // MARK: - Screenshot

    func takeScreenshot(device: Device, localFolder: URL) async throws -> URL {
        let localFile = output.filePath(in: localFolder, type: .screenshot)

        _ = try await runner.run(idbPath, arguments: [
            "screenshot", "--udid", device.id, localFile.path
        ])

        return localFile
    }

    // MARK: - Cleanup

    /// Kill all idb processes (mirrors TearDown in Recorder.sh)
    func cleanup() async {
        _ = try? await runner.run(idbPath, arguments: ["kill"])
    }
}
