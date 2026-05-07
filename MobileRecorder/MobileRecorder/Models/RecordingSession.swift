import Foundation

struct RecordingSession: Identifiable {
    let id = UUID()
    let device: Device
    let folderURL: URL
    let startTime: Date
    var isRecording: Bool = true
    var package: String?

    // Internal state for managing the recording process
    var recordingProcess: RunningProcess?
    var logProcess: RunningProcess?
    var androidRemoteFile: String?
    var androidLocalFile: URL?
    var androidLogStartTime: String?

    var displayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "\(formatter.string(from: startTime)) (\(device.platform.displayName))"
    }

    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    var elapsedTimeFormatted: String {
        let elapsed = Int(elapsedTime)
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
