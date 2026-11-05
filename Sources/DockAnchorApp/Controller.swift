import AppKit
import ApplicationServices
import DockAnchorCore

final class Controller {
    private(set) var config: Config
    private(set) var displays: [Display] = []
    var onChange: (() -> Void)?

    private let store = ConfigStore()
    private let locker = DockLocker()
    private var screenChangeWork: DispatchWorkItem?
    private var pollTimer: Timer?
    private var screenAreas: [CGDirectDisplayID: ScreenArea] = [:]
    private var dockThickness: CGFloat = 0

    init() {
        config = (try? store.load()) ?? Config()
    }

    var setupKey: String { Displays.setupKey(displays) }
    var hasAccessibility: Bool { AXIsProcessTrusted() }

    var lockedDisplay: Display? {
        guard let lock = config.setups[setupKey] else { return nil }
        return displays.first { $0.uuid == lock.displayUUID }
    }

    func start() {
        displays = Displays.active()
        screenAreas = Displays.screenAreas()
        if !hasAccessibility {
            AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        }
        ensureTap()
        applyGuard()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.screensChanged() }

        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(forName: IPC.reloadConfig, object: nil, queue: .main) { [weak self] _ in
            self?.reloadConfig()
        }
        distributed.addObserver(forName: IPC.moveDock, object: nil, queue: .main) { [weak self] note in
            guard let self, let uuid = note.userInfo?[IPC.displayKey] as? String,
                  let display = self.displays.first(where: { $0.uuid == uuid }) else { return }
            self.moveDock(to: display)
        }

        // Accessibility can be granted while we run, and Dock orientation has no change notification.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            guard let self else { return }
            let wasRunning = self.locker.isRunning
            self.ensureTap()
            let orientation = DockOrientation.current()
            if orientation != self.locker.orientation || wasRunning != self.locker.isRunning {
                self.applyGuard()
            }
        }

        if config.enabled, let display = lockedDisplay { moveDock(to: display) }
        fitWindows(previous: screenAreas)
    }

    func setEnabled(_ enabled: Bool) {
        config.enabled = enabled
        save()
        if enabled, let display = lockedDisplay { moveDock(to: display) }
    }

    func lock(to display: Display) {
        config.setups[setupKey] = SetupLock(
            displayUUID: display.uuid,
            displayName: display.name,
            setupDisplayNames: displays.map(\.name)
        )
        config.enabled = true
        save()
        moveDock(to: display)
    }

    func unlock() {
        config.setups[setupKey] = nil
        save()
    }

    func lockToCursorDisplay() {
        if let display = Displays.display(at: Displays.cursorLocation(), in: displays) { lock(to: display) }
    }

    func lockToNextDisplay() {
        let current = lockedDisplay?.uuid ?? Displays.display(at: Displays.cursorLocation(), in: displays)?.uuid
        if let display = Displays.next(after: current, in: displays) { lock(to: display) }
    }

    func setAutoUpdate(_ enabled: Bool) {
        config.autoUpdate = enabled
        save()
    }

    func setResizeMaximizedWindows(_ enabled: Bool) {
        config.resizeMaximizedWindows = enabled
        save()
        if enabled { fitWindows(previous: screenAreas) }
    }

    func setHotkey(_ hotkey: Hotkey?, for action: HotkeyAction) {
        config.hotkeys[action.rawValue] = hotkey
        save()
    }

    func moveDock(to display: Display) {
        guard !locker.suspended else { return }
        locker.suspended = true
        DockMover.move(to: display.frame, orientation: DockOrientation.current()) { [weak self] moved in
            self?.locker.suspended = false
            if !moved { NSLog("DockAnchor: Dock did not move to \(display.name)") }
        }
    }

    private func ensureTap() {
        if !locker.isRunning && hasAccessibility { _ = locker.start() }
    }

    private func applyGuard() {
        locker.displayFrames = displays.map(\.frame)
        locker.orientation = DockOrientation.current()
        locker.allowedFrame = config.enabled ? lockedDisplay?.frame : nil
        onChange?()
    }

    private func save() {
        do { try store.save(config) } catch { NSLog("DockAnchor: failed to save config: \(error)") }
        applyGuard()
    }

    private func reloadConfig() {
        let before = (config.enabled, lockedDisplay?.uuid)
        guard let loaded = try? store.load() else { return }
        config = loaded
        applyGuard()
        let after = (config.enabled, lockedDisplay?.uuid)
        if config.enabled, let display = lockedDisplay, before != after { moveDock(to: display) }
    }

    private func fitWindows(previous: [CGDirectDisplayID: ScreenArea]) {
        let current = Displays.screenAreas()
        screenAreas = current
        let orientation = DockOrientation.current()
        // Remembered because the Dock may be mid-move (or hidden) when a pass runs; its size is the same on every display.
        if let measured = current.values.map({ $0.dockThickness(orientation) }).max(), measured > 4 {
            dockThickness = measured
        }
        guard config.resizeMaximizedWindows, hasAccessibility else { return }
        WindowAdjuster.fitMaximizedWindows(
            previous: previous, current: current, dockThickness: dockThickness, orientation: orientation
        )
    }

    // Fires in bursts while monitors wake, and also whenever the Dock moves or resizes (visible frames change).
    private func screensChanged() {
        screenChangeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let current = Displays.active()
            guard current != self.displays else {
                self.fitWindows(previous: self.screenAreas)
                return
            }
            self.displays = current
            self.applyGuard()
            if self.config.enabled, let display = self.lockedDisplay, !DockMover.isDock(on: display.frame) {
                self.moveDock(to: display)
            }
            // Give macOS time to migrate windows off a removed display before fitting them.
            let previous = self.screenAreas
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.fitWindows(previous: previous) }
        }
        screenChangeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }
}
