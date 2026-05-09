import XCTest
@testable import MobileRecorder

final class OutputManagerTests: XCTestCase {
    let output = OutputManager()

    func testCreateSessionFolder_android() throws {
        let folder = try output.createSessionFolder(platform: .android)
        XCTAssertTrue(folder.path.contains("AndroidRecorder"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
        // Clean up
        try? FileManager.default.removeItem(at: folder)
    }

    func testCreateSessionFolder_ios() throws {
        let folder = try output.createSessionFolder(platform: .ios)
        XCTAssertTrue(folder.path.contains("iOSRecorder"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
        try? FileManager.default.removeItem(at: folder)
    }

    func testFilePath_screenRecord() throws {
        let folder = try output.createSessionFolder(platform: .android)
        let path = output.filePath(in: folder, type: .screenRecord)
        XCTAssertTrue(path.lastPathComponent.hasPrefix("Screenrecord-"))
        XCTAssertTrue(path.lastPathComponent.hasSuffix(".mp4"))
        try? FileManager.default.removeItem(at: folder)
    }

    func testFilePath_log() throws {
        let folder = try output.createSessionFolder(platform: .android)
        let path = output.filePath(in: folder, type: .log)
        XCTAssertTrue(path.lastPathComponent.hasPrefix("Log-"))
        XCTAssertTrue(path.lastPathComponent.hasSuffix(".log"))
        try? FileManager.default.removeItem(at: folder)
    }

    func testFilePath_screenshot() throws {
        let folder = try output.createSessionFolder(platform: .ios)
        let path = output.filePath(in: folder, type: .screenshot)
        XCTAssertTrue(path.lastPathComponent.hasPrefix("Screenshot-"))
        XCTAssertTrue(path.lastPathComponent.hasSuffix(".png"))
        try? FileManager.default.removeItem(at: folder)
    }
}
