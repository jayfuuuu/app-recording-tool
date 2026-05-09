import Foundation

enum ToolLocator {
    /// Cached PATH from the user's login shell
    private static var resolvedPATH: String?
    /// Cached environment variables from shell config files
    private static var resolvedShellEnv: [String: String]?

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

    /// Parse shell config files (.zshrc, .zprofile, .bash_profile, .bashrc) for exported variables
    private static func shellEnv() -> [String: String] {
        if let cached = resolvedShellEnv { return cached }

        // Use login shell to resolve all env vars at once
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "env"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        var env: [String: String] = [:]

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                for line in output.split(separator: "\n") {
                    if let eqIndex = line.firstIndex(of: "=") {
                        let key = String(line[line.startIndex..<eqIndex])
                        let value = String(line[line.index(after: eqIndex)...])
                        env[key] = value
                    }
                }
            }
        } catch {}

        // Also parse config files directly for variables that may not be exported
        let home = NSHomeDirectory()
        let configFiles = [
            "\(home)/.zshrc",
            "\(home)/.zprofile",
            "\(home)/.zshenv",
            "\(home)/.bash_profile",
            "\(home)/.bashrc",
        ]

        let pattern = #/^\s*export\s+(\w+)\s*=\s*["']?([^"'\s#]+)["']?/#
        for file in configFiles {
            guard let content = try? String(contentsOfFile: file, encoding: .utf8) else { continue }
            for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
                if let match = String(line).firstMatch(of: pattern) {
                    let key = String(match.1)
                    var value = String(match.2)
                    // Resolve $HOME references
                    value = value.replacingOccurrences(of: "$HOME", with: home)
                    value = value.replacingOccurrences(of: "${HOME}", with: home)
                    value = value.replacingOccurrences(of: "~", with: home)
                    if env[key] == nil {
                        env[key] = value
                    }
                }
            }
        }

        resolvedShellEnv = env
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
        // 1. Check user-saved path first
        if let saved = UserDefaults.standard.string(forKey: "adbPath"),
           !saved.isEmpty,
           FileManager.default.isExecutableFile(atPath: saved) {
            return saved
        }

        let home = NSHomeDirectory()
        let env = shellEnv()

        // 2. Check ANDROID_HOME / ANDROID_SDK_ROOT environment variables
        let androidDirs = [
            env["ANDROID_HOME"],
            env["ANDROID_SDK_ROOT"],
            env["ANDROID_SDK"],
        ].compactMap { $0 }

        for dir in androidDirs {
            let path = (dir as NSString).appendingPathComponent("platform-tools/adb")
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }

        // 3. Check common known locations
        let knownPaths = [
            "\(home)/Library/Android/sdk/platform-tools/adb",
            "/opt/homebrew/bin/adb",
            "/usr/local/bin/adb",
            "\(home)/Android/Sdk/platform-tools/adb",                 // Linux-style
            "/Applications/Android Studio.app/Contents/jbr/bin/../../../platform-tools/adb",
            "\(home)/Library/Developer/Xamarin/android-sdk-macosx/platform-tools/adb",
        ]
        for path in knownPaths {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }

        // 4. Scan PATH
        return find("adb")
    }

    static func findIdb() -> String? {
        // 1. Check user-saved path first
        if let saved = UserDefaults.standard.string(forKey: "idbPath"),
           !saved.isEmpty,
           FileManager.default.isExecutableFile(atPath: saved) {
            return saved
        }

        let home = NSHomeDirectory()

        // 2. Check common known locations
        let knownPaths = [
            "/opt/homebrew/bin/idb",
            "/usr/local/bin/idb",
            "\(home)/.local/bin/idb",
            "\(home)/Library/Python/3.9/bin/idb",
            "\(home)/Library/Python/3.10/bin/idb",
            "\(home)/Library/Python/3.11/bin/idb",
            "\(home)/Library/Python/3.12/bin/idb",
            "\(home)/Library/Python/3.13/bin/idb",
        ]
        for path in knownPaths {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }

        // 3. Scan PATH
        return find("idb")
    }
}
