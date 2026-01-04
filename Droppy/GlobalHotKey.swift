
import Cocoa
import Carbon
import IOKit
import IOKit.hid

/// A robust Global Hotkey handler that attempts:
/// 1. Carbon (Standard, blocked by Secure Input)
/// 2. IOHIDManager (Low-level, bypasses Secure Input, requires Input Monitoring)
class GlobalHotKey {
    
    internal var callback: (() -> Void)?
    private let targetKeyCode: Int
    private let targetModifiers: UInt
    
    // Carbon
    internal var hotKeyID: EventHotKeyID
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private static var uniqueID: UInt32 = 1

    // IOHIDManager
    private var hidManager: IOHIDManager?
    private var modifierState: UInt = 0
    public var isInputMonitoringActive: Bool = false
    
    // Manual Modifier Tracking (Bypasses CGEventSource during Secure Input)
    private var pressedModifiers: Set<UInt32> = []
    
    // Mappings
    // Simple subset of HID Usage to VKCode for common keys
    private let hidToVK: [UInt32: Int] = [
        0x04: kVK_ANSI_A, 0x05: kVK_ANSI_B, 0x06: kVK_ANSI_C, 0x07: kVK_ANSI_D,
        0x08: kVK_ANSI_E, 0x09: kVK_ANSI_F, 0x0A: kVK_ANSI_G, 0x0B: kVK_ANSI_H,
        0x0C: kVK_ANSI_I, 0x0D: kVK_ANSI_J, 0x0E: kVK_ANSI_K, 0x0F: kVK_ANSI_L,
        0x10: kVK_ANSI_M, 0x11: kVK_ANSI_N, 0x12: kVK_ANSI_O, 0x13: kVK_ANSI_P,
        0x14: kVK_ANSI_Q, 0x15: kVK_ANSI_R, 0x16: kVK_ANSI_S, 0x17: kVK_ANSI_T,
        0x18: kVK_ANSI_U, 0x19: kVK_ANSI_V, 0x1A: kVK_ANSI_W, 0x1B: kVK_ANSI_X,
        0x1C: kVK_ANSI_Y, 0x1D: kVK_ANSI_Z,
        0x1E: kVK_ANSI_1, 0x1F: kVK_ANSI_2, 0x20: kVK_ANSI_3, 0x21: kVK_ANSI_4,
        0x22: kVK_ANSI_5, 0x23: kVK_ANSI_6, 0x24: kVK_ANSI_7, 0x25: kVK_ANSI_8,
        0x26: kVK_ANSI_9, 0x27: kVK_ANSI_0,
        0x28: kVK_Return, 0x29: kVK_Escape, 0x2A: kVK_Delete, 0x2B: kVK_Tab,
        0x2C: kVK_Space, 0x2D: kVK_ANSI_Minus, 0x2E: kVK_ANSI_Equal,
        0x2F: kVK_ANSI_LeftBracket, 0x30: kVK_ANSI_RightBracket, 0x31: kVK_ANSI_Backslash,
        0x33: kVK_ANSI_Semicolon, 0x34: kVK_ANSI_Quote, 0x35: kVK_ANSI_Grave,
        0x36: kVK_ANSI_Comma, 0x37: kVK_ANSI_Period, 0x38: kVK_ANSI_Slash
    ]

    init(keyCode: Int, modifiers: UInt, block: @escaping () -> Void) {
        self.callback = block
        self.targetKeyCode = keyCode
        self.targetModifiers = modifiers
        self.hotKeyID = EventHotKeyID(signature: 0x44525059, id: Self.uniqueID)
        Self.uniqueID += 1
        
        print("⌨️ GlobalHotKey: Init (Code: \(keyCode), Mods: \(modifiers))")
        
        // 1. Register Carbon
        registerCarbon(keyCode: keyCode, modifiers: modifiers)
        
        // 2. Setup IOHIDManager as backup
        setupIOHIDManager()
    }
    
    deinit {
        unregister()
    }
    
    // MARK: - Carbon
    
    private func registerCarbon(keyCode: Int, modifiers: UInt) {
        var carbonModifiers: UInt32 = 0
        if modifiers & NSEvent.ModifierFlags.command.rawValue != 0 { carbonModifiers |= UInt32(cmdKey) }
        if modifiers & NSEvent.ModifierFlags.option.rawValue != 0 { carbonModifiers |= UInt32(optionKey) }
        if modifiers & NSEvent.ModifierFlags.control.rawValue != 0 { carbonModifiers |= UInt32(controlKey) }
        if modifiers & NSEvent.ModifierFlags.shift.rawValue != 0 { carbonModifiers |= UInt32(shiftKey) }
        
        let status = RegisterEventHotKey(UInt32(keyCode),
                                         carbonModifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &hotKeyRef)
        if status == noErr {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            var handlerRef: EventHandlerRef?
            let selfPointer = Unmanaged.passUnretained(self).toOpaque()
            InstallEventHandler(GetApplicationEventTarget(), GlobalHotKeyHandler, 1, &spec, selfPointer, &handlerRef)
            eventHandler = handlerRef
            print("✅ GlobalHotKey: Carbon Registered")
        } else {
            print("❌ GlobalHotKey: Carbon Registration Failed (\(status))")
        }
    }
    
    // MARK: - IOHIDManager
    
    private func setupIOHIDManager() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        hidManager = manager
        
        // Create matching dictionary
        let deviceCriteria: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard
        ]
        
        IOHIDManagerSetDeviceMatching(manager, deviceCriteria as CFDictionary)
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, HandleIOHIDValueCallback, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        
        let openRet = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openRet == kIOReturnSuccess {
            print("✅ GlobalHotKey: IOHIDManager Monitoring Active")
            self.isInputMonitoringActive = true
        } else {
            print("⚠️ GlobalHotKey: IOHIDManager Setup Failed (Result: \(openRet))")
        }
    }
    
    internal func handleHIDEvent(value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let intValue = IOHIDValueGetIntegerValue(value)
        
        // Key down is 1, up is 0
        let isDown = (intValue != 0)
        
        // kHIDPage_KeyboardOrKeypad is usually 0x07
        guard usagePage == 0x07 else { return }
        
        // Handle Modifiers (0xE0 - 0xE7)
        if (usage >= 0xE0 && usage <= 0xE7) {
            if isDown {
                pressedModifiers.insert(usage)
            } else {
                pressedModifiers.remove(usage)
            }
            return
        }
        
        // Handle Normal Key Trigger
        if isDown {
            print("⌨️ GlobalHotKey DEBUG: KeyDown Usage: 0x\(String(format:"%02X", usage))")
            if let vk = hidToVK[usage] {
                // Check Match
                print("   -> VK: \(vk) | Target: \(targetKeyCode)")
                if vk == targetKeyCode {
                    if checkModifiers() {
                        print("   -> 🟢 TRIGGER MATCHED!")
                        DispatchQueue.main.async { self.callback?() }
                    } else {
                        print("   -> 🔴 Modifiers mismatch")
                    }
                }
            }
        }
    }
    
    private func checkModifiers() -> Bool {
        var cCmd = false
        var cOpt = false
        var cCtrl = false
        var cShift = false
        
        for usage in pressedModifiers {
            switch usage {
            case 0xE0, 0xE4: cCtrl = true
            case 0xE1, 0xE5: cShift = true
            case 0xE2, 0xE6: cOpt = true
            case 0xE3, 0xE7: cCmd = true
            default: break
            }
        }
        
        let target = NSEvent.ModifierFlags(rawValue: targetModifiers)
        let tCmd = target.contains(.command)
        let tOpt = target.contains(.option)
        let tCtrl = target.contains(.control)
        let tShift = target.contains(.shift)
        
        let match = cCmd == tCmd && cOpt == tOpt && cCtrl == tCtrl && cShift == tShift
        
        if !match {
            print("   -> Mods Current: [Cmd:\(cCmd) Opt:\(cOpt) Ctrl:\(cCtrl) Shift:\(cShift)]")
            print("   -> Mods Target:  [Cmd:\(tCmd) Opt:\(tOpt) Ctrl:\(tCtrl) Shift:\(tShift)]")
        }
        
        return match
    }

    private func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let handler = eventHandler { RemoveEventHandler(handler); eventHandler = nil }
        
        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            hidManager = nil
        }
    }
}

// C Callbacks

private func GlobalHotKeyHandler(handler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData = userData else { return OSStatus(eventNotHandledErr) }
    let instance = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
    
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
    
    if status == noErr && hotKeyID.signature == instance.hotKeyID.signature && hotKeyID.id == instance.hotKeyID.id {
        print("⌨️ GlobalHotKey: Trigger via Carbon")
        DispatchQueue.main.async { instance.callback?() }
        return noErr
    }
    return OSStatus(eventNotHandledErr)
}

private func HandleIOHIDValueCallback(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, value: IOHIDValue) {
    guard let context = context else { return }
    let instance = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
    instance.handleHIDEvent(value: value)
}
