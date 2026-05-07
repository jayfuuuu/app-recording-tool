import Foundation

/// Streams log output line-by-line from adb logcat or idb log
@Observable
class LogStreamService {
    var lines: [String] = []
    var isStreaming = false

    private var process: RunningProcess?
    private var readTask: Task<Void, Never>?
    private let runner = ProcessRunner()
    private let maxLines = 5000

    func startAndroidStream(device: Device) {
        guard let adbPath = ToolLocator.findAdb() else { return }
        start(executable: adbPath, arguments: ["logcat"])
    }

    func startIOSStream(device: Device) {
        guard let idbPath = ToolLocator.findIdb() else { return }
        start(executable: idbPath, arguments: ["log", "--udid", device.id])
    }

    private func start(executable: String, arguments: [String]) {
        stop()

        let proc = Process()
        let pipe = Pipe()

        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = arguments
        proc.environment = ToolLocator.processEnvironment()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
        } catch {
            return
        }

        process = RunningProcess(process: proc)
        isStreaming = true
        lines = []

        let fileHandle = pipe.fileHandleForReading
        let limit = maxLines

        readTask = Task { [weak self] in
            while !Task.isCancelled {
                let data = fileHandle.availableData
                guard !data.isEmpty else { break }

                if let text = String(data: data, encoding: .utf8) {
                    let newLines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        self.lines.append(contentsOf: newLines)
                        if self.lines.count > limit {
                            self.lines = Array(self.lines.suffix(limit))
                        }
                    }
                }
            }

            await MainActor.run { [weak self] in
                self?.isStreaming = false
            }
        }
    }

    func stop() {
        readTask?.cancel()
        readTask = nil
        process?.terminate()
        process = nil
        isStreaming = false
    }

    func clear() {
        lines = []
    }
}
