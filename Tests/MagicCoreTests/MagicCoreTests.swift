import Carbon.HIToolbox
import XCTest

@testable import MagicCore

final class HotKeyComboTests: XCTestCase {
    func testDisplayStringOrdersModifiers() {
        let combo = HotKeyCombo(keyCode: 46, modifiers: UInt32(cmdKey | controlKey | optionKey | shiftKey))
        XCTAssertEqual(combo.displayString, "⌃⌥⇧⌘M")
    }

    func testShiftOnlyIsInvalid() {
        XCTAssertFalse(HotKeyCombo(keyCode: 46, modifiers: UInt32(shiftKey)).isValid)
        XCTAssertFalse(HotKeyCombo(keyCode: 46, modifiers: 0).isValid)
    }

    func testUnknownKeyIsInvalid() {
        XCTAssertFalse(HotKeyCombo(keyCode: 200, modifiers: UInt32(cmdKey)).isValid)
    }

    func testControlOptionIsValid() {
        XCTAssertTrue(HotKeyCombo(keyCode: 46, modifiers: UInt32(controlKey | optionKey)).isValid)
    }
}

final class AppConfigTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testMissingFileLoadsAsNil() throws {
        let store = ConfigStore(url: directory.appendingPathComponent("config.json"))
        XCTAssertNil(try store.load())
    }

    func testRoundTrip() throws {
        let store = ConfigStore(url: directory.appendingPathComponent("config.json"))
        let combo = HotKeyCombo(keyCode: 46, modifiers: UInt32(controlKey | optionKey))
        let config = AppConfig(clips: [Clip(name: "A", path: "/tmp/a.mp4", hotKey: combo)], scale: 3)
        try store.save(config)
        XCTAssertEqual(try store.load(), config)
    }

    func testCorruptFileThrowsAndCanBeQuarantined() throws {
        let url = directory.appendingPathComponent("config.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        let store = ConfigStore(url: url)
        XCTAssertThrowsError(try store.load())
        XCTAssertNotNil(store.quarantine())
        XCTAssertNil(try store.load())
    }

    func testNewerVersionIsRejected() throws {
        let url = directory.appendingPathComponent("config.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"version": 99, "clips": [], "scale": 2}"#.utf8).write(to: url)
        XCTAssertThrowsError(try ConfigStore(url: url).load())
    }

    func testScaleIsClamped() throws {
        XCTAssertEqual(AppConfig(scale: 100).scale, AppConfig.scaleRange.upperBound)
        XCTAssertEqual(AppConfig(scale: 0).scale, AppConfig.scaleRange.lowerBound)
        let url = directory.appendingPathComponent("config.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"version": 1, "clips": [], "scale": 50}"#.utf8).write(to: url)
        XCTAssertEqual(try ConfigStore(url: url).load()?.scale, AppConfig.scaleRange.upperBound)
    }

    func testDuplicateHotKeyDetection() {
        let combo = HotKeyCombo(keyCode: 46, modifiers: UInt32(controlKey | optionKey))
        let first = Clip(name: "A", path: "a", hotKey: combo)
        let second = Clip(name: "B", path: "b")
        let config = AppConfig(clips: [first, second])
        XCTAssertEqual(config.clip(using: combo, excluding: second.id)?.id, first.id)
        XCTAssertNil(config.clip(using: combo, excluding: first.id))
    }
}
