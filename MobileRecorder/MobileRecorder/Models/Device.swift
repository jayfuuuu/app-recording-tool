import Foundation

struct Device: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let platform: Platform

    var displayName: String {
        "\(name) (\(platform.displayName))"
    }
}
