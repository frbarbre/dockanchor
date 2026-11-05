import AppKit
import DockAnchorCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let controller = Controller()
    private let hotkeys = HotkeyCenter()
    private var statusItem: NSStatusItem!
    private var settings: SettingsWindowController?
    private var registeredHotkeys: [String: Hotkey]?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        controller.onChange = { [weak self] in self?.refresh() }
        controller.start()
        refresh()
    }

    private func refresh() {
        let locked = controller.config.enabled && controller.lockedDisplay != nil
        let symbol = locked ? "dock.rectangle" : "rectangle.bottomhalf.inset.filled"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "DockAnchor")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.appearsDisabled = !controller.config.enabled

        if registeredHotkeys != controller.config.hotkeys {
            registeredHotkeys = controller.config.hotkeys
            registerHotkeys()
        }
    }

    private func registerHotkeys() {
        let bindings: [(Hotkey, () -> Void)] = HotkeyAction.allCases.compactMap { action in
            guard let hotkey = controller.config.hotkey(for: action) else { return nil }
            return (hotkey, { [weak self] in self?.perform(action) })
        }
        hotkeys.register(bindings)
    }

    private func perform(_ action: HotkeyAction) {
        switch action {
        case .toggleLock: controller.setEnabled(!controller.config.enabled)
        case .lockToCursorDisplay: controller.lockToCursorDisplay()
        case .lockToNextDisplay: controller.lockToNextDisplay()
        }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let displays = controller.displays
        let locked = controller.lockedDisplay

        let status: String
        if !controller.config.enabled {
            status = "Dock lock is off"
        } else if let locked {
            status = "Dock locked to \(locked.name)"
        } else {
            status = "No lock for this screen setup"
        }
        menu.addItem(NSMenuItem(title: status, action: nil, keyEquivalent: ""))

        if !controller.hasAccessibility {
            menu.addItem(item("Grant Accessibility Access…", #selector(openAccessibilitySettings)))
        }
        menu.addItem(.separator())

        let toggle = item("Enable Dock Lock", #selector(toggleEnabled))
        toggle.state = controller.config.enabled ? .on : .off
        menu.addItem(toggle)

        let lockMenu = NSMenu()
        for display in displays {
            let entry = item(display.name, #selector(lockToDisplay(_:)))
            entry.representedObject = display.uuid
            entry.image = DisplayThumbnail.image(displays: displays, highlight: display.id)
            entry.state = display.uuid == locked?.uuid ? .on : .off
            lockMenu.addItem(entry)
        }
        lockMenu.addItem(.separator())
        let unlock = item("Don't Lock on This Setup", #selector(unlockSetup))
        unlock.isEnabled = locked != nil
        lockMenu.addItem(unlock)
        menu.addItem(submenu("Lock Dock to Display", lockMenu))

        let resize = item("Resize Maximized Windows", #selector(toggleResizeWindows))
        resize.state = controller.config.resizeMaximizedWindows ? .on : .off
        menu.addItem(resize)

        menu.addItem(.separator())
        menu.addItem(item("Hotkeys…", #selector(openSettings), key: ","))
        let login = item("Launch at Login", #selector(toggleLaunchAtLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit DockAnchor", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func submenu(_ title: String, _ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private func display(for sender: NSMenuItem) -> Display? {
        guard let uuid = sender.representedObject as? String else { return nil }
        return controller.displays.first { $0.uuid == uuid }
    }

    @objc private func toggleEnabled() { controller.setEnabled(!controller.config.enabled) }
    @objc private func unlockSetup() { controller.unlock() }
    @objc private func toggleResizeWindows() {
        controller.setResizeMaximizedWindows(!controller.config.resizeMaximizedWindows)
    }

    @objc private func lockToDisplay(_ sender: NSMenuItem) {
        if let display = display(for: sender) { controller.lock(to: display) }
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    @objc private func openSettings() {
        if settings == nil {
            settings = SettingsWindowController(controller: controller, hotkeys: hotkeys)
        }
        settings?.show()
    }
}
