//
//  MenuBarFloatingWindows.swift
//  Droppy
//
//  Window controllers used by the always-hidden floating bar.
//

import AppKit
import SwiftUI

private enum FloatingBarMetrics {
    static func slotWidth(for item: MenuBarFloatingItemSnapshot) -> CGFloat {
        MenuBarFloatingIconLayout.nativeIconSize(for: item).width + 8
    }

    static func contentWidth(for items: [MenuBarFloatingItemSnapshot]) -> CGFloat {
        items.reduce(0) { partial, item in
            partial + slotWidth(for: item)
        }
    }

    static func rowHeight(for items: [MenuBarFloatingItemSnapshot]) -> CGFloat {
        let maxIconHeight = items.map { MenuBarFloatingIconLayout.nativeIconSize(for: $0).height }.max() ?? NSStatusBar.system.thickness
        return max(28, maxIconHeight + 8)
    }
    static let horizontalPadding: CGFloat = 10
    static let verticalPadding: CGFloat = 8
}

@MainActor
final class MenuBarMaskController {
    private var windowsByID: [String: NSWindow] = [:]
    private var preparedSnapshotByID: [String: NSImage] = [:]

    func prepareBackgroundSnapshots(for hiddenItems: [MenuBarFloatingItemSnapshot]) {
        let keepIDs = Set(hiddenItems.map(\.id))
        preparedSnapshotByID = preparedSnapshotByID.filter { keepIDs.contains($0.key) }

        for item in hiddenItems {
            guard preparedSnapshotByID[item.id] == nil else { continue }
            guard let snapshot = captureBackgroundSnapshot(for: item) else { continue }
            preparedSnapshotByID[item.id] = snapshot
        }
    }

    func clearPreparedSnapshots() {
        preparedSnapshotByID.removeAll()
    }

    func update(hiddenItems: [MenuBarFloatingItemSnapshot], usePreparedSnapshots: Bool) {
        let nextIDs = Set(hiddenItems.map(\.id))
        let currentIDs = Set(windowsByID.keys)

        for removedID in currentIDs.subtracting(nextIDs) {
            windowsByID[removedID]?.orderOut(nil)
            windowsByID.removeValue(forKey: removedID)
        }

        for item in hiddenItems {
            let window = windowsByID[item.id] ?? makeWindow()
            windowsByID[item.id] = window
            window.setFrame(item.appKitFrame, display: false)
            if usePreparedSnapshots {
                guard let snapshot = preparedSnapshotByID[item.id] else {
                    window.orderOut(nil)
                    continue
                }
                applySnapshot(snapshot, to: window)
            } else {
                applyMaterialMask(to: window)
            }
            window.orderFrontRegardless()
        }
    }

    func hideAll() {
        for window in windowsByID.values {
            window.orderOut(nil)
        }
    }

    func windowNumber(for id: String) -> Int? {
        windowsByID[id]?.windowNumber
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.ignoresMouseEvents = true
        applyMaterialMask(to: window)

        return window
    }

    private func applyMaterialMask(to window: NSWindow) {
        if let effect = window.contentView as? NSVisualEffectView {
            effect.frame = window.contentView?.bounds ?? .zero
            return
        }

        let effect = NSVisualEffectView(frame: .zero)
        effect.autoresizingMask = [.width, .height]
        effect.material = .titlebar
        effect.blendingMode = .withinWindow
        effect.state = .active
        window.contentView = effect
    }

    private func applySnapshot(_ snapshot: NSImage, to window: NSWindow) {
        if let imageView = window.contentView as? NSImageView {
            imageView.image = snapshot
            imageView.frame = window.contentView?.bounds ?? .zero
            return
        }

        let imageView = NSImageView(frame: .zero)
        imageView.autoresizingMask = [.width, .height]
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleAxesIndependently
        imageView.image = snapshot
        window.contentView = imageView
    }

    private func captureBackgroundSnapshot(for item: MenuBarFloatingItemSnapshot) -> NSImage? {
        let quartzRect = item.quartzFrame
        guard quartzRect.width > 1, quartzRect.height > 1 else { return nil }

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
        guard clampedRect.width > 1, clampedRect.height > 1,
              let cgImage = CGDisplayCreateImage(displayID, rect: clampedRect) else {
            return nil
        }

        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: quartzRect.width, height: quartzRect.height)
        )
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
}

@MainActor
final class MenuBarFloatingPanelController {
    private var panel: FloatingPanel?
    private var hostingView: NSHostingView<MenuBarFloatingBarView>?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func containsMouseLocation(_ point: CGPoint = NSEvent.mouseLocation) -> Bool {
        guard let panel, panel.isVisible else { return false }
        // Slightly expanded hit area keeps behavior stable near rounded edges.
        return panel.frame.insetBy(dx: -4, dy: -4).contains(point)
    }

    func show(
        items: [MenuBarFloatingItemSnapshot],
        onPress: @escaping (MenuBarFloatingItemSnapshot) -> Void
    ) {
        if panel == nil {
            panel = makePanel()
        }

        let content = MenuBarFloatingBarView(items: items, onPress: onPress)
        if let hostingView {
            hostingView.rootView = content
        } else {
            let view = NSHostingView(rootView: content)
            view.translatesAutoresizingMaskIntoConstraints = false
            hostingView = view
            panel?.contentView = view
        }

        positionPanel(for: items)
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.animationBehavior = .none
        return panel
    }

    private func positionPanel(for items: [MenuBarFloatingItemSnapshot]) {
        guard let panel else { return }
        guard let screen = bestScreen(for: items) ?? NSScreen.main else { return }

        let contentWidth = FloatingBarMetrics.contentWidth(for: items)
        let width = max(
            140,
            min(
                screen.frame.width - 12,
                contentWidth + (FloatingBarMetrics.horizontalPadding * 2)
            )
        )
        let rowHeight = FloatingBarMetrics.rowHeight(for: items)
        let height = rowHeight + (FloatingBarMetrics.verticalPadding * 2)

        let menuBarHeight = NSStatusBar.system.thickness
        let originX = screen.frame.maxX - width - 8
        let originY = screen.frame.maxY - menuBarHeight - height - 10

        panel.setFrame(
            CGRect(
                x: originX,
                y: originY,
                width: width,
                height: height
            ),
            display: true
        )
    }

    private func bestScreen(for items: [MenuBarFloatingItemSnapshot]) -> NSScreen? {
        // Priority 1: Screen owning the control items (definitive anchor)
        if let controlScreen = screenForControlItemFrames() {
            return controlScreen
        }

        // Priority 2: Screen with the most items
        if let mostItemsScreen = screenWithMostItems(items) {
            return mostItemsScreen
        }

        // Priority 3: Mouse screen (only if pointer is near the menu bar)
        let mouseLocation = NSEvent.mouseLocation
        if let mouseScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            let pointerNearMenuBar = mouseLocation.y >= (mouseScreen.frame.maxY - max(28, NSStatusBar.system.thickness + 4))
            if pointerNearMenuBar {
                return mouseScreen
            }
        }

        // Priority 4: Absolute fallback
        return NSScreen.main
    }

    private func screenForControlItemFrames() -> NSScreen? {
        if let hiddenFrame = MenuBarManager.shared.controlItemFrame(for: .hidden),
           let hiddenScreen = NSScreen.screens.first(where: { $0.frame.intersects(hiddenFrame) }) {
            return hiddenScreen
        }
        if let alwaysHiddenFrame = MenuBarManager.shared.controlItemFrame(for: .alwaysHidden),
           let alwaysHiddenScreen = NSScreen.screens.first(where: { $0.frame.intersects(alwaysHiddenFrame) }) {
            return alwaysHiddenScreen
        }
        return nil
    }

    private func screenWithMostItems(_ items: [MenuBarFloatingItemSnapshot]) -> NSScreen? {
        guard !items.isEmpty else { return nil }

        var countByDisplayID = [CGDirectDisplayID: Int]()
        var screenByDisplayID = [CGDirectDisplayID: NSScreen]()

        for item in items {
            let point = CGPoint(x: item.quartzFrame.midX, y: item.quartzFrame.midY)
            guard let itemScreen = MenuBarFloatingCoordinateConverter.screenContaining(quartzPoint: point),
                  let itemDisplayID = MenuBarFloatingCoordinateConverter.displayID(for: itemScreen) else {
                continue
            }
            countByDisplayID[itemDisplayID, default: 0] += 1
            screenByDisplayID[itemDisplayID] = itemScreen
        }

        guard !countByDisplayID.isEmpty else { return nil }

        let bestDisplayID = countByDisplayID.keys.max { lhs, rhs in
            let lhsCount = countByDisplayID[lhs] ?? 0
            let rhsCount = countByDisplayID[rhs] ?? 0
            if lhsCount != rhsCount {
                return lhsCount < rhsCount
            }
            let lhsMaxX = screenByDisplayID[lhs]?.frame.maxX ?? 0
            let rhsMaxX = screenByDisplayID[rhs]?.frame.maxX ?? 0
            return lhsMaxX < rhsMaxX
        }

        guard let bestDisplayID else { return nil }
        return screenByDisplayID[bestDisplayID]
    }

    private func hasItems(_ items: [MenuBarFloatingItemSnapshot], on screen: NSScreen) -> Bool {
        guard let displayID = MenuBarFloatingCoordinateConverter.displayID(for: screen) else {
            return false
        }
        for item in items {
            let itemPoint = CGPoint(x: item.quartzFrame.midX, y: item.quartzFrame.midY)
            guard let itemScreen = MenuBarFloatingCoordinateConverter.screenContaining(quartzPoint: itemPoint),
                  let itemDisplayID = MenuBarFloatingCoordinateConverter.displayID(for: itemScreen) else {
                continue
            }
            if itemDisplayID == displayID {
                return true
            }
        }
        return false
    }

    private final class FloatingPanel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }
}

private struct MenuBarFloatingBarView: View {
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    let items: [MenuBarFloatingItemSnapshot]
    let onPress: (MenuBarFloatingItemSnapshot) -> Void

    private var rowHeight: CGFloat {
        FloatingBarMetrics.rowHeight(for: items)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    useTransparentBackground
                    ? AnyShapeStyle(.ultraThinMaterial)
                    : AdaptiveColors.panelBackgroundOpaqueStyle
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AdaptiveColors.overlayAuto(useTransparentBackground ? 0.2 : 0.1), lineWidth: 1)
                )

            HStack(spacing: 0) {
                ForEach(items) { item in
                    Button {
                        onPress(item)
                    } label: {
                        let iconSize = MenuBarFloatingIconLayout.nativeIconSize(for: item)
                        let slotWidth = FloatingBarMetrics.slotWidth(for: item)
                        floatingIconView(for: item)
                        .frame(width: iconSize.width, height: iconSize.height)
                        .frame(width: slotWidth, height: rowHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("\(item.displayName) (\(item.ownerBundleID))")
                }
            }
            .padding(.horizontal, FloatingBarMetrics.horizontalPadding)
            .padding(.vertical, FloatingBarMetrics.verticalPadding)
        }
    }

    @ViewBuilder
    private func floatingIconView(for item: MenuBarFloatingItemSnapshot) -> some View {
        if let icon = resolvedIcon(for: item) {
            if icon.isTemplate {
                Image(nsImage: icon)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                    .foregroundStyle(.primary)
            } else {
                Image(nsImage: icon)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
            }
        } else {
            Image(systemName: "app.dashed")
                .resizable()
                .scaledToFit()
        }
    }

    private func resolvedIcon(for item: MenuBarFloatingItemSnapshot) -> NSImage? {
        item.icon ?? MenuBarFloatingFallbackIconProvider.icon(for: item)
    }

}
