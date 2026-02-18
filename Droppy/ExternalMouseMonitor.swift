import Foundation
import IOKit.hid
import Combine
import SwiftUI

final class ExternalMouseMonitor: ObservableObject {
    static let shared = ExternalMouseMonitor()

    @Published private(set) var hasExternalMouse = false

    private let queue = DispatchQueue(label: "com.droppy.external-mouse-monitor", qos: .utility)
    private var pollTimer: DispatchSourceTimer?

    /// Once IOHIDManagerOpen fails (TCC deny), stop trying to avoid log spam and lag.
    private var hidAccessDenied = false

    private init() {
        startPolling()
    }

    private func startPolling() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .seconds(5), leeway: .seconds(1))
        timer.setEventHandler { [weak self] in
            self?.refreshState()
        }
        pollTimer = timer
        timer.resume()
    }

    private func refreshState() {
        let hasMouse = detectExternalMouse()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.hasExternalMouse != hasMouse {
                self.hasExternalMouse = hasMouse
            }
        }
    }

    private func detectExternalMouse() -> Bool {
        // If a previous attempt was denied by TCC, don't keep retrying.
        // Each IOHIDManagerOpen failure logs "TCC deny IOHIDDeviceOpen" and stalls the app.
        guard !hidAccessDenied else { return false }

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        let mouseMatch: [String: Int] = [
            kIOHIDDeviceUsagePageKey: Int(kHIDPage_GenericDesktop),
            kIOHIDDeviceUsageKey: Int(kHIDUsage_GD_Mouse)
        ]

        let pointerMatch: [String: Int] = [
            kIOHIDDeviceUsagePageKey: Int(kHIDPage_GenericDesktop),
            kIOHIDDeviceUsageKey: Int(kHIDUsage_GD_Pointer)
        ]

        IOHIDManagerSetDeviceMatchingMultiple(manager, [mouseMatch, pointerMatch] as CFArray)
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        guard openResult == kIOReturnSuccess else {
            // TCC denied — stop all future attempts.
            hidAccessDenied = true
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return false
        }
        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }

        guard let rawDevices = IOHIDManagerCopyDevices(manager) else { return false }
        let devices = rawDevices as NSSet

        for case let device as IOHIDDevice in devices {
            let isBuiltIn = boolProperty(device, key: kIOHIDBuiltInKey as CFString) ?? false
            if isBuiltIn {
                continue
            }

            let transport = (stringProperty(device, key: kIOHIDTransportKey as CFString) ?? "").lowercased()
            if transport == "spi" || transport == "i2c" {
                continue
            }

            if transport == "usb" || transport == "bluetooth" || transport == "btle" {
                return true
            }

            // Unknown transport, but non-built-in pointer devices are usually external.
            return true
        }

        return false
    }

    private func boolProperty(_ device: IOHIDDevice, key: CFString) -> Bool? {
        guard let value = IOHIDDeviceGetProperty(device, key) else { return nil }
        if let boolValue = value as? Bool {
            return boolValue
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return nil
    }

    private func stringProperty(_ device: IOHIDDevice, key: CFString) -> String? {
        guard let value = IOHIDDeviceGetProperty(device, key) else { return nil }
        if let string = value as? String {
            return string
        }
        if let nsString = value as? NSString {
            return nsString as String
        }
        return nil
    }
}
