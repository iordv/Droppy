//
//  VolumeManager.swift
//  Droppy
//
//  Created by Droppy on 05/01/2026.
//
//

import AppKit
import AudioToolbox
import Combine
import CoreAudio
import Foundation
import IOKit
import IOKit.graphics
import IOKit.i2c

private typealias VolumeIOAVServiceRef = CFTypeRef

@_silgen_name("IOAVServiceCreateWithService")
private func VolumeIOAVServiceCreateWithService(
    _ allocator: CFAllocator?,
    _ service: io_service_t
) -> Unmanaged<CFTypeRef>?

@_silgen_name("IOAVServiceReadI2C")
private func VolumeIOAVServiceReadI2C(
    _ service: VolumeIOAVServiceRef,
    _ chipAddress: UInt32,
    _ offset: UInt32,
    _ outputBuffer: UnsafeMutableRawPointer?,
    _ outputBufferSize: UInt32
) -> IOReturn

@_silgen_name("IOAVServiceWriteI2C")
private func VolumeIOAVServiceWriteI2C(
    _ service: VolumeIOAVServiceRef,
    _ chipAddress: UInt32,
    _ dataAddress: UInt32,
    _ inputBuffer: UnsafeMutableRawPointer?,
    _ inputBufferSize: UInt32
) -> IOReturn

@_silgen_name("CGSServiceForDisplayNumber")
private func VolumeCGSServiceForDisplayNumber(
    _ display: CGDirectDisplayID,
    _ service: UnsafeMutablePointer<io_service_t>
)

private enum VolumeDisplayIOServiceResolver {
    static func servicePort(for displayID: CGDirectDisplayID) -> io_service_t? {
        guard displayID != 0 else { return nil }
        
        var cgsService: io_service_t = 0
        VolumeCGSServiceForDisplayNumber(displayID, &cgsService)
        if cgsService != 0 {
            return cgsService
        }
        
        return servicePortUsingDisplayPropertiesMatching(displayID: displayID)
    }
    
    private static func servicePortUsingDisplayPropertiesMatching(displayID: CGDirectDisplayID) -> io_service_t? {
        let vendorID = CGDisplayVendorNumber(displayID)
        let productID = CGDisplayModelNumber(displayID)
        let serialNumber = CGDisplaySerialNumber(displayID)
        let unitNumber = CGDisplayUnitNumber(displayID)
        
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator) == kIOReturnSuccess else {
            return nil
        }
        defer { IOObjectRelease(iterator) }
        
        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            
            if matches(
                service: service,
                vendorID: vendorID,
                productID: productID,
                serialNumber: serialNumber,
                unitNumber: unitNumber
            ) {
                return service
            }
            
            IOObjectRelease(service)
        }
        
        return nil
    }
    
    private static func matches(
        service: io_service_t,
        vendorID: UInt32,
        productID: UInt32,
        serialNumber: UInt32,
        unitNumber: UInt32
    ) -> Bool {
        let dict = IODisplayCreateInfoDictionary(service, IOOptionBits(kIODisplayOnlyPreferredName)).takeRetainedValue() as NSDictionary
        
        let readUInt32: (CFString) -> UInt32 = { key in
            if let value = dict[key] as? NSNumber {
                return value.uint32Value
            }
            if let value = dict[key as String] as? NSNumber {
                return value.uint32Value
            }
            return 0
        }
        
        guard readUInt32(kDisplayVendorID as CFString) == vendorID else { return false }
        guard readUInt32(kDisplayProductID as CFString) == productID else { return false }
        
        let serviceSerial = readUInt32(kDisplaySerialNumber as CFString)
        if serialNumber != 0 && serviceSerial != 0 && serviceSerial != serialNumber {
            return false
        }
        
        if let location = dict[kIODisplayLocationKey] as? NSString ?? dict[kIODisplayLocationKey as String] as? NSString {
            let regex = try? NSRegularExpression(pattern: "@([0-9]+)[^@]+$", options: [])
            if let regex,
               let match = regex.firstMatch(in: location as String, options: [], range: NSRange(location: 0, length: location.length)),
               let range = Range(match.range(at: 1), in: location as String) {
                let locationUnit = UInt32((location as String)[range]) ?? 0
                if locationUnit != unitNumber {
                    return false
                }
            }
        }
        
        return true
    }
}

private protocol ExternalVolumeTransport: AnyObject {
    func isSupported() -> Bool
    func readNormalizedVolume() -> Float32?
    func writeNormalizedVolume(_ value: Float32) -> Bool
}

private final class ExternalDisplayDDCVolumeController: NSObject {
    static let shared = ExternalDisplayDDCVolumeController()
    
    private var transports: [CGDirectDisplayID: ExternalVolumeTransport] = [:]
    private let lock = NSLock()
    
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func canControl(displayID: CGDirectDisplayID) -> Bool {
        hasTransport(displayID: displayID)
    }
    
    func hasTransport(displayID: CGDirectDisplayID) -> Bool {
        transport(for: displayID) != nil
    }
    
    func volume(displayID: CGDirectDisplayID) -> Float32? {
        guard let transport = transport(for: displayID) else { return nil }
        return transport.readNormalizedVolume()
    }
    
    func setVolume(_ value: Float32, displayID: CGDirectDisplayID) -> Bool {
        guard let transport = transport(for: displayID) else { return false }
        return transport.writeNormalizedVolume(max(0, min(1, value)))
    }
    
    @objc private func handleScreenParametersChanged() {
        let activeDisplayIDs = Set(NSScreen.screens.map { $0.displayID })
        lock.lock()
        transports = transports.filter { activeDisplayIDs.contains($0.key) }
        lock.unlock()
    }
    
    private func transport(for displayID: CGDirectDisplayID) -> ExternalVolumeTransport? {
        guard displayID != 0 else { return nil }
        guard CGDisplayIsBuiltin(displayID) == 0 else { return nil }
        
        lock.lock()
        if let existing = transports[displayID] {
            lock.unlock()
            return existing
        }
        lock.unlock()
        
        guard let discovered = discoverTransport(for: displayID) else {
            return nil
        }
        
        lock.lock()
        transports[displayID] = discovered
        lock.unlock()
        return discovered
    }
    
    private func discoverTransport(for displayID: CGDirectDisplayID) -> ExternalVolumeTransport? {
        let framebuffer = VolumeDisplayIOServiceResolver.servicePort(for: displayID) ?? 0
        
        if framebuffer != 0 {
            let i2cTransport = IntelI2CDDCCVolumeTransport(framebuffer: framebuffer)
            if i2cTransport.isSupported() {
                return i2cTransport
            }
        }
        
        if let avTransport = Arm64AVDDCCVolumeTransport(displayID: displayID),
           avTransport.isSupported() {
            return avTransport
        }
        
        return nil
    }
}

private final class IntelI2CDDCCVolumeTransport: ExternalVolumeTransport {
    private static let vcpVolume: UInt8 = 0x62
    private static let writeAddress: UInt32 = 0x6E
    private static let readAddress: UInt32 = 0x6F
    private static let replySubAddress: UInt8 = 0x51
    private static let readRetries = 3
    private static let writeCycles = 2
    private static let writeSleep: useconds_t = 10000
    
    private let framebuffer: io_service_t
    private var cachedMaxValue: UInt16 = 100
    private var lastKnownCurrentValue: UInt16 = 100
    
    init(framebuffer: io_service_t) {
        self.framebuffer = framebuffer
    }
    
    func isSupported() -> Bool {
        readVolumeRaw() != nil
    }
    
    func readNormalizedVolume() -> Float32? {
        if let values = readVolumeRaw() {
            cachedMaxValue = max(1, values.max)
            lastKnownCurrentValue = min(values.current, cachedMaxValue)
            return normalize(lastKnownCurrentValue, maximum: cachedMaxValue)
        }
        
        if cachedMaxValue > 0 {
            return normalize(lastKnownCurrentValue, maximum: cachedMaxValue)
        }
        
        return nil
    }
    
    func writeNormalizedVolume(_ value: Float32) -> Bool {
        let clamped = max(0, min(1, value))
        
        if let values = readVolumeRaw() {
            cachedMaxValue = max(1, values.max)
            lastKnownCurrentValue = min(values.current, cachedMaxValue)
        }
        
        let target = UInt16(round(Float(cachedMaxValue) * Float(clamped)))
        let didWrite = writeVolumeRaw(target, maxValue: cachedMaxValue)
        if didWrite {
            lastKnownCurrentValue = target
        }
        return didWrite
    }
    
    private func normalize(_ current: UInt16, maximum: UInt16) -> Float32 {
        guard maximum > 0 else { return 0 }
        return Swift.max(0, Swift.min(1, Float32(current) / Float32(maximum)))
    }
    
    private func readVolumeRaw() -> (current: UInt16, max: UInt16)? {
        var requestData: [UInt8] = [0x51, 0x82, 0x01, Self.vcpVolume, 0]
        requestData[4] = checksum(seed: UInt8(Self.writeAddress), data: requestData, upTo: 3)
        
        for transactionType in [IOOptionBits(kIOI2CDDCciReplyTransactionType), IOOptionBits(kIOI2CSimpleTransactionType)] {
            for _ in 0..<Self.readRetries {
                usleep(Self.writeSleep)
                
                var replyData = Array<UInt8>(repeating: 0, count: 11)
                var request = IOI2CRequest()
                request.commFlags = 0
                request.sendAddress = Self.writeAddress
                request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
                request.sendBuffer = withUnsafeMutablePointer(to: &requestData[0]) { vm_address_t(bitPattern: $0) }
                request.sendBytes = UInt32(requestData.count)
                request.minReplyDelay = 10
                request.replyAddress = Self.readAddress
                request.replySubAddress = Self.replySubAddress
                request.replyTransactionType = transactionType
                request.replyBytes = UInt32(replyData.count)
                request.replyBuffer = withUnsafeMutablePointer(to: &replyData[0]) { vm_address_t(bitPattern: $0) }
                
                guard Self.send(request: &request, framebuffer: framebuffer) else { continue }
                guard validate(reply: replyData) else { continue }
                
                let maxValue = (UInt16(replyData[6]) << 8) | UInt16(replyData[7])
                let currentValue = (UInt16(replyData[8]) << 8) | UInt16(replyData[9])
                guard maxValue > 0 else { continue }
                return (current: currentValue, max: maxValue)
            }
        }
        
        return nil
    }
    
    private func writeVolumeRaw(_ current: UInt16, maxValue: UInt16) -> Bool {
        let value = min(current, maxValue)
        var data: [UInt8] = [
            0x51,
            0x84,
            0x03,
            Self.vcpVolume,
            UInt8(value >> 8),
            UInt8(value & 0xFF),
            0
        ]
        data[6] = checksum(seed: UInt8(Self.writeAddress), data: data, upTo: 5)
        
        var wroteOnce = false
        for _ in 0..<Self.writeCycles {
            usleep(Self.writeSleep)
            
            var request = IOI2CRequest()
            request.commFlags = 0
            request.sendAddress = Self.writeAddress
            request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
            request.sendBuffer = withUnsafeMutablePointer(to: &data[0]) { vm_address_t(bitPattern: $0) }
            request.sendBytes = UInt32(data.count)
            request.replyTransactionType = IOOptionBits(kIOI2CNoTransactionType)
            request.replyBytes = 0
            
            if Self.send(request: &request, framebuffer: framebuffer) {
                wroteOnce = true
            }
        }
        
        return wroteOnce
    }
    
    private func validate(reply: [UInt8]) -> Bool {
        guard reply.count >= 11 else { return false }
        guard reply[2] == 0x02 else { return false }
        guard reply[3] == 0x00 else { return false }
        
        var calculatedChecksum: UInt8 = 0x50
        for i in 0..<10 {
            calculatedChecksum ^= reply[i]
        }
        return calculatedChecksum == reply[10]
    }
    
    private func checksum(seed: UInt8, data: [UInt8], upTo: Int) -> UInt8 {
        guard !data.isEmpty else { return seed }
        var value = seed
        for index in 0...upTo {
            value ^= data[index]
        }
        return value
    }
    
    private static func send(request: inout IOI2CRequest, framebuffer: io_service_t) -> Bool {
        var busCount: IOItemCount = 0
        guard IOFBGetI2CInterfaceCount(framebuffer, &busCount) == kIOReturnSuccess else { return false }
        
        for bus in 0..<busCount {
            var interface: io_service_t = 0
            guard IOFBCopyI2CInterfaceForBus(framebuffer, IOOptionBits(bus), &interface) == kIOReturnSuccess else {
                continue
            }
            defer { IOObjectRelease(interface) }
            
            var connect: IOI2CConnectRef?
            guard IOI2CInterfaceOpen(interface, 0, &connect) == kIOReturnSuccess,
                  let openedConnect = connect else {
                continue
            }
            defer { _ = IOI2CInterfaceClose(openedConnect, 0) }
            
            guard IOI2CSendRequest(openedConnect, 0, &request) == kIOReturnSuccess else { continue }
            guard request.result == kIOReturnSuccess else { continue }
            return true
        }
        
        return false
    }
}

private final class Arm64AVDDCCVolumeTransport: ExternalVolumeTransport {
    private static let ddcChipAddress: UInt8 = 0x37
    private static let ddcDataAddress: UInt8 = 0x51
    private static let volumeVCP: UInt8 = 0x62
    private static let readReplyLength = 11
    private static let writeSleep: useconds_t = 10000
    private static let readSleep: useconds_t = 50000
    private static let retrySleep: useconds_t = 20000
    private static let retries = 4
    private static let writeCycles = 2
    
    private let service: VolumeIOAVServiceRef
    private var cachedMaxValue: UInt16 = 100
    private var lastKnownCurrentValue: UInt16 = 100
    
    init?(displayID: CGDirectDisplayID) {
        guard let service = Self.createService(displayID: displayID) else { return nil }
        self.service = service
    }
    
    func isSupported() -> Bool {
        readVolumeRaw() != nil
    }
    
    func readNormalizedVolume() -> Float32? {
        if let values = readVolumeRaw() {
            cachedMaxValue = max(1, values.max)
            lastKnownCurrentValue = min(values.current, cachedMaxValue)
            return normalize(lastKnownCurrentValue, maximum: cachedMaxValue)
        }
        
        if cachedMaxValue > 0 {
            return normalize(lastKnownCurrentValue, maximum: cachedMaxValue)
        }
        
        return nil
    }
    
    func writeNormalizedVolume(_ value: Float32) -> Bool {
        let clamped = max(0, min(1, value))
        
        if let values = readVolumeRaw() {
            cachedMaxValue = max(1, values.max)
            lastKnownCurrentValue = min(values.current, cachedMaxValue)
        }
        
        let target = UInt16(round(Float(cachedMaxValue) * Float(clamped)))
        let didWrite = writeVolumeRaw(target, maxValue: cachedMaxValue)
        if didWrite {
            lastKnownCurrentValue = target
        }
        return didWrite
    }
    
    private func normalize(_ current: UInt16, maximum: UInt16) -> Float32 {
        guard maximum > 0 else { return 0 }
        return Swift.max(0, Swift.min(1, Float32(current) / Float32(maximum)))
    }
    
    private func readVolumeRaw() -> (current: UInt16, max: UInt16)? {
        var reply = Array<UInt8>(repeating: 0, count: Self.readReplyLength)
        
        for _ in 0..<Self.retries {
            var readCommandPacket = Self.makePacket(sendData: [Self.volumeVCP])
            let writeResult = readCommandPacket.withUnsafeMutableBytes { bytes -> IOReturn in
                VolumeIOAVServiceWriteI2C(
                    service,
                    UInt32(Self.ddcChipAddress),
                    UInt32(Self.ddcDataAddress),
                    bytes.baseAddress,
                    UInt32(bytes.count)
                )
            }
            guard writeResult == kIOReturnSuccess else {
                usleep(Self.retrySleep)
                continue
            }
            
            usleep(Self.readSleep)
            let readResult = reply.withUnsafeMutableBytes { bytes -> IOReturn in
                VolumeIOAVServiceReadI2C(
                    service,
                    UInt32(Self.ddcChipAddress),
                    0,
                    bytes.baseAddress,
                    UInt32(bytes.count)
                )
            }
            guard readResult == kIOReturnSuccess else {
                usleep(Self.retrySleep)
                continue
            }
            guard validate(reply: reply) else {
                usleep(Self.retrySleep)
                continue
            }
            
            let maxValue = (UInt16(reply[6]) << 8) | UInt16(reply[7])
            let currentValue = (UInt16(reply[8]) << 8) | UInt16(reply[9])
            guard maxValue > 0 else {
                usleep(Self.retrySleep)
                continue
            }
            
            return (current: currentValue, max: maxValue)
        }
        
        return nil
    }
    
    private func writeVolumeRaw(_ current: UInt16, maxValue: UInt16) -> Bool {
        let value = min(current, maxValue)
        let payload: [UInt8] = [Self.volumeVCP, UInt8(value >> 8), UInt8(value & 0xFF)]
        
        for _ in 0..<Self.retries {
            var wroteAny = false
            for _ in 0..<Self.writeCycles {
                usleep(Self.writeSleep)
                var packet = Self.makePacket(sendData: payload)
                let result = packet.withUnsafeMutableBytes { bytes -> IOReturn in
                    VolumeIOAVServiceWriteI2C(
                        service,
                        UInt32(Self.ddcChipAddress),
                        UInt32(Self.ddcDataAddress),
                        bytes.baseAddress,
                        UInt32(bytes.count)
                    )
                }
                if result == kIOReturnSuccess {
                    wroteAny = true
                }
            }
            
            if wroteAny {
                return true
            }
            
            usleep(Self.retrySleep)
        }
        
        return false
    }
    
    private static func makePacket(sendData: [UInt8]) -> [UInt8] {
        var packet: [UInt8] = [UInt8(0x80 | (sendData.count + 1)), UInt8(sendData.count)]
        packet.append(contentsOf: sendData)
        packet.append(0)
        
        let seed: UInt8 = sendData.count == 1
            ? (ddcChipAddress << 1)
            : ((ddcChipAddress << 1) ^ ddcDataAddress)
        packet[packet.count - 1] = checksum(seed: seed, data: packet, upTo: packet.count - 2)
        return packet
    }
    
    private static func checksum(seed: UInt8, data: [UInt8], upTo: Int) -> UInt8 {
        guard !data.isEmpty else { return seed }
        var value = seed
        for i in 0...upTo {
            value ^= data[i]
        }
        return value
    }
    
    private func validate(reply: [UInt8]) -> Bool {
        guard reply.count >= Self.readReplyLength else { return false }
        guard reply[2] == 0x02 else { return false }
        guard reply[3] == 0x00 else { return false }
        
        let expected = Self.checksum(seed: 0x50, data: reply, upTo: reply.count - 2)
        return expected == reply[reply.count - 1]
    }
    
    private static func createService(displayID: CGDirectDisplayID) -> VolumeIOAVServiceRef? {
        var cgsService: io_service_t = 0
        VolumeCGSServiceForDisplayNumber(displayID, &cgsService)
        
        if cgsService != 0,
           let avService = VolumeIOAVServiceCreateWithService(kCFAllocatorDefault, cgsService)?.takeRetainedValue() {
            return avService
        }
        
        guard let framebuffer = VolumeDisplayIOServiceResolver.servicePort(for: displayID),
              framebuffer != 0,
              let avService = VolumeIOAVServiceCreateWithService(kCFAllocatorDefault, framebuffer)?.takeRetainedValue() else {
            return nil
        }
        
        return avService
    }
}

/// Manages system volume using CoreAudio APIs
/// Provides real-time volume monitoring and control with auto-hide HUD timing
final class VolumeManager: NSObject, ObservableObject {
    static let shared = VolumeManager()
    
    private enum MediaControlTargetMode: String {
        case mainMacBook
        case activeDisplay
    }
    
    // MARK: - Published Properties
    @Published private(set) var rawVolume: Float = 0
    @Published private(set) var isMuted: Bool = false
    @Published private(set) var lastChangeAt: Date = .distantPast
    @Published private(set) var lastChangeDisplayID: CGDirectDisplayID?
    @Published private(set) var activeOutputDeviceName: String = ""
    @Published private(set) var activeOutputDeviceType: ConnectedAirPods.DeviceType? = nil
    
    // MARK: - Configuration
    let visibleDuration: TimeInterval = 1.5
    private let step: Float32 = 1.0 / 16.0
    
    // MARK: - Private State
    private var didInitialFetch = false
    private var previousVolumeBeforeMute: Float32 = 0.2
    private var previousExternalVolumeBeforeMute: [CGDirectDisplayID: Float32] = [:]
    private var softwareMuted: Bool = false
    private let externalHardwareVolumeController = ExternalDisplayDDCVolumeController.shared
    
    // osascript debouncing - coalesce rapid volume changes to avoid delay
    private var osascriptWorkItem: DispatchWorkItem?
    private let osascriptDebounceDelay: TimeInterval = 0.05 // 50ms debounce
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupAudioListener()
        fetchCurrentVolume()
    }
    
    /// Whether the HUD overlay should be visible
    var shouldShowOverlay: Bool {
        Date().timeIntervalSince(lastChangeAt) < visibleDuration
    }
    
    private var mediaControlTargetMode: MediaControlTargetMode {
        let raw = UserDefaults.standard.string(forKey: AppPreferenceKey.mediaControlTargetMode)
            ?? PreferenceDefault.mediaControlTargetMode
        return MediaControlTargetMode(rawValue: raw) ?? .activeDisplay
    }
    
    /// Whether the current output device supports volume control via CoreAudio
    /// Checks both VirtualMainVolume (preferred, works with USB devices) and VolumeScalar
    var supportsVolumeControl: Bool {
        // AppleScript fallback always works, so we always support volume control
        return true
    }

    /// Device-aware icon used by volume HUDs.
    /// Returns AirPods/headphones symbols when a supported output device is active.
    func volumeHUDIcon(for value: CGFloat, isMuted: Bool) -> String {
        if isMuted || value <= 0.0001 {
            return "speaker.slash.fill"
        }

        if let deviceType = activeOutputDeviceType {
            return deviceType.symbolName
        }

        if value < 0.33 { return "speaker.wave.1.fill" }
        if value < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
    
    // MARK: - Public Control API
    
    /// Increase volume by one step
    @MainActor func increase(stepDivisor: Float = 1.0, screenHint: NSScreen? = nil) {
        let divisor = max(stepDivisor, 0.25)
        let delta = step / Float32(divisor)
        let targetDisplayID = resolveHUDTargetDisplayID(screenHint: screenHint)
        let current = targetDisplayID.flatMap { volumeForExternalTarget(displayID: $0) } ?? readVolumeInternal() ?? rawVolume
        let target = max(0, min(1, current + delta))
        setAbsolute(target, screenHint: screenHint)
    }
    
    /// Decrease volume by one step
    @MainActor func decrease(stepDivisor: Float = 1.0, screenHint: NSScreen? = nil) {
        let divisor = max(stepDivisor, 0.25)
        let delta = step / Float32(divisor)
        let targetDisplayID = resolveHUDTargetDisplayID(screenHint: screenHint)
        let current = targetDisplayID.flatMap { volumeForExternalTarget(displayID: $0) } ?? readVolumeInternal() ?? rawVolume
        let target = max(0, min(1, current - delta))
        setAbsolute(target, screenHint: screenHint)
    }
    
    /// Toggle mute state
    @MainActor func toggleMute(screenHint: NSScreen? = nil) {
        let deviceID = systemOutputDeviceID()
        let targetDisplayID = resolveHUDTargetDisplayID(screenHint: screenHint)
        refreshOutputDeviceInfo(deviceID: deviceID)
        
        if let targetDisplayID, toggleExternalMute(displayID: targetDisplayID) {
            return
        }
        
        if deviceID == kAudioObjectUnknown {
            // Software mute fallback
        } else {
            // Hardware mute
        }
        
        toggleMuteInternal(displayID: targetDisplayID)
    }
    
    /// Refresh volume from system
    func refresh() {
        if let targetDisplayID = resolveHUDTargetDisplayID(),
           let externalVolume = volumeForExternalTarget(displayID: targetDisplayID) {
            publish(volume: externalVolume, muted: externalVolume <= 0.001, touchDate: false, displayID: targetDisplayID)
            return
        }
        fetchCurrentVolume()
    }
    
    /// Set volume to absolute value (0.0 - 1.0)
    @MainActor func setAbsolute(_ value: Float32, screenHint: NSScreen? = nil) {
        let clamped = max(0, min(1, value))
        let deviceID = systemOutputDeviceID()
        refreshOutputDeviceInfo(deviceID: deviceID)
        let targetDisplayID = resolveHUDTargetDisplayID(screenHint: screenHint)
        
        if let targetDisplayID,
           shouldAttemptExternalHardwareVolume(displayID: targetDisplayID) {
            let previousVolume = volumeForExternalTarget(displayID: targetDisplayID) ?? rawVolume
            let wasEffectivelyMuted = previousVolume < 0.01
            let isNowAudible = clamped >= step * 0.5
            
            if externalHardwareVolumeController.setVolume(clamped, displayID: targetDisplayID) {
                if clamped > 0.001 {
                    previousExternalVolumeBeforeMute[targetDisplayID] = clamped
                }
                publish(volume: clamped, muted: clamped <= 0.001, touchDate: true, displayID: targetDisplayID)
                
                if wasEffectivelyMuted && isNowAudible {
                    HapticFeedback.toggle()
                }
                return
            }
        }
        
        let currentlyMuted = isMutedInternal()
        let previousVolume = rawVolume
        
        // Detect "unmute" transition: going from 0 (or muted) to first audible step
        let wasEffectivelyMuted = currentlyMuted || previousVolume < 0.01
        let isNowAudible = clamped >= step * 0.5  // At least ~half a step (first audible)
        
        if currentlyMuted && clamped > 0 {
            toggleMuteInternal(displayID: targetDisplayID)
        }
        
        writeVolumeInternal(clamped)
        
        if clamped == 0 && !currentlyMuted {
            toggleMuteInternal(displayID: targetDisplayID)
        }
        
        publish(volume: clamped, muted: isMutedInternal(), touchDate: true, displayID: targetDisplayID)
        
        // Haptic feedback: bumpy feel when coming out of silence (0 → first step)
        if wasEffectivelyMuted && isNowAudible {
            HapticFeedback.toggle()
        }
    }
    
    // MARK: - CoreAudio Helpers
    
    private func systemOutputDeviceID() -> AudioObjectID {
        var defaultDeviceID = kAudioObjectUnknown
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &defaultDeviceID
        )
        if status != noErr { return kAudioObjectUnknown }
        return defaultDeviceID
    }
    
    private func fetchCurrentVolume() {
        let deviceID = systemOutputDeviceID()
        refreshOutputDeviceInfo(deviceID: deviceID)
        
        var fetchedVolume: Float32? = nil
        
        if deviceID != kAudioObjectUnknown {
            // First try VirtualMainVolume (works with USB devices like Jabra)
            var virtualAddr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            if AudioObjectHasProperty(deviceID, &virtualAddr) {
                var vol = Float32(0)
                var size = UInt32(MemoryLayout<Float32>.size)
                if AudioObjectGetPropertyData(deviceID, &virtualAddr, 0, nil, &size, &vol) == noErr {
                    fetchedVolume = vol
                }
            }
            
            // Fall back to VolumeScalar
            if fetchedVolume == nil {
                var volumes: [Float32] = []
                let candidateElements: [UInt32] = [kAudioObjectPropertyElementMain, 1, 2, 3, 4]
                
                for element in candidateElements {
                    if let v = readValidatedScalar(deviceID: deviceID, element: element) {
                        volumes.append(v)
                    }
                }
                
                if !volumes.isEmpty {
                    fetchedVolume = volumes.reduce(0, +) / Float32(volumes.count)
                }
            }
        }
        
        // Final fallback: osascript
        if fetchedVolume == nil {
            fetchedVolume = readVolumeViaOsascript()
        }
        
        if let avg = fetchedVolume {
            let clampedAvg = max(0, min(1, avg))
            DispatchQueue.main.async {
                let previousVolume = self.rawVolume
                let wasEffectivelyMuted = previousVolume < 0.01
                let isNowAudible = clampedAvg >= self.step * 0.5
                
                if self.rawVolume != clampedAvg {
                    if self.didInitialFetch {
                        self.lastChangeAt = Date()
                        self.lastChangeDisplayID = self.resolveHUDTargetDisplayID()
                        
                        // Haptic feedback: bumpy feel when coming out of silence (0 → first step)
                        if wasEffectivelyMuted && isNowAudible {
                            HapticFeedback.toggle()
                        }
                    }
                }
                self.rawVolume = clampedAvg
                self.didInitialFetch = true
            }
        }

        
        // Check mute state
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectHasProperty(deviceID, &muteAddr) {
            var sizeNeeded: UInt32 = 0
            if AudioObjectGetPropertyDataSize(deviceID, &muteAddr, 0, nil, &sizeNeeded) == noErr,
               sizeNeeded == UInt32(MemoryLayout<UInt32>.size) {
                var muted: UInt32 = 0
                var mSize = sizeNeeded
                if AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &mSize, &muted) == noErr {
                    let newMuted = muted != 0
                    DispatchQueue.main.async {
                        if self.isMuted != newMuted {
                            self.lastChangeAt = Date()
                            self.lastChangeDisplayID = self.resolveHUDTargetDisplayID()
                        }
                        self.isMuted = newMuted
                    }
                }
            }
        }
    }
    
    private func setupAudioListener() {
        let deviceID = systemOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }
        
        // Listen for default device changes
        var defaultDevAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &defaultDevAddr, nil
        ) { [weak self] _, _ in
            self?.fetchCurrentVolume()
        }
        
        // Listen for volume changes
        var masterAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectHasProperty(deviceID, &masterAddr) {
            AudioObjectAddPropertyListenerBlock(deviceID, &masterAddr, nil) { [weak self] _, _ in
                self?.fetchCurrentVolume()
            }
        } else {
            for ch in [UInt32(1), UInt32(2)] {
                var chAddr = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: ch
                )
                if AudioObjectHasProperty(deviceID, &chAddr) {
                    AudioObjectAddPropertyListenerBlock(deviceID, &chAddr, nil) { [weak self] _, _ in
                        self?.fetchCurrentVolume()
                    }
                }
            }
        }
        
        // Listen for mute changes
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &muteAddr) {
            AudioObjectAddPropertyListenerBlock(deviceID, &muteAddr, nil) { [weak self] _, _ in
                self?.fetchCurrentVolume()
            }
        }
    }
    
    private func readVolumeInternal() -> Float32? {
        let deviceID = systemOutputDeviceID()
        
        if deviceID != kAudioObjectUnknown {
            // First try VirtualMainVolume (works with USB devices like Jabra)
            var virtualAddr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            if AudioObjectHasProperty(deviceID, &virtualAddr) {
                var vol = Float32(0)
                var size = UInt32(MemoryLayout<Float32>.size)
                if AudioObjectGetPropertyData(deviceID, &virtualAddr, 0, nil, &size, &vol) == noErr {
                    return vol
                }
            }
            
            // Fall back to VolumeScalar (for devices that don't support VirtualMainVolume)
            var collected: [Float32] = []
            for el in [kAudioObjectPropertyElementMain, UInt32(1), UInt32(2), UInt32(3), UInt32(4)] {
                if let v = readValidatedScalar(deviceID: deviceID, element: el) {
                    collected.append(v)
                }
            }
            if !collected.isEmpty {
                return collected.reduce(0, +) / Float32(collected.count)
            }
        }
        
        // Final fallback: osascript (works for USB devices that CoreAudio can't read)
        return readVolumeViaOsascript()
    }
    
    /// Read volume using osascript - the same method macOS uses for system volume control
    /// Note: This runs synchronously but is only called as a fallback when CoreAudio fails
    private func readVolumeViaOsascript() -> Float32? {
        // Don't block main thread - return cached value instead
        if Thread.isMainThread {
            return nil // Let caller use rawVolume instead
        }
        
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "output volume of (get volume settings)"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let volumePercent = Int(output) {
                return Float32(volumePercent) / 100.0
            }
        } catch {
            print("[VolumeManager] osascript read failed: \(error)")
        }
        return nil
    }
    
    private func writeVolumeInternal(_ value: Float32) {
        let deviceID = systemOutputDeviceID()
        let newVal = max(0, min(1, value))
        
        // Skip CoreAudio attempts if no device found
        if deviceID != kAudioObjectUnknown {
            // First try VirtualMainVolume (works with USB devices like Jabra)
            var virtualAddr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            if AudioObjectHasProperty(deviceID, &virtualAddr) {
                var vol = newVal
                let size = UInt32(MemoryLayout<Float32>.size)
                if AudioObjectSetPropertyData(deviceID, &virtualAddr, 0, nil, size, &vol) == noErr {
                    // Verify the write actually worked (some USB devices return success but don't apply)
                    var readBack = Float32(0)
                    var readSize = size
                    if AudioObjectGetPropertyData(deviceID, &virtualAddr, 0, nil, &readSize, &readBack) == noErr {
                        // Check if the value is close to what we set (within 2%)
                        if abs(readBack - newVal) < 0.02 {
                            return
                        }
                    }
                }
            }
            
            // Fall back to VolumeScalar
            if writeValidatedScalar(deviceID: deviceID, element: kAudioObjectPropertyElementMain, value: newVal) {
                // Verify this one too
                let readBack = readValidatedScalar(deviceID: deviceID, element: kAudioObjectPropertyElementMain)
                if let rb = readBack, abs(rb - newVal) < 0.02 {
                    return
                }
            }
            
            // Try individual channels - skip verification for simplicity, just try
            var channelSuccess = false
            for el in [UInt32(1), UInt32(2), UInt32(3), UInt32(4)] {
                if writeValidatedScalar(deviceID: deviceID, element: el, value: newVal) {
                    channelSuccess = true
                }
            }
            if channelSuccess {
                // Verify at least one channel changed
                if let vol = readVolumeInternal(), abs(vol - newVal) < 0.05 {
                    return
                }
            }
        }
        
        // Final fallback: osascript (same as macOS system volume control)
        writeVolumeViaOsascript(newVal)
    }
    
    /// Write volume using osascript - the same method macOS uses for system volume control
    /// Uses debouncing to coalesce rapid key presses and avoid delay buildup
    private func writeVolumeViaOsascript(_ value: Float32) {
        let volumePercent = Int(value * 100)
        
        // Cancel any pending osascript execution
        osascriptWorkItem?.cancel()
        
        // Create new work item with the latest volume value
        let workItem = DispatchWorkItem { [weak self] in
            guard self != nil else { return }
            
            // First unmute (some USB devices like Jabra get stuck in muted state)
            // Then set volume - both in one script call for efficiency
            let script = "set volume without output muted\nset volume output volume \(volumePercent)"
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                print("[VolumeManager] osascript failed: \(error)")
            }
        }
        
        osascriptWorkItem = workItem
        
        // Execute after debounce delay on background queue
        DispatchQueue.global(qos: .userInteractive).asyncAfter(
            deadline: .now() + osascriptDebounceDelay,
            execute: workItem
        )
    }
    
    private func isMutedInternal() -> Bool {
        let deviceID = systemOutputDeviceID()
        if deviceID == kAudioObjectUnknown { return softwareMuted }
        
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &muteAddr) else { return softwareMuted }
        
        var sizeNeeded: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &muteAddr, 0, nil, &sizeNeeded) == noErr,
              sizeNeeded == UInt32(MemoryLayout<UInt32>.size) else { return softwareMuted }
        
        var muted: UInt32 = 0
        var size = sizeNeeded
        if AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &size, &muted) == noErr {
            return muted != 0
        }
        return softwareMuted
    }
    
    private func toggleMuteInternal(displayID: CGDirectDisplayID?) {
        let deviceID = systemOutputDeviceID()
        if deviceID == kAudioObjectUnknown {
            performSoftwareMuteToggle(currentVolume: rawVolume, displayID: displayID)
            return
        }
        
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if !AudioObjectHasProperty(deviceID, &muteAddr) {
            performSoftwareMuteToggle(currentVolume: readVolumeInternal() ?? rawVolume, displayID: displayID)
            return
        }
        
        var sizeNeeded: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &muteAddr, 0, nil, &sizeNeeded) == noErr,
              sizeNeeded == UInt32(MemoryLayout<UInt32>.size) else {
            performSoftwareMuteToggle(currentVolume: readVolumeInternal() ?? rawVolume, displayID: displayID)
            return
        }
        
        var muted: UInt32 = 0
        var size = sizeNeeded
        if AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &size, &muted) == noErr {
            var newVal: UInt32 = muted == 0 ? 1 : 0
            AudioObjectSetPropertyData(deviceID, &muteAddr, 0, nil, size, &newVal)
            let vol = readVolumeInternal() ?? rawVolume
            publish(volume: vol, muted: newVal != 0, touchDate: true, displayID: displayID)
        } else {
            performSoftwareMuteToggle(currentVolume: readVolumeInternal() ?? rawVolume, displayID: displayID)
        }
    }
    
    private func performSoftwareMuteToggle(currentVolume: Float32, displayID: CGDirectDisplayID?) {
        if softwareMuted {
            let restore = max(0, min(1, previousVolumeBeforeMute))
            writeVolumeInternal(restore)
            softwareMuted = false
            publish(volume: restore, muted: false, touchDate: true, displayID: displayID)
        } else {
            if currentVolume > 0.001 { previousVolumeBeforeMute = currentVolume }
            writeVolumeInternal(0)
            softwareMuted = true
            publish(volume: 0, muted: true, touchDate: true, displayID: displayID)
        }
    }
    
    private func readValidatedScalar(deviceID: AudioObjectID, element: UInt32) -> Float32? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        guard AudioObjectHasProperty(deviceID, &addr) else { return nil }
        
        var sizeNeeded: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &sizeNeeded) == noErr,
              sizeNeeded == UInt32(MemoryLayout<Float32>.size) else { return nil }
        
        var vol = Float32(0)
        var size = sizeNeeded
        let status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &vol)
        return status == noErr ? vol : nil
    }
    
    private func writeValidatedScalar(deviceID: AudioObjectID, element: UInt32, value: Float32) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        guard AudioObjectHasProperty(deviceID, &addr) else { return false }
        
        let size = UInt32(MemoryLayout<Float32>.size)
        var val = value
        let status = AudioObjectSetPropertyData(deviceID, &addr, 0, nil, size, &val)
        return status == noErr
    }
    
    private func publish(volume: Float32, muted: Bool, touchDate: Bool, displayID: CGDirectDisplayID?) {
        DispatchQueue.main.async {
            if self.rawVolume != volume || self.isMuted != muted || touchDate {
                if touchDate {
                    self.lastChangeAt = Date()
                    self.lastChangeDisplayID = displayID
                }
                self.rawVolume = volume
                self.isMuted = muted
            }
        }
    }

    private func refreshOutputDeviceInfo(deviceID: AudioObjectID) {
        guard deviceID != kAudioObjectUnknown else {
            DispatchQueue.main.async {
                self.activeOutputDeviceName = ""
                self.activeOutputDeviceType = nil
            }
            return
        }

        let deviceName = readDeviceName(deviceID: deviceID) ?? ""
        var classifiedType = classifyPortableAudioDevice(from: deviceName)
        
        if classifiedType == nil && isBluetoothOutputDevice(deviceID: deviceID) {
            // Unknown Bluetooth headset/earbuds model: still show a device icon.
            classifiedType = .headphones
        }

        DispatchQueue.main.async {
            self.activeOutputDeviceName = deviceName
            self.activeOutputDeviceType = classifiedType
        }
    }

    private func readDeviceName(deviceID: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectHasProperty(deviceID, &address) else { return nil }

        var unmanagedName: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &unmanagedName) { namePointer in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, namePointer)
        }
        guard status == noErr, let unmanagedName else { return nil }

        // HAL string properties are returned as unretained CF objects.
        let resolved = unmanagedName.takeUnretainedValue() as String
        return resolved.isEmpty ? nil : resolved
    }
    
    private func isBluetoothOutputDevice(deviceID: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        guard AudioObjectHasProperty(deviceID, &address) else { return false }
        
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transport)
        guard status == noErr else { return false }
        
        return transport == kAudioDeviceTransportTypeBluetooth
    }

    private func classifyPortableAudioDevice(from deviceName: String) -> ConnectedAirPods.DeviceType? {
        let name = deviceName.lowercased()
        guard !name.isEmpty else { return nil }

        if name.contains("airpods") {
            if name.contains("max") { return .airpodsMax }
            if name.contains("pro") { return .airpodsPro }
            if name.contains("3") || name.contains("gen 3") || name.contains("third") { return .airpodsGen3 }
            return .airpods
        }

        if name.contains("beats") || name.contains("powerbeats") || name.contains("studio buds") {
            return .beats
        }

        if name.contains("buds") || name.contains("earbuds") || name.contains("earbud") ||
            name.contains("galaxy buds") || name.contains("pixel buds") ||
            name.contains("jabra") || name.contains("wf-") {
            return .earbuds
        }

        if name.contains("headphone") || name.contains("headset") || name.contains("wh-") ||
            name.contains("bose") || name.contains("quietcomfort") ||
            name.contains("sennheiser") || name.contains("momentum") ||
            name.contains("jbl") || name.contains("skullcandy") ||
            name.contains("audio-technica") || name.contains("anker") ||
            name.contains("soundcore") || name.contains("sony") {
            return .headphones
        }

        return nil
    }
    
    private func shouldAttemptExternalHardwareVolume(displayID: CGDirectDisplayID) -> Bool {
        guard displayID != 0 else { return false }
        guard CGDisplayIsBuiltin(displayID) == 0 else { return false }
        return externalHardwareVolumeController.hasTransport(displayID: displayID)
    }
    
    private func volumeForExternalTarget(displayID: CGDirectDisplayID) -> Float32? {
        guard shouldAttemptExternalHardwareVolume(displayID: displayID) else { return nil }
        guard let externalVolume = externalHardwareVolumeController.volume(displayID: displayID) else { return nil }
        return max(0, min(1, externalVolume))
    }
    
    @MainActor
    private func toggleExternalMute(displayID: CGDirectDisplayID) -> Bool {
        guard shouldAttemptExternalHardwareVolume(displayID: displayID) else { return false }
        guard let currentVolume = volumeForExternalTarget(displayID: displayID) else { return false }
        
        if currentVolume > 0.001 {
            previousExternalVolumeBeforeMute[displayID] = currentVolume
            if externalHardwareVolumeController.setVolume(0, displayID: displayID) {
                publish(volume: 0, muted: true, touchDate: true, displayID: displayID)
                return true
            }
            return false
        }
        
        let restoreVolume = max(
            step,
            min(1, previousExternalVolumeBeforeMute[displayID] ?? previousVolumeBeforeMute)
        )
        guard externalHardwareVolumeController.setVolume(restoreVolume, displayID: displayID) else {
            return false
        }
        publish(volume: restoreVolume, muted: false, touchDate: true, displayID: displayID)
        return true
    }
    
    private func resolveHUDTargetDisplayID(screenHint: NSScreen? = nil) -> CGDirectDisplayID? {
        switch mediaControlTargetMode {
        case .mainMacBook:
            return NSScreen.builtIn?.displayID
                ?? NSScreen.builtInWithNotch?.displayID
                ?? NSScreen.main?.displayID
                ?? NSScreen.screens.first?.displayID
        case .activeDisplay:
            let resolvedScreen = screenHint
                ?? NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
                ?? NSScreen.main
                ?? NSScreen.screens.first
            return resolvedScreen?.displayID
        }
    }
}
