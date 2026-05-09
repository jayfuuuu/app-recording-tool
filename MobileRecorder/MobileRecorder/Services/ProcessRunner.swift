import Foundation

struct ProcessResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

final class RunningProcess: @unchecked Sendable {
    let process: Process

    init(process: Process) {
        self.process = process
    }

    var isRunning: Bool { process.isRunning }

    /// Send SIGTERM (use for Android screenrecord)
    func terminate() {
        guard process.isRunning else { return }
        process.terminate()
    }

    /// Send SIGINT (use for iOS idb record video)
    func interrupt() {
        guard process.isRunning else { return }
        process.interrupt()
    }

    /// Wait for the process to exit
    func waitForExit() async -> Int32 {
        let proc = process
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                proc.waitUntilExit()
                continuation.resume(returning: proc.terminationStatus)
            }
        }
    }
}

final class ProcessRunner: @unchecked Sendable {
    private let environment: [String: String]

    init() {
        self.environment = ToolLocator.processEnvironment()
    }

    /// Run a command and wait for completion, capturing output
    func run(_ executable: String, arguments: [String] = []) async throws -> ProcessResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.environment = environment

        try process.run()

        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                process.waitUntilExit()
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let result = ProcessResult(
                    exitCode: process.terminationStatus,
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? ""
                )
                continuation.resume(returning: result)
            }
        }
    }

    /// Start a background process (for recording, log streaming)
    func runBackground(_ executable: String, arguments: [String] = [], outputFile: URL? = nil) throws -> RunningProcess {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment

        if let outputFile {
            FileManager.default.createFile(atPath: outputFile.path, contents: nil)
            let fileHandle = try FileHandle(forWritingTo: outputFile)
            process.standardOutput = fileHandle
            process.standardError = FileHandle.nullDevice
        } else {
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
        }

        try process.run()
        return RunningProcess(process: process)
    }
}
