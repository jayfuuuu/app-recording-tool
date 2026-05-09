import Foundation

enum ToolStatus: Equatable {
    case checking
    case found(path: String)
    case notFound
    case installing
    case installed(path: String)
    case failed(error: String)

    var isFound: Bool {
        switch self {
        case .found, .installed: return true
        default: return false
        }
    }

    var path: String? {
        switch self {
        case .found(let p), .installed(let p): return p
        default: return nil
        }
    }

    var displayText: String {
        switch self {
        case .checking: return "Checking..."
        case .found(let p): return p
        case .notFound: return "Not installed"
        case .installing: return "Installing..."
        case .installed(let p): return p
        case .failed(let e): return "Failed: \(e)"
        }
    }
}

@Observable
final class SetupViewModel {
    var brewStatus: ToolStatus = .checking
    var adbStatus: ToolStatus = .checking
    var idbStatus: ToolStatus = .checking
    var installLog: String = ""
    var isInstalling: Bool = false

    private let runner = ProcessRunner()

    func checkAll() {
        brewStatus = ToolLocator.find("brew") != nil ? .found(path: ToolLocator.find("brew")!) : .notFound

        if let adbPath = ToolLocator.findAdb() {
            adbStatus = .found(path: adbPath)
        } else {
            adbStatus = .notFound
        }

        if let idbPath = ToolLocator.findIdb() {
            idbStatus = .found(path: idbPath)
        } else {
            idbStatus = .notFound
        }
    }

    func installAdb() async {
        guard !isInstalling else { return }
        isInstalling = true
        adbStatus = .installing
        installLog += "=== Installing adb ===\n"

        do {
            let result = try await runShell("brew install --cask android-platform-tools")
            installLog += result.stdout
            if !result.stderr.isEmpty { installLog += result.stderr }

            if result.exitCode == 0, let path = ToolLocator.findAdb() {
                adbStatus = .installed(path: path)
                installLog += "\n✓ adb installed successfully at \(path)\n"
            } else {
                adbStatus = .failed(error: "Exit code \(result.exitCode)")
                installLog += "\n✗ adb installation failed\n"
            }
        } catch {
            adbStatus = .failed(error: error.localizedDescription)
            installLog += "\n✗ Error: \(error.localizedDescription)\n"
        }

        isInstalling = false
    }

    func installIdb() async {
        guard !isInstalling else { return }
        isInstalling = true
        idbStatus = .installing
        installLog += "=== Installing idb ===\n"

        do {
            // Step 1: brew tap + install idb-companion
            installLog += "→ brew tap facebook/fb\n"
            let tap = try await runShell("brew tap facebook/fb")
            installLog += tap.stdout + tap.stderr

            installLog += "→ brew install idb-companion\n"
            let companion = try await runShell("brew install idb-companion")
            installLog += companion.stdout + companion.stderr

            // Step 2: pip install fb-idb
            installLog += "→ pip3 install fb-idb\n"
            let pip = try await runShell("pip3 install fb-idb")
            installLog += pip.stdout + pip.stderr

            if let path = ToolLocator.findIdb() {
                idbStatus = .installed(path: path)
                installLog += "\n✓ idb installed successfully at \(path)\n"
            } else {
                idbStatus = .failed(error: "idb not found after installation")
                installLog += "\n✗ idb not found in PATH after installation\n"
            }
        } catch {
            idbStatus = .failed(error: error.localizedDescription)
            installLog += "\n✗ Error: \(error.localizedDescription)\n"
        }

        isInstalling = false
    }

    func setAdbPath(_ path: String) {
        if FileManager.default.isExecutableFile(atPath: path) {
            adbStatus = .found(path: path)
        } else {
            adbStatus = .failed(error: "Not executable: \(path)")
        }
    }

    func setIdbPath(_ path: String) {
        if FileManager.default.isExecutableFile(atPath: path) {
            idbStatus = .found(path: path)
        } else {
            idbStatus = .failed(error: "Not executable: \(path)")
        }
    }

    func saveSettings(_ settings: UserSettings) {
        if let path = adbStatus.path {
            settings.adbPath = path
        }
        if let path = idbStatus.path {
            settings.idbPath = path
        }
        settings.setupCompleted = true
    }

    private func runShell(_ command: String) async throws -> ProcessResult {
        try await runner.run("/bin/zsh", arguments: ["-l", "-c", command])
    }
}
