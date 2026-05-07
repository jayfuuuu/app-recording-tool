import Foundation

struct OutputManager {
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = Constants.timestampFormat
        return f
    }()

    /// Create a timestamped session folder: ~/Desktop/{AndroidRecorder|iOSRecorder}/{timestamp}/
    func createSessionFolder(platform: Platform) throws -> URL {
        let folderName = dateFormatter.string(from: Date())
        let url = Constants.outputBasePath
            .appendingPathComponent(platform.recorderFolderName)
            .appendingPathComponent(folderName)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Generate a file path within a session folder
    func filePath(in folder: URL, type: FileType) -> URL {
        let timestamp = dateFormatter.string(from: Date())
        return folder.appendingPathComponent("\(type.prefix)-\(timestamp).\(type.ext)")
    }

    enum FileType {
        case screenRecord
        case log
        case screenshot

        var prefix: String {
            switch self {
            case .screenRecord: "Screenrecord"
            case .log: "Log"
            case .screenshot: "Screenshot"
            }
        }

        var ext: String {
            switch self {
            case .screenRecord: "mp4"
            case .log: "log"
            case .screenshot: "png"
            }
        }
    }
}
