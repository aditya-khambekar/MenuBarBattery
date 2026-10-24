import AppKit
import ServiceManagement
import AirPodsBattery

@main
enum MenuBarBatteryMain {
    static func main() {
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.setActivationPolicy(.accessory)
            app.delegate = delegate
            app.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let monitor = AirPodsMonitor()
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var latest: AirPodsBattery?

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.onUpdate = { [weak self] battery in
            self?.apply(battery)
        }
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        removeStatusItem()
    }

    private func apply(_ battery: AirPodsBattery?) {
        latest = battery
        let summary = battery.map(String.init(describing:)) ?? "none"
        fputs("MenuBarBattery \(summary)\n", stderr)
        fflush(stderr)
        guard let battery, !StatusLayout.pieces(for: battery).isEmpty else {
            removeStatusItem()
            return
        }
        let item = ensureStatusItem()
        item.button?.image = BatteryLabel.image(for: battery)
        item.button?.imagePosition = .imageOnly
        item.button?.imageScaling = .scaleProportionallyDown
        if let label = StatusLayout.accessibilityDescription(for: battery) {
            item.button?.setAccessibilityLabel(label)
        }
        if let menu {
            fill(menu, with: battery)
        }
    }

    private func ensureStatusItem() -> NSStatusItem {
        if let statusItem { return statusItem }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        item.menu = menu
        self.menu = menu
        statusItem = item
        return item
    }

    private func removeStatusItem() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
        menu = nil
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let latest else { return }
        fill(menu, with: latest)
    }

    private func fill(_ menu: NSMenu, with battery: AirPodsBattery) {
        menu.removeAllItems()
        let name = NSMenuItem(title: battery.name, action: nil, keyEquivalent: "")
        name.isEnabled = false
        menu.addItem(name)
        menu.addItem(.separator())
        for line in StatusLayout.menuLines(for: battery) {
            let item = NSMenuItem(title: line.title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let launch = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launch.target = self
        launch.state = Self.launchAtLoginIsOn ? .on : .off
        launch.isEnabled = true
        menu.addItem(launch)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        quit.isEnabled = true
        menu.addItem(quit)
    }

    private static var launchAtLoginIsOn: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return true
        default:
            return false
        }
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if Self.launchAtLoginIsOn {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn’t change launch at login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        sender.state = Self.launchAtLoginIsOn ? .on : .off
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}
