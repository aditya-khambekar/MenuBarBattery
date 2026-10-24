import AppKit
import ServiceManagement

/// Launch-at-login registration for this app bundle.
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            true
        default:
            false
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            if !isEnabled {
                try service.register()
            }
        } else if isEnabled {
            try service.unregister()
        }
    }
}

/// Settings window: launch at login, and the status-item appearance.
@MainActor
final class SettingsWindowController: NSWindowController {
    private let appearanceSettings: AppearanceSettings
    private let launchCheckbox = NSButton(checkboxWithTitle: "Launch at Login", target: nil, action: nil)
    private let percentPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let iconPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let filledCheckbox = NSButton(checkboxWithTitle: "Filled charging case", target: nil, action: nil)
    private var didPosition = false

    init(appearance: AppearanceSettings) {
        appearanceSettings = appearance
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = .moveToActiveSpace
        super.init(window: window)
        window.contentView = makeContentView()
        wireControls()
        loadControlState()
        sizeToFit()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    /// Brings the window forward. An accessory app has to activate before it can become key.
    func present() {
        launchCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
        guard let window else { return }
        if !didPosition {
            window.center()
            didPosition = true
        }
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        window.makeKeyAndOrderFront(nil)
    }

    private func makeContentView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let grid = NSGridView(views: [
            [fieldLabel("Percent size"), percentPopup],
            [fieldLabel("Icons"), iconPopup],
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowAlignment = .firstBaseline
        grid.columnSpacing = 12
        grid.rowSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading

        stack.addArrangedSubview(sectionHeader("General"))
        stack.addArrangedSubview(launchCheckbox)
        stack.setCustomSpacing(18, after: launchCheckbox)
        stack.addArrangedSubview(sectionHeader("Appearance"))
        stack.addArrangedSubview(grid)
        stack.addArrangedSubview(filledCheckbox)

        percentPopup.translatesAutoresizingMaskIntoConstraints = false
        percentPopup.widthAnchor.constraint(equalToConstant: 160).isActive = true
        iconPopup.widthAnchor.constraint(equalTo: percentPopup.widthAnchor).isActive = true

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            content.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: 40),
            content.heightAnchor.constraint(equalTo: stack.heightAnchor, constant: 38),
        ])
        return content
    }

    private func sectionHeader(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        return label
    }

    private func fieldLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: NSFont.systemFontSize)
        label.alignment = .right
        return label
    }

    private func wireControls() {
        fill(percentPopup, with: PercentSize.allCases.map { ($0.menuTitle, $0.rawValue) })
        percentPopup.target = self
        percentPopup.action = #selector(percentChanged(_:))

        fill(iconPopup, with: IconStyle.allCases.map { ($0.menuTitle, $0.rawValue) })
        iconPopup.target = self
        iconPopup.action = #selector(iconStyleChanged(_:))

        launchCheckbox.target = self
        launchCheckbox.action = #selector(launchChanged(_:))
        filledCheckbox.target = self
        filledCheckbox.action = #selector(filledChanged(_:))
    }

    private func fill(_ popup: NSPopUpButton, with items: [(title: String, raw: String)]) {
        popup.removeAllItems()
        for item in items {
            popup.addItem(withTitle: item.title)
            popup.lastItem?.representedObject = item.raw
        }
    }

    private func loadControlState() {
        launchCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
        select(percentPopup, raw: appearanceSettings.appearance.percentSize.rawValue)
        select(iconPopup, raw: appearanceSettings.appearance.iconStyle.rawValue)
        filledCheckbox.state = appearanceSettings.appearance.filledChargingCase ? .on : .off
    }

    private func select(_ popup: NSPopUpButton, raw: String) {
        if let item = popup.itemArray.first(where: { $0.representedObject as? String == raw }) {
            popup.select(item)
        }
    }

    private func sizeToFit() {
        guard let content = window?.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let size = content.fittingSize
        guard size.width > 1, size.height > 1 else { return }
        window?.setContentSize(size)
    }

    @objc private func launchChanged(_ sender: NSButton) {
        do {
            try LaunchAtLogin.setEnabled(sender.state == .on)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn’t change launch at login"
            alert.informativeText = error.localizedDescription
            if let window {
                alert.beginSheetModal(for: window)
            } else {
                alert.runModal()
            }
        }
        sender.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    @objc private func percentChanged(_ sender: NSPopUpButton) {
        guard let raw = sender.selectedItem?.representedObject as? String,
              let size = PercentSize(rawValue: raw) else { return }
        var next = appearanceSettings.appearance
        next.percentSize = size
        appearanceSettings.appearance = next
    }

    @objc private func iconStyleChanged(_ sender: NSPopUpButton) {
        guard let raw = sender.selectedItem?.representedObject as? String,
              let style = IconStyle(rawValue: raw) else { return }
        var next = appearanceSettings.appearance
        next.iconStyle = style
        appearanceSettings.appearance = next
    }

    @objc private func filledChanged(_ sender: NSButton) {
        var next = appearanceSettings.appearance
        next.filledChargingCase = sender.state == .on
        appearanceSettings.appearance = next
    }
}
