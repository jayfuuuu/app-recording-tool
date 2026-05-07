import Foundation

@Observable
class UserSettings {
    var outputBasePath: String {
        didSet { UserDefaults.standard.set(outputBasePath, forKey: "outputBasePath") }
    }
    var androidRecordingSize: String {
        didSet { UserDefaults.standard.set(androidRecordingSize, forKey: "androidRecordingSize") }
    }
    var pollingInterval: Double {
        didSet { UserDefaults.standard.set(pollingInterval, forKey: "pollingInterval") }
    }
    var lastAndroidPackage: String {
        didSet { UserDefaults.standard.set(lastAndroidPackage, forKey: "lastAndroidPackage") }
    }

    init() {
        let defaults = UserDefaults.standard
        self.outputBasePath = defaults.string(forKey: "outputBasePath")
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Desktop").path
        self.androidRecordingSize = defaults.string(forKey: "androidRecordingSize") ?? "480x800"
        self.pollingInterval = defaults.double(forKey: "pollingInterval").nonZero ?? 3.0
        self.lastAndroidPackage = defaults.string(forKey: "lastAndroidPackage") ?? ""
    }
}

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}
