import SwiftUI
import Carbon

struct SavedShortcut: Codable, Equatable {
    var keyCode: Int
    var modifiers: UInt
    
    var description: String {
        var str = ""
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.control) { str += "⌃" }
        if flags.contains(.option) { str += "⌥" }
        if flags.contains(.shift) { str += "⇧" }
        if flags.contains(.command) { str += "⌘" }
        
        // For modifier-only shortcuts, the flags already describe the combo.
        if KeyCodeHelper.isModifierKey(code: UInt16(keyCode)) {
            return str.isEmpty ? KeyCodeHelper.string(for: UInt16(keyCode)) : str
        }

        if keyCode == 49 { str += "Space" }
        else { str += KeyCodeHelper.string(for: UInt16(keyCode)) }
        return str
    }
    
    // MARK: - SwiftUI Keyboard Shortcut Support
    
    /// Returns the key equivalent for SwiftUI's .keyboardShortcut() modifier
    var keyEquivalent: KeyEquivalent? {
        let keyString = KeyCodeHelper.string(for: UInt16(keyCode)).lowercased()
        guard keyString.count == 1, let char = keyString.first else { return nil }
        return KeyEquivalent(char)
    }
    
    /// Returns the event modifiers for SwiftUI's .keyboardShortcut() modifier
    var eventModifiers: SwiftUI.EventModifiers {
        var result: SwiftUI.EventModifiers = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.control) { result.insert(.control) }
        return result
    }
}

struct KeyShortcutRecorder: View {
    @Binding var shortcut: SavedShortcut?
    var recordButtonTitle: String = "Record Shortcut"
    var recordingButtonTitle: String = "Press Keys..."
    var recordButtonColor: Color = .blue
    var recordButtonWidth: CGFloat = 120
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Shortcut display
            Text(shortcut?.description ?? "None")
                .font(.system(size: 12, weight: .medium))
                .frame(minWidth: 80, alignment: .center)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(AdaptiveColors.buttonBackgroundAuto)
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                        .stroke(isRecording ? Color.blue : AdaptiveColors.subtleBorderAuto, lineWidth: isRecording ? 2 : 1)
                )
            
            // Record button
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                Text(isRecording ? recordingButtonTitle : recordButtonTitle)
                    .lineLimit(1)
                    .frame(width: recordButtonWidth)
            }
            .buttonStyle(DroppyAccentButtonStyle(color: isRecording ? .red : recordButtonColor, size: .small))
        }
        .onDisappear {
            stopRecording() // Cleanup
        }
    }
    
    func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Ignore modifier keys pressed alone (including Caps Lock)
            // 54-55: Right/Left Command, 56: Left Shift, 57: Caps Lock
            // 58: Left Option, 59: Left Control, 60: Right Shift
            // 61: Right Option, 62: Right Control
            if event.keyCode == 54 || event.keyCode == 55 || event.keyCode == 56 || 
               event.keyCode == 57 || event.keyCode == 58 || event.keyCode == 59 || 
               event.keyCode == 60 || event.keyCode == 61 || event.keyCode == 62 {
                return nil
            }
            
            // Capture
            DispatchQueue.main.async {
                let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
                self.shortcut = SavedShortcut(keyCode: Int(event.keyCode), modifiers: flags.rawValue)
                self.stopRecording()
            }
            return nil // Swallow event
        }
    }
    
    func stopRecording() {
        isRecording = false
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}

struct KeyCodeHelper {
    static func isModifierKey(code: UInt16) -> Bool {
        [54, 55, 56, 58, 59, 60, 61, 62].contains(code)
    }

    static func string(for code: UInt16) -> String {
        switch code {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Esc"
        case 57: return "⇪" // Caps Lock
        case 54: return "R⌘"
        case 55: return "L⌘"
        case 56: return "L⇧"
        case 58: return "L⌥"
        case 59: return "L⌃"
        case 60: return "R⇧"
        case 61: return "R⌥"
        case 62: return "R⌃"
        // Arrow keys
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        // Function keys
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 105: return "F13"
        case 107: return "F14"
        case 109: return "F10"
        case 111: return "F12"
        case 113: return "F15"
        case 118: return "F4"
        case 120: return "F2"
        case 122: return "F1"
        // Navigation keys
        case 115: return "Home"
        case 116: return "PgUp"
        case 117: return "Del"
        case 119: return "End"
        case 121: return "PgDn"
        default:
            if let layoutString = layoutAwareString(for: code) {
                return layoutString
            }
            return "Key \(code)"
        }
    }

    /// Resolve key label using the active keyboard layout (AZERTY/QWERTZ/etc),
    /// so displayed shortcuts match what the user actually pressed.
    private static func layoutAwareString(for code: UInt16) -> String? {
        guard let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPointer = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let layoutData = unsafeBitCast(layoutDataPointer, to: CFData.self)
        guard let keyboardLayout = CFDataGetBytePtr(layoutData)?.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1, { $0 }) else {
            return nil
        }

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0

        let status = UCKeyTranslate(
            keyboardLayout,
            code,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )

        guard status == noErr, length > 0 else { return nil }

        let raw = String(utf16CodeUnits: chars, count: length)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        return raw.uppercased()
    }
}
