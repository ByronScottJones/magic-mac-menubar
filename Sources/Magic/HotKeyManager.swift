import Carbon.HIToolbox
import MagicCore

extension Notification.Name {
    /// Posted by the shortcut recorder so global hotkeys don't fire while a shortcut is being captured.
    static let hotKeyRecordingBegan = Notification.Name("MagicHotKeyRecordingBegan")
    static let hotKeyRecordingEnded = Notification.Name("MagicHotKeyRecordingEnded")
}

/// Registers system-wide hotkeys through Carbon. Unlike event taps or `NSEvent` global monitors,
/// this needs no Accessibility permission and delivers the event on the main thread immediately.
final class HotKeyManager {
    private struct Registration {
        let combo: HotKeyCombo
        let action: () -> Void
    }

    private static let signature: OSType = 0x4D41_4743  // 'MAGC'

    private var registrations: [UInt32: Registration] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 1
    private var handler: EventHandlerRef?
    private(set) var isSuspended = false

    init() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var id = EventHotKeyID()
                let status = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                guard status == noErr else { return status }
                Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue().fire(id.id)
                return noErr
            },
            1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    deinit {
        unregisterAll()
        if let handler { RemoveEventHandler(handler) }
    }

    /// Replaces all registrations. Returns the indices of combos the system refused (already taken).
    func replaceAll(with items: [(combo: HotKeyCombo, action: () -> Void)]) -> Set<Int> {
        unregisterAll()
        registrations.removeAll()
        var failed = Set<Int>()
        for (index, item) in items.enumerated() {
            let id = nextID
            nextID += 1
            registrations[id] = Registration(combo: item.combo, action: item.action)
            if !isSuspended, !register(id) { failed.insert(index) }
        }
        return failed
    }

    func setSuspended(_ suspended: Bool) {
        guard suspended != isSuspended else { return }
        isSuspended = suspended
        if suspended {
            unregisterAll()
        } else {
            for id in registrations.keys { _ = register(id) }
        }
    }

    private func register(_ id: UInt32) -> Bool {
        guard let registration = registrations[id] else { return false }
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            registration.combo.keyCode, registration.combo.modifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        refs[id] = ref
        return true
    }

    private func unregisterAll() {
        for ref in refs.values { UnregisterEventHotKey(ref) }
        refs.removeAll()
    }

    fileprivate func fire(_ id: UInt32) {
        registrations[id]?.action()
    }
}
