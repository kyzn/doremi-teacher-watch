import XCTest
@testable import Doremi_Teacher_Watch_App

@MainActor
final class SettingsStoreTests: XCTestCase {
    private let suiteName = "DoremiTeacherTests.settings"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDefaults() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.settings, .default)
        XCTAssertEqual(store.settings.naming.relationship, .standard)
        XCTAssertEqual(store.settings.noteSet, .seven)
        XCTAssertTrue(store.settings.referenceSoundOn)
        XCTAssertEqual(store.settings.referenceNatural, .c)
    }

    func testSurvivesRelaunch() {
        let store = SettingsStore(defaults: defaults)
        store.settings.naming = sazNaming
        store.settings.noteSet = .twelve
        store.settings.referenceSoundOn = false
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.settings.naming, sazNaming)
        XCTAssertEqual(reloaded.settings.noteSet, .twelve)
        XCTAssertFalse(reloaded.settings.referenceSoundOn)
        XCTAssertEqual(reloaded.settings.referenceNatural, .d)
    }

    func testCorruptOrNewerDataFallsBackToDefaults() {
        defaults.set(Data("nonsense".utf8), forKey: SettingsStore.defaultsKey)
        XCTAssertEqual(SettingsStore(defaults: defaults).settings, .default)
        var future = PracticeSettings.default
        future.schemaVersion = 99
        defaults.set(try! JSONEncoder().encode(future), forKey: SettingsStore.defaultsKey)
        XCTAssertEqual(SettingsStore(defaults: defaults).settings, .default)
    }
}
