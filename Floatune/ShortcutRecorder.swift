import AppKit
import Carbon
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
    let shortcut: Shortcut?
    let onChange: (Shortcut?) -> Void

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.onChange = onChange
        button.shortcut = shortcut
        return button
    }

    func updateNSView(_ nsView: RecorderButton, context: Context) {
        nsView.onChange = onChange
        nsView.shortcut = shortcut
    }
}

final class RecorderButton: NSButton {
    var onChange: ((Shortcut?) -> Void)?
    var shortcut: Shortcut? {
        didSet {
            guard isRecording == false else { return }
            title = shortcut?.displayString ?? "Record Shortcut"
        }
    }

    private var isRecording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
        focusRingType = .none
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    @objc private func beginRecording() {
        isRecording = true
        title = "Type Shortcut"
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 {
            finish()
            return
        }
        if event.keyCode == 51 || event.keyCode == 117 {
            onChange?(nil)
            finish()
            return
        }

        let modifiers = carbonModifiers(from: event.modifierFlags)
        guard modifiers != 0 else {
            NSSound.beep()
            return
        }
        onChange?(Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers))
        finish()
    }

    override func resignFirstResponder() -> Bool {
        finish()
        return super.resignFirstResponder()
    }

    private func finish() {
        isRecording = false
        title = shortcut?.displayString ?? "Record Shortcut"
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}

