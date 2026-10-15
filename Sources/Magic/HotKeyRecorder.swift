import AppKit
import Carbon.HIToolbox
import MagicCore
import SwiftUI

/// A button that captures the next modifier+key chord the user types.
/// Esc cancels, Delete clears the shortcut.
struct HotKeyRecorder: NSViewRepresentable {
    let combo: HotKeyCombo?
    let label: String
    let onChange: (HotKeyCombo?) -> Void

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        button.target = button
        button.action = #selector(RecorderButton.beginRecording)
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return button
    }

    func updateNSView(_ button: RecorderButton, context: Context) {
        button.combo = combo
        button.onChange = onChange
        button.setAccessibilityLabel(label)
    }
}

final class RecorderButton: NSButton {
    var combo: HotKeyCombo? { didSet { refreshTitle() } }
    var onChange: ((HotKeyCombo?) -> Void)?
    private var isRecording = false { didSet { refreshTitle() } }

    override var acceptsFirstResponder: Bool { true }

    @objc func beginRecording() {
        guard !isRecording, window?.makeFirstResponder(self) == true else { return }
        isRecording = true
        NotificationCenter.default.post(name: .hotKeyRecordingBegan, object: nil)
    }

    private func endRecording() {
        guard isRecording else { return }
        isRecording = false
        NotificationCenter.default.post(name: .hotKeyRecordingEnded, object: nil)
    }

    override func resignFirstResponder() -> Bool {
        endRecording()
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        if !capture(event) { super.keyDown(with: event) }
    }

    // Chords containing ⌘ arrive here instead of keyDown.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        capture(event) || super.performKeyEquivalent(with: event)
    }

    private func capture(_ event: NSEvent) -> Bool {
        guard isRecording, event.type == .keyDown else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.isEmpty {
            switch Int(event.keyCode) {
            case kVK_Escape:
                endRecording()
                return true
            case kVK_Delete, kVK_ForwardDelete:
                combo = nil
                onChange?(nil)
                endRecording()
                return true
            default: break
            }
        }
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        let candidate = HotKeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        guard candidate.isValid else {
            NSSound.beep()  // needs ⌘, ⌃ or ⌥ and a supported key
            return true
        }
        combo = candidate
        onChange?(candidate)
        endRecording()
        window?.makeFirstResponder(nil)
        return true
    }

    private func refreshTitle() {
        title = isRecording ? "Type shortcut…" : (combo?.displayString ?? "Record Shortcut")
    }
}
