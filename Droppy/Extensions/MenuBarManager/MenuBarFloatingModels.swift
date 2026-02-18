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

enum MenuBarFloatingFallbackIconProvider {
    private static var cachedIconsByKey = [String: NSImage]()

    static func clearCache() {
        cachedIconsByKey.removeAll(keepingCapacity: false)
    }

    static func icon(for item: MenuBarFloatingItemSnapshot) -> NSImage? {
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

        let bundleKey = item.ownerBundleID.lowercased()
        if let cachedBundleIcon = cachedIconsByKey[bundleKey] {
            cachedIconsByKey[identityToken] = cachedBundleIcon
            return cachedBundleIcon
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.ownerBundleID) else {
            return nil
        }

        let bundleIcon = NSWorkspace.shared.icon(forFile: appURL.path)
        let iconDimension = max(16, min(24, round(NSStatusBar.system.thickness)))
        bundleIcon.size = NSSize(width: iconDimension, height: iconDimension)
        bundleIcon.isTemplate = false
        cachedIconsByKey[bundleKey] = bundleIcon
        cachedIconsByKey[identityToken] = bundleIcon
        return bundleIcon
    }

    private static func mappedSystemSymbolIcon(for item: MenuBarFloatingItemSnapshot) -> NSImage? {
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
