//
//  MenuBarFloatingBarManager.swift
//  Droppy
//
//  Orchestrates always-hidden menu bar item behavior for Menu Bar Manager.
//

import AppKit
import Combine
import CoreGraphics
import Foundation

enum MenuBarFloatingPlacement: String, CaseIterable, Identifiable {
    case visible
    case hidden
    case floating

    var id: String { rawValue }
}

@MainActor
final class MenuBarFloatingBarManager: ObservableObject {
    static let shared = MenuBarFloatingBarManager()

    @Published private(set) var scannedItems = [MenuBarFloatingItemSnapshot]()
    @Published var isFeatureEnabled: Bool {
        didSet {
            guard !isLoadingConfiguration else { return }
            saveConfiguration()
            applyPanel()
        }
    }
    @Published var alwaysHiddenItemIDs: Set<String> {
        didSet {
            guard !isLoadingConfiguration else { return }
            saveConfiguration()
            applyPanel()
        }
    }

    private struct Config: Codable {
        var isFeatureEnabled: Bool
        var alwaysHiddenItemIDs: [String]
    }

    private enum RelocationTarget {
        case alwaysHidden
        case hidden
        case visible
    }

    private enum ControlItemOrder {
        case alwaysHiddenLeftOfHidden
        case unknown
    }

    private struct MoveSessionState {
        let visibleState: HidingState
        let hiddenState: HidingState
        let alwaysHiddenState: HidingState
        let alwaysHiddenSectionEnabled: Bool
    }

    private enum PressResolution {
        case success
        case failure
    }

    private let scanner = MenuBarFloatingScanner()
    private let panelController = MenuBarFloatingPanelController()
    private let maskController = MenuBarMaskController()
    private let defaultsKey = "MenuBarManager_FloatingBarConfig"
    private let iconCacheDefaultsKey = "MenuBarManager_FloatingBarIconCacheV7"

    private var rescanTimer: Timer?
    private var currentRescanInterval: TimeInterval = 0
    private var observers = [NSObjectProtocol]()
    private var activeMenuTrackingDepth = 0
    private var lastMenuTrackingEventTime: TimeInterval = 0
    private var isRunning = false
    private var isMenuBarHiddenSectionVisible = false
    private var isInSettingsInspectionMode = false
    private var iconCacheByID = [String: NSImage]()
    private var persistedIconCacheKeys = Set<String>()
    private var itemRegistryByID = [String: MenuBarFloatingItemSnapshot]()
    private var moveInProgressItemIDs = Set<String>()
    private var pendingPlacementByID = [String: MenuBarFloatingPlacement]()
    private var queuedPlacementRequest: (target: MenuBarFloatingPlacement, item: MenuBarFloatingItemSnapshot)?
    private var isRelocationInProgress = false
    private var isManualPreviewRequested = false
    private var isHandlingPanelPress = false
    private var pendingMenuRestoreTask: Task<Void, Never>?
    private var pendingMenuRestoreToken: UUID?
    private var menuInteractionItem: MenuBarFloatingItemSnapshot?
    private var menuInteractionLockDepth = 0
    private var wasLockedVisibleBeforeMenuInteraction = false
    private var lastOrderFixAttempt = Date.distantPast
    private var isLoadingConfiguration = false
    private var stateCancellable: AnyCancellable?
    private var lastKnownHiddenSeparatorOriginX: CGFloat?
    private var lastKnownHiddenSeparatorRightEdgeX: CGFloat?
    private var lastKnownAlwaysHiddenSeparatorOriginX: CGFloat?
    private var lastKnownAlwaysHiddenSeparatorRightEdgeX: CGFloat?
    private var relocationSettleDelayMs: UInt64 = 125
    private let minRelocationSettleDelayMs: UInt64 = 70
    private let maxRelocationSettleDelayMs: UInt64 = 320

    private var shouldEnableAlwaysHiddenSection: Bool {
        isFeatureEnabled && !alwaysHiddenItemIDs.isEmpty
    }

    private let mandatoryControlTokens: Set<String> = [
        "droppymbm_icon",
        "droppymbm_hidden",
        "droppymbm_alwayshidden",
    ]

    private static func validatedAXUIElement(_ rawValue: AnyObject) -> AXUIElement {
        // Safe because callers gate with CFGetTypeID(rawValue) == AXUIElementGetTypeID().
        unsafeBitCast(rawValue, to: AXUIElement.self)
    }

    private var isHiddenSectionVisibleNow: Bool {
        if let hiddenSection = MenuBarManager.shared.section(withName: .hidden) {
            return !hiddenSection.isHidden
        }
        return isMenuBarHiddenSectionVisible
    }

    private init() {
        self.isFeatureEnabled = true
        self.alwaysHiddenItemIDs = []
        isLoadingConfiguration = true
        loadConfiguration()
        loadPersistedIconCache()
        isLoadingConfiguration = false
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        activeMenuTrackingDepth = 0
        lastMenuTrackingEventTime = 0
        isMenuBarHiddenSectionVisible = isHiddenSectionVisibleNow
        installObservers()
        scheduleRescanTimer()
        syncAlwaysHiddenSectionEnabled(forceEnable: false)
        rescan()
    }

    func stop() {
        guard isRunning else { return }
        cancelPendingMenuRestore(using: MenuBarManager.shared)
        resetMenuInteractionLock(using: MenuBarManager.shared)
        isRunning = false
        activeMenuTrackingDepth = 0
        lastMenuTrackingEventTime = 0
        isMenuBarHiddenSectionVisible = false
        isInSettingsInspectionMode = false
        isManualPreviewRequested = false
        isHandlingPanelPress = false
        isRelocationInProgress = false
        moveInProgressItemIDs.removeAll()
        pendingPlacementByID.removeAll()
        queuedPlacementRequest = nil
        MenuBarManager.shared.setAlwaysHiddenSectionEnabled(false)
        stateCancellable?.cancel()
        stateCancellable = nil
        teardownObservers()
        rescanTimer?.invalidate()
        rescanTimer = nil
        currentRescanInterval = 0
        scannedItems = []
        itemRegistryByID.removeAll()
        lastKnownHiddenSeparatorOriginX = nil
        lastKnownHiddenSeparatorRightEdgeX = nil
        lastKnownAlwaysHiddenSeparatorOriginX = nil
        lastKnownAlwaysHiddenSeparatorRightEdgeX = nil
        panelController.hide()
        clearMenuInteractionMask()
    }

    func rescan(force: Bool = false, refreshIcons: Bool = false) {
        guard isRunning else { return }
        guard !isRelocationInProgress || force else { return }

        guard PermissionManager.shared.isAccessibilityGranted else {
            scannedItems = []
            panelController.hide()
            return
        }

        syncAlwaysHiddenSectionEnabled(forceEnable: isInSettingsInspectionMode)

        if !isInSettingsInspectionMode, alwaysHiddenItemIDs.isEmpty, !isManualPreviewRequested {
            if !scannedItems.isEmpty {
                scannedItems = []
            }
            panelController.hide()
            return
        }

        // Capture real menu bar icon bitmaps only on explicit user-initiated refreshes.
        // This keeps settings-open rescans lightweight and avoids capture stalls.
        let includeIcons = PermissionManager.shared.isScreenRecordingGranted && refreshIcons
        let ownerHints = refreshIcons ? nil : preferredOwnerBundleIDsForRescan()
        let rawItems = scanner.scan(includeIcons: includeIcons, preferredOwnerBundleIDs: ownerHints)
        let resolvedItems = rawItems.map { item in
            let resolvedIcon: NSImage?
            if includeIcons, let captured = item.icon {
                resolvedIcon = captured
                cacheIcon(captured, for: iconCacheKeys(for: item), overwrite: refreshIcons)
            } else {
                resolvedIcon = cachedIcon(for: item)
            }
            return MenuBarFloatingItemSnapshot(
                id: item.id,
                windowID: item.windowID,
                axElement: item.axElement,
                quartzFrame: item.quartzFrame,
                appKitFrame: item.appKitFrame,
                ownerBundleID: item.ownerBundleID,
                axIdentifier: item.axIdentifier,
                statusItemIndex: item.statusItemIndex,
                title: item.title,
                detail: item.detail,
                icon: resolvedIcon
            )
        }

        reconcileAlwaysHiddenIDs(using: resolvedItems)
        sanitizeAlwaysHiddenIDs(using: resolvedItems)

        let nonHideableIDs = Set(
            resolvedItems.compactMap { item in
                nonHideableReason(for: item) != nil ? item.id : nil
            }
        )
        if !nonHideableIDs.isEmpty {
            let sanitizedAlwaysHidden = alwaysHiddenItemIDs.subtracting(nonHideableIDs)
            if sanitizedAlwaysHidden != alwaysHiddenItemIDs {
                alwaysHiddenItemIDs = sanitizedAlwaysHidden
            }
        }

        scannedItems = resolvedItems
        updateRegistry(with: resolvedItems)
        refreshSeparatorCaches()
        attemptControlItemOrderFixIfNeeded()
        applyPanel()
    }

    func requestAccessibilityPermission() {
        PermissionManager.shared.requestAccessibility(context: .userInitiated)
        scheduleFollowUpRescan()
    }

    func requestScreenRecordingPermission() {
        _ = PermissionManager.shared.requestScreenRecording()
        scheduleFollowUpRescan(refreshIcons: true)
    }

    func showBarNow() {
        guard isRunning, isFeatureEnabled else { return }
        isManualPreviewRequested = true
        scheduleRescanTimer()
        rescan(force: true)
        let hiddenItems = currentlyHiddenItems()
        var itemsToShow = hiddenItems.isEmpty
            ? scannedItems.filter { !isMandatoryMenuBarManagerControlItem($0) }
            : hiddenItems
        if itemsToShow.isEmpty {
            rescan(force: true)
            let refreshedHiddenItems = currentlyHiddenItems()
            itemsToShow = refreshedHiddenItems.isEmpty
                ? scannedItems.filter { !isMandatoryMenuBarManagerControlItem($0) }
                : refreshedHiddenItems
        }
        guard !itemsToShow.isEmpty else { return }
        panelController.show(items: itemsToShow) { [weak self] item in
            self?.performAction(for: item)
        }
    }

    func setMenuBarHiddenSectionVisible(_ visible: Bool) {
        isMenuBarHiddenSectionVisible = visible
        scheduleRescanTimer()
        if visible {
            requestRescanOnMainActor(force: true)
        }
        applyPanel()
    }

    func enterSettingsInspectionMode() {
        isInSettingsInspectionMode = true
        isManualPreviewRequested = false
        syncAlwaysHiddenSectionEnabled(forceEnable: true)
        scheduleRescanTimer()
        applyPanel()
    }

    func exitSettingsInspectionMode() {
        isInSettingsInspectionMode = false
        isManualPreviewRequested = false
        syncAlwaysHiddenSectionEnabled(forceEnable: false)
        scheduleRescanTimer()
        applyPanel()
        requestRescanOnMainActor(force: true)
    }

    func isAlwaysHidden(_ item: MenuBarFloatingItemSnapshot) -> Bool {
        alwaysHiddenItemIDs.contains(item.id)
    }

    func nonHideableReason(for item: MenuBarFloatingItemSnapshot) -> String? {
        let owner = item.ownerBundleID.lowercased()
        guard owner.hasPrefix("com.apple.") else { return nil }

        let identifier = item.axIdentifier?.lowercased() ?? ""
        let title = stableTextToken(item.title) ?? ""
        let detail = stableTextToken(item.detail) ?? ""

        let looksLikeClock =
            identifier.contains("clock")
            || title.contains("clock")
            || detail.contains("clock")
        if looksLikeClock && (owner.contains("controlcenter") || owner.contains("systemuiserver")) {
            return "Clock is managed by macOS and can't be hidden."
        }

        let looksLikeControlCenter =
            identifier.contains("controlcenter")
            || title.contains("control center")
            || title.contains("control centre")
            || detail.contains("control center")
            || detail.contains("control centre")
        if looksLikeControlCenter {
            return "Control Center is managed by macOS and can't be hidden."
        }

        return nil
    }

    func placement(for item: MenuBarFloatingItemSnapshot) -> MenuBarFloatingPlacement {
        if let pendingPlacement = pendingPlacementByID[item.id] {
            if pendingPlacement == .floating, !isFeatureEnabled {
                return .hidden
            }
            return pendingPlacement
        }

        if alwaysHiddenItemIDs.contains(item.id), isFeatureEnabled {
            return .floating
        } else if alwaysHiddenItemIDs.contains(item.id) {
            // When floating bar is disabled, treat previously pinned items as hidden.
            return .hidden
        }

        let resolved = scannedItems.first(where: { $0.id == item.id }) ?? item

        guard let hiddenOriginX = hiddenSeparatorOriginX(),
              let hiddenRightEdgeX = hiddenSeparatorRightEdgeX() else {
            return .visible
        }

        let midpoint = resolved.quartzFrame.midX
        let margin = max(4, resolved.quartzFrame.width * 0.22)

        if midpoint > (hiddenRightEdgeX + margin) {
            return .visible
        }
        // Items not in alwaysHiddenItemIDs should never be classified as
        // .floating based on position alone — that membership check (above)
        // is the single source of truth. Position-only classification treats
        // everything left of the hidden separator as .hidden.
        if midpoint < (hiddenOriginX - margin) {
            return .hidden
        }

        return .hidden
    }

    func settingsItems(for placement: MenuBarFloatingPlacement) -> [MenuBarFloatingItemSnapshot] {
        settingsItems.filter { self.placement(for: $0) == placement }
    }

    private func indexByID(_ items: [MenuBarFloatingItemSnapshot]) -> [String: MenuBarFloatingItemSnapshot] {
        var indexed = [String: MenuBarFloatingItemSnapshot]()
        indexed.reserveCapacity(items.count)
        for item in items where indexed[item.id] == nil {
            indexed[item.id] = item
        }
        return indexed
    }

    var settingsItems: [MenuBarFloatingItemSnapshot] {
        let scannedByID = indexByID(scannedItems)
        var merged = scannedItems

        for id in alwaysHiddenItemIDs {
            guard scannedByID[id] == nil, let cached = itemRegistryByID[id] else { continue }
            merged.append(cached)
        }

        return merged
            .filter { !isMandatoryMenuBarManagerControlItem($0) }
            .sorted { lhs, rhs in
            lhs.quartzFrame.minX < rhs.quartzFrame.minX
        }
    }

    private func isMandatoryMenuBarManagerControlItem(_ item: MenuBarFloatingItemSnapshot) -> Bool {
        let normalizedFields = [
            item.id.lowercased(),
            item.axIdentifier?.lowercased(),
            item.title?.lowercased(),
            item.detail?.lowercased(),
        ]
        .compactMap { $0 }

        if normalizedFields.contains(where: { field in
            mandatoryControlTokens.contains(where: { token in field.contains(token) })
        }) {
            return true
        }

        guard item.ownerBundleID == Bundle.main.bundleIdentifier else { return false }

        let controlFrames = [
            MenuBarManager.shared.controlItemFrame(for: .visible),
            MenuBarManager.shared.controlItemFrame(for: .hidden),
            MenuBarManager.shared.controlItemFrame(for: .alwaysHidden),
        ]
        .compactMap { $0 }

        guard !controlFrames.isEmpty else { return false }
        let itemFrame = item.appKitFrame.insetBy(dx: -3, dy: -2)
        return controlFrames.contains { $0.intersects(itemFrame) }
    }

    private func isMandatoryMenuBarManagerControlID(_ id: String) -> Bool {
        let normalized = id.lowercased()
        return mandatoryControlTokens.contains { normalized.contains($0) }
    }

    func setAlwaysHidden(_ hidden: Bool, for item: MenuBarFloatingItemSnapshot) {
        setPlacement(hidden ? .floating : .visible, for: item)
    }

    func setPlacement(_ targetPlacement: MenuBarFloatingPlacement, for item: MenuBarFloatingItemSnapshot) {
        guard isRunning else { return }
        guard !(targetPlacement == .floating && !isFeatureEnabled) else { return }
        if targetPlacement != .visible, isMandatoryMenuBarManagerControlItem(item) {
            return
        }
        if targetPlacement != .visible, nonHideableReason(for: item) != nil {
            return
        }
        let currentPlacement = placement(for: item)
        guard targetPlacement != currentPlacement else { return }
        if isRelocationInProgress || moveInProgressItemIDs.contains(item.id) {
            queuedPlacementRequest = (targetPlacement, item)
            return
        }

        var trackedItem = item

        if targetPlacement == .floating {
            if let capturedIcon = captureAndCacheIconForItemIfNeeded(item) {
                trackedItem = MenuBarFloatingItemSnapshot(
                    id: item.id,
                    windowID: item.windowID,
                    axElement: item.axElement,
                    quartzFrame: item.quartzFrame,
                    appKitFrame: item.appKitFrame,
                    ownerBundleID: item.ownerBundleID,
                    axIdentifier: item.axIdentifier,
                    statusItemIndex: item.statusItemIndex,
                    title: item.title,
                    detail: item.detail,
                    icon: capturedIcon
                )
            }
            itemRegistryByID[item.id] = trackedItem
            if let icon = trackedItem.icon {
                cacheIcon(icon, for: iconCacheKeys(for: trackedItem), overwrite: false)
            }
        }

        let previousAlwaysHidden = alwaysHiddenItemIDs

        // Optimistically reflect toggle state in UI, then revert on failure.
        if targetPlacement == .floating {
            alwaysHiddenItemIDs.insert(item.id)
        } else {
            alwaysHiddenItemIDs.remove(item.id)
        }
        pendingPlacementByID[item.id] = targetPlacement

        isRelocationInProgress = true
        moveInProgressItemIDs.insert(item.id)

        Task { @MainActor [weak self] in
            guard let strongSelf = self else { return }
            var moved = false
            defer {
                strongSelf.moveInProgressItemIDs.remove(item.id)
                strongSelf.isRelocationInProgress = false
                strongSelf.rescan(force: true)
                strongSelf.pendingPlacementByID.removeValue(forKey: item.id)
                strongSelf.pendingPlacementByID = strongSelf.pendingPlacementByID.filter { key, _ in
                    strongSelf.moveInProgressItemIDs.contains(key)
                }
                if let queued = strongSelf.queuedPlacementRequest {
                    strongSelf.queuedPlacementRequest = nil
                    strongSelf.setPlacement(queued.target, for: queued.item)
                }
            }

            let target: RelocationTarget = switch targetPlacement {
            case .floating: .alwaysHidden
            case .hidden: .hidden
            case .visible: .visible
            }
            moved = await strongSelf.relocateItem(itemID: item.id, fallback: trackedItem, to: target)

            if !moved {
                strongSelf.alwaysHiddenItemIDs = previousAlwaysHidden
                strongSelf.pendingPlacementByID.removeValue(forKey: item.id)
            }
        }
    }

    private func captureAndCacheIconForItemIfNeeded(_ item: MenuBarFloatingItemSnapshot) -> NSImage? {
        if let existing = cachedIcon(for: item) {
            return existing
        }

        if let fallback = item.icon {
            cacheIcon(fallback, for: iconCacheKeys(for: item), overwrite: false)
            return fallback
        }

        return nil
    }

    private func currentlyHiddenItems() -> [MenuBarFloatingItemSnapshot] {
        let scannedByID = indexByID(scannedItems)
        var hidden = [MenuBarFloatingItemSnapshot]()
        hidden.reserveCapacity(alwaysHiddenItemIDs.count)

        for id in alwaysHiddenItemIDs {
            if let scanned = scannedByID[id] {
                hidden.append(scanned)
            } else if let cached = itemRegistryByID[id] {
                hidden.append(cached)
            }
        }

        return hidden
            .filter { !isMandatoryMenuBarManagerControlItem($0) }
            .sorted { lhs, rhs in
                lhs.quartzFrame.minX < rhs.quartzFrame.minX
            }
    }

    private func applyPanel() {
        guard isRunning else {
            panelController.hide()
            return
        }

        syncAlwaysHiddenSectionEnabled(forceEnable: isInSettingsInspectionMode)
        scheduleRescanTimer()

        guard isFeatureEnabled else {
            isManualPreviewRequested = false
            panelController.hide()
            return
        }

        attemptControlItemOrderFixIfNeeded()

        if isHandlingPanelPress {
            panelController.hide()
            return
        }

        let hiddenItems = currentlyHiddenItems()
        let shouldStayVisibleBecausePanelHover = panelController.containsMouseLocation()
        let shouldShowBecauseHover = isHiddenSectionVisibleNow || shouldStayVisibleBecausePanelHover
        let shouldShowBecauseManualPreview = isManualPreviewRequested
        let itemsToShow = shouldShowBecauseManualPreview && hiddenItems.isEmpty
            ? scannedItems.filter { !isMandatoryMenuBarManagerControlItem($0) }
            : hiddenItems
        guard (shouldShowBecauseHover || shouldShowBecauseManualPreview), !itemsToShow.isEmpty else {
            panelController.hide()
            return
        }

        panelController.show(items: itemsToShow) { [weak self] item in
            self?.performAction(for: item)
        }
    }

    private func attemptControlItemOrderFixIfNeeded() {
        guard shouldEnableAlwaysHiddenSection,
              !isInSettingsInspectionMode,
              !isRelocationInProgress,
              detectControlItemOrder() != .alwaysHiddenLeftOfHidden else {
            return
        }

        let now = Date()
        guard now.timeIntervalSince(lastOrderFixAttempt) > 2.0 else { return }
        lastOrderFixAttempt = now

        Task { @MainActor [weak self] in
            guard let self else { return }
            let fixed = await self.ensureControlItemOrder()
            if fixed {
                self.requestRescanOnMainActor()
            }
        }
    }

    private func performAction(for item: MenuBarFloatingItemSnapshot) {
        let manager = MenuBarManager.shared
        cancelPendingMenuRestore(using: manager)
        clearMenuInteractionMask()
        menuInteractionItem = nil
        isManualPreviewRequested = false
        isHandlingPanelPress = true
        panelController.hide()

        Task { @MainActor [weak self] in
            guard let self else { return }
            let opened = await self.openMenuForFloatingItem(item)
            if !opened {
                try? await Task.sleep(for: .milliseconds(180))
                self.isHandlingPanelPress = false
                self.applyPanel()
            }
        }
    }

    private func openMenuForFloatingItem(_ requested: MenuBarFloatingItemSnapshot) async -> Bool {
        let manager = MenuBarManager.shared
        beginMenuInteractionLock(using: manager)
        manager.cancelAutoHide()
        let sessionState = MoveSessionState(
            visibleState: manager.section(withName: .visible)?.controlItem.state ?? .hideItems,
            hiddenState: manager.section(withName: .hidden)?.controlItem.state ?? .hideItems,
            alwaysHiddenState: manager.section(withName: .alwaysHidden)?.controlItem.state ?? .hideItems,
            alwaysHiddenSectionEnabled: manager.isSectionEnabled(.alwaysHidden)
        )

        // Match legacy app behavior:
        // 1) reveal first, 2) wait for layout settle, 3) resolve target, 4) click.
        applyMenuInteractionMask(except: requested, captureBackground: true)
        await applyShowAllShield(using: manager)
        rescan(force: true)
        var liveItem = resolveLiveItem(for: requested)
        itemRegistryByID[liveItem.id] = liveItem
        applyMenuInteractionMask(except: liveItem)
        try? await Task.sleep(for: .milliseconds(500))

        var didOpenMenu = false

        for attempt in 0 ..< 3 {
            rescan(force: true)
            liveItem = resolveLiveItem(for: liveItem)
            itemRegistryByID[liveItem.id] = liveItem
            applyMenuInteractionMask(except: liveItem)

            if case .success = triggerMenuAction(for: liveItem, allowHardwareFallback: true) {
                didOpenMenu = true
                break
            }

            if attempt < 2 {
                try? await Task.sleep(for: .milliseconds(120))
            }
        }

        if didOpenMenu {
            try? await Task.sleep(for: .milliseconds(90))
            rescan(force: true)
            liveItem = resolveLiveItem(for: liveItem)
            menuInteractionItem = liveItem
            let restoreToken = UUID()
            pendingMenuRestoreToken = restoreToken
            pendingMenuRestoreTask = Task { @MainActor [weak self] in
                guard let self else { return }
                defer {
                    if self.pendingMenuRestoreToken == restoreToken {
                        self.pendingMenuRestoreTask = nil
                        self.pendingMenuRestoreToken = nil
                        self.clearMenuInteractionMask()
                        self.menuInteractionItem = nil
                        self.endMenuInteractionLock(using: manager)
                        self.isHandlingPanelPress = false
                        self.applyPanel()
                    }
                }
                try? await Task.sleep(for: .milliseconds(120))
                await self.waitForMenuDismissal(maxWaitSeconds: 15)
                guard !Task.isCancelled else { return }
                guard !self.isInSettingsInspectionMode else { return }
                await self.restoreMoveSession(using: manager, state: sessionState)
                self.rescan(force: true)
            }
        } else {
            clearMenuInteractionMask()
            menuInteractionItem = nil
            await restoreMoveSession(using: manager, state: sessionState)
            endMenuInteractionLock(using: manager)
            rescan(force: true)
        }

        return didOpenMenu
    }

    private func hasActiveMenuWindow() -> Bool {
        let now = ProcessInfo.processInfo.systemUptime

        if let menuInteractionItem,
           isMenuCurrentlyOpen(for: menuInteractionItem) {
            return true
        }

        if hasGlobalMenuWindow(for: menuInteractionItem) {
            return true
        }

        if hasAnyOnScreenPopupMenuWindowContainingMouse() {
            return true
        }

        if RunLoop.main.currentMode == .eventTracking {
            return true
        }

        let hasMenuWindow = NSApp.windows.contains { window in
            guard window.isVisible else { return false }
            guard window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue else { return false }
            let className = NSStringFromClass(type(of: window)).lowercased()
            return className.contains("menu")
        }

        if hasMenuWindow {
            return true
        }

        if activeMenuTrackingDepth > 0 {
            let trackingGrace: TimeInterval = 0.9
            if now - lastMenuTrackingEventTime <= trackingGrace {
                return true
            }
            // Failsafe for unbalanced didBegin/didEnd notifications.
            activeMenuTrackingDepth = 0
        }

        return false
    }

    private func isMenuCurrentlyOpen(for item: MenuBarFloatingItemSnapshot) -> Bool {
        if let expanded = MenuBarAXTools.copyAttribute(item.axElement, "AXExpanded" as CFString) as? Bool,
           expanded {
            return true
        }

        if let menuVisible = MenuBarAXTools.copyAttribute(item.axElement, "AXMenuVisible" as CFString) as? Bool,
           menuVisible {
            return true
        }

        if let menuAttribute = MenuBarAXTools.copyAttribute(item.axElement, "AXMenu" as CFString),
           CFGetTypeID(menuAttribute) == AXUIElementGetTypeID() {
            let menuElement = Self.validatedAXUIElement(menuAttribute)
            if isAXMenuElementCurrentlyVisible(menuElement) {
                return true
            }
        }

        let children = MenuBarAXTools.copyChildren(item.axElement)
        for child in children {
            let role = MenuBarAXTools.copyString(child, kAXRoleAttribute as CFString) ?? ""
            if (role == (kAXMenuRole as String) || role == "AXMenu"),
               isAXMenuElementCurrentlyVisible(child) {
                return true
            }
        }

        return false
    }

    private func hasGlobalMenuWindow(for item: MenuBarFloatingItemSnapshot?) -> Bool {
        guard let item else { return false }

        let ownerPIDs = Set(
            NSRunningApplication
                .runningApplications(withBundleIdentifier: item.ownerBundleID)
                .map(\.processIdentifier)
        )
        guard !ownerPIDs.isEmpty else { return false }

        return hasOnScreenPopupMenuWindowContainingMouse(ownerPIDs: ownerPIDs)
    }

    private func hasAnyOnScreenPopupMenuWindowContainingMouse() -> Bool {
        hasOnScreenPopupMenuWindowContainingMouse(ownerPIDs: nil)
    }

    private func hasOnScreenPopupMenuWindowContainingMouse(ownerPIDs: Set<pid_t>?) -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let currentPID = getpid()

        let popUpLayer = Int(CGWindowLevelForKey(.popUpMenuWindow))
        let statusLayer = Int(CGWindowLevelForKey(.statusWindow))
        let mainMenuLayer = Int(CGWindowLevelForKey(.mainMenuWindow))
        let acceptedLayers = Set([
            popUpLayer - 1,
            popUpLayer,
            popUpLayer + 1,
            statusLayer,
            mainMenuLayer,
        ])
        let mouseQuartzRect = MenuBarFloatingCoordinateConverter.appKitToQuartz(
            CGRect(x: NSEvent.mouseLocation.x, y: NSEvent.mouseLocation.y, width: 1, height: 1)
        )
        let mouseQuartzPoint = CGPoint(x: mouseQuartzRect.midX, y: mouseQuartzRect.midY)

        for window in windows {
            let ownerPID: pid_t
            if let pid = window[kCGWindowOwnerPID as String] as? Int32 {
                ownerPID = pid_t(pid)
            } else if let pid = window[kCGWindowOwnerPID as String] as? Int {
                ownerPID = pid_t(pid)
            } else {
                continue
            }
            if let ownerPIDs, !ownerPIDs.contains(ownerPID) {
                continue
            }
            // Ignore Droppy's own utility windows (floating panel/popovers).
            if ownerPIDs == nil, ownerPID == currentPID {
                continue
            }

            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            guard acceptedLayers.contains(layer) else { continue }

            if let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
               let bounds = CGRect(dictionaryRepresentation: boundsDict),
               !bounds.contains(mouseQuartzPoint) {
                continue
            }
            return true
        }

        return false
    }

    private func isAXMenuElementCurrentlyVisible(_ element: AXUIElement) -> Bool {
        if let visible = MenuBarAXTools.copyAttribute(element, "AXVisible" as CFString) as? Bool,
           visible {
            return true
        }

        if let expanded = MenuBarAXTools.copyAttribute(element, "AXExpanded" as CFString) as? Bool,
           expanded {
            return true
        }

        if let menuVisible = MenuBarAXTools.copyAttribute(element, "AXMenuVisible" as CFString) as? Bool,
           menuVisible {
            return true
        }

        return false
    }

    private func waitForMenuDismissal(maxWaitSeconds: TimeInterval) async {
        let start = Date()
        let deadline = start.addingTimeInterval(maxWaitSeconds)
        var sawMenuOpen = false
        var consecutiveInactiveSamples = 0

        while Date() < deadline {
            if Task.isCancelled {
                return
            }

            rescan(force: true)
            if hasActiveMenuWindow() {
                sawMenuOpen = true
                consecutiveInactiveSamples = 0
                try? await Task.sleep(for: .milliseconds(130))
                continue
            }

            // Match hover behavior: never restore while the pointer is still
            // in the active menu-bar interaction zone.
            if isCursorInInteractiveMenuBarZone() {
                consecutiveInactiveSamples = 0
                try? await Task.sleep(for: .milliseconds(130))
                continue
            }

            // Before first positive menu detection, use interaction heuristics
            // only during a short warm-up to avoid false immediate restores.
            if !sawMenuOpen {
                let elapsed = Date().timeIntervalSince(start)
                if elapsed < 1.25 {
                    if hasRecentMenuInteraction(threshold: 0.95) {
                        consecutiveInactiveSamples = 0
                    }
                    try? await Task.sleep(for: .milliseconds(130))
                    continue
                }
            }

            consecutiveInactiveSamples += 1
            let requiredSamples = sawMenuOpen ? 3 : 5
            if consecutiveInactiveSamples >= requiredSamples {
                return
            }

            try? await Task.sleep(for: .milliseconds(130))
        }
    }

    private func hasRecentMenuInteraction(threshold: CFTimeInterval = 0.4) -> Bool {
        let state: CGEventSourceStateID = .combinedSessionState

        func happenedRecently(_ type: CGEventType) -> Bool {
            CGEventSource.secondsSinceLastEventType(state, eventType: type) < threshold
        }

        return happenedRecently(.mouseMoved)
            || happenedRecently(.scrollWheel)
            || happenedRecently(.leftMouseDown)
            || happenedRecently(.leftMouseUp)
            || happenedRecently(.leftMouseDragged)
            || happenedRecently(.otherMouseDown)
            || happenedRecently(.otherMouseUp)
            || happenedRecently(.otherMouseDragged)
            || happenedRecently(.rightMouseDown)
            || happenedRecently(.rightMouseUp)
            || happenedRecently(.keyDown)
    }

    private func isCursorInInteractiveMenuBarZone() -> Bool {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = interactionScreen(for: mouseLocation) else { return false }
        let menuBarHeight = effectiveMenuBarHeight(for: screen)
        let isAtTop = mouseLocation.y >= screen.frame.maxY - menuBarHeight
        let isOnRightSideOfNotch = isOnRightSideMenuBarArea(mouseLocation: mouseLocation, screen: screen)
        return isAtTop && isOnRightSideOfNotch
    }

    private func interactionScreen(for mouseLocation: CGPoint) -> NSScreen? {
        if let hiddenFrame = MenuBarManager.shared.controlItemFrame(for: .hidden),
           let hiddenScreen = NSScreen.screens.first(where: { $0.frame.intersects(hiddenFrame) }) {
            return hiddenScreen
        }
        if let alwaysHiddenFrame = MenuBarManager.shared.controlItemFrame(for: .alwaysHidden),
           let alwaysHiddenScreen = NSScreen.screens.first(where: { $0.frame.intersects(alwaysHiddenFrame) }) {
            return alwaysHiddenScreen
        }
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
    }

    private func effectiveMenuBarHeight(for screen: NSScreen) -> CGFloat {
        let inferredHeight = screen.frame.maxY - screen.visibleFrame.maxY
        if inferredHeight > 0 {
            return inferredHeight
        }
        return max(24, NSStatusBar.system.thickness)
    }

    private func isOnRightSideMenuBarArea(mouseLocation: CGPoint, screen: NSScreen) -> Bool {
        let hasNotch = screen.safeAreaInsets.top > 0
        if !hasNotch {
            return mouseLocation.x > screen.frame.midX
        }
        let notchExclusionWidth: CGFloat = 200
        return mouseLocation.x > screen.frame.midX + (notchExclusionWidth / 2)
    }

    private func beginMenuInteractionLock(using manager: MenuBarManager) {
        if menuInteractionLockDepth == 0 {
            wasLockedVisibleBeforeMenuInteraction = manager.isLockedVisible
            manager.isLockedVisible = true
        }
        menuInteractionLockDepth += 1
    }

    private func endMenuInteractionLock(using manager: MenuBarManager) {
        guard menuInteractionLockDepth > 0 else { return }
        menuInteractionLockDepth -= 1
        if menuInteractionLockDepth == 0 {
            manager.isLockedVisible = wasLockedVisibleBeforeMenuInteraction
        }
    }

    private func resetMenuInteractionLock(using manager: MenuBarManager) {
        guard menuInteractionLockDepth > 0 else { return }
        menuInteractionLockDepth = 0
        manager.isLockedVisible = wasLockedVisibleBeforeMenuInteraction
    }

    private func cancelPendingMenuRestore(using manager: MenuBarManager) {
        pendingMenuRestoreTask?.cancel()
        pendingMenuRestoreTask = nil
        pendingMenuRestoreToken = nil
        clearMenuInteractionMask()
        menuInteractionItem = nil
        isHandlingPanelPress = false
        resetMenuInteractionLock(using: manager)
    }

    private func applyMenuInteractionMask(
        except activeItem: MenuBarFloatingItemSnapshot,
        captureBackground: Bool = false
    ) {
        let hiddenItems = currentlyHiddenItems()
        var masks = hiddenItems.filter { !isMaskEquivalent($0, activeItem) }
        if masks.count == hiddenItems.count,
           let fallbackExclude = bestMaskExclusionCandidate(for: activeItem, in: hiddenItems) {
            masks = hiddenItems.filter { $0.id != fallbackExclude.id }
        }
        if masks.isEmpty {
            maskController.hideAll()
            return
        }
        if captureBackground {
            maskController.prepareBackgroundSnapshots(for: masks)
        }
        maskController.update(hiddenItems: masks, usePreparedSnapshots: true)
    }

    private func isMaskEquivalent(
        _ lhs: MenuBarFloatingItemSnapshot,
        _ rhs: MenuBarFloatingItemSnapshot
    ) -> Bool {
        if lhs.id == rhs.id { return true }
        guard lhs.ownerBundleID == rhs.ownerBundleID else { return false }

        if let lhsIdentifier = lhs.axIdentifier,
           let rhsIdentifier = rhs.axIdentifier,
           !lhsIdentifier.isEmpty,
           lhsIdentifier == rhsIdentifier {
            return true
        }

        if let lhsIndex = lhs.statusItemIndex,
           let rhsIndex = rhs.statusItemIndex,
           lhsIndex == rhsIndex {
            return true
        }

        let lhsDetail = stableTextToken(lhs.detail)
        let rhsDetail = stableTextToken(rhs.detail)
        if let lhsDetail, let rhsDetail, lhsDetail == rhsDetail {
            return true
        }

        let lhsTitle = stableTextToken(lhs.title)
        let rhsTitle = stableTextToken(rhs.title)
        if let lhsTitle, let rhsTitle, lhsTitle == rhsTitle {
            return true
        }

        let midpointDistance = abs(lhs.quartzFrame.midX - rhs.quartzFrame.midX)
        let widthClose = abs(lhs.quartzFrame.width - rhs.quartzFrame.width) <= 2
        let heightClose = abs(lhs.quartzFrame.height - rhs.quartzFrame.height) <= 2
        return midpointDistance <= 8 && widthClose && heightClose
    }

    private func bestMaskExclusionCandidate(
        for activeItem: MenuBarFloatingItemSnapshot,
        in hiddenItems: [MenuBarFloatingItemSnapshot]
    ) -> MenuBarFloatingItemSnapshot? {
        var best: (item: MenuBarFloatingItemSnapshot, score: Double)?

        for candidate in hiddenItems {
            guard candidate.ownerBundleID == activeItem.ownerBundleID else { continue }

            var score: Double = 0
            if candidate.id == activeItem.id {
                score += 120
            }
            if let lhsIdentifier = candidate.axIdentifier,
               let rhsIdentifier = activeItem.axIdentifier,
               !lhsIdentifier.isEmpty,
               lhsIdentifier == rhsIdentifier {
                score += 90
            }
            if let lhsIndex = candidate.statusItemIndex,
               let rhsIndex = activeItem.statusItemIndex,
               lhsIndex == rhsIndex {
                score += 70
            }
            if let lhsDetail = stableTextToken(candidate.detail),
               let rhsDetail = stableTextToken(activeItem.detail),
               lhsDetail == rhsDetail {
                score += 45
            }
            if let lhsTitle = stableTextToken(candidate.title),
               let rhsTitle = stableTextToken(activeItem.title),
               lhsTitle == rhsTitle {
                score += 25
            }

            let distance = abs(candidate.quartzFrame.midX - activeItem.quartzFrame.midX)
            score -= Double(distance) / 5.0

            if let currentBest = best {
                if score > currentBest.score {
                    best = (candidate, score)
                }
            } else {
                best = (candidate, score)
            }
        }

        guard let best else { return nil }
        return best.score >= 18 ? best.item : nil
    }

    private func clearMenuInteractionMask() {
        maskController.hideAll()
        maskController.clearPreparedSnapshots()
    }

    private func resolveLiveItem(for requested: MenuBarFloatingItemSnapshot) -> MenuBarFloatingItemSnapshot {
        if let axIdentifier = requested.axIdentifier,
           let byIdentifier = scannedItems.first(where: {
               $0.ownerBundleID == requested.ownerBundleID && $0.axIdentifier == axIdentifier
           }) {
            return byIdentifier
        }

        if let statusItemIndex = requested.statusItemIndex,
           let byIndex = scannedItems.first(where: {
               $0.ownerBundleID == requested.ownerBundleID && $0.statusItemIndex == statusItemIndex
           }) {
            return byIndex
        }

        if let scanned = scannedItems.first(where: { $0.id == requested.id }) {
            return scanned
        }

        if let registry = itemRegistryByID[requested.id] {
            return registry
        }

        if let candidate = relocationCandidate(itemID: requested.id, fallback: requested) {
            return candidate
        }

        if let title = requested.title, !title.isEmpty,
           let bestByTitle = scannedItems.first(where: { $0.ownerBundleID == requested.ownerBundleID && $0.title == title }) {
            return bestByTitle
        }

        return requested
    }

    private func triggerMenuAction(
        for item: MenuBarFloatingItemSnapshot,
        allowHardwareFallback: Bool
    ) -> PressResolution {
        // Prefer a real click first so menu tracking behaves like native status-item interaction.
        if allowHardwareFallback,
           let clickPoint = clickPointForItemIfVisible(item),
           postLeftClick(at: clickPoint) {
            return .success
        }

        if performBestAXPress(on: item.axElement) {
            return .success
        }

        for child in MenuBarAXTools.copyChildren(item.axElement) {
            if performBestAXPress(on: child) {
                return .success
            }
        }

        return .failure
    }

    private func performBestAXPress(on element: AXUIElement) -> Bool {
        let pressAction = "AXPress" as CFString
        let showMenuAction = "AXShowMenu" as CFString

        let bestAction = MenuBarAXTools.bestMenuBarAction(for: element)
        if MenuBarAXTools.performAction(element, bestAction) {
            return true
        }

        if (bestAction as String) != (pressAction as String),
           MenuBarAXTools.performAction(element, pressAction) {
            return true
        }

        if (bestAction as String) != (showMenuAction as String),
           MenuBarAXTools.performAction(element, showMenuAction) {
            return true
        }

        return false
    }

    private func clickPointForItemIfVisible(_ item: MenuBarFloatingItemSnapshot) -> CGPoint? {
        guard isQuartzFrameVisibleOnAnyDisplay(item.quartzFrame) else {
            return nil
        }
        return CGPoint(x: item.quartzFrame.midX, y: item.quartzFrame.midY)
    }

    private func postLeftClick(at point: CGPoint) -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            return false
        }
        guard let down = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        ),
        let up = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            return false
        }

        down.post(tap: .cghidEventTap)
        usleep(12_000)
        up.post(tap: .cghidEventTap)
        return true
    }

    private func relocateItem(
        itemID: String,
        fallback: MenuBarFloatingItemSnapshot,
        to target: RelocationTarget
    ) async -> Bool {
        guard isRunning,
              PermissionManager.shared.isAccessibilityGranted else {
            return false
        }
        if target == .alwaysHidden, !isFeatureEnabled {
            return false
        }

        let manager = MenuBarManager.shared
        let sessionState = MoveSessionState(
            visibleState: manager.section(withName: .visible)?.controlItem.state ?? .hideItems,
            hiddenState: manager.section(withName: .hidden)?.controlItem.state ?? .hideItems,
            alwaysHiddenState: manager.section(withName: .alwaysHidden)?.controlItem.state ?? .hideItems,
            alwaysHiddenSectionEnabled: manager.isSectionEnabled(.alwaysHidden)
        )

        await applyShowAllShield(using: manager)

        guard await waitForControlItemFrames() else {
            await restoreMoveSession(using: manager, state: sessionState)
            return false
        }

        if target == .alwaysHidden || target == .hidden {
            let hasCorrectOrder = await ensureControlItemOrder()
            if !hasCorrectOrder {
                await restoreMoveSession(using: manager, state: sessionState)
                return false
            }
        }

        var moved = false

        for attempt in 0 ..< 7 {
            rescan(force: true)

            guard let sourceSnapshot = await waitForRelocationCandidate(itemID: itemID, fallback: fallback) else {
                continue
            }

            guard let destinationPoint = relocationDestination(
                for: target,
                source: sourceSnapshot,
                attempt: attempt
            ) else {
                continue
            }

            let sourcePoint = CGPoint(x: sourceSnapshot.quartzFrame.midX, y: sourceSnapshot.quartzFrame.midY)
            let posted = performCommandDrag(from: sourcePoint, to: destinationPoint)
            if !posted {
                continue
            }

            if let relocatedItem = await verifyRelocationAfterDrag(
                itemID: itemID,
                fallback: fallback,
                target: target
            ) {
                remapTrackedItemIDIfNeeded(
                    oldID: itemID,
                    newItem: relocatedItem,
                    target: target
                )
                moved = true
                break
            }
        }

        var restoredSessionState = sessionState
        if shouldEnableAlwaysHiddenSection || (moved && target == .alwaysHidden) {
            restoredSessionState = MoveSessionState(
                visibleState: sessionState.visibleState,
                hiddenState: sessionState.hiddenState,
                alwaysHiddenState: .hideItems,
                alwaysHiddenSectionEnabled: true
            )
        }

        await restoreMoveSession(using: manager, state: restoredSessionState)
        return moved
    }

    private func applyShowAllShield(using manager: MenuBarManager) async {
        manager.setAlwaysHiddenSectionEnabled(true)
        manager.section(withName: .visible)?.controlItem.state = .showItems

        // Shield first, then contract AH separator, then reveal.
        manager.section(withName: .hidden)?.controlItem.state = .hideItems
        manager.section(withName: .alwaysHidden)?.controlItem.state = .showItems
        try? await Task.sleep(for: .milliseconds(50))

        manager.section(withName: .hidden)?.controlItem.state = .showItems
        try? await Task.sleep(for: .milliseconds(140))
        refreshSeparatorCaches()
    }

    private func restoreMoveSession(using manager: MenuBarManager, state: MoveSessionState) async {
        // Restore through a shield transition to avoid separator race conditions.
        manager.section(withName: .hidden)?.controlItem.state = .hideItems
        manager.section(withName: .alwaysHidden)?.controlItem.state = .hideItems
        try? await Task.sleep(for: .milliseconds(50))

        manager.section(withName: .visible)?.controlItem.state = state.visibleState
        manager.section(withName: .hidden)?.controlItem.state = state.hiddenState
        manager.section(withName: .alwaysHidden)?.controlItem.state = state.alwaysHiddenState
        manager.setAlwaysHiddenSectionEnabled(
            state.alwaysHiddenSectionEnabled || shouldEnableAlwaysHiddenSection || isInSettingsInspectionMode
        )

        try? await Task.sleep(for: .milliseconds(90))
        refreshSeparatorCaches()
    }

    private func waitForRelocationCandidate(
        itemID: String,
        fallback: MenuBarFloatingItemSnapshot
    ) async -> MenuBarFloatingItemSnapshot? {
        for _ in 0 ..< 20 {
            if let candidate = relocationCandidate(itemID: itemID, fallback: fallback),
               isQuartzFrameVisibleOnAnyDisplay(candidate.quartzFrame) {
                return candidate
            }
            try? await Task.sleep(for: .milliseconds(80))
            rescan(force: true)
        }
        return relocationCandidate(itemID: itemID, fallback: fallback)
    }

    private func isQuartzFrameVisibleOnAnyDisplay(_ frame: CGRect) -> Bool {
        let midpoint = CGPoint(x: frame.midX, y: frame.midY)
        if let screen = MenuBarFloatingCoordinateConverter.screenContaining(quartzPoint: midpoint),
           let bounds = MenuBarFloatingCoordinateConverter.displayBounds(of: screen) {
            return bounds.intersects(frame)
        }
        return frame.width > 0 && frame.height > 0
    }

    private func relocationDestination(
        for target: RelocationTarget,
        source: MenuBarFloatingItemSnapshot,
        attempt: Int
    ) -> CGPoint? {
        let attemptOffset = CGFloat(attempt)
        let sourceWidth = max(18, source.quartzFrame.width)

        switch target {
        case .alwaysHidden:
            guard let alwaysHiddenOriginX = alwaysHiddenSeparatorOriginX() else {
                return nil
            }

            let fallbackBounds = MenuBarFloatingCoordinateConverter
                .screenContaining(quartzPoint: CGPoint(x: source.quartzFrame.midX, y: source.quartzFrame.midY))
                .flatMap { MenuBarFloatingCoordinateConverter.displayBounds(of: $0) }
            let hardLeft = (fallbackBounds?.minX ?? alwaysHiddenOriginX - 420) + 8
            let moveOffset = max(80, sourceWidth + 56)
            let targetX = max(hardLeft, alwaysHiddenOriginX - moveOffset - (attemptOffset * 42))
            return CGPoint(x: targetX, y: source.quartzFrame.midY)

        case .hidden:
            guard let hiddenOriginX = hiddenSeparatorOriginX() else {
                return nil
            }

            let rightPadding = max(16, sourceWidth * 0.42)
            let corridorRight = hiddenOriginX - rightPadding

            if let alwaysHiddenRightEdgeX = alwaysHiddenSeparatorRightEdgeX() {
                let corridorLeft = alwaysHiddenRightEdgeX + max(16, sourceWidth * 0.42)
                if corridorRight > corridorLeft {
                    let midpoint = (corridorLeft + corridorRight) / 2
                    let stride = max(14, sourceWidth * 0.36)
                    let direction: CGFloat = attempt.isMultiple(of: 2) ? 1 : -1
                    let wave = CGFloat((attempt + 1) / 2)
                    let targetX = min(corridorRight, max(corridorLeft, midpoint + (direction * wave * stride)))
                    return CGPoint(x: targetX, y: source.quartzFrame.midY)
                }
            }

            // Fallback when hidden corridor is too narrow or always-hidden separator is unavailable:
            // place immediately left of the hidden divider.
            let fallbackOffset = max(44, sourceWidth + 24) + (CGFloat(attempt) * 16)
            let targetX = hiddenOriginX - fallbackOffset
            return CGPoint(x: targetX, y: source.quartzFrame.midY)

        case .visible:
            guard let hiddenRightEdgeX = hiddenSeparatorRightEdgeX() else {
                return nil
            }

            let fallbackBounds = MenuBarFloatingCoordinateConverter
                .screenContaining(quartzPoint: CGPoint(x: source.quartzFrame.midX, y: source.quartzFrame.midY))
                .flatMap { MenuBarFloatingCoordinateConverter.displayBounds(of: $0) }
            let hardRight = (fallbackBounds?.maxX ?? hiddenRightEdgeX + 420) - 8
            let moveOffset = max(70, sourceWidth + 40)
            let targetX = min(hardRight, hiddenRightEdgeX + moveOffset + (attemptOffset * 38))
            return CGPoint(x: targetX, y: source.quartzFrame.midY)
        }
    }

    private func verifyRelocation(
        itemID: String,
        fallback: MenuBarFloatingItemSnapshot,
        target: RelocationTarget
    ) -> MenuBarFloatingItemSnapshot? {
        guard let item = relocationCandidate(itemID: itemID, fallback: fallback) else {
            return nil
        }

        switch target {
        case .alwaysHidden:
            guard let alwaysHiddenOriginX = alwaysHiddenSeparatorOriginX() else {
                return nil
            }
            let margin = max(4, item.quartzFrame.width * 0.3)
            return item.quartzFrame.midX < (alwaysHiddenOriginX - margin) ? item : nil

        case .hidden:
            guard let hiddenOriginX = hiddenSeparatorOriginX() else {
                return nil
            }
            let margin = max(4, item.quartzFrame.width * 0.28)
            let midpoint = item.quartzFrame.midX
            // Hidden classification is based on being left of the hidden divider
            // (and not explicitly pinned to Floating Bar by ID).
            return midpoint < (hiddenOriginX - margin) ? item : nil

        case .visible:
            guard let hiddenRightEdgeX = hiddenSeparatorRightEdgeX() else {
                return nil
            }
            let margin = max(4, item.quartzFrame.width * 0.3)
            return item.quartzFrame.midX > (hiddenRightEdgeX + margin) ? item : nil
        }
    }

    private func verifyRelocationAfterDrag(
        itemID: String,
        fallback: MenuBarFloatingItemSnapshot,
        target: RelocationTarget
    ) async -> MenuBarFloatingItemSnapshot? {
        let firstDelay = Int(max(minRelocationSettleDelayMs, min(maxRelocationSettleDelayMs, relocationSettleDelayMs)))
        try? await Task.sleep(for: .milliseconds(firstDelay))
        rescan(force: true)

        if let relocated = verifyRelocation(itemID: itemID, fallback: fallback, target: target) {
            tuneRelocationSettleDelay(success: true)
            return relocated
        }

        try? await Task.sleep(for: .milliseconds(max(55, firstDelay / 2)))
        rescan(force: true)
        if let relocated = verifyRelocation(itemID: itemID, fallback: fallback, target: target) {
            tuneRelocationSettleDelay(success: true)
            return relocated
        }

        tuneRelocationSettleDelay(success: false)
        return nil
    }

    private func tuneRelocationSettleDelay(success: Bool) {
        if success {
            relocationSettleDelayMs = max(
                minRelocationSettleDelayMs,
                UInt64(Double(relocationSettleDelayMs) * 0.88)
            )
            return
        }
        relocationSettleDelayMs = min(maxRelocationSettleDelayMs, relocationSettleDelayMs + 24)
    }

    private func relocationCandidate(
        itemID: String,
        fallback: MenuBarFloatingItemSnapshot
    ) -> MenuBarFloatingItemSnapshot? {
        if let exact = scannedItems.first(where: { $0.id == itemID }) {
            return exact
        }
        if let exactCached = itemRegistryByID[itemID] {
            return exactCached
        }

        func stableTextToken(_ text: String?) -> String? {
            guard let text, !text.isEmpty else { return nil }
            let prefix = text
                .split(separator: ",", maxSplits: 1)
                .first
                .map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let prefix, !prefix.isEmpty {
                return prefix
            }
            return text
        }

        let fallbackTitleToken = stableTextToken(fallback.title)
        let fallbackDetailToken = stableTextToken(fallback.detail)

        let sameMetadata = scannedItems.filter { candidate in
            guard candidate.ownerBundleID == fallback.ownerBundleID else { return false }
            if let fallbackIdentifier = fallback.axIdentifier {
                return candidate.axIdentifier == fallbackIdentifier
            }
            if let fallbackIndex = fallback.statusItemIndex {
                return candidate.statusItemIndex == fallbackIndex
            }
            if let titleToken = fallbackTitleToken {
                return stableTextToken(candidate.title) == titleToken
            }
            if let detailToken = fallbackDetailToken {
                return stableTextToken(candidate.detail) == detailToken
            }
            let widthClose = abs(candidate.quartzFrame.width - fallback.quartzFrame.width) <= 2
            let heightClose = abs(candidate.quartzFrame.height - fallback.quartzFrame.height) <= 2
            return widthClose && heightClose
        }

        guard !sameMetadata.isEmpty else {
            return nil
        }

        if sameMetadata.count == 1 {
            return sameMetadata[0]
        }

        return sameMetadata.min { lhs, rhs in
            let lhsDistance = abs(lhs.quartzFrame.midX - fallback.quartzFrame.midX)
            let rhsDistance = abs(rhs.quartzFrame.midX - fallback.quartzFrame.midX)
            return lhsDistance < rhsDistance
        }
    }

    private func remapTrackedItemIDIfNeeded(
        oldID: String,
        newItem: MenuBarFloatingItemSnapshot,
        target: RelocationTarget
    ) {
        let newID = newItem.id
        guard newID != oldID else {
            itemRegistryByID[oldID] = newItem
            return
        }

        if let pendingPlacement = pendingPlacementByID.removeValue(forKey: oldID) {
            pendingPlacementByID[newID] = pendingPlacement
        }

        if target == .alwaysHidden {
            alwaysHiddenItemIDs.remove(oldID)
            alwaysHiddenItemIDs.insert(newID)
        } else {
            alwaysHiddenItemIDs.remove(newID)
        }

        let oldEntry = itemRegistryByID[oldID]
        itemRegistryByID.removeValue(forKey: oldID)
        let oldEntryCachedIcon = oldEntry.flatMap { cachedIcon(for: $0) }
        let newEntryCachedIcon = cachedIcon(for: newItem)

        let merged = MenuBarFloatingItemSnapshot(
            id: newID,
            windowID: newItem.windowID,
            axElement: newItem.axElement,
            quartzFrame: newItem.quartzFrame,
            appKitFrame: newItem.appKitFrame,
            ownerBundleID: newItem.ownerBundleID,
            axIdentifier: newItem.axIdentifier ?? oldEntry?.axIdentifier,
            statusItemIndex: newItem.statusItemIndex ?? oldEntry?.statusItemIndex,
            title: newItem.title ?? oldEntry?.title,
            detail: newItem.detail ?? oldEntry?.detail,
            icon: newItem.icon ?? oldEntry?.icon ?? oldEntryCachedIcon ?? newEntryCachedIcon
        )
        itemRegistryByID[newID] = merged
        if let mergedIcon = merged.icon {
            cacheIcon(mergedIcon, for: iconCacheKeys(for: merged), overwrite: false)
        }
    }

    private func detectControlItemOrder() -> ControlItemOrder {
        guard let alwaysOriginX = alwaysHiddenSeparatorOriginX(),
              let hiddenOriginX = hiddenSeparatorOriginX() else {
            return .unknown
        }
        if alwaysOriginX < hiddenOriginX {
            return .alwaysHiddenLeftOfHidden
        }
        return .unknown
    }

    private func ensureControlItemOrder() async -> Bool {
        if detectControlItemOrder() == .alwaysHiddenLeftOfHidden {
            return true
        }

        guard await waitForControlItemFrames() else {
            return false
        }

        for attempt in 0 ..< 5 {
            guard let alwaysHiddenFrame = MenuBarManager.shared.controlItemFrame(for: .alwaysHidden),
                  let hiddenFrame = MenuBarManager.shared.controlItemFrame(for: .hidden) else {
                return false
            }

            let alwaysAnchor = MenuBarFloatingCoordinateConverter.appKitToQuartz(alwaysHiddenFrame)
            let hiddenAnchor = MenuBarFloatingCoordinateConverter.appKitToQuartz(hiddenFrame)
            let hiddenOriginX = hiddenSeparatorOriginX() ?? hiddenAnchor.minX
            let start = CGPoint(x: alwaysAnchor.midX, y: alwaysAnchor.midY)
            let screenBounds = screenQuartzBounds(containing: hiddenFrame)
                ?? screenQuartzBounds(containing: alwaysHiddenFrame)
            let hardLeft = (screenBounds?.minX ?? hiddenAnchor.minX - 360) + 8
            let proposedX = hiddenOriginX - 110 - CGFloat(attempt * 58)
            let end = CGPoint(x: max(hardLeft, proposedX), y: hiddenAnchor.midY)

            _ = performCommandDrag(from: start, to: end)
            try? await Task.sleep(for: .milliseconds(150))
            rescan(force: true)
            refreshSeparatorCaches()

            if detectControlItemOrder() == .alwaysHiddenLeftOfHidden {
                return true
            }
        }

        return false
    }

    private func waitForControlItemFrames() async -> Bool {
        for _ in 0 ..< 14 {
            let hasAlways = MenuBarManager.shared.controlItemFrame(for: .alwaysHidden) != nil
            let hasHidden = MenuBarManager.shared.controlItemFrame(for: .hidden) != nil
            if hasAlways && hasHidden {
                refreshSeparatorCaches()
                return true
            }
            try? await Task.sleep(for: .milliseconds(60))
        }
        return false
    }

    private func refreshSeparatorCaches() {
        _ = hiddenSeparatorOriginX()
        _ = hiddenSeparatorRightEdgeX()
        _ = alwaysHiddenSeparatorOriginX()
        _ = alwaysHiddenSeparatorRightEdgeX()
    }

    private func hiddenSeparatorOriginX() -> CGFloat? {
        guard let frame = MenuBarManager.shared.controlItemFrame(for: .hidden) else {
            return lastKnownHiddenSeparatorOriginX
        }
        let quartzFrame = MenuBarFloatingCoordinateConverter.appKitToQuartz(frame)
        if quartzFrame.width > 0, quartzFrame.width < 500, isQuartzFrameVisibleOnAnyDisplay(quartzFrame) {
            lastKnownHiddenSeparatorOriginX = quartzFrame.minX
            lastKnownHiddenSeparatorRightEdgeX = quartzFrame.maxX
            return quartzFrame.minX
        }
        return lastKnownHiddenSeparatorOriginX
    }

    private func hiddenSeparatorRightEdgeX() -> CGFloat? {
        guard let frame = MenuBarManager.shared.controlItemFrame(for: .hidden) else {
            return lastKnownHiddenSeparatorRightEdgeX
        }
        let quartzFrame = MenuBarFloatingCoordinateConverter.appKitToQuartz(frame)
        if quartzFrame.width > 0, quartzFrame.width < 500, isQuartzFrameVisibleOnAnyDisplay(quartzFrame) {
            lastKnownHiddenSeparatorOriginX = quartzFrame.minX
            lastKnownHiddenSeparatorRightEdgeX = quartzFrame.maxX
            return quartzFrame.maxX
        }
        return lastKnownHiddenSeparatorRightEdgeX
    }

    private func alwaysHiddenSeparatorOriginX() -> CGFloat? {
        guard let frame = MenuBarManager.shared.controlItemFrame(for: .alwaysHidden) else {
            return lastKnownAlwaysHiddenSeparatorOriginX
        }
        let quartzFrame = MenuBarFloatingCoordinateConverter.appKitToQuartz(frame)
        if quartzFrame.width > 0, quartzFrame.width < 500, isQuartzFrameVisibleOnAnyDisplay(quartzFrame) {
            lastKnownAlwaysHiddenSeparatorOriginX = quartzFrame.minX
            lastKnownAlwaysHiddenSeparatorRightEdgeX = quartzFrame.maxX
            return quartzFrame.minX
        }
        return lastKnownAlwaysHiddenSeparatorOriginX
    }

    private func alwaysHiddenSeparatorRightEdgeX() -> CGFloat? {
        guard let frame = MenuBarManager.shared.controlItemFrame(for: .alwaysHidden) else {
            return lastKnownAlwaysHiddenSeparatorRightEdgeX
        }
        let quartzFrame = MenuBarFloatingCoordinateConverter.appKitToQuartz(frame)
        if quartzFrame.width > 0, quartzFrame.width < 500, isQuartzFrameVisibleOnAnyDisplay(quartzFrame) {
            lastKnownAlwaysHiddenSeparatorOriginX = quartzFrame.minX
            lastKnownAlwaysHiddenSeparatorRightEdgeX = quartzFrame.maxX
            return quartzFrame.maxX
        }
        return lastKnownAlwaysHiddenSeparatorRightEdgeX
    }

    private func performCommandDrag(from start: CGPoint, to end: CGPoint) -> Bool {
        guard isRelocationInProgress else {
            return false
        }
        guard start.x.isFinite, start.y.isFinite, end.x.isFinite, end.y.isFinite else {
            return false
        }

        if postCommandDrag(from: start, to: end, sourceStateID: .hidSystemState) {
            return true
        }
        return postCommandDrag(from: start, to: end, sourceStateID: .combinedSessionState)
    }

    private func postCommandDrag(
        from start: CGPoint,
        to end: CGPoint,
        sourceStateID: CGEventSourceStateID
    ) -> Bool {
        guard let source = CGEventSource(stateID: sourceStateID) else {
            return false
        }

        func post(_ event: CGEvent) {
            event.post(tap: .cghidEventTap)
        }

        let originalLocation = CGEvent(source: nil)?.location
        let referencePoint = originalLocation ?? start
        let screenBounds =
            MenuBarFloatingCoordinateConverter
            .screenContaining(quartzPoint: referencePoint)
            .flatMap { MenuBarFloatingCoordinateConverter.displayBounds(of: $0) }
            ?? MenuBarFloatingCoordinateConverter
            .screenContaining(quartzPoint: start)
            .flatMap { MenuBarFloatingCoordinateConverter.displayBounds(of: $0) }

        func clampPoint(_ point: CGPoint, bounds: CGRect?) -> CGPoint {
            guard let bounds else { return point }
            return CGPoint(
                x: min(max(point.x, bounds.minX + 2), bounds.maxX - 2),
                y: min(max(point.y, bounds.minY + 2), bounds.maxY - 2)
            )
        }

        let clampedStart = clampPoint(start, bounds: screenBounds)
        let clampedEnd = clampPoint(end, bounds: screenBounds)

        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let flags: CGEventFlags = [.maskCommand]
        let commandKeyCode: CGKeyCode = 0x37 // left command
        var didSendCommandDown = false
        var didWarpCursor = false

        defer {
            if didSendCommandDown,
               let commandUp = CGEvent(
                   keyboardEventSource: source,
                   virtualKey: commandKeyCode,
                   keyDown: false
               ) {
                post(commandUp)
            }
            if didWarpCursor, let originalLocation {
                CGWarpMouseCursorPosition(originalLocation)
            }
        }

        CGWarpMouseCursorPosition(clampedStart)
        didWarpCursor = true
        usleep(8_000)

        guard let mouseDown = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseDown,
            mouseCursorPosition: clampedStart,
            mouseButton: .left
        ) else {
            return false
        }

        if let commandDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: commandKeyCode,
            keyDown: true
        ) {
            commandDown.flags = flags
            post(commandDown)
            didSendCommandDown = true
            usleep(5_000)
        }

        mouseDown.flags = flags
        post(mouseDown)

        let stepCount = 14
        for step in 1 ... stepCount {
            let progress = CGFloat(step) / CGFloat(stepCount)
            let point = CGPoint(
                x: clampedStart.x + ((clampedEnd.x - clampedStart.x) * progress),
                y: clampedStart.y + ((clampedEnd.y - clampedStart.y) * progress)
            )
            if let drag = CGEvent(
                mouseEventSource: source,
                mouseType: .leftMouseDragged,
                mouseCursorPosition: point,
                mouseButton: .left
            ) {
                drag.flags = flags
                post(drag)
            }
            usleep(6_000)
        }

        guard let mouseUp = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseUp,
            mouseCursorPosition: clampedEnd,
            mouseButton: .left
        ) else {
            return false
        }

        mouseUp.flags = flags
        post(mouseUp)
        usleep(10_000)
        return dragEventsWereObservedRecently()
    }

    private func dragEventsWereObservedRecently(threshold: CFTimeInterval = 0.28) -> Bool {
        let states: [CGEventSourceStateID] = [.combinedSessionState, .hidSystemState]
        for state in states {
            if CGEventSource.secondsSinceLastEventType(state, eventType: .leftMouseDragged) < threshold {
                return true
            }
            if CGEventSource.secondsSinceLastEventType(state, eventType: .leftMouseUp) < threshold {
                return true
            }
            if CGEventSource.secondsSinceLastEventType(state, eventType: .leftMouseDown) < threshold {
                return true
            }
        }
        return false
    }

    private func updateRegistry(with items: [MenuBarFloatingItemSnapshot]) {
        for item in items {
            var merged = item
            if merged.icon == nil, let cachedIcon = cachedIcon(for: item) {
                merged = MenuBarFloatingItemSnapshot(
                    id: item.id,
                    windowID: item.windowID,
                    axElement: item.axElement,
                    quartzFrame: item.quartzFrame,
                    appKitFrame: item.appKitFrame,
                    ownerBundleID: item.ownerBundleID,
                    axIdentifier: item.axIdentifier,
                    statusItemIndex: item.statusItemIndex,
                    title: item.title,
                    detail: item.detail,
                    icon: cachedIcon
                )
            }
            itemRegistryByID[item.id] = merged
            if let icon = merged.icon {
                cacheIcon(icon, for: iconCacheKeys(for: merged), overwrite: false)
            }
        }

        let keep = alwaysHiddenItemIDs
        let scannedIDs = Set(scannedItems.map(\.id))
        itemRegistryByID = itemRegistryByID.filter { key, _ in
            keep.contains(key) || scannedIDs.contains(key)
        }
    }

    private func reconcileAlwaysHiddenIDs(using items: [MenuBarFloatingItemSnapshot]) {
        guard !alwaysHiddenItemIDs.isEmpty, !items.isEmpty else { return }

        let scannedIDs = Set(items.map(\.id))
        let missingHiddenIDs = alwaysHiddenItemIDs.subtracting(scannedIDs)
        guard !missingHiddenIDs.isEmpty else { return }

        var reservedIDs = alwaysHiddenItemIDs.intersection(scannedIDs)
        var remaps = [(oldID: String, newItem: MenuBarFloatingItemSnapshot)]()

        for missingID in missingHiddenIDs.sorted() {
            guard let fallback = itemRegistryByID[missingID] else { continue }
            guard let candidate = bestAlwaysHiddenRemapCandidate(
                for: fallback,
                in: items,
                reservedIDs: reservedIDs
            ) else {
                continue
            }
            reservedIDs.insert(candidate.id)
            remaps.append((oldID: missingID, newItem: candidate))
        }

        guard !remaps.isEmpty else { return }
        for remap in remaps {
            remapTrackedItemIDIfNeeded(oldID: remap.oldID, newItem: remap.newItem, target: .alwaysHidden)
        }
    }

    private func sanitizeAlwaysHiddenIDs(using items: [MenuBarFloatingItemSnapshot]) {
        guard !alwaysHiddenItemIDs.isEmpty else { return }

        let scannedByID = indexByID(items)
        var sanitized = alwaysHiddenItemIDs.filter { !isMandatoryMenuBarManagerControlID($0) }

        sanitized = sanitized.filter { id in
            if let scanned = scannedByID[id] {
                return !isMandatoryMenuBarManagerControlItem(scanned)
            }
            if let cached = itemRegistryByID[id] {
                return !isMandatoryMenuBarManagerControlItem(cached)
            }
            return true
        }

        let sanitizedSet = Set(sanitized)
        if sanitizedSet != alwaysHiddenItemIDs {
            alwaysHiddenItemIDs = sanitizedSet
        }
    }

    private func bestAlwaysHiddenRemapCandidate(
        for fallback: MenuBarFloatingItemSnapshot,
        in items: [MenuBarFloatingItemSnapshot],
        reservedIDs: Set<String>
    ) -> MenuBarFloatingItemSnapshot? {
        let candidates = items.filter { candidate in
            candidate.ownerBundleID == fallback.ownerBundleID
                && !reservedIDs.contains(candidate.id)
                && !isMandatoryMenuBarManagerControlItem(candidate)
        }
        guard !candidates.isEmpty else { return nil }

        if let fallbackIdentifier = fallback.axIdentifier,
           let identifierMatch = candidates.first(where: { $0.axIdentifier == fallbackIdentifier }) {
            return identifierMatch
        }

        let fallbackDetailToken = stableTextToken(fallback.detail)
        if let fallbackDetailToken {
            let detailMatches = candidates.filter { stableTextToken($0.detail) == fallbackDetailToken }
            if let detailMatch = nearestByQuartzDistance(from: fallback, in: detailMatches) {
                return detailMatch
            }
        }

        let fallbackTitleToken = stableTextToken(fallback.title)
        if let fallbackTitleToken {
            let titleMatches = candidates.filter { stableTextToken($0.title) == fallbackTitleToken }
            if let titleMatch = nearestByQuartzDistance(from: fallback, in: titleMatches) {
                return titleMatch
            }
        }

        if let fallbackIndex = fallback.statusItemIndex {
            let indexMatches = candidates.filter { $0.statusItemIndex == fallbackIndex }
            if let indexMatch = nearestByQuartzDistance(from: fallback, in: indexMatches) {
                return indexMatch
            }
        }

        let geometryMatches = candidates.filter { candidate in
            abs(candidate.quartzFrame.width - fallback.quartzFrame.width) <= 2
                && abs(candidate.quartzFrame.height - fallback.quartzFrame.height) <= 2
                && abs(candidate.quartzFrame.midX - fallback.quartzFrame.midX) <= 28
        }
        if geometryMatches.count == 1 {
            return geometryMatches[0]
        }

        return nil
    }

    private func nearestByQuartzDistance(
        from source: MenuBarFloatingItemSnapshot,
        in candidates: [MenuBarFloatingItemSnapshot]
    ) -> MenuBarFloatingItemSnapshot? {
        guard !candidates.isEmpty else { return nil }
        return candidates.min { lhs, rhs in
            let lhsDistance = abs(lhs.quartzFrame.midX - source.quartzFrame.midX)
            let rhsDistance = abs(rhs.quartzFrame.midX - source.quartzFrame.midX)
            return lhsDistance < rhsDistance
        }
    }

    private func screenQuartzBounds(containing appKitFrame: CGRect) -> CGRect? {
        let midpoint = CGPoint(x: appKitFrame.midX, y: appKitFrame.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(midpoint) }),
              let bounds = MenuBarFloatingCoordinateConverter.displayBounds(of: screen) else {
            return nil
        }
        return bounds
    }

    private func installObservers() {
        let notificationCenter = NotificationCenter.default
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        observers.append(notificationCenter.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.requestRescanOnMainActor()
        })

        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.requestRescanOnMainActor()
        })

        observers.append(notificationCenter.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.activeMenuTrackingDepth += 1
                self.lastMenuTrackingEventTime = ProcessInfo.processInfo.systemUptime
            }
        })

        observers.append(notificationCenter.addObserver(
            forName: NSMenu.didEndTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.activeMenuTrackingDepth = max(0, self.activeMenuTrackingDepth - 1)
                self.lastMenuTrackingEventTime = ProcessInfo.processInfo.systemUptime
            }
        })

        // React instantly to hidden-section visibility changes
        // so the floating bar appears/disappears without waiting for the rescan timer.
        if let hiddenSection = MenuBarManager.shared.section(withName: .hidden) {
            stateCancellable = hiddenSection.controlItem.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.applyPanel()
                    }
                }
        }
    }

    private func teardownObservers() {
        let notificationCenter = NotificationCenter.default
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        for observer in observers {
            notificationCenter.removeObserver(observer)
            workspaceCenter.removeObserver(observer)
        }
        observers.removeAll()

        stateCancellable?.cancel()
        stateCancellable = nil
    }

    private func scheduleRescanTimer() {
        let interval = desiredRescanInterval()
        if rescanTimer != nil, abs(currentRescanInterval - interval) < 0.01 {
            return
        }

        currentRescanInterval = interval
        rescanTimer?.invalidate()
        rescanTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.requestRescanOnMainActor()
        }
    }

    private func scheduleFollowUpRescan(refreshIcons: Bool = false) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.requestRescanOnMainActor(refreshIcons: refreshIcons)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.requestRescanOnMainActor(refreshIcons: refreshIcons)
        }
    }

    private nonisolated func requestRescanOnMainActor(force: Bool = false, refreshIcons: Bool = false) {
        Task { @MainActor [weak self] in
            self?.rescan(force: force, refreshIcons: refreshIcons)
        }
    }

    private func desiredRescanInterval() -> TimeInterval {
        if isInSettingsInspectionMode {
            // Keep settings scrolling/interaction fluid by reducing scan churn while editing.
            return 2.8
        }
        if isHiddenSectionVisibleNow || isManualPreviewRequested || panelController.isVisible {
            return 1.4
        }
        return 3.5
    }

    private func saveConfiguration() {
        let config = Config(
            isFeatureEnabled: isFeatureEnabled,
            alwaysHiddenItemIDs: Array(alwaysHiddenItemIDs)
        )
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func loadConfiguration() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let config = try? JSONDecoder().decode(Config.self, from: data) else {
            return
        }
        isFeatureEnabled = config.isFeatureEnabled
        alwaysHiddenItemIDs = Set(config.alwaysHiddenItemIDs.filter { !isMandatoryMenuBarManagerControlID($0) })
    }

    private func loadPersistedIconCache() {
        guard let data = UserDefaults.standard.data(forKey: iconCacheDefaultsKey),
              let stored = try? JSONDecoder().decode([String: Data].self, from: data) else {
            return
        }

        var restored = [String: NSImage]()
        restored.reserveCapacity(stored.count)
        for (cacheKey, imageData) in stored {
            if let image = NSImage(data: imageData) {
                restored[cacheKey] = image
            }
        }
        iconCacheByID = restored
        persistedIconCacheKeys = Set(stored.keys)
    }

    private func savePersistedIconCache() {
        var encodedCache = [String: Data]()
        encodedCache.reserveCapacity(persistedIconCacheKeys.count)

        for cacheKey in persistedIconCacheKeys {
            guard let image = iconCacheByID[cacheKey] else { continue }
            guard let imageData = pngData(for: image) else { continue }
            encodedCache[cacheKey] = imageData
        }

        guard let data = try? JSONEncoder().encode(encodedCache) else { return }
        UserDefaults.standard.set(data, forKey: iconCacheDefaultsKey)
    }

    private func cacheIcon(_ icon: NSImage, for cacheKeys: [String], overwrite: Bool = false) {
        var didWrite = false
        var seen = Set<String>()

        for cacheKey in cacheKeys where !cacheKey.isEmpty {
            guard seen.insert(cacheKey).inserted else { continue }
            if !overwrite, iconCacheByID[cacheKey] != nil {
                continue
            }
            iconCacheByID[cacheKey] = icon
            persistedIconCacheKeys.insert(cacheKey)
            didWrite = true
        }

        if didWrite {
            savePersistedIconCache()
        }
    }

    private func pngData(for image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:]) ?? tiff
    }

    private func syncAlwaysHiddenSectionEnabled(forceEnable: Bool) {
        guard isRunning || forceEnable else { return }
        let enabled = isRunning && (forceEnable || shouldEnableAlwaysHiddenSection)
        MenuBarManager.shared.setAlwaysHiddenSectionEnabled(enabled)
    }

    private func preferredOwnerBundleIDsForRescan() -> Set<String>? {
        guard !isInSettingsInspectionMode else { return nil }

        var ownerBundleIDs = Set<String>()

        for itemID in alwaysHiddenItemIDs {
            guard let separatorRange = itemID.range(of: "::") else { continue }
            let owner = String(itemID[..<separatorRange.lowerBound])
            if owner.contains(".") {
                ownerBundleIDs.insert(owner)
            }
        }

        for item in itemRegistryByID.values where alwaysHiddenItemIDs.contains(item.id) {
            ownerBundleIDs.insert(item.ownerBundleID)
        }

        for item in scannedItems where alwaysHiddenItemIDs.contains(item.id) {
            ownerBundleIDs.insert(item.ownerBundleID)
        }

        if ownerBundleIDs.isEmpty {
            return Set(MenuBarFloatingScanner.Owner.allCases.map { $0.rawValue })
        }

        return ownerBundleIDs
    }

    private func cachedIcon(for item: MenuBarFloatingItemSnapshot) -> NSImage? {
        for key in iconCacheKeys(for: item) {
            if let icon = iconCacheByID[key] {
                return icon
            }
        }
        return nil
    }

    private func iconCacheKeys(for item: MenuBarFloatingItemSnapshot) -> [String] {
        var keys = [String]()
        keys.reserveCapacity(5)

        if let axIdentifier = item.axIdentifier, !axIdentifier.isEmpty {
            keys.append("\(item.ownerBundleID)::axid:\(axIdentifier)")
        }
        if let titleToken = stableTextToken(item.title) {
            keys.append("\(item.ownerBundleID)::title:\(titleToken)")
        }
        if let detailToken = stableTextToken(item.detail) {
            keys.append("\(item.ownerBundleID)::detail:\(detailToken)")
        }
        if let statusItemIndex = item.statusItemIndex {
            keys.append("\(item.ownerBundleID)::statusItem:\(statusItemIndex)")
        }
        if !item.id.isEmpty {
            keys.append(item.id)
        }

        var seen = Set<String>()
        return keys.filter { key in
            seen.insert(key).inserted
        }
    }

    private func stableTextToken(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        let token = trimmed
            .split(separator: ",", maxSplits: 1)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let token, !token.isEmpty {
            return token
        }
        return trimmed.lowercased()
    }
}
