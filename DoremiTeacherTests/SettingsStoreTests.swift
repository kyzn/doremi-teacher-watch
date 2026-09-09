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
    }

    func testSurvivesRelaunch() {
        let store = SettingsStore(defaults: defaults)
        store.settings.naming = sazNaming
        store.settings.noteSet = .twelve
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.settings.naming, sazNaming)
        XCTAssertEqual(reloaded.settings.noteSet, .twelve)
    }

    func testLettersDropInstrumentNaming() {
        let store = SettingsStore(defaults: defaults)
        store.settings.naming = sazNaming
        XCTAssertEqual(store.settings.naming.relationship, sazNaming.relationship)
        store.settings.naming.style = .letters
        XCTAssertEqual(store.settings.naming.relationship, .standard)
        XCTAssertEqual(SettingsStore(defaults: defaults).settings.naming.relationship, .standard, "normalized value is what gets saved")
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
