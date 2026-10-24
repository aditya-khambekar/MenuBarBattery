import XCTest
@testable import MenuBarBattery

@MainActor
final class StatusItemPositionStoreTests: XCTestCase {
    func testClearingPreferredPositionRestoresCachedValue() {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }

        defaults.set(142.0, forKey: store.preferredPositionKey)
        store.startProtecting()
        defaults.removeObject(forKey: store.preferredPositionKey)

        XCTAssertEqual(defaults.double(forKey: store.preferredPositionKey), 142.0)
    }

    func testNewPreferredPositionUpdatesCache() {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }

        defaults.set(142.0, forKey: store.preferredPositionKey)
        store.startProtecting()
        defaults.set(88.0, forKey: store.preferredPositionKey)
        defaults.removeObject(forKey: store.preferredPositionKey)

        XCTAssertEqual(defaults.double(forKey: store.preferredPositionKey), 88.0)
    }

    func testClearPersistedVisibilityRemovesOnlyVisibleKey() {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }

        defaults.set(false, forKey: store.visibilityKey)
        defaults.set(142.0, forKey: store.preferredPositionKey)
        store.clearPersistedVisibility()

        XCTAssertNil(defaults.object(forKey: store.visibilityKey))
        XCTAssertEqual(defaults.double(forKey: store.preferredPositionKey), 142.0)
    }

    private func makeStore() -> (StatusItemPositionStore, UserDefaults, String) {
        let name = "MenuBarBatteryPositionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let store = StatusItemPositionStore(defaults: defaults)
        return (store, defaults, name)
    }
}
