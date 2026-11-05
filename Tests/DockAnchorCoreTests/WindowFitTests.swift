import CoreGraphics
import XCTest
@testable import DockAnchorCore

final class UpdateTests: XCTestCase {
    func testVersionComparison() {
        XCTAssertTrue(Updates.isNewer("0.2.0", than: "0.1.0"))
        XCTAssertTrue(Updates.isNewer("v1.10.0", than: "1.9.3"))
        XCTAssertTrue(Updates.isNewer("0.1.1", than: "0.1"))
        XCTAssertFalse(Updates.isNewer("0.1.0", than: "0.1.0"))
        XCTAssertFalse(Updates.isNewer("0.1.0", than: "0.2.0"))
    }

    func testManifestDecodes() throws {
        let json = #"{"version":"0.2.0","sha256":"abc","file":"DockAnchor.zip"}"#
        let manifest = try JSONDecoder().decode(UpdateManifest.self, from: Data(json.utf8))
        XCTAssertEqual(manifest, UpdateManifest(version: "0.2.0", sha256: "abc", file: "DockAnchor.zip"))
    }

    func testSwapScriptQuotesPathsAndRelaunchesOnEveryFailure() {
        let script = Updates.swapScript(UpdateSwapPlan(
            appPath: "/Applications/DockAnchor.app", pid: 42, zipPath: "/tmp/it's.zip",
            stagingDir: "/tmp/staging", backupPath: "/tmp/prev.app", logPath: "/tmp/log"
        ))
        XCTAssertTrue(script.contains("kill -0 42"))
        XCTAssertTrue(script.contains("'/tmp/it'\\''s.zip'"))
        let exits = script.components(separatedBy: "exit 1").count - 1
        let relaunches = script.components(separatedBy: "/usr/bin/open '/Applications/DockAnchor.app' || true").count - 1
        XCTAssertEqual(exits, 4)
        XCTAssertEqual(relaunches, exits)
    }
}

final class WindowFitTests: XCTestCase {
    let screen = CGRect(x: 0, y: 0, width: 3440, height: 1440)
    let withDock = CGRect(x: 0, y: 33, width: 3440, height: 1407 - 80)
    let withoutDock = CGRect(x: 0, y: 33, width: 3440, height: 1407)

    func testShrinksMaximizedWindowWhenDockArrives() {
        let fitted = WindowFit.retarget(withoutDock, references: [withoutDock], target: withDock)
        XCTAssertEqual(fitted, withDock)
    }

    func testGrowsMaximizedWindowWhenDockLeaves() {
        let fitted = WindowFit.retarget(withDock, references: [withDock], target: withoutDock)
        XCTAssertEqual(fitted, withoutDock)
    }

    func testKeepsGaps() {
        let gapped = withDock.insetBy(dx: 8, dy: 8)
        let fitted = WindowFit.retarget(gapped, references: [withDock], target: withoutDock)
        XCTAssertEqual(fitted, withoutDock.insetBy(dx: 8, dy: 8))
    }

    func testFitsWindowSpanningWholeDisplayAfterMigration() {
        let fitted = WindowFit.retarget(screen, references: [withDock, withoutDock, screen], target: withDock)
        XCTAssertEqual(fitted, withDock)
    }

    func testIgnoresRegularWindows() {
        let window = CGRect(x: 200, y: 200, width: 1200, height: 800)
        XCTAssertNil(WindowFit.retarget(window, references: [withDock, withoutDock, screen], target: withoutDock))
    }

    func testIgnoresHalfScreenWindows() {
        let left = CGRect(x: 0, y: 33, width: 1720, height: 1327)
        XCTAssertNil(WindowFit.retarget(left, references: [withDock, withoutDock, screen], target: withoutDock))
    }

    func testRecognizesDockSizedWindowWithoutHistory() {
        let dockless = ScreenArea(frame: screen, visible: withoutDock)
        let docked = ScreenArea(frame: screen, visible: withDock)
        XCTAssertEqual(docked.dockThickness(.bottom), 80)

        let reference = dockless.withDock(thickness: 80, orientation: .bottom)
        XCTAssertEqual(reference, withDock)
        let fitted = WindowFit.retarget(withDock, references: [dockless.withoutDock, screen, reference], target: dockless.visible)
        XCTAssertEqual(fitted, withoutDock)
    }

    func testKeepsTopWhenVisibleFrameIgnoresMenuBar() {
        let pl = CGRect(x: -2560, y: 0, width: 2560, height: 1440)
        let misreportedVisible = CGRect(x: -2560, y: 0, width: 2560, height: 1350)
        let dia = CGRect(x: -2560, y: 31, width: 2560, height: 1307)
        let area = ScreenArea(frame: pl, visible: misreportedVisible)
        let fitted = WindowFit.retarget(dia, references: [area.withoutDock, pl, area.withDock(thickness: 90, orientation: .bottom)], target: misreportedVisible)
        XCTAssertEqual(fitted, CGRect(x: -2560, y: 31, width: 2560, height: 1319))
    }

    func testNoChangeWhenAlreadyFitted() {
        XCTAssertNil(WindowFit.retarget(withDock, references: [withDock], target: withDock))
    }
}
