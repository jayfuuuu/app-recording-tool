import Foundation

@Observable
class DeviceDetectionService {
    var devices: [Device] = []
    var adbAvailable = false
    var idbAvailable = false

    private var pollingTask: Task<Void, Never>?
    private let runner = ProcessRunner()

    /// Callback to sync device selection when device list changes
    var onDevicesChanged: (([Device]) -> Void)?

    func startPolling() {
        stopPolling()
        // Resolve tool availability once
        adbAvailable = ToolLocator.findAdb() != nil
        idbAvailable = ToolLocator.findIdb() != nil

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshDevices()
                try? await Task.sleep(for: .seconds(Constants.devicePollingInterval))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refreshDevices() async {
        var android: [Device] = []
        var ios: [Device] = []

        if adbAvailable, let adbPath = ToolLocator.findAdb() {
            android = await detectAndroid(adbPath: adbPath)
        }

        if idbAvailable, let idbPath = ToolLocator.findIdb() {
            ios = await detectIOS(idbPath: idbPath)
        }

        let detected = android + ios
        await MainActor.run {
            self.devices = detected
            onDevicesChanged?(detected)
        }
    }

    // MARK: - Android

    /// Parse `adb devices` output. Format:
    /// ```
    /// List of devices attached
    /// R5CR1234567\tdevice
    /// ```
    private func detectAndroid(adbPath: String) async -> [Device] {
        guard let result = try? await runner.run(adbPath, arguments: ["devices"]) else {
            return []
        }

        let deviceIds = result.stdout
            .split(separator: "\n")
            .dropFirst() // skip "List of devices attached"
            .compactMap { line -> String? in
                let parts = line.split(separator: "\t")
                guard parts.count >= 2, parts[1] == "device" else { return nil }
                return String(parts[0])
            }

        var devices: [Device] = []
        for id in deviceIds {
            let name = await getAndroidModelName(adbPath: adbPath, deviceId: id) ?? id
            devices.append(Device(id: id, name: name, platform: .android))
        }
        return devices
    }

    /// Query the device model name via `adb -s <id> shell getprop ro.product.model`
    private func getAndroidModelName(adbPath: String, deviceId: String) async -> String? {
        guard let result = try? await runner.run(
            adbPath,
            arguments: ["-s", deviceId, "shell", "getprop", "ro.product.model"]
        ) else { return nil }

        let name = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    // MARK: - iOS

    /// Parse `idb list-targets` output. Pipe-delimited fields, filter for "Booted"
    private func detectIOS(idbPath: String) async -> [Device] {
        guard let result = try? await runner.run(idbPath, arguments: ["list-targets"]) else {
            return []
        }

        return result.stdout
            .split(separator: "\n")
            .compactMap { line -> Device? in
                let raw = String(line)
                guard raw.lowercased().contains("booted") else { return nil }
                let fields = raw.split(separator: "|").map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
                guard fields.count >= 2 else { return nil }
                let name = fields[0]
                let id = fields[1]
                return Device(id: id, name: name, platform: .ios)
            }
    }
}
