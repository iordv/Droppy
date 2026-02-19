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
        let effect: NSVisualEffectView
        if let existing = window.contentView as? NSVisualEffectView {
            effect = existing
        } else {
            effect = NSVisualEffectView(frame: .zero)
            window.contentView = effect
        }

        effect.frame = window.contentView?.bounds ?? .zero
        effect.autoresizingMask = [.width, .height]
        // Blend with the real pixels behind the mask window so the temporary
        // cover does not appear as opaque titlebar tiles.
        effect.material = .menu
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.isEmphasized = false
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
    private struct ControlAnchor {
        let frame: CGRect
        let x: CGFloat
    }

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
        allowReposition: Bool = true,
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

        if allowReposition || !(panel?.isVisible ?? false) {
            let positioned = positionPanel(for: items)
            if !positioned {
                if panel?.isVisible == true {
                    // Keep current placement rather than flickering out when divider
                    // frame is transiently unavailable during menu bar state changes.
                    panel?.orderFrontRegardless()
                    return
                }
                panel?.orderOut(nil)
                return
            }
        }
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

    @discardableResult
    private func positionPanel(for items: [MenuBarFloatingItemSnapshot]) -> Bool {
        guard let panel else { return false }
        guard let screen = bestScreen(for: items) else { return false }
        guard let anchor = hiddenDividerAnchor(on: screen) else {
            return false
        }

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

        let verticalGap: CGFloat = 10
        let horizontalInset: CGFloat = 8
        let anchoredOriginX: CGFloat = {
            return anchor.x - (width / 2)
        }()
        let minX = screen.frame.minX + horizontalInset
        let maxX = screen.frame.maxX - width - horizontalInset
        let originX = min(max(anchoredOriginX, minX), maxX)
        let menuBarBaselineY = menuBarBottomY(on: screen, anchorFrame: anchor.frame)
        let originY = menuBarBaselineY - height - verticalGap

        panel.setFrame(
            CGRect(
                x: originX,
                y: originY,
                width: width,
                height: height
            ),
            display: true
        )
        return true
    }

    private func hiddenDividerAnchor(on screen: NSScreen) -> ControlAnchor? {
        anchorForControlItem(.hidden, on: screen)
    }

    private func anchorForControlItem(_ sectionName: MenuBarSection.Name, on screen: NSScreen) -> ControlAnchor? {
        guard let frame = MenuBarManager.shared.controlItemFrame(for: sectionName),
              let ownerScreen = screenContainingDivider(of: frame),
              isSameDisplay(ownerScreen, screen) else {
            return nil
        }
        return ControlAnchor(frame: frame, x: dividerAnchorX(for: frame))
    }

    private enum HiddenSectionSide {
        case leftOfHiddenDivider
        case rightOfHiddenDivider
    }

    private func hiddenSectionSide() -> HiddenSectionSide {
        if let hiddenFrame = MenuBarManager.shared.controlItemFrame(for: .hidden),
           let visibleFrame = MenuBarManager.shared.controlItemFrame(for: .visible) {
            return visibleFrame.midX >= hiddenFrame.midX ? .leftOfHiddenDivider : .rightOfHiddenDivider
        }
        if let hiddenFrame = MenuBarManager.shared.controlItemFrame(for: .hidden),
           let alwaysHiddenFrame = MenuBarManager.shared.controlItemFrame(for: .alwaysHidden) {
            return alwaysHiddenFrame.midX < hiddenFrame.midX ? .leftOfHiddenDivider : .rightOfHiddenDivider
        }
        return NSApp.userInterfaceLayoutDirection == .rightToLeft ? .rightOfHiddenDivider : .leftOfHiddenDivider
    }

    private func dividerAnchorX(for frame: CGRect) -> CGFloat {
        // Divider controls can report expanded frames while hiding items.
        // Anchor on the visible-section side so placement works for RTL layouts.
        let inset = min(6, frame.width / 2)
        switch hiddenSectionSide() {
        case .leftOfHiddenDivider:
            return frame.maxX - inset
        case .rightOfHiddenDivider:
            return frame.minX + inset
        }
    }

    private func screenContainingDivider(of frame: CGRect) -> NSScreen? {
        let anchorPoint = CGPoint(x: dividerAnchorX(for: frame), y: frame.midY)
        return NSScreen.screens.first(where: { $0.frame.contains(anchorPoint) })
    }

    private func isSameDisplay(_ lhs: NSScreen, _ rhs: NSScreen) -> Bool {
        if let lhsID = MenuBarFloatingCoordinateConverter.displayID(for: lhs),
           let rhsID = MenuBarFloatingCoordinateConverter.displayID(for: rhs) {
            return lhsID == rhsID
        }
        return lhs.frame.equalTo(rhs.frame)
    }

    private func menuBarBottomY(on screen: NSScreen, anchorFrame: CGRect?) -> CGFloat {
        let inferredMenuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        if inferredMenuBarHeight > 0, inferredMenuBarHeight < 80 {
            return screen.frame.maxY - inferredMenuBarHeight
        }
        if let anchorFrame, screen.frame.intersects(anchorFrame) {
            return anchorFrame.minY
        }
        return screen.frame.maxY - NSStatusBar.system.thickness
    }

    private func bestScreen(for _: [MenuBarFloatingItemSnapshot]) -> NSScreen? {
        // Priority 1: Screen owning the control items (definitive anchor)
        if let hiddenControlScreen = screenForHiddenControlItemFrame() {
            return hiddenControlScreen
        }
        // No divider anchor available yet; skip showing until we can place deterministically.
        return nil
    }

    private func screenForHiddenControlItemFrame() -> NSScreen? {
        if let hiddenFrame = MenuBarManager.shared.controlItemFrame(for: .hidden),
           let hiddenScreen = screenContainingDivider(of: hiddenFrame) {
            return hiddenScreen
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
            if MenuBarFloatingIconRendering.shouldUseTemplateTint(for: icon) {
                Image(nsImage: icon)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                    .foregroundStyle(AdaptiveColors.primaryTextAuto)
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
                .foregroundStyle(AdaptiveColors.primaryTextAuto)
        }
    }

    private func resolvedIcon(for item: MenuBarFloatingItemSnapshot) -> NSImage? {
        item.icon
    }

}
