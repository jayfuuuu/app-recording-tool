import Foundation

enum ToolLocator {
    /// Cached PATH from the user's login shell
    private static var resolvedPATH: String?

    /// Get the user's full shell PATH (GUI apps don't inherit it)
    static func shellPATH() -> String {
        if let cached = resolvedPATH { return cached }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "echo $PATH"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            resolvedPATH = path
            return path
        } catch {
            return "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
        }
    }

    /// Build environment dictionary with the user's PATH
    static func processEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = shellPATH()
        return env
    }

    /// Find a tool by name, searching the user's PATH
    static func find(_ toolName: String) -> String? {
        let paths = shellPATH().split(separator: ":").map(String.init)
        for dir in paths {
            let fullPath = (dir as NSString).appendingPathComponent(toolName)
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }
        return nil
    }

    static func findAdb() -> String? {
        // Check common known locations first
        let knownPaths = [
            "\(NSHomeDirectory())/Library/Android/sdk/platform-tools/adb",
            "/opt/homebrew/bin/adb",
            "/usr/local/bin/adb",
        ]
        for path in knownPaths {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return find("adb")
    }

    static func findIdb() -> String? {
        let knownPaths = [
            "/opt/homebrew/bin/idb",
            "/usr/local/bin/idb",
            "\(NSHomeDirectory())/.local/bin/idb",
        ]
        for path in knownPaths {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return find("idb")
    }
}
