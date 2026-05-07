import Foundation

enum Platform: String, CaseIterable, Identifiable {
    case android
    case ios

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .android: "Android"
        case .ios: "iOS"
        }
    }

    var recorderFolderName: String {
        switch self {
        case .android: "AndroidRecorder"
        case .ios: "iOSRecorder"
        }
    }
}
