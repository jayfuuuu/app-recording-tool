import Foundation

enum Constants {
    static let devicePollingInterval: TimeInterval = 3.0
    static let androidRecordingSize = "480x800"

    static var outputBasePath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
    }

    static let timestampFormat = "yyyyMMdd_HHmmss"
    static let logTimestampFormat = "MM-dd HH:mm:ss.000"
}
