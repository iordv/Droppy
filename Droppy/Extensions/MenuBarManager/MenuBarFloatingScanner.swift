//
//  MenuBarFloatingScanner.swift
//  Droppy
//
//  Accessibility-based scanner for menu bar items used by the always-hidden bar.
//

import AppKit
import ApplicationServices
import CoreGraphics
import ScreenCaptureKit

private final class MenuBarCaptureBox: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var storage = [(CGWindowID, CGImage, CGRect)]()

    nonisolated func append(_ capture: (CGWindowID, CGImage, CGRect)) {
        lock.lock()
        storage.append(capture)
        lock.unlock()
    }

    nonisolated func snapshot() -> [(CGWindowID, CGImage, CGRect)] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

final class MenuBarFloatingScanner {
    enum Owner: String, CaseIterable {
        case systemUIServer = "com.apple.systemuiserver"
        case controlCenter = "com.apple.controlcenter"
    }

    private struct Candidate {
        let identityBase: String
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
    }

    private let excludedControlItemTokens: Set<String> = [
        "droppymbm_icon",
        "droppymbm_hidden",
        "droppymbm_alwayshidden",
    ]
    private var ownerHasMenuBarRoots = [String: Bool]()
    private var cachedRunningBundleIDs = [String]()
    private var runningBundleCacheTimestamp: TimeInterval = 0
    private var lastFullOwnerDiscoveryTimestamp: TimeInterval = 0
    private let runningBundleCacheInterval: TimeInterval = 2.0
    private let fullOwnerDiscoveryInterval: TimeInterval = 30.0

    private static func validatedAXUIElement(_ rawValue: AnyObject) -> AXUIElement {
        // Safe because callers gate with CFGetTypeID(rawValue) == AXUIElementGetTypeID().
        unsafeBitCast(rawValue, to: AXUIElement.self)
    }

    func scan(includeIcons: Bool, preferredOwnerBundleIDs: Set<String>? = nil) -> [MenuBarFloatingItemSnapshot] {
        var candidates = [Candidate]()
        candidates.reserveCapacity(64)

        for ownerBundleID in ownerBundleIDsToScan(preferredOwnerBundleIDs: preferredOwnerBundleIDs) {
            candidates.append(contentsOf: scanCandidates(ownerBundleID: ownerBundleID, includeIcons: includeIcons))
        }

        let sortedCandidates = candidates.sorted { lhs, rhs in
            let delta = lhs.quartzFrame.minX - rhs.quartzFrame.minX
            if abs(delta) > 0.5 {
                return delta < 0
            }
            if lhs.ownerBundleID != rhs.ownerBundleID {
                return lhs.ownerBundleID < rhs.ownerBundleID
            }
            if lhs.statusItemIndex != rhs.statusItemIndex {
                return (lhs.statusItemIndex ?? Int.max) < (rhs.statusItemIndex ?? Int.max)
            }
            if lhs.axIdentifier != rhs.axIdentifier {
                return (lhs.axIdentifier ?? "") < (rhs.axIdentifier ?? "")
            }
            let lhsTitle = lhs.title ?? ""
            let rhsTitle = rhs.title ?? ""
            if lhsTitle != rhsTitle {
                return lhsTitle < rhsTitle
            }
            return (lhs.detail ?? "") < (rhs.detail ?? "")
        }

        var occurrenceByBase = [String: Int]()
        var snapshots = [MenuBarFloatingItemSnapshot]()
        snapshots.reserveCapacity(sortedCandidates.count)

        for candidate in sortedCandidates {
            let occurrence = occurrenceByBase[candidate.identityBase, default: 0]
            occurrenceByBase[candidate.identityBase] = occurrence + 1

            let id: String
            if occurrence == 0 {
                id = candidate.identityBase
            } else {
                id = "\(candidate.identityBase)#\(occurrence)"
            }

            snapshots.append(
                MenuBarFloatingItemSnapshot(
                    id: id,
                    windowID: candidate.windowID,
                    axElement: candidate.axElement,
                    quartzFrame: candidate.quartzFrame,
                    appKitFrame: candidate.appKitFrame,
                    ownerBundleID: candidate.ownerBundleID,
                    axIdentifier: candidate.axIdentifier,
                    statusItemIndex: candidate.statusItemIndex,
                    title: candidate.title,
                    detail: candidate.detail,
                    icon: candidate.icon
                )
            )
        }

        return snapshots
    }

    private func scanCandidates(ownerBundleID: String, includeIcons: Bool) -> [Candidate] {
        guard let application = NSRunningApplication.runningApplications(withBundleIdentifier: ownerBundleID).first else {
            ownerHasMenuBarRoots[ownerBundleID] = false
            return []
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        let menuBarRoots = menuBarRoots(for: appElement, ownerBundleID: ownerBundleID)
        ownerHasMenuBarRoots[ownerBundleID] = !menuBarRoots.isEmpty
        guard !menuBarRoots.isEmpty else {
            return []
        }

        // Pre-fetch menu bar window list for per-window icon capture.
        let menuBarWindowMap = includeIcons ? buildMenuBarWindowMap() : [:]

        // Pre-capture all icons compositely (transparent backgrounds, no deprecated APIs).
        let compositeImages: [CGWindowID: NSImage]? = includeIcons ? compositeCapture(windowMap: menuBarWindowMap) : nil

        var scannedCandidates = [Candidate]()

        for menuBarRoot in menuBarRoots {
            let menuItems = collectMenuBarItems(from: menuBarRoot)
            for (index, element) in menuItems.enumerated() {
                guard let quartzFrame = MenuBarAXTools.copyFrameQuartz(element) else {
                    continue
                }

                guard isLikelyMenuBarExtra(quartzFrame: quartzFrame) else {
                    continue
                }
                if ownerBundleID == Bundle.main.bundleIdentifier,
                   isLikelyPrimaryAppMenuItem(quartzFrame: quartzFrame) {
                    continue
                }

                let title = normalizeText(MenuBarAXTools.copyString(element, kAXTitleAttribute as CFString))

                let description = normalizeText(MenuBarAXTools.copyString(element, kAXDescriptionAttribute as CFString))
                let help = normalizeText(MenuBarAXTools.copyString(element, kAXHelpAttribute as CFString))
                let detail = description ?? help
                let identifier = normalizeText(MenuBarAXTools.copyString(element, kAXIdentifierAttribute as CFString))
                if isExcludedControlItem(title: title, detail: detail, identifier: identifier) {
                    continue
                }

                // Match this AX item to its window ID via frame overlap.
                let matchedWindowID = findWindowID(for: quartzFrame, in: menuBarWindowMap)

                let icon: NSImage?
                if includeIcons {
                    icon = captureIcon(quartzRect: quartzFrame, windowID: matchedWindowID, compositeImages: compositeImages)
                } else {
                    icon = nil
                }
                let appKitFrame = MenuBarFloatingCoordinateConverter.quartzToAppKit(quartzFrame)

                scannedCandidates.append(
                    Candidate(
                        identityBase: makeIdentityBase(
                            ownerBundleID: ownerBundleID,
                            title: title,
                            detail: detail,
                            identifier: identifier,
                            index: index
                        ),
                        windowID: matchedWindowID,
                        axElement: element,
                        quartzFrame: quartzFrame,
                        appKitFrame: appKitFrame,
                        ownerBundleID: ownerBundleID,
                        axIdentifier: identifier,
                        statusItemIndex: index,
                        title: title,
                        detail: detail,
                        icon: icon
                    )
                )
            }
        }

        return scannedCandidates
    }

    private func menuBarRoots(for appElement: AXUIElement, ownerBundleID: String) -> [AXUIElement] {
        if let raw = MenuBarAXTools.copyAttribute(appElement, "AXExtrasMenuBar" as CFString),
           CFGetTypeID(raw) == AXUIElementGetTypeID() {
            let element = Self.validatedAXUIElement(raw)
            return [element]
        }

        let isOwnAppBundle = Bundle.main.bundleIdentifier == ownerBundleID
        let allowFallbackMenuBar =
            ownerBundleID == Owner.systemUIServer.rawValue
            || ownerBundleID == Owner.controlCenter.rawValue
            || isOwnAppBundle
        guard allowFallbackMenuBar else {
            return []
        }

        if let raw = MenuBarAXTools.copyAttribute(appElement, kAXMenuBarAttribute as CFString),
           CFGetTypeID(raw) == AXUIElementGetTypeID() {
            let element = Self.validatedAXUIElement(raw)
            return [element]
        }

        return []
    }

    private func collectMenuBarItems(from root: AXUIElement) -> [AXUIElement] {
        var items = [AXUIElement]()

        func visit(_ node: AXUIElement) {
            let role = MenuBarAXTools.copyString(node, kAXRoleAttribute as CFString) ?? ""
            if role == (kAXMenuBarItemRole as String) || role == "AXMenuBarItem" {
                items.append(node)
                return
            }

            for child in MenuBarAXTools.copyChildren(node) {
                visit(child)
            }
        }

        visit(root)
        return items
    }

    private func ownerBundleIDsToScan(preferredOwnerBundleIDs: Set<String>?) -> [String] {
        var ordered = [String]()
        var seen = Set<String>()

        for owner in Owner.allCases.map(\.rawValue) {
            if seen.insert(owner).inserted {
                ordered.append(owner)
            }
        }

        if let preferredOwnerBundleIDs, !preferredOwnerBundleIDs.isEmpty {
            for bundleID in preferredOwnerBundleIDs.sorted() {
                if seen.insert(bundleID).inserted {
                    ordered.append(bundleID)
                }
            }
            return ordered
        }

        let now = ProcessInfo.processInfo.systemUptime
        let shouldRunFullDiscovery =
            ownerHasMenuBarRoots.isEmpty
            || (now - lastFullOwnerDiscoveryTimestamp) >= fullOwnerDiscoveryInterval
        let runningBundleIDs: [String]
        if shouldRunFullDiscovery {
            runningBundleIDs = runningBundleIDsSnapshot()
            lastFullOwnerDiscoveryTimestamp = now
        } else {
            runningBundleIDs = ownerHasMenuBarRoots
                .compactMap { (bundleID, hasRoots) in
                    hasRoots ? bundleID : nil
                }
                .sorted()
        }

        for bundleID in runningBundleIDs {
            if seen.insert(bundleID).inserted {
                ordered.append(bundleID)
            }
        }

        return ordered
    }

    private func runningBundleIDsSnapshot() -> [String] {
        let now = ProcessInfo.processInfo.systemUptime
        if cachedRunningBundleIDs.isEmpty || (now - runningBundleCacheTimestamp) >= runningBundleCacheInterval {
            cachedRunningBundleIDs = NSWorkspace.shared.runningApplications
                .compactMap(\.bundleIdentifier)
                .sorted()
            runningBundleCacheTimestamp = now
        }
        return cachedRunningBundleIDs
    }

    private func normalizeText(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func isExcludedControlItem(title: String?, detail: String?, identifier: String?) -> Bool {
        let fields = [title, detail, identifier]
            .compactMap { $0?.lowercased() }
        for field in fields {
            if excludedControlItemTokens.contains(field) {
                return true
            }
            if excludedControlItemTokens.contains(where: { field.contains($0) }) {
                return true
            }
        }
        return false
    }

    private func leadingToken(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let token = value
            .split(separator: ",", maxSplits: 1)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let token, !token.isEmpty {
            return token
        }
        return value
    }

    private func makeIdentityBase(
        ownerBundleID: String,
        title: String?,
        detail: String?,
        identifier: String?,
        index: Int
    ) -> String {
        if let identifier, !identifier.isEmpty {
            return "\(ownerBundleID)::axid:\(identifier)"
        }

        if let moduleToken = canonicalModuleIdentityToken(
            ownerBundleID: ownerBundleID,
            title: title,
            detail: detail,
            identifier: identifier
        ) {
            return "\(ownerBundleID)::module:\(moduleToken)"
        }

        if let detailToken = leadingToken(detail), !detailToken.isEmpty {
            return "\(ownerBundleID)::detail:\(detailToken)"
        }

        if let titleToken = leadingToken(title), !titleToken.isEmpty {
            return "\(ownerBundleID)::title:\(titleToken)"
        }

        return "\(ownerBundleID)::statusItem:\(index)"
    }

    private func canonicalModuleIdentityToken(
        ownerBundleID: String,
        title: String?,
        detail: String?,
        identifier: String?
    ) -> String? {
        guard ownerBundleID == Owner.controlCenter.rawValue || ownerBundleID == Owner.systemUIServer.rawValue else {
            return nil
        }
        let haystack = [
            identifier?.lowercased(),
            title?.lowercased(),
            detail?.lowercased(),
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        if haystack.contains("now playing") {
            return "now-playing"
        }
        return nil
    }

    private func isLikelyMenuBarExtra(quartzFrame: CGRect) -> Bool {
        guard quartzFrame.width > 3,
              quartzFrame.height > 3,
              quartzFrame.width < 180,
              quartzFrame.height < 50 else {
            return false
        }
        return true
    }

    private func isLikelyPrimaryAppMenuItem(quartzFrame: CGRect) -> Bool {
        let midpoint = CGPoint(x: quartzFrame.midX, y: quartzFrame.midY)
        guard let screen = MenuBarFloatingCoordinateConverter.screenContaining(quartzPoint: midpoint),
              let bounds = MenuBarFloatingCoordinateConverter.displayBounds(of: screen) else {
            return false
        }
        return midpoint.x < bounds.midX
    }

    // MARK: - Window ID Lookup

    /// Builds a map of CGWindowID → CGRect for all current menu bar item windows.
    /// Uses CGWindowListCopyWindowInfo which returns windows with their bounds.
    private func buildMenuBarWindowMap() -> [CGWindowID: CGRect] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[CFString: Any]] else {
            return [:]
        }

        var map = [CGWindowID: CGRect]()
        for windowInfo in windowList {
            // Menu bar items are at window layer 25 (kCGStatusWindowLevel).
            guard let layer = windowInfo[kCGWindowLayer] as? Int,
                  layer == 25,
                  let windowID = windowInfo[kCGWindowNumber] as? CGWindowID,
                  let boundsDict = windowInfo[kCGWindowBounds] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let w = boundsDict["Width"],
                  let h = boundsDict["Height"],
                  w > 1, h > 1, w < 180, h < 50 else {
                continue
            }
            map[windowID] = CGRect(x: x, y: y, width: w, height: h)
        }
        return map
    }

    /// Finds the CGWindowID whose bounds best match the given AX element frame.
    private func findWindowID(for quartzFrame: CGRect, in windowMap: [CGWindowID: CGRect]) -> CGWindowID? {
        var bestID: CGWindowID?
        var bestOverlap: CGFloat = 0

        for (windowID, windowBounds) in windowMap {
            let intersection = quartzFrame.intersection(windowBounds)
            guard !intersection.isNull else { continue }
            let overlap = intersection.width * intersection.height
            let matchQuality = overlap / max(1, quartzFrame.width * quartzFrame.height)
            if matchQuality > 0.5, overlap > bestOverlap {
                bestOverlap = overlap
                bestID = windowID
            }
        }
        return bestID
    }

    // MARK: - Icon Capture

    /// Batch-captures all menu bar item windows with transparent backgrounds.
    /// Uses CGWindowListCreateImage for predictable synchronous behavior.
    private func compositeCapture(windowMap: [CGWindowID: CGRect]) -> [CGWindowID: NSImage] {
        guard !windowMap.isEmpty else { return [:] }
        return compositeCaptureLegacy(windowMap: windowMap)
    }

    /// ScreenCaptureKit-based capture (macOS 14.0+). Captures each window independently
    /// with full transparency — no menu bar background, no wallpaper bleed.
    @available(macOS 14.0, *)
    private func compositeCaptureModern(windowMap: [CGWindowID: CGRect]) -> [CGWindowID: NSImage] {
        let box = MenuBarCaptureBox()
        let semaphore = DispatchSemaphore(value: 0)
        let mapSnapshot = windowMap

        // Keep priority aligned with the caller to avoid user-interactive waits on lower-QoS work.
        Task.detached(priority: .high) {
            defer { semaphore.signal() }
            guard let content = try? await SCShareableContent.excludingDesktopWindows(
                true, onScreenWindowsOnly: true
            ) else { return }

            // Build window ID → SCWindow lookup.
            var scWindows = [CGWindowID: SCWindow]()
            for w in content.windows {
                scWindows[w.windowID] = w
            }

            let config = SCStreamConfiguration()
            config.captureResolution = .best
            config.showsCursor = false

            for (wid, bounds) in mapSnapshot {
                guard let scw = scWindows[wid] else { continue }
                let filter = SCContentFilter(desktopIndependentWindow: scw)
                if let img = try? await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                ) {
                    box.append((wid, img, bounds))
                }
            }
        }
        semaphore.wait()

        // Process captures synchronously (transparency/suspicious checks).
        var results = [CGWindowID: NSImage]()
        for (wid, cgImage, bounds) in box.snapshot() {
            guard !isFullyTransparent(cgImage) else { continue }
            let nsImage = NSImage(
                cgImage: cgImage,
                size: NSSize(width: bounds.width, height: bounds.height)
            )
            guard !isSuspiciousCapture(nsImage) else { continue }
            results[wid] = nsImage
        }
        return results
    }

    /// Legacy capture using CGWindowListCreateImage (pre-macOS 14).
    private func compositeCaptureLegacy(windowMap: [CGWindowID: CGRect]) -> [CGWindowID: NSImage] {
        var results = [CGWindowID: NSImage]()
        let captureOption: CGWindowImageOption = [.boundsIgnoreFraming, .bestResolution]

        for (windowID, bounds) in windowMap {
            guard let cgImage = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                windowID,
                captureOption
            ) else {
                continue
            }
            guard !isFullyTransparent(cgImage) else { continue }
            let nsImage = NSImage(
                cgImage: cgImage,
                size: NSSize(width: bounds.width, height: bounds.height)
            )
            guard !isSuspiciousCapture(nsImage) else { continue }
            results[windowID] = nsImage
        }
        return results
    }

    private func captureIcon(quartzRect: CGRect, windowID: CGWindowID?, compositeImages: [CGWindowID: NSImage]?) -> NSImage? {
        guard quartzRect.width > 1, quartzRect.height > 1 else {
            return nil
        }

        // Primary path: use pre-captured composite image.
        if let windowID, let image = compositeImages?[windowID] {
            return image
        }

        // Fallback: region-based capture with background removal.
        return captureIconRegionBased(quartzRect: quartzRect)
    }

    /// Returns true if the image is fully transparent (all alpha values near zero).
    private func isFullyTransparent(_ image: CGImage) -> Bool {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return true }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let context: CGContext = pixels.withUnsafeMutableBytes({ rawBufferPointer -> CGContext? in
            guard let baseAddress = rawBufferPointer.baseAddress else { return nil }
            return CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        }) else {
            return true
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        for index in stride(from: 3, to: pixels.count, by: 4) {
            if pixels[index] > 4 {
                return false
            }
        }
        return true
    }

    /// Legacy region-based capture using CGDisplayCreateImage.
    /// Used as a fallback when window ID matching fails.
    private func captureIconRegionBased(quartzRect: CGRect) -> NSImage? {
        let center = CGPoint(x: quartzRect.midX, y: quartzRect.midY)
        guard let screen = MenuBarFloatingCoordinateConverter.screenContaining(quartzPoint: center),
              let displayID = MenuBarFloatingCoordinateConverter.displayID(for: screen),
              let displayBounds = MenuBarFloatingCoordinateConverter.displayBounds(of: screen) else {
            return nil
        }

        let localRect = CGRect(
            x: quartzRect.origin.x - displayBounds.origin.x,
            y: quartzRect.origin.y - displayBounds.origin.y,
            width: quartzRect.width,
            height: quartzRect.height
        )
        let captureScale = effectiveCaptureScale(
            quartzRect: quartzRect,
            screen: screen,
            displayBounds: displayBounds,
            displayID: displayID
        )
        let scaledRect = CGRect(
            x: localRect.origin.x * captureScale,
            y: localRect.origin.y * captureScale,
            width: localRect.width * captureScale,
            height: localRect.height * captureScale
        ).integral
        let displayPixelBounds = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(CGDisplayPixelsWide(displayID)),
            height: CGFloat(CGDisplayPixelsHigh(displayID))
        )
        let clampedRect = clampCaptureRect(scaledRect, within: displayPixelBounds)
        guard clampedRect.width > 1, clampedRect.height > 1 else {
            return nil
        }

        guard let image = CGDisplayCreateImage(displayID, rect: clampedRect) else {
            return nil
        }

        let rawImage = NSImage(
            cgImage: image,
            size: NSSize(width: quartzRect.width, height: quartzRect.height)
        )

        if let cleanedImage = removeMenuBarBackground(from: image) {
            let cleanedNSImage = NSImage(
                cgImage: cleanedImage,
                size: NSSize(width: quartzRect.width, height: quartzRect.height)
            )
            if !isSuspiciousCapture(cleanedNSImage) {
                return cleanedNSImage
            }
        }

        if !isSuspiciousCapture(rawImage) {
            return rawImage
        }

        return nil
    }

    private func clampCaptureRect(_ rect: CGRect, within bounds: CGRect) -> CGRect {
        var clamped = rect.intersection(bounds)
        if clamped.origin.x < bounds.minX { clamped.origin.x = bounds.minX }
        if clamped.origin.y < bounds.minY { clamped.origin.y = bounds.minY }
        if clamped.maxX > bounds.maxX { clamped.size.width = max(0, bounds.maxX - clamped.minX) }
        if clamped.maxY > bounds.maxY { clamped.size.height = max(0, bounds.maxY - clamped.minY) }
        return clamped.integral
    }

    private func effectiveCaptureScale(
        quartzRect: CGRect,
        screen: NSScreen,
        displayBounds: CGRect,
        displayID: CGDirectDisplayID
    ) -> CGFloat {
        let screenScale = max(1.0, screen.backingScaleFactor)
        let pixelScaleX = CGFloat(CGDisplayPixelsWide(displayID)) / max(1.0, displayBounds.width)
        let pixelScaleY = CGFloat(CGDisplayPixelsHigh(displayID)) / max(1.0, displayBounds.height)
        let inferredScale = max(screenScale, min(3.0, (pixelScaleX + pixelScaleY) / 2.0))
        let statusBarHeight = max(1, NSStatusBar.system.thickness)
        let looksAlreadyPixelAligned = quartzRect.height >= (statusBarHeight * 1.6)
        return looksAlreadyPixelAligned ? 1.0 : inferredScale
    }

    private func removeMenuBarBackground(from image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > 2, height > 2 else { return image }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let drawContext: CGContext = pixels.withUnsafeMutableBytes({ rawBufferPointer -> CGContext? in
            guard let baseAddress = rawBufferPointer.baseAddress else { return nil }
            return CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        }) else {
            return image
        }

        drawContext.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let pixelCount = width * height
        let opaqueCount = stride(from: 0, to: pixels.count, by: 4).reduce(0) { partial, index in
            partial + (pixels[index + 3] > 250 ? 1 : 0)
        }
        guard Double(opaqueCount) / Double(max(pixelCount, 1)) > 0.9 else {
            return image
        }

        let border = max(1, min(2, min(width, height) / 5))
        var bgR: Double = 0
        var bgG: Double = 0
        var bgB: Double = 0
        var sampleCount = 0

        func samplePixel(x: Int, y: Int) {
            let idx = ((y * width) + x) * 4
            bgR += Double(pixels[idx])
            bgG += Double(pixels[idx + 1])
            bgB += Double(pixels[idx + 2])
            sampleCount += 1
        }

        for y in 0 ..< height {
            for x in 0 ..< width where x < border || x >= (width - border) || y < border || y >= (height - border) {
                samplePixel(x: x, y: y)
            }
        }
        guard sampleCount > 0 else { return image }

        bgR /= Double(sampleCount)
        bgG /= Double(sampleCount)
        bgB /= Double(sampleCount)

        var borderDistanceSum: Double = 0
        for y in 0 ..< height {
            for x in 0 ..< width where x < border || x >= (width - border) || y < border || y >= (height - border) {
                let idx = ((y * width) + x) * 4
                let dr = Double(pixels[idx]) - bgR
                let dg = Double(pixels[idx + 1]) - bgG
                let db = Double(pixels[idx + 2]) - bgB
                borderDistanceSum += (dr * dr) + (dg * dg) + (db * db)
            }
        }
        let borderVariance = borderDistanceSum / Double(sampleCount)
        let baseThresholdSquared: Double = 28.0 * 28.0
        let adaptiveThresholdSquared = min(
            54.0 * 54.0,
            max(baseThresholdSquared, (borderVariance * 2.2) + (14.0 * 14.0))
        )
        let interiorPocketThresholdSquared = min(62.0 * 62.0, adaptiveThresholdSquared * 1.12)

        var visited = [Bool](repeating: false, count: pixelCount)
        var queue = [(Int, Int)]()
        var queueIndex = 0

        func isBackgroundCandidate(x: Int, y: Int, thresholdSquared: Double) -> Bool {
            let idx = ((y * width) + x) * 4
            let alpha = pixels[idx + 3]
            if alpha < 6 { return true }
            let dr = Double(pixels[idx]) - bgR
            let dg = Double(pixels[idx + 1]) - bgG
            let db = Double(pixels[idx + 2]) - bgB
            return (dr * dr) + (dg * dg) + (db * db) <= thresholdSquared
        }

        func enqueueBorderPixel(x: Int, y: Int) {
            let flatIndex = (y * width) + x
            guard !visited[flatIndex] else { return }
            guard isBackgroundCandidate(x: x, y: y, thresholdSquared: adaptiveThresholdSquared) else { return }
            visited[flatIndex] = true
            queue.append((x, y))
        }

        for x in 0 ..< width {
            enqueueBorderPixel(x: x, y: 0)
            enqueueBorderPixel(x: x, y: height - 1)
        }
        for y in 0 ..< height {
            enqueueBorderPixel(x: 0, y: y)
            enqueueBorderPixel(x: width - 1, y: y)
        }

        while queueIndex < queue.count {
            let (x, y) = queue[queueIndex]
            queueIndex += 1

            let idx = ((y * width) + x) * 4
            pixels[idx] = 0
            pixels[idx + 1] = 0
            pixels[idx + 2] = 0
            pixels[idx + 3] = 0

            let neighbors = [
                (x + 1, y),
                (x - 1, y),
                (x, y + 1),
                (x, y - 1),
            ]

            for (nx, ny) in neighbors {
                guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                let flatIndex = (ny * width) + nx
                guard !visited[flatIndex] else { continue }
                guard isBackgroundCandidate(x: nx, y: ny, thresholdSquared: adaptiveThresholdSquared) else { continue }
                visited[flatIndex] = true
                queue.append((nx, ny))
            }
        }

        // Remove enclosed background pockets (e.g. ring/circle interiors) that don't touch borders.
        for y in 0 ..< height {
            for x in 0 ..< width {
                let idx = ((y * width) + x) * 4
                guard pixels[idx + 3] > 18 else { continue }
                guard isBackgroundCandidate(x: x, y: y, thresholdSquared: interiorPocketThresholdSquared) else { continue }
                pixels[idx] = 0
                pixels[idx + 1] = 0
                pixels[idx + 2] = 0
                pixels[idx + 3] = 0
            }
        }

        func clearRowIfLikelySeparatorArtifact(_ y: Int) {
            guard y >= 0, y < height else { return }

            var opaque = 0
            var sumR: Double = 0
            var sumG: Double = 0
            var sumB: Double = 0

            for x in 0 ..< width {
                let idx = ((y * width) + x) * 4
                let alpha = pixels[idx + 3]
                if alpha <= 18 { continue }
                opaque += 1
                sumR += Double(pixels[idx])
                sumG += Double(pixels[idx + 1])
                sumB += Double(pixels[idx + 2])
            }

            let coverage = Double(opaque) / Double(max(width, 1))
            guard opaque > 0, coverage >= 0.48 else { return }

            let meanR = sumR / Double(opaque)
            let meanG = sumG / Double(opaque)
            let meanB = sumB / Double(opaque)
            let luminance = (meanR * 0.2126) + (meanG * 0.7152) + (meanB * 0.0722)

            var varianceSum: Double = 0
            for x in 0 ..< width {
                let idx = ((y * width) + x) * 4
                let alpha = pixels[idx + 3]
                if alpha <= 18 { continue }
                let dr = Double(pixels[idx]) - meanR
                let dg = Double(pixels[idx + 1]) - meanG
                let db = Double(pixels[idx + 2]) - meanB
                varianceSum += (dr * dr) + (dg * dg) + (db * db)
            }
            let variance = varianceSum / Double(max(opaque, 1))

            // Thin, flat, mostly monochrome rows at extreme edges are almost always menu-bar border captures.
            if variance <= (18.0 * 18.0), luminance <= 210 {
                for x in 0 ..< width {
                    let idx = ((y * width) + x) * 4
                    pixels[idx] = 0
                    pixels[idx + 1] = 0
                    pixels[idx + 2] = 0
                    pixels[idx + 3] = 0
                }
            }
        }

        clearRowIfLikelySeparatorArtifact(0)
        clearRowIfLikelySeparatorArtifact(1)
        clearRowIfLikelySeparatorArtifact(height - 2)
        clearRowIfLikelySeparatorArtifact(height - 1)

        let foregroundCount = stride(from: 0, to: pixels.count, by: 4).reduce(0) { partial, index in
            partial + (pixels[index + 3] > 18 ? 1 : 0)
        }
        guard foregroundCount >= max(8, pixelCount / 60) else {
            return image
        }

        return pixels.withUnsafeMutableBytes {
            guard let baseAddress = $0.baseAddress else { return nil }
            guard let outputContext = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                return nil
            }
            return outputContext.makeImage()
        }
    }

    private func isSuspiciousCapture(_ image: NSImage) -> Bool {
        guard let cgImage = image.cgImage(
            forProposedRect: nil,
            context: nil,
            hints: nil
        ) else {
            return true
        }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return true }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let context: CGContext = pixels.withUnsafeMutableBytes({ rawBufferPointer -> CGContext? in
            guard let baseAddress = rawBufferPointer.baseAddress else { return nil }
            return CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        }) else {
            return true
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var foregroundCount = 0
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0

        for y in 0 ..< height {
            for x in 0 ..< width {
                let idx = ((y * width) + x) * 4
                if pixels[idx + 3] > 18 {
                    foregroundCount += 1
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard foregroundCount >= max(8, (width * height) / 80) else {
            return true
        }

        let bboxWidth = max(1, maxX - minX + 1)
        let bboxHeight = max(1, maxY - minY + 1)
        let widthRatio = Double(bboxWidth) / Double(width)
        let heightRatio = Double(bboxHeight) / Double(height)
        let areaRatio = Double(foregroundCount) / Double(width * height)
        let edgeCount = max((width * 2) + (max(0, height - 2) * 2), 1)
        var edgeOpaqueCount = 0

        if height > 0 {
            for x in 0 ..< width {
                let topIdx = x * 4
                if pixels[topIdx + 3] > 18 {
                    edgeOpaqueCount += 1
                }
                if height > 1 {
                    let bottomIdx = (((height - 1) * width) + x) * 4
                    if pixels[bottomIdx + 3] > 18 {
                        edgeOpaqueCount += 1
                    }
                }
            }
        }

        if width > 1, height > 2 {
            for y in 1 ..< (height - 1) {
                let leftIdx = ((y * width) * 4)
                if pixels[leftIdx + 3] > 18 {
                    edgeOpaqueCount += 1
                }
                let rightIdx = (((y * width) + (width - 1)) * 4)
                if pixels[rightIdx + 3] > 18 {
                    edgeOpaqueCount += 1
                }
            }
        }
        let edgeOpaqueRatio = Double(edgeOpaqueCount) / Double(edgeCount)

        if widthRatio < 0.14 || heightRatio < 0.14 {
            return true
        }
        if widthRatio > 0.995 && heightRatio > 0.995 && areaRatio > 0.9 {
            return true
        }
        if areaRatio < 0.04 {
            return true
        }
        if areaRatio > 0.92 {
            return true
        }
        if edgeOpaqueRatio > 0.78 {
            return true
        }
        return false
    }

}
