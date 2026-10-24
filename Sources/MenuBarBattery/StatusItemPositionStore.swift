import AppKit

/// Keeps AppKit from deleting the Command-drag slot when the extra is hidden or removed.
///
/// Setting `autosaveName`, `isVisible = false`, or `removeStatusItem` clears
/// `NSStatusItem Preferred Position <name>`. This store snapshots that value and
/// writes it back if AppKit deletes it. A later Command-drag writes a new number
/// and becomes the cached slot.
@MainActor
final class StatusItemPositionStore {
    static let autosaveName = "MenuBarBattery"

    let preferredPositionKey: String
    let visibilityKey: String

    private let defaults: UserDefaults
    private let autosaveName: String
    private var observer: PositionObserver?

    init(
        defaults: UserDefaults = .standard,
        autosaveName: String = StatusItemPositionStore.autosaveName
    ) {
        self.defaults = defaults
        self.autosaveName = autosaveName
        preferredPositionKey = "NSStatusItem Preferred Position \(autosaveName)"
        visibilityKey = "NSStatusItem Visible \(autosaveName)"
    }

    /// Start KVO before assigning `autosaveName` — that assignment also clears the key.
    func startProtecting() {
        guard observer == nil else { return }
        observer = PositionObserver(defaults: defaults, key: preferredPositionKey)
    }

    func apply(to item: NSStatusItem) {
        startProtecting()
        item.autosaveName = autosaveName
        item.isVisible = true
    }

    /// Programmatic hides must not persist as “the user dragged this extra off the bar.”
    func clearPersistedVisibility() {
        defaults.removeObject(forKey: visibilityKey)
    }
}

/// KVO lives on a nonisolated `NSObject` so `deinit` can drop the observer.
private final class PositionObserver: NSObject {
    private let defaults: UserDefaults
    private let key: String
    private var cachedPosition: Any?
    private var isRestoring = false

    init(defaults: UserDefaults, key: String) {
        self.defaults = defaults
        self.key = key
        cachedPosition = defaults.object(forKey: key)
        super.init()
        defaults.addObserver(self, forKeyPath: key, options: [.new], context: nil)
    }

    deinit {
        defaults.removeObserver(self, forKeyPath: key)
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard keyPath == key else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        guard !isRestoring else { return }
        let newValue = change?[.newKey]
        if newValue == nil || newValue is NSNull {
            guard let cachedPosition else { return }
            isRestoring = true
            defaults.set(cachedPosition, forKey: key)
            isRestoring = false
            return
        }
        cachedPosition = newValue
    }
}
