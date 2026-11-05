import Carbon
import DockAnchorCore

final class HotkeyCenter {
    private var refs: [EventHotKeyRef] = []
    private var handlers: [UInt32: () -> Void] = [:]
    private var handlerRef: EventHandlerRef?
    private var bindings: [(Hotkey, () -> Void)] = []

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &id
            )
            let center = Unmanaged<HotkeyCenter>.fromOpaque(userData).takeUnretainedValue()
            center.handlers[id.id]?()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }

    func register(_ bindings: [(Hotkey, () -> Void)]) {
        self.bindings = bindings
        activate()
    }

    /// Lets the shortcut recorder capture a combination that is currently bound.
    func pause() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs = []
        handlers = [:]
    }

    func activate() {
        pause()
        for (index, (hotkey, action)) in bindings.enumerated() {
            let id = EventHotKeyID(signature: 0x444B_4E43, id: UInt32(index + 1))
            var ref: EventHotKeyRef?
            guard RegisterEventHotKey(hotkey.keyCode, hotkey.modifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr,
                  let ref else { continue }
            refs.append(ref)
            handlers[id.id] = action
        }
    }
}
