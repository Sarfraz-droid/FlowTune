import AppKit
import Carbon
import Combine
import Foundation

enum ShortcutAction: String, CaseIterable, Codable, Identifiable {
    case toggleWindow
    case playPause
    case previous
    case next
    case shuffle
    case repeatMode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toggleWindow: "Show or hide player"
        case .playPause: "Play or pause"
        case .previous: "Previous track"
        case .next: "Next track"
        case .shuffle: "Toggle shuffle"
        case .repeatMode: "Toggle repeat"
        }
    }
}

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    var displayString: String {
        var value = ""
        if modifiers & UInt32(controlKey) != 0 { value += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { value += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { value += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { value += "⌘" }
        value += keyName
        return value
    }

    private var keyName: String {
        switch keyCode {
        case 49: return "Space"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 36: return "Return"
        case 53: return "Esc"
        default:
            guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
                  let dataPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
            else { return "Key \(keyCode)" }
            let data = unsafeBitCast(dataPointer, to: CFData.self)
            guard let layout = CFDataGetBytePtr(data) else { return "Key \(keyCode)" }

            var deadKeyState: UInt32 = 0
            var characters = [UniChar](repeating: 0, count: 4)
            var length = 0
            let status = layout.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { keyboardLayout in
                UCKeyTranslate(
                    keyboardLayout,
                    UInt16(keyCode),
                    UInt16(kUCKeyActionDisplay),
                    0,
                    UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysBit),
                    &deadKeyState,
                    characters.count,
                    &length,
                    &characters
                )
            }
            guard status == noErr, length > 0 else { return "Key \(keyCode)" }
            return String(utf16CodeUnits: characters, count: length).uppercased()
        }
    }
}

@MainActor
final class GlobalShortcutManager: ObservableObject {
    static let shared = GlobalShortcutManager()

    @Published private(set) var shortcuts: [ShortcutAction: Shortcut] = [:]
    @Published private(set) var errors: [ShortcutAction: String] = [:]
    var onAction: ((ShortcutAction) -> Void)?

    private let defaults: UserDefaults
    private var hotKeyRefs: [ShortcutAction: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private let signature: OSType = 0x464C544E // FLTN

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        installHandler()
    }

    func shortcut(for action: ShortcutAction) -> Shortcut? {
        shortcuts[action]
    }

    func set(_ shortcut: Shortcut?, for action: ShortcutAction) {
        if let shortcut,
           let conflict = shortcuts.first(where: { $0.key != action && $0.value == shortcut })?.key {
            errors[action] = "Already used by “\(conflict.title)”."
            return
        }

        errors[action] = nil
        if let shortcut {
            shortcuts[action] = shortcut
        } else {
            shortcuts.removeValue(forKey: action)
        }
        save()
        register(action)
    }

    func registerAll() {
        ShortcutAction.allCases.forEach(register)
    }

    private func register(_ action: ShortcutAction) {
        if let existing = hotKeyRefs.removeValue(forKey: action) {
            UnregisterEventHotKey(existing)
        }
        guard let shortcut = shortcuts[action] else { return }

        let id = UInt32(ShortcutAction.allCases.firstIndex(of: action)! + 1)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            EventHotKeyID(signature: signature, id: id),
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status == noErr, let hotKeyRef {
            hotKeyRefs[action] = hotKeyRef
            errors[action] = nil
        } else {
            errors[action] = "This shortcut is reserved by macOS or another app."
        }
    }

    private func installHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }
                let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in manager.handle(hotKeyID) }
                return noErr
            },
            1,
            &eventType,
            pointer,
            &eventHandler
        )
    }

    private func handle(_ id: EventHotKeyID) {
        guard id.signature == signature,
              id.id > 0,
              Int(id.id) <= ShortcutAction.allCases.count
        else { return }
        onAction?(ShortcutAction.allCases[Int(id.id) - 1])
    }

    private func load() {
        let defaultsByAction: [ShortcutAction: Shortcut] = [
            .toggleWindow: Shortcut(keyCode: 49, modifiers: UInt32(controlKey | optionKey)),
            .playPause: Shortcut(keyCode: 35, modifiers: UInt32(controlKey | optionKey)),
            .previous: Shortcut(keyCode: 123, modifiers: UInt32(controlKey | optionKey)),
            .next: Shortcut(keyCode: 124, modifiers: UInt32(controlKey | optionKey))
        ]

        for action in ShortcutAction.allCases {
            if let data = defaults.data(forKey: key(for: action)),
               let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) {
                shortcuts[action] = shortcut
            } else if let defaultShortcut = defaultsByAction[action] {
                shortcuts[action] = defaultShortcut
            }
        }
    }

    private func save() {
        for action in ShortcutAction.allCases {
            let key = key(for: action)
            if let shortcut = shortcuts[action], let data = try? JSONEncoder().encode(shortcut) {
                defaults.set(data, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }

    private func key(for action: ShortcutAction) -> String {
        "shortcut.\(action.rawValue)"
    }
}
