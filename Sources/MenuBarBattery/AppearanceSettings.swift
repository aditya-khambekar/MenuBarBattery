import Foundation

/// How large the percent sits next to each menu-bar glyph.
enum PercentSize: String, Equatable, Sendable, CaseIterable {
    /// `NSFont.smallSystemFontSize`, smaller than the 13pt symbol.
    case smaller
    /// The same point size as the glyph.
    case matchIcons

    var menuTitle: String {
        switch self {
        case .smaller: "Smaller"
        case .matchIcons: "Same as icons"
        }
    }
}

/// SF Symbol rendering used for the menu-bar glyphs.
enum IconStyle: String, Equatable, Sendable, CaseIterable {
    case hierarchical
    case monochrome

    var menuTitle: String {
        switch self {
        case .hierarchical: "Hierarchical"
        case .monochrome: "Monochrome"
        }
    }
}

/// Saved look of the status item. Defaults match the original drawing.
struct Appearance: Equatable, Sendable {
    var percentSize: PercentSize
    var iconStyle: IconStyle
    var filledChargingCase: Bool

    static let standard = Appearance(
        percentSize: .smaller,
        iconStyle: .hierarchical,
        filledChargingCase: true
    )
}

/// UserDefaults-backed appearance. Posts ``didChangeNotification`` after a change.
@MainActor
final class AppearanceSettings {
    static let didChangeNotification = Notification.Name("MenuBarBatteryAppearanceDidChange")

    private let defaults: UserDefaults

    private enum Key {
        static let percentSize = "appearance.percentSize"
        static let iconStyle = "appearance.iconStyle"
        static let filledChargingCase = "appearance.filledChargingCase"
    }

    var appearance: Appearance {
        didSet {
            guard appearance != oldValue else { return }
            defaults.set(appearance.percentSize.rawValue, forKey: Key.percentSize)
            defaults.set(appearance.iconStyle.rawValue, forKey: Key.iconStyle)
            defaults.set(appearance.filledChargingCase, forKey: Key.filledChargingCase)
            NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let percent = defaults.string(forKey: Key.percentSize).flatMap(PercentSize.init(rawValue:)) ?? .smaller
        let style = defaults.string(forKey: Key.iconStyle).flatMap(IconStyle.init(rawValue:)) ?? .hierarchical
        let filled = defaults.object(forKey: Key.filledChargingCase) as? Bool ?? true
        appearance = Appearance(percentSize: percent, iconStyle: style, filledChargingCase: filled)
    }
}
