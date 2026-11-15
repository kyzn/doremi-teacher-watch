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

    // MARK: B2, docs/STATE_MACHINES.md §4: the instrument mapping survives Standard and A B C

    private let reD = NamingRelationship.instrument(reference: .d, soundsLike: .d)

    func testStandardAndBackRestoresInstrumentMapping() {
        let store = SettingsStore(defaults: defaults)
        store.settings.useInstrumentNaming()
        XCTAssertEqual(store.settings.naming.relationship, sazNaming.relationship, "first time: the saz example")
        store.settings.naming.relationship = reD
        store.settings.naming.relationship = .standard
        store.settings.useInstrumentNaming()
        XCTAssertEqual(store.settings.naming.relationship, reD)
    }

    func testLettersAndBackRestoresInstrumentMapping() {
        let store = SettingsStore(defaults: defaults)
        store.settings.naming.relationship = reD
        store.settings.naming.style = .letters
        XCTAssertEqual(store.settings.naming.relationship, .standard)
        store.settings.naming.style = .syllables
        store.settings.useInstrumentNaming()
        XCTAssertEqual(store.settings.naming.relationship, reD)
    }

    func testRememberedMappingSurvivesRelaunch() {
        let store = SettingsStore(defaults: defaults)
        store.settings.naming.relationship = reD
        store.settings.naming.relationship = .standard
        let reloaded = SettingsStore(defaults: defaults)
        reloaded.settings.useInstrumentNaming()
        XCTAssertEqual(reloaded.settings.naming.relationship, reD)
    }

    /// Settings saved by 1.0 have no `lastInstrument` key. They must still load, and an active
    /// mapping becomes the remembered one.
    func testDecodesSettingsSavedBefore11() throws {
        var old = PracticeSettings.default   // raw struct: nothing has filled lastInstrument
        old.noteSet = .twelve
        old.naming.relationship = reD
        let data = try JSONEncoder().encode(old)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNil(json["lastInstrument"], "nil is omitted, so this is the 1.0 shape")
        defaults.set(data, forKey: SettingsStore.defaultsKey)

        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.settings.noteSet, .twelve)
        XCTAssertEqual(store.settings.naming.relationship, reD)
        store.settings.naming.relationship = .standard
        store.settings.useInstrumentNaming()
        XCTAssertEqual(store.settings.naming.relationship, reD)
    }
}
