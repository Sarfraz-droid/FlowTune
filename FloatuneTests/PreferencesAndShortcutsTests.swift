import Carbon
import XCTest
@testable import Floatune

@MainActor
final class PreferencesAndShortcutsTests: XCTestCase {
    func testPreferencesPersist() {
        let name = "FloatuneTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        let settings = AppSettings(defaults: defaults)
        settings.alwaysOnTop = false
        settings.startsExpanded = true

        let restored = AppSettings(defaults: defaults)
        XCTAssertFalse(restored.alwaysOnTop)
        XCTAssertTrue(restored.startsExpanded)
    }

    func testShortcutCollisionIsRejected() {
        let name = "FloatuneTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let manager = GlobalShortcutManager(defaults: defaults)
        let shortcut = Shortcut(keyCode: 8, modifiers: UInt32(controlKey | optionKey))

        manager.set(shortcut, for: .shuffle)
        manager.set(shortcut, for: .repeatMode)

        XCTAssertEqual(manager.shortcut(for: .shuffle), shortcut)
        XCTAssertNil(manager.shortcut(for: .repeatMode))
        XCTAssertNotNil(manager.errors[.repeatMode])
    }
}

