import XCTest
@testable import MobileRecorder

final class ProcessRunnerTests: XCTestCase {
    let runner = ProcessRunner()

    func testRunEcho() async throws {
        let result = try await runner.run("/bin/echo", arguments: ["hello world"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "hello world")
    }

    func testRunExitCode() async throws {
        let result = try await runner.run("/usr/bin/false")
        XCTAssertNotEqual(result.exitCode, 0)
    }

    func testRunBackgroundAndTerminate() async throws {
        let process = try runner.runBackground("/bin/sleep", arguments: ["60"])
        XCTAssertTrue(process.isRunning)
        process.terminate()
        let exitCode = await process.waitForExit()
        XCTAssertFalse(process.isRunning)
        _ = exitCode
    }

    func testRunBackgroundAndInterrupt() async throws {
        let process = try runner.runBackground("/bin/sleep", arguments: ["60"])
        XCTAssertTrue(process.isRunning)
        process.interrupt()
        let _ = await process.waitForExit()
        XCTAssertFalse(process.isRunning)
    }
}
