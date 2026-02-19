//
//  MenuBarFloatingModels.swift
//  Droppy
//
//  Models and helpers for Menu Bar Manager's always-hidden floating bar.
//

import AppKit
import ApplicationServices
import CoreGraphics

struct MenuBarFloatingItemSnapshot: Identifiable {
    let id: String
    let windowID: CGWindowID?
    let axElement: AXUIElement
    let quartzFrame: CGRect
    let appKitFrame: CGRect
    let ownerBundleID: String
    let axIdentifier: String?
    let statusItemIndex: Int?
    let title: String?
    let detail: String?
    let icon: NSImage?

    var displayName: String {
        if let title, !title.isEmpty {
            return title
        }
        if let detail, !detail.isEmpty {
            return detail
        }
        return ownerBundleID
    }
}

enum MenuBarFloatingIconLayout {
    static func nativeIconSize(for item: MenuBarFloatingItemSnapshot) -> CGSize {
        if let icon = item.icon {
            let size = icon.size
            if size.width > 1, size.height > 1 {
                return CGSize(
                    width: max(10, min(72, round(size.width))),
                    height: max(14, min(32, round(size.height)))
                )
            }
        }

        let frame = item.quartzFrame
        if frame.width > 1, frame.height > 1 {
            return CGSize(
                width: max(10, min(72, round(frame.width))),
                height: max(14, min(32, round(frame.height)))
            )
        }

        let fallbackHeight = max(14, min(32, round(NSStatusBar.system.thickness)))
        return CGSize(width: fallbackHeight, height: fallbackHeight)
    }
}

enum MenuBarFloatingIconRendering {
    private static let cacheLock = NSLock()
    private static var templateDecisionByImageID = [ObjectIdentifier: Bool]()

    static func clearCache() {
        cacheLock.lock()
        templateDecisionByImageID.removeAll(keepingCapacity: false)
        cacheLock.unlock()
    }

    static func shouldUseTemplateTint(for icon: NSImage) -> Bool {
        if icon.isTemplate {
            return true
        }

        let cacheKey = ObjectIdentifier(icon)
        cacheLock.lock()
        if let cached = templateDecisionByImageID[cacheKey] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let decision = isLikelyMonochromeLightGlyph(icon)

        cacheLock.lock()
        templateDecisionByImageID[cacheKey] = decision
        cacheLock.unlock()
        return decision
    }

    private static func isLikelyMonochromeLightGlyph(_ icon: NSImage) -> Bool {
        guard let cgImage = icon.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }

        let sampleWidth = max(1, min(48, cgImage.width))
        let sampleHeight = max(1, min(48, cgImage.height))
        let bytesPerPixel = 4
        let bytesPerRow = sampleWidth * bytesPerPixel
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        var pixels = [UInt8](repeating: 0, count: bytesPerRow * sampleHeight)
        guard let context: CGContext = pixels.withUnsafeMutableBytes({ rawBufferPointer -> CGContext? in
            guard let baseAddress = rawBufferPointer.baseAddress else { return nil }
            return CGContext(
                data: baseAddress,
                width: sampleWidth,
                height: sampleHeight,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        }) else {
            return false
        }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

        var opaqueCount = 0
        var monochromeCount = 0
        var vividColorCount = 0
        var saturationSum = 0.0

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3]) / 255.0
            if alpha <= 0.03 {
                continue
            }

            let red = Double(pixels[index]) / 255.0
            let green = Double(pixels[index + 1]) / 255.0
            let blue = Double(pixels[index + 2]) / 255.0
            let maxChannel = max(red, max(green, blue))
            let minChannel = min(red, min(green, blue))
            let saturation = maxChannel > 0 ? (maxChannel - minChannel) / maxChannel : 0
            let luminance = (red * 0.2126) + (green * 0.7152) + (blue * 0.0722)

            opaqueCount += 1
            saturationSum += saturation
            if saturation < 0.22 {
                monochromeCount += 1
            }
            if saturation > 0.30 && luminance > 0.08 {
                vividColorCount += 1
            }
        }

        guard opaqueCount >= 5 else { return false }
        let monochromeRatio = Double(monochromeCount) / Double(opaqueCount)
        let vividColorRatio = Double(vividColorCount) / Double(opaqueCount)
        let averageSaturation = saturationSum / Double(opaqueCount)
        if monochromeRatio >= 0.62 && vividColorRatio <= 0.24 {
            return true
        }
        return averageSaturation <= 0.20 && vividColorRatio <= 0.30
    }
}

struct MenuBarFloatingIconDebugSummary {
    let pixelWidth: Int
    let pixelHeight: Int
    let opaqueRatio: Double
    let nearWhiteOpaqueRatio: Double
    let averageLuminance: Double
    let averageSaturation: Double
    let isTemplate: Bool

    var isLikelyWhiteBlob: Bool {
        opaqueRatio >= 0.62
            && nearWhiteOpaqueRatio >= 0.88
            && averageSaturation <= 0.12
            && averageLuminance >= 0.85
    }

    var compactDescription: String {
        let opaque = String(format: "%.2f", opaqueRatio)
        let white = String(format: "%.2f", nearWhiteOpaqueRatio)
        let luminance = String(format: "%.2f", averageLuminance)
        let saturation = String(format: "%.2f", averageSaturation)
        return "px=\(pixelWidth)x\(pixelHeight) opaque=\(opaque) white=\(white) lum=\(luminance) sat=\(saturation) template=\(isTemplate) whiteBlob=\(isLikelyWhiteBlob)"
    }
}

enum MenuBarFloatingIconDiagnostics {
    static func summarize(_ icon: NSImage?) -> MenuBarFloatingIconDebugSummary? {
        guard let icon,
              let cgImage = icon.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let sampleWidth = max(1, min(48, cgImage.width))
        let sampleHeight = max(1, min(48, cgImage.height))
        let bytesPerPixel = 4
        let bytesPerRow = sampleWidth * bytesPerPixel
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        var pixels = [UInt8](repeating: 0, count: bytesPerRow * sampleHeight)
        guard let context: CGContext = pixels.withUnsafeMutableBytes({ rawBufferPointer -> CGContext? in
            guard let baseAddress = rawBufferPointer.baseAddress else { return nil }
            return CGContext(
                data: baseAddress,
                width: sampleWidth,
                height: sampleHeight,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        }) else {
            return nil
        }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

        let totalPixels = sampleWidth * sampleHeight
        var opaqueCount = 0
        var nearWhiteOpaqueCount = 0
        var luminanceSum = 0.0
        var saturationSum = 0.0

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3]) / 255.0
            if alpha <= 0.03 {
                continue
            }

            let red = Double(pixels[index]) / 255.0
            let green = Double(pixels[index + 1]) / 255.0
            let blue = Double(pixels[index + 2]) / 255.0
            let maxChannel = max(red, max(green, blue))
            let minChannel = min(red, min(green, blue))
            let saturation = maxChannel > 0 ? (maxChannel - minChannel) / maxChannel : 0
            let luminance = (red * 0.2126) + (green * 0.7152) + (blue * 0.0722)

            opaqueCount += 1
            luminanceSum += luminance
            saturationSum += saturation

            if red >= 0.93 && green >= 0.93 && blue >= 0.93 {
                nearWhiteOpaqueCount += 1
            }
        }

        let opaqueRatio = totalPixels > 0 ? Double(opaqueCount) / Double(totalPixels) : 0
        let nearWhiteOpaqueRatio = opaqueCount > 0 ? Double(nearWhiteOpaqueCount) / Double(opaqueCount) : 0
        let averageLuminance = opaqueCount > 0 ? (luminanceSum / Double(opaqueCount)) : 0
        let averageSaturation = opaqueCount > 0 ? (saturationSum / Double(opaqueCount)) : 0

        return MenuBarFloatingIconDebugSummary(
            pixelWidth: sampleWidth,
            pixelHeight: sampleHeight,
            opaqueRatio: opaqueRatio,
            nearWhiteOpaqueRatio: nearWhiteOpaqueRatio,
            averageLuminance: averageLuminance,
            averageSaturation: averageSaturation,
            isTemplate: icon.isTemplate
        )
    }
}

enum MenuBarFloatingFallbackIconProvider {
    private static var cachedIconsByKey = [String: NSImage]()

    static func clearCache() {
        cachedIconsByKey.removeAll(keepingCapacity: false)
    }

    static func icon(for item: MenuBarFloatingItemSnapshot) -> NSImage? {
        // Only synthesize fallback symbols for items we can tie to a real status window.
        guard item.windowID != nil else {
            return nil
        }

        let identityToken = [
            item.ownerBundleID.lowercased(),
            item.axIdentifier?.lowercased() ?? "",
            item.title?.lowercased() ?? "",
            item.detail?.lowercased() ?? "",
        ]
        .joined(separator: "|")

        if let cached = cachedIconsByKey[identityToken] {
            return cached
        }

        if let systemSymbol = mappedSystemSymbolIcon(for: item) {
            cachedIconsByKey[identityToken] = systemSymbol
            return systemSymbol
        }

        // Do not fall back to application dock icons for menu bar items.
        // They are frequently inaccurate and confusing vs. actual status glyphs.
        return nil
    }

    private static func mappedSystemSymbolIcon(for item: MenuBarFloatingItemSnapshot) -> NSImage? {
        guard item.ownerBundleID.lowercased().hasPrefix("com.apple.") else {
            return nil
        }

        let normalized = [
            item.axIdentifier?.lowercased(),
            item.title?.lowercased(),
            item.detail?.lowercased(),
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        func makeSymbol(_ name: String) -> NSImage? {
            let image = NSImage(systemSymbolName: name, accessibilityDescription: item.displayName)
            image?.isTemplate = true
            return image
        }

        if normalized.contains("wifi") || normalized.contains("wi-fi") { return makeSymbol("wifi") }
        if normalized.contains("battery") { return makeSymbol("battery.100") }
        if normalized.contains("bluetooth") { return makeSymbol("bolt.horizontal.circle") }
        if normalized.contains("volume") || normalized.contains("sound") { return makeSymbol("speaker.wave.2") }
        if normalized.contains("spotlight") || normalized.contains("search") { return makeSymbol("magnifyingglass") }
        if normalized.contains("clock") || normalized.contains("date") || normalized.contains("calendar") {
            return makeSymbol("clock")
        }
        if normalized.contains("now playing") || normalized.contains("music") { return makeSymbol("music.note") }
        if normalized.contains("control center") || normalized.contains("controlcentre") { return makeSymbol("switch.2") }
        if normalized.contains("siri") { return makeSymbol("sparkles") }
        if normalized.contains("vpn") { return makeSymbol("lock.shield") }
        if normalized.contains("screen") || normalized.contains("display") { return makeSymbol("display") }
        if normalized.contains("keyboard") || normalized.contains("input") { return makeSymbol("keyboard") }
        return nil
    }
}

enum MenuBarStatusWindowCache {
    struct Entry {
        let bounds: CGRect
        let ownerPID: pid_t
    }

    private struct Snapshot {
        var timestamp: TimeInterval = 0
        var entries = [CGWindowID: Entry]()
        var mouseButtonSignature: UInt8 = 0
    }

    private static let lock = NSLock()
    private static var snapshot = Snapshot()

    static func invalidate() {
        lock.lock()
        snapshot = Snapshot()
        lock.unlock()
    }

    static func windowEntries(maxAge: TimeInterval = 0.35) -> [CGWindowID: Entry] {
        let now = ProcessInfo.processInfo.systemUptime
        let buttonSignature = currentMouseButtonSignature()
        lock.lock()
        let age = now - snapshot.timestamp
        if snapshot.timestamp > 0,
           age <= maxAge,
           snapshot.mouseButtonSignature == buttonSignature {
            let cached = snapshot.entries
            lock.unlock()
            return cached
        }
        lock.unlock()

        let freshEntries = fetchEntries()

        lock.lock()
        snapshot.timestamp = now
        snapshot.entries = freshEntries
        snapshot.mouseButtonSignature = buttonSignature
        lock.unlock()
        return freshEntries
    }

    static func windowMap(maxAge: TimeInterval = 0.35) -> [CGWindowID: CGRect] {
        let entries = windowEntries(maxAge: maxAge)
        var map = [CGWindowID: CGRect]()
        map.reserveCapacity(entries.count)
        for (windowID, entry) in entries {
            map[windowID] = entry.bounds
        }
        return map
    }

    static func signature(maxAge: TimeInterval = 0.35) -> [CGWindowID] {
        windowEntries(maxAge: maxAge).keys.sorted()
    }

    static func containsStatusItem(at quartzPoint: CGPoint, maxAge: TimeInterval = 0.2) -> Bool {
        let currentPID = getpid()
        for entry in windowEntries(maxAge: maxAge).values {
            if entry.ownerPID == currentPID {
                continue
            }
            if !isHoverEligibleBounds(entry.bounds) {
                continue
            }
            if entry.bounds.contains(quartzPoint) {
                return true
            }
        }
        return false
    }

    static func containsAnyStatusWindow(at quartzPoint: CGPoint, maxAge: TimeInterval = 0.2) -> Bool {
        let currentPID = getpid()
        for entry in windowEntries(maxAge: maxAge).values {
            if entry.ownerPID == currentPID {
                continue
            }
            let bounds = entry.bounds
            guard bounds.width > 2,
                  bounds.height > 2,
                  bounds.width <= 640,
                  bounds.height <= 90,
                  bounds.width / max(bounds.height, 1) <= 12.0 else {
                continue
            }
            if bounds.contains(quartzPoint) {
                return true
            }
        }
        return false
    }

    private static func isHoverEligibleBounds(_ bounds: CGRect) -> Bool {
        guard bounds.width > 5,
              bounds.height > 5,
              bounds.width <= 360,
              bounds.height <= 72 else {
            return false
        }
        let aspectRatio = bounds.width / max(bounds.height, 1)
        guard aspectRatio <= 6.0 else {
            return false
        }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        guard let screen = MenuBarFloatingCoordinateConverter.screenContaining(quartzPoint: center),
              let displayBounds = MenuBarFloatingCoordinateConverter.displayBounds(of: screen) else {
            return false
        }
        let inferredMenuBarHeight = max(22, min(64, screen.frame.maxY - screen.visibleFrame.maxY))
        let minMenuBandY = displayBounds.maxY - max(40, inferredMenuBarHeight + 14)
        return bounds.maxY >= minMenuBandY
    }

    private static func currentMouseButtonSignature() -> UInt8 {
        let leftDown = CGEventSource.buttonState(.combinedSessionState, button: .left)
        let rightDown = CGEventSource.buttonState(.combinedSessionState, button: .right)
        let centerDown = CGEventSource.buttonState(.combinedSessionState, button: .center)
        var signature: UInt8 = 0
        if leftDown { signature |= 1 << 0 }
        if rightDown { signature |= 1 << 1 }
        if centerDown { signature |= 1 << 2 }
        return signature
    }

    private static func fetchEntries() -> [CGWindowID: Entry] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[CFString: Any]] else {
            return [:]
        }

        let statusLayer = Int(CGWindowLevelForKey(.statusWindow))
        let acceptedLayers = Set([
            statusLayer - 2,
            statusLayer - 1,
            statusLayer,
            statusLayer + 1,
            statusLayer + 2,
        ])

        var entries = [CGWindowID: Entry]()
        entries.reserveCapacity(windowList.count)

        for windowInfo in windowList {
            guard let layer = windowInfo[kCGWindowLayer] as? Int,
                  acceptedLayers.contains(layer),
                  let windowID = windowInfo[kCGWindowNumber] as? CGWindowID,
                  let boundsDict = windowInfo[kCGWindowBounds] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else {
                continue
            }

            guard bounds.width > 3,
                  bounds.height > 3,
                  bounds.width < 280,
                  bounds.height < 56 else {
                continue
            }

            let ownerPID: pid_t = {
                if let pid = windowInfo[kCGWindowOwnerPID] as? Int32 {
                    return pid_t(pid)
                }
                if let pid = windowInfo[kCGWindowOwnerPID] as? Int {
                    return pid_t(pid)
                }
                return 0
            }()

            entries[windowID] = Entry(bounds: bounds, ownerPID: ownerPID)
        }

        return entries
    }
}

enum MenuBarAXTools {
    private static func validatedAXValue(_ rawValue: AnyObject) -> AXValue {
        // Safe because callers gate with CFGetTypeID(rawValue) == AXValueGetTypeID().
        unsafeBitCast(rawValue, to: AXValue.self)
    }

    static func copyAttribute(_ element: AXUIElement, _ attribute: CFString) -> AnyObject? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success, let value else {
            return nil
        }
        return value as AnyObject
    }

    static func copyString(_ element: AXUIElement, _ attribute: CFString) -> String? {
        copyAttribute(element, attribute) as? String
    }

    static func copyChildren(_ element: AXUIElement) -> [AXUIElement] {
        (copyAttribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement]) ?? []
    }

    static func copyPoint(_ element: AXUIElement, _ attribute: CFString) -> CGPoint? {
        guard let rawValue = copyAttribute(element, attribute),
              CFGetTypeID(rawValue) == AXValueGetTypeID() else {
            return nil
        }
        let value = validatedAXValue(rawValue)
        guard
              AXValueGetType(value) == .cgPoint else {
            return nil
        }
        var point = CGPoint.zero
        AXValueGetValue(value, .cgPoint, &point)
        return point
    }

    static func copySize(_ element: AXUIElement, _ attribute: CFString) -> CGSize? {
        guard let rawValue = copyAttribute(element, attribute),
              CFGetTypeID(rawValue) == AXValueGetTypeID() else {
            return nil
        }
        let value = validatedAXValue(rawValue)
        guard
              AXValueGetType(value) == .cgSize else {
            return nil
        }
        var size = CGSize.zero
        AXValueGetValue(value, .cgSize, &size)
        return size
    }

    static func copyFrameQuartz(_ element: AXUIElement) -> CGRect? {
        guard let position = copyPoint(element, kAXPositionAttribute as CFString),
              let size = copySize(element, kAXSizeAttribute as CFString) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    static func availableActions(for element: AXUIElement) -> [String] {
        var actionNames: CFArray?
        guard AXUIElementCopyActionNames(element, &actionNames) == .success,
              let actionNames = actionNames as? [String] else {
            return []
        }
        return actionNames
    }

    static func bestMenuBarAction(for element: AXUIElement) -> CFString {
        let actions = availableActions(for: element)
        if actions.contains(kAXShowMenuAction as String) {
            return kAXShowMenuAction as CFString
        }
        return kAXPressAction as CFString
    }

    static func performAction(_ element: AXUIElement, _ action: CFString) -> Bool {
        AXUIElementPerformAction(element, action) == .success
    }
}

enum MenuBarFloatingCoordinateConverter {
    static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    static func displayBounds(of screen: NSScreen) -> CGRect? {
        guard let id = displayID(for: screen) else {
            return nil
        }
        return CGDisplayBounds(id)
    }

    static func screenContaining(quartzPoint: CGPoint) -> NSScreen? {
        let screens = NSScreen.screens
        if let exact = screens.first(where: { screen in
            guard let bounds = displayBounds(of: screen) else {
                return false
            }
            return bounds.insetBy(dx: -1, dy: -1).contains(quartzPoint)
        }) {
            return exact
        }
        return nearestScreenToQuartzPoint(quartzPoint)
    }

    static func quartzToAppKit(_ quartzRect: CGRect) -> CGRect {
        let point = CGPoint(x: quartzRect.midX, y: quartzRect.midY)
        guard let screen = screenContaining(quartzPoint: point) ?? NSScreen.main,
              let displayBounds = displayBounds(of: screen) else {
            let mainHeight = NSScreen.main?.frame.height ?? 0
            return CGRect(
                x: quartzRect.origin.x,
                y: mainHeight - quartzRect.origin.y - quartzRect.height,
                width: quartzRect.width,
                height: quartzRect.height
            )
        }

        let localX = quartzRect.origin.x - displayBounds.origin.x
        let localY = quartzRect.origin.y - displayBounds.origin.y
        let flippedLocalY = displayBounds.height - localY - quartzRect.height

        return CGRect(
            x: screen.frame.origin.x + localX,
            y: screen.frame.origin.y + flippedLocalY,
            width: quartzRect.width,
            height: quartzRect.height
        )
    }

    static func appKitToQuartz(_ appKitRect: CGRect) -> CGRect {
        let point = CGPoint(x: appKitRect.midX, y: appKitRect.midY)
        guard let screen = screenContaining(appKitPoint: point) ?? NSScreen.main,
              let displayBounds = displayBounds(of: screen) else {
            let mainHeight = NSScreen.main?.frame.height ?? 0
            return CGRect(
                x: appKitRect.origin.x,
                y: mainHeight - appKitRect.origin.y - appKitRect.height,
                width: appKitRect.width,
                height: appKitRect.height
            )
        }

        let localX = appKitRect.origin.x - screen.frame.origin.x
        let localY = appKitRect.origin.y - screen.frame.origin.y
        let flippedLocalY = displayBounds.height - localY - appKitRect.height

        return CGRect(
            x: displayBounds.origin.x + localX,
            y: displayBounds.origin.y + flippedLocalY,
            width: appKitRect.width,
            height: appKitRect.height
        )
    }

    private static func screenContaining(appKitPoint: CGPoint) -> NSScreen? {
        let screens = NSScreen.screens
        if let exact = screens.first(where: { $0.frame.insetBy(dx: -1, dy: -1).contains(appKitPoint) }) {
            return exact
        }
        return nearestScreenToAppKitPoint(appKitPoint)
    }

    private static func nearestScreenToQuartzPoint(_ point: CGPoint) -> NSScreen? {
        var best: (screen: NSScreen, distanceSquared: CGFloat)?

        for screen in NSScreen.screens {
            guard let bounds = displayBounds(of: screen) else { continue }
            let nearestX = min(max(point.x, bounds.minX), bounds.maxX)
            let nearestY = min(max(point.y, bounds.minY), bounds.maxY)
            let dx = point.x - nearestX
            let dy = point.y - nearestY
            let distanceSquared = (dx * dx) + (dy * dy)

            if let best, best.distanceSquared <= distanceSquared {
                continue
            }
            best = (screen, distanceSquared)
        }

        return best?.screen
    }

    private static func nearestScreenToAppKitPoint(_ point: CGPoint) -> NSScreen? {
        var best: (screen: NSScreen, distanceSquared: CGFloat)?

        for screen in NSScreen.screens {
            let frame = screen.frame
            let nearestX = min(max(point.x, frame.minX), frame.maxX)
            let nearestY = min(max(point.y, frame.minY), frame.maxY)
            let dx = point.x - nearestX
            let dy = point.y - nearestY
            let distanceSquared = (dx * dx) + (dy * dy)

            if let best, best.distanceSquared <= distanceSquared {
                continue
            }
            best = (screen, distanceSquared)
        }

        return best?.screen
    }
}
