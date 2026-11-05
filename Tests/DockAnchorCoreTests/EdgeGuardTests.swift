import CoreGraphics
import XCTest
@testable import DockAnchorCore

final class EdgeGuardTests: XCTestCase {
    let laptop = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let external = CGRect(x: 1512, y: 0, width: 2560, height: 1440)

    func testClampsBottomEdgeOfDisallowedDisplay() {
        let p = EdgeGuard.clamp(CGPoint(x: 700, y: 981.5), displays: [laptop, external], allowed: external, orientation: .bottom)
        XCTAssertEqual(p, CGPoint(x: 700, y: 980))
    }

    func testLeavesAllowedDisplayAlone() {
        let p = EdgeGuard.clamp(CGPoint(x: 2000, y: 1439), displays: [laptop, external], allowed: external, orientation: .bottom)
        XCTAssertNil(p)
    }

    func testLeavesPointsAwayFromEdgeAlone() {
        let p = EdgeGuard.clamp(CGPoint(x: 700, y: 500), displays: [laptop, external], allowed: external, orientation: .bottom)
        XCTAssertNil(p)
    }

    func testDoesNotBlockCrossingIntoDisplayBelow() {
        let below = CGRect(x: 0, y: 982, width: 1512, height: 982)
        let p = EdgeGuard.clamp(CGPoint(x: 700, y: 981.5), displays: [laptop, external, below], allowed: external, orientation: .bottom)
        XCTAssertNil(p)
    }

    func testClampsLeftEdge() {
        let p = EdgeGuard.clamp(CGPoint(x: 0.5, y: 400), displays: [laptop, external], allowed: external, orientation: .left)
        XCTAssertEqual(p, CGPoint(x: 2, y: 400))
    }

    func testLeftEdgeBetweenDisplaysIsNotAnOuterEdge() {
        let p = EdgeGuard.clamp(CGPoint(x: 1512.5, y: 400), displays: [laptop, external], allowed: laptop, orientation: .left)
        XCTAssertNil(p)
    }

    func testClampsRightEdge() {
        let p = EdgeGuard.clamp(CGPoint(x: 4071.5, y: 400), displays: [laptop, external], allowed: laptop, orientation: .right)
        XCTAssertEqual(p, CGPoint(x: 4070, y: 400))
    }
}

final class DisplayResolveTests: XCTestCase {
    let displays = [
        Display(id: 1, uuid: "AAA", name: "Built-in Retina Display", frame: CGRect(x: 0, y: 0, width: 1512, height: 982), isMain: false),
        Display(id: 2, uuid: "BBB", name: "Odyssey G85SD", frame: CGRect(x: 1512, y: 0, width: 3440, height: 1440), isMain: true),
        Display(id: 3, uuid: "CCC", name: "PL2797Q", frame: CGRect(x: 4952, y: 0, width: 2560, height: 1440), isMain: false),
    ]

    func testResolvesByIndexNameUUIDAndKeywords() throws {
        XCTAssertEqual(try Displays.resolve("3", in: displays).uuid, "CCC")
        XCTAssertEqual(try Displays.resolve("#1", in: displays).uuid, "AAA")
        XCTAssertEqual(try Displays.resolve("odyssey", in: displays).uuid, "BBB")
        XCTAssertEqual(try Displays.resolve("ccc", in: displays).uuid, "CCC")
        XCTAssertEqual(try Displays.resolve("main", in: displays).uuid, "BBB")
        XCTAssertEqual(try Displays.resolve("cursor", in: displays, cursor: CGPoint(x: 100, y: 100)).uuid, "AAA")
        XCTAssertEqual(try Displays.resolve("next", in: displays, locked: "CCC").uuid, "AAA")
    }

    func testUnknownAndAmbiguousQueriesThrow() {
        XCTAssertThrowsError(try Displays.resolve("dell", in: displays))
        XCTAssertThrowsError(try Displays.resolve("d", in: displays)) { error in
            guard case DisplayQueryError.ambiguous = error else { return XCTFail("expected ambiguous, got \(error)") }
        }
    }

    func testSetupKeyIgnoresOrder() {
        XCTAssertEqual(Displays.setupKey(displays), Displays.setupKey(displays.reversed()))
    }

    func testConfigDecodesWithMissingKeys() throws {
        let config = try JSONDecoder().decode(Config.self, from: Data("{}".utf8))
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.hotkeys, Config.defaultHotkeys)
    }
}
