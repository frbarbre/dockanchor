import AppKit
import Carbon
import DockAnchorCore

final class SettingsWindowController: NSWindowController {
    private let controller: Controller
    private let hotkeys: HotkeyCenter

    init(controller: Controller, hotkeys: HotkeyCenter) {
        self.controller = controller
        self.hotkeys = hotkeys
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "DockAnchor Hotkeys"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildContent() {
        let grid = NSGridView()
        grid.rowSpacing = 12
        grid.columnSpacing = 12

        for action in HotkeyAction.allCases {
            let label = NSTextField(labelWithString: action.title + ":")
            label.alignment = .right
            let recorder = ShortcutRecorder(hotkey: controller.config.hotkey(for: action))
            recorder.onRecordingChanged = { [weak self] recording in
                recording ? self?.hotkeys.pause() : self?.hotkeys.activate()
            }
            recorder.onChange = { [weak self] hotkey in self?.controller.setHotkey(hotkey, for: action) }
            let clear = NSButton(title: "Clear", target: recorder, action: #selector(ShortcutRecorder.clear))
            clear.bezelStyle = .rounded
            grid.addRow(with: [label, recorder, clear])
        }
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).width = 140

        let hint = NSTextField(labelWithString: "Click a field and press a key combination with ⌘, ⌃ or ⌥. Esc cancels.")
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [grid, hint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        window?.contentView = stack
    }
}

final class ShortcutRecorder: NSButton {
    var onChange: ((Hotkey?) -> Void)?
    var onRecordingChanged: ((Bool) -> Void)?

    private var hotkey: Hotkey?
    private var monitor: Any?

    init(hotkey: Hotkey?) {
        self.hotkey = hotkey
        super.init(frame: .zero)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(startRecording)
        updateTitle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc func clear() {
        stopRecording()
        hotkey = nil
        updateTitle()
        onChange?(nil)
    }

    @objc private func startRecording() {
        guard monitor == nil else { return }
        title = "Type shortcut…"
        onRecordingChanged?(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.record(event)
            return nil
        }
    }

    private func record(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.intersection([.command, .control, .option]).isEmpty else {
            NSSound.beep()
            return
        }
        hotkey = Hotkey(
            keyCode: UInt32(event.keyCode),
            modifiers: Self.carbonModifiers(flags),
            label: Self.modifierSymbols(flags) + Self.keyName(event)
        )
        stopRecording()
        onChange?(hotkey)
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        let wasRecording = monitor != nil
        monitor = nil
        updateTitle()
        if wasRecording { onRecordingChanged?(false) }
    }

    private func updateTitle() {
        title = hotkey?.label ?? "Record Shortcut"
    }

    private static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    private static func modifierSymbols(_ flags: NSEvent.ModifierFlags) -> String {
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        return result
    }

    private static let specialKeys: [Int: String] = [
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private static func keyName(_ event: NSEvent) -> String {
        if let special = specialKeys[Int(event.keyCode)] { return special }
        return event.charactersIgnoringModifiers?.uppercased() ?? "#\(event.keyCode)"
    }
}
