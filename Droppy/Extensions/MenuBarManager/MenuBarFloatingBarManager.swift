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

    @Published private(set) var scannedItems = [MenuBarFloatingItemSnapshot]() {
        didSet {
            invalidateSettingsLaneCache()
        }
    }
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
            let floatingSubset = floatingBarItemIDs.intersection(alwaysHiddenItemIDs)
            if floatingSubset != floatingBarItemIDs {
                floatingBarItemIDs = floatingSubset
            }
            invalidateSettingsLaneCache()
            saveConfiguration()
            applyPanel()
        }
    }
    @Published var floatingBarItemIDs: Set<String> {
        didSet {
            guard !isLoadingConfiguration else { return }
            invalidateSettingsLaneCache()
            saveConfiguration()
            applyPanel()
        }
    }

    private struct Config: Codable {
        var isFeatureEnabled: Bool
        var alwaysHiddenItemIDs: [String]
        var floatingBarItemIDs: [String]?
    }

    private struct PersistedIconCacheEnvelope: Codable {
        var savedAt: TimeInterval
        var images: [String: Data]
    }

    private enum RelocationTarget {
        case alwaysHidden
        case hidden
        case visible
    }

    private enum ControlItemOrder {
        case alwaysHiddenLeftOfHidden
        case alwaysHiddenRightOfHidden
        case unknown
    }

    private enum HiddenSectionSide {
        case leftOfHiddenDivider
        case rightOfHiddenDivider
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

    private enum PersistedIconCacheSource {
        case disk
        case defaults
    }

    private let scanner = MenuBarFloatingScanner()
    private let panelController = MenuBarFloatingPanelController()
    private let maskController = MenuBarMaskController()
    private let defaultsKey = "MenuBarManager_FloatingBarConfig"
    private let iconCacheDefaultsKey = "MenuBarManager_FloatingBarIconCacheV8"
    private let legacyIconCacheDefaultsKeys = [
        "MenuBarManager_FloatingBarIconCacheV9",
        "MenuBarManager_FloatingBarIconCacheV7",
    ]
    private let iconDebugKey = "DEBUG_MENU_BAR_ICON_CAPTURE"
    private let iconCacheFileName = "menu_bar_floating_icon_cache_v8.json"
    private let persistedIconCacheMaxAge: TimeInterval = 60 * 60 * 24
    private let userDefaultsHardLimitBytes = 4 * 1024 * 1024
    private let persistedIconCacheMaxPayloadBytes = 3_500_000

    private var rescanTimer: Timer?
    private var currentRescanInterval: TimeInterval = 0
    private var observers = [NSObjectProtocol]()
    private var distributedObservers = [NSObjectProtocol]()
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
    private var panelPressStartedAt: Date?
    private var lastPanelHoverAt = Date.distantPast
    private var lastHiddenSectionVisibleAt = Date.distantPast
    private var menuInteractionItem: MenuBarFloatingItemSnapshot?
    private var menuInteractionLockDepth = 0
    private var wasLockedVisibleBeforeMenuInteraction = false
    private var isLoadingConfiguration = false
    private var stateCancellable: AnyCancellable?
    private var lastKnownHiddenSeparatorOriginX: CGFloat?
    private var lastKnownHiddenSeparatorRightEdgeX: CGFloat?
    private var lastKnownAlwaysHiddenSeparatorOriginX: CGFloat?
    private var lastKnownAlwaysHiddenSeparatorRightEdgeX: CGFloat?
    private var relocationSettleDelayMs: UInt64 = 125
    private let minRelocationSettleDelayMs: UInt64 = 70
    private let maxRelocationSettleDelayMs: UInt64 = 320
    private let panelPressRecoveryTimeout: TimeInterval = 6.0
    private let panelHoverGraceInterval: TimeInterval = 0.14
    private let panelTransitionGraceInterval: TimeInterval = 0.24
    private let panelHoverMonitorMinInterval: TimeInterval = 1.0 / 45.0
    private var lastScannedWindowSignature = [CGWindowID]()
    private var lastSuccessfulScanAt = Date.distantPast
    private var consecutiveEmptyScanCount = 0
    private let requiredConsecutiveEmptyScansToCommit = 3
    private let minRescanIntervalNoChanges: TimeInterval = 0.65
    private let minSettingsRescanIntervalNoChanges: TimeInterval = 4.0
    private let iconCacheSaveDebounceInterval: TimeInterval = 0.5
    private var pendingPersistedIconSaveWorkItem: DispatchWorkItem?
    private var pendingRescanWorkItem: DispatchWorkItem?
    private var pendingRescanForce = false
    private var pendingRescanRefreshIcons = false
    private var pendingPanelPressWatchdogTask: Task<Void, Never>?
    private var lastPlacementRequestAt = Date.distantPast
    private let maxPlacementDragAge: TimeInterval = 12
    private var panelHoverMonitor: Any?
    private var lastPanelHoverMonitorProcessTime: TimeInterval = 0
    private var didLogIconDebugBootstrap = false
    private var hasPerformedSettingsBootstrapRefresh = false
    private var settingsLaneCacheSignature: Int?
    private var settingsLaneCacheVisible = [MenuBarFloatingItemSnapshot]()
    private var settingsLaneCacheHidden = [MenuBarFloatingItemSnapshot]()
    private var settingsLaneCacheAlwaysHidden = [MenuBarFloatingItemSnapshot]()
    private var settingsLaneCacheFloatingBar = [MenuBarFloatingItemSnapshot]()
    private var settingsLaneCacheAllFloating = [MenuBarFloatingItemSnapshot]()
    private lazy var iconCacheFileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let droppyDirectory = appSupport.appendingPathComponent("Droppy", isDirectory: true)
        try? FileManager.default.createDirectory(at: droppyDirectory, withIntermediateDirectories: true)
        return droppyDirectory.appendingPathComponent(iconCacheFileName)
    }()
    // Menu interaction requires temporarily revealing status items. Mask overlays
    // can produce visible artifacts on some menu bar backgrounds, so keep them off.
    private let shouldMaskNonTargetIconsDuringInteraction = false

    private var shouldEnableAlwaysHiddenSection: Bool {
        !alwaysHiddenItemIDs.isEmpty
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
        self.floatingBarItemIDs = []
        isLoadingConfiguration = true
        loadConfiguration()
        loadPersistedIconCache()
        isLoadingConfiguration = false
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        if isIconDebugEnabled, !didLogIconDebugBootstrap {
            didLogIconDebugBootstrap = true
            iconDebugLog("enabled bundle=\(Bundle.main.bundleIdentifier ?? "nil")")
        }
        activeMenuTrackingDepth = 0
        lastMenuTrackingEventTime = 0
        isMenuBarHiddenSectionVisible = isHiddenSectionVisibleNow
        if isMenuBarHiddenSectionVisible {
            lastHiddenSectionVisibleAt = Date()
        }
        installObservers()
        scheduleRescanTimer()
        syncAlwaysHiddenSectionEnabled(forceEnable: false)
        // Keep startup responsive; perform first scan on the next run loop.
        requestRescanOnMainActor(force: true)
    }

    func stop() {
        guard isRunning else { return }
        cancelPendingMenuRestore(using: MenuBarManager.shared)
        resetMenuInteractionLock(using: MenuBarManager.shared)
        pendingRescanWorkItem?.cancel()
        pendingRescanWorkItem = nil
        pendingRescanForce = false
        pendingRescanRefreshIcons = false
        pendingPanelPressWatchdogTask?.cancel()
        pendingPanelPressWatchdogTask = nil
        removePanelHoverMonitor()
        isRunning = false
        activeMenuTrackingDepth = 0
        lastMenuTrackingEventTime = 0
        isMenuBarHiddenSectionVisible = false
        isInSettingsInspectionMode = false
        isManualPreviewRequested = false
        hasPerformedSettingsBootstrapRefresh = false
        isHandlingPanelPress = false
        panelPressStartedAt = nil
        lastPanelHoverAt = Date.distantPast
        lastHiddenSectionVisibleAt = Date.distantPast
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
        lastScannedWindowSignature.removeAll()
        lastSuccessfulScanAt = Date.distantPast
        consecutiveEmptyScanCount = 0
        itemRegistryByID.removeAll()
        lastKnownHiddenSeparatorOriginX = nil
        lastKnownHiddenSeparatorRightEdgeX = nil
        lastKnownAlwaysHiddenSeparatorOriginX = nil
        lastKnownAlwaysHiddenSeparatorRightEdgeX = nil
        pendingPersistedIconSaveWorkItem?.cancel()
        pendingPersistedIconSaveWorkItem = nil
        invalidateSettingsLaneCache()
        panelController.hide()
        clearMenuInteractionMask()
    }

    func rescan(force: Bool = false, refreshIcons: Bool = false) {
        guard isRunning else { return }
        guard !isRelocationInProgress || force else { return }
        if force || refreshIcons {
            MenuBarStatusWindowCache.invalidate()
        }

        guard PermissionManager.shared.isAccessibilityGranted else {
            scannedItems = []
            lastScannedWindowSignature.removeAll()
            lastSuccessfulScanAt = Date.distantPast
            consecutiveEmptyScanCount = 0
            panelController.hide()
            return
        }

        syncAlwaysHiddenSectionEnabled(forceEnable: isInSettingsInspectionMode)

        if !isInSettingsInspectionMode, alwaysHiddenItemIDs.isEmpty, !isManualPreviewRequested {
            if !scannedItems.isEmpty {
                scannedItems = []
            }
            lastScannedWindowSignature.removeAll()
            lastSuccessfulScanAt = Date.distantPast
            consecutiveEmptyScanCount = 0
            panelController.hide()
            return
        }

        let windowSignature = scanner.currentWindowSignature()
        let now = Date()
        if !force, !refreshIcons {
            let unchangedSignature = windowSignature == lastScannedWindowSignature
            let minimumInterval = isInSettingsInspectionMode
                ? minSettingsRescanIntervalNoChanges
                : minRescanIntervalNoChanges
            if unchangedSignature, now.timeIntervalSince(lastSuccessfulScanAt) < minimumInterval {
                applyPanel()
                return
            }
        }

        // Capture real menu bar icon bitmaps only on explicit user refreshes.
        // This avoids recurring screen-recording capture activity during idle scans.
        let includeIcons = PermissionManager.shared.isScreenRecordingGranted && refreshIcons
        let ownerHints = refreshIcons ? nil : preferredOwnerBundleIDsForRescan()
        let rawItems = scanner.scan(includeIcons: includeIcons, preferredOwnerBundleIDs: ownerHints)
        let resolvedItems = rawItems.map { item in
            let resolvedIcon: NSImage?
            let iconSource: String
            if includeIcons, let captured = item.icon {
                resolvedIcon = captured
                cacheIcon(captured, for: iconCacheKeys(for: item), overwrite: refreshIcons)
                iconSource = "captured"
            } else if let cached = cachedIcon(for: item) {
                resolvedIcon = cached
                iconSource = "cached"
            } else {
                resolvedIcon = nil
                iconSource = "none"
            }
            logResolvedIcon(for: item, source: iconSource, icon: resolvedIcon)
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

        let shouldGuardTransientEmptyScan =
            !force
            && !refreshIcons
            && !isInSettingsInspectionMode
            && !alwaysHiddenItemIDs.isEmpty
            && !scannedItems.isEmpty

        if resolvedItems.isEmpty, shouldGuardTransientEmptyScan {
            consecutiveEmptyScanCount += 1
            if consecutiveEmptyScanCount < requiredConsecutiveEmptyScansToCommit {
                applyPanel()
                return
            }
            consecutiveEmptyScanCount = 0
        } else if !resolvedItems.isEmpty {
            consecutiveEmptyScanCount = 0
        }

        reconcileAlwaysHiddenIDs(using: resolvedItems)
        sanitizeAlwaysHiddenIDs(using: resolvedItems)
        sanitizeFloatingBarIDs()

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
            let sanitizedFloatingBar = floatingBarItemIDs.subtracting(nonHideableIDs)
            if sanitizedFloatingBar != floatingBarItemIDs {
                floatingBarItemIDs = sanitizedFloatingBar
            }
        }

        scannedItems = resolvedItems
        lastScannedWindowSignature = windowSignature
        lastSuccessfulScanAt = now
        updateRegistry(with: resolvedItems)
        refreshSeparatorCaches()
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
        if visible {
            lastHiddenSectionVisibleAt = Date()
        }
        scheduleRescanTimer()
        if visible {
            requestRescanOnMainActor(force: true)
        }
        applyPanel()
    }

    func enterSettingsInspectionMode() {
        isInSettingsInspectionMode = true
        isManualPreviewRequested = false
        hasPerformedSettingsBootstrapRefresh = false
        syncAlwaysHiddenSectionEnabled(forceEnable: true)
        scheduleRescanTimer()
        if !hasPerformedSettingsBootstrapRefresh {
            hasPerformedSettingsBootstrapRefresh = true
            // Avoid forcing an immediate heavy scan while the settings sheet is animating in.
            requestRescanOnMainActor(force: false, refreshIcons: false)
        }
        applyPanel()
    }

    func exitSettingsInspectionMode() {
        isInSettingsInspectionMode = false
        isManualPreviewRequested = false
        hasPerformedSettingsBootstrapRefresh = false
        syncAlwaysHiddenSectionEnabled(forceEnable: false)
        scheduleRescanTimer()
        applyPanel()
        // Coalesce close-time scans so sheet dismissal stays responsive.
        requestRescanOnMainActor(force: false)
    }

    func isAlwaysHidden(_ item: MenuBarFloatingItemSnapshot) -> Bool {
        alwaysHiddenItemIDs.contains(item.id)
    }

    func isInFloatingBar(_ item: MenuBarFloatingItemSnapshot) -> Bool {
        isInFloatingBar(item.id)
    }

    func setFloatingBarInclusion(_ included: Bool, for item: MenuBarFloatingItemSnapshot) {
        let id = item.id
        if included {
            if !alwaysHiddenItemIDs.contains(id), placement(for: item) == .floating {
                alwaysHiddenItemIDs.insert(id)
            }
            guard alwaysHiddenItemIDs.contains(id) else { return }
            floatingBarItemIDs.insert(id)
        } else {
            floatingBarItemIDs.remove(id)
        }
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

    private func menuBarControlAnchorX(for frame: CGRect) -> CGFloat {
        let inset = min(6, frame.width / 2)
        switch hiddenSectionSide() {
        case .leftOfHiddenDivider:
            return frame.maxX - inset
        case .rightOfHiddenDivider:
            return frame.minX + inset
        }
    }

    private func hiddenDividerBoundaryX(for hiddenFrame: CGRect) -> CGFloat {
        if hiddenFrame.width > 120 {
            let inset = min(18, hiddenFrame.width * 0.15)
            switch hiddenSectionSide() {
            case .leftOfHiddenDivider:
                return hiddenFrame.minX + inset
            case .rightOfHiddenDivider:
                return hiddenFrame.maxX - inset
            }
        }
        return menuBarControlAnchorX(for: hiddenFrame)
    }

    private func placementForResolvedItem(
        _ item: MenuBarFloatingItemSnapshot,
        hiddenOriginX: CGFloat,
        hiddenRightEdgeX: CGFloat,
        alwaysHiddenOriginX: CGFloat?,
        alwaysHiddenRightEdgeX: CGFloat?
    ) -> MenuBarFloatingPlacement {
        let midpoint = item.quartzFrame.midX
        let hiddenMargin = max(4, item.quartzFrame.width * 0.22)
        let alwaysMargin = max(4, item.quartzFrame.width * 0.22)

        switch hiddenSectionSide() {
        case .leftOfHiddenDivider:
            if let alwaysHiddenOriginX,
               midpoint < (alwaysHiddenOriginX - alwaysMargin) {
                return .floating
            }
            if midpoint > (hiddenRightEdgeX + hiddenMargin) {
                return .visible
            }
            if midpoint < (hiddenOriginX - hiddenMargin) {
                if let alwaysHiddenRightEdgeX,
                   midpoint <= (alwaysHiddenRightEdgeX + alwaysMargin) {
                    return .floating
                }
                return .hidden
            }
            return .hidden
        case .rightOfHiddenDivider:
            if let alwaysHiddenRightEdgeX,
               midpoint > (alwaysHiddenRightEdgeX + alwaysMargin) {
                return .floating
            }
            if midpoint < (hiddenOriginX - hiddenMargin) {
                return .visible
            }
            if midpoint > (hiddenRightEdgeX + hiddenMargin) {
                if let alwaysHiddenOriginX,
                   midpoint >= (alwaysHiddenOriginX - alwaysMargin) {
                    return .floating
                }
                return .hidden
            }
            return .hidden
        }
    }

    func placement(for item: MenuBarFloatingItemSnapshot) -> MenuBarFloatingPlacement {
        if let pendingPlacement = pendingPlacementByID[item.id] {
            return pendingPlacement
        }

        if alwaysHiddenItemIDs.contains(item.id) {
            return .floating
        }

        let resolved = scannedItems.first(where: { $0.id == item.id }) ?? item

        guard let hiddenOriginX = hiddenSeparatorOriginX(),
              let hiddenRightEdgeX = hiddenSeparatorRightEdgeX() else {
            return .visible
        }
        return placementForResolvedItem(
            resolved,
            hiddenOriginX: hiddenOriginX,
            hiddenRightEdgeX: hiddenRightEdgeX,
            alwaysHiddenOriginX: alwaysHiddenSeparatorOriginX(),
            alwaysHiddenRightEdgeX: alwaysHiddenSeparatorRightEdgeX()
        )
    }

    struct SettingsLaneItems {
        let visible: [MenuBarFloatingItemSnapshot]
        let hidden: [MenuBarFloatingItemSnapshot]
        let alwaysHidden: [MenuBarFloatingItemSnapshot]
        let floatingBar: [MenuBarFloatingItemSnapshot]
        let allFloating: [MenuBarFloatingItemSnapshot]
    }

    private func invalidateSettingsLaneCache() {
        settingsLaneCacheSignature = nil
        settingsLaneCacheVisible.removeAll(keepingCapacity: false)
        settingsLaneCacheHidden.removeAll(keepingCapacity: false)
        settingsLaneCacheAlwaysHidden.removeAll(keepingCapacity: false)
        settingsLaneCacheFloatingBar.removeAll(keepingCapacity: false)
        settingsLaneCacheAllFloating.removeAll(keepingCapacity: false)
    }

    func settingsLaneItems() -> SettingsLaneItems {
        let items = settingsItems
        let signature = settingsLaneSignature(for: items)
        if settingsLaneCacheSignature == signature {
            return SettingsLaneItems(
                visible: settingsLaneCacheVisible,
                hidden: settingsLaneCacheHidden,
                alwaysHidden: settingsLaneCacheAlwaysHidden,
                floatingBar: settingsLaneCacheFloatingBar,
                allFloating: settingsLaneCacheAllFloating
            )
        }
        let liveByID = Dictionary(uniqueKeysWithValues: scannedItems.map { ($0.id, $0) })
        let hiddenOriginX = hiddenSeparatorOriginX()
        let hiddenRightEdgeX = hiddenSeparatorRightEdgeX()
        let alwaysHiddenOriginX = alwaysHiddenSeparatorOriginX()
        let alwaysHiddenRightEdgeX = alwaysHiddenSeparatorRightEdgeX()
        var visible = [MenuBarFloatingItemSnapshot]()
        var hidden = [MenuBarFloatingItemSnapshot]()
        var floating = [MenuBarFloatingItemSnapshot]()
        visible.reserveCapacity(items.count)
        hidden.reserveCapacity(items.count)
        floating.reserveCapacity(items.count)

        for item in items {
            let effectivePlacement: MenuBarFloatingPlacement = {
                if let pendingPlacement = pendingPlacementByID[item.id] {
                    return pendingPlacement
                }
                if alwaysHiddenItemIDs.contains(item.id) {
                    return .floating
                }
                guard let hiddenOriginX, let hiddenRightEdgeX else {
                    return .visible
                }
                let resolved = liveByID[item.id] ?? item
                return placementForResolvedItem(
                    resolved,
                    hiddenOriginX: hiddenOriginX,
                    hiddenRightEdgeX: hiddenRightEdgeX,
                    alwaysHiddenOriginX: alwaysHiddenOriginX,
                    alwaysHiddenRightEdgeX: alwaysHiddenRightEdgeX
                )
            }()

            switch effectivePlacement {
            case .visible:
                visible.append(item)
            case .hidden:
                hidden.append(item)
            case .floating:
                floating.append(item)
            }
        }

        let floatingIDs = floatingBarItemIDs
        let alwaysHidden = floating.filter { !floatingIDs.contains($0.id) }
        let floatingBar = floating.filter { floatingIDs.contains($0.id) }

        settingsLaneCacheSignature = signature
        settingsLaneCacheVisible = visible
        settingsLaneCacheHidden = hidden
        settingsLaneCacheAlwaysHidden = alwaysHidden
        settingsLaneCacheFloatingBar = floatingBar
        settingsLaneCacheAllFloating = floating

        return SettingsLaneItems(
            visible: visible,
            hidden: hidden,
            alwaysHidden: alwaysHidden,
            floatingBar: floatingBar,
            allFloating: floating
        )
    }

    private func settingsLaneSignature(for items: [MenuBarFloatingItemSnapshot]) -> Int {
        var hasher = Hasher()
        hasher.combine(items.count)
        for item in items {
            hasher.combine(item.id)
            hasher.combine(Int(item.quartzFrame.minX.rounded()))
            hasher.combine(Int(item.quartzFrame.width.rounded()))
        }

        hasher.combine(alwaysHiddenItemIDs.count)
        for id in alwaysHiddenItemIDs.sorted() {
            hasher.combine(id)
        }

        hasher.combine(floatingBarItemIDs.count)
        for id in floatingBarItemIDs.sorted() {
            hasher.combine(id)
        }

        hasher.combine(pendingPlacementByID.count)
        for (id, placement) in pendingPlacementByID.sorted(by: { $0.key < $1.key }) {
            hasher.combine(id)
            hasher.combine(placement.rawValue)
        }

        if let hiddenOriginX = lastKnownHiddenSeparatorOriginX {
            hasher.combine(Int(hiddenOriginX.rounded()))
        }
        if let hiddenRightEdgeX = lastKnownHiddenSeparatorRightEdgeX {
            hasher.combine(Int(hiddenRightEdgeX.rounded()))
        }
        if let alwaysHiddenOriginX = lastKnownAlwaysHiddenSeparatorOriginX {
            hasher.combine(Int(alwaysHiddenOriginX.rounded()))
        }
        if let alwaysHiddenRightEdgeX = lastKnownAlwaysHiddenSeparatorRightEdgeX {
            hasher.combine(Int(alwaysHiddenRightEdgeX.rounded()))
        }

        return hasher.finalize()
    }

    func settingsItems(for placement: MenuBarFloatingPlacement) -> [MenuBarFloatingItemSnapshot] {
        let lanes = settingsLaneItems()
        switch placement {
        case .visible:
            return lanes.visible
        case .hidden:
            return lanes.hidden
        case .floating:
            return lanes.allFloating
        }
    }

    func settingsAlwaysHiddenItems() -> [MenuBarFloatingItemSnapshot] {
        settingsLaneItems().alwaysHidden
    }

    func settingsFloatingBarItems() -> [MenuBarFloatingItemSnapshot] {
        settingsLaneItems().floatingBar
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
            guard shouldUseRegistryFallback(for: cached, itemID: id) else { continue }
            merged.append(withCachedIconIfNeeded(cached))
        }

        return merged
            .filter { !isMandatoryMenuBarManagerControlItem($0) }
            .sorted { lhs, rhs in
            lhs.quartzFrame.minX < rhs.quartzFrame.minX
        }
    }

    private func isInFloatingBar(_ itemID: String) -> Bool {
        floatingBarItemIDs.contains(itemID) && alwaysHiddenItemIDs.contains(itemID)
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
        lastPlacementRequestAt = Date()
        if targetPlacement != .visible, isMandatoryMenuBarManagerControlItem(item) {
            return
        }
        if targetPlacement != .visible, nonHideableReason(for: item) != nil {
            return
        }
        let currentPlacement = placement(for: item)
        if targetPlacement == currentPlacement {
            if targetPlacement == .floating {
                alwaysHiddenItemIDs.insert(item.id)
                floatingBarItemIDs.insert(item.id)
            }
            return
        }
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
        let previousFloatingBar = floatingBarItemIDs

        // Optimistically reflect toggle state in UI, then revert on failure.
        if targetPlacement == .floating {
            alwaysHiddenItemIDs.insert(item.id)
            // Default behavior: newly always-hidden items are included in Floating Bar.
            // Settings drag/drop can immediately opt out via setFloatingBarInclusion(false,...).
            floatingBarItemIDs.insert(item.id)
        } else {
            alwaysHiddenItemIDs.remove(item.id)
            floatingBarItemIDs.remove(item.id)
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
                strongSelf.floatingBarItemIDs = previousFloatingBar
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
        var hiddenByID = [String: MenuBarFloatingItemSnapshot]()
        let effectiveFloatingIDs = floatingBarItemIDs.intersection(alwaysHiddenItemIDs)
        hiddenByID.reserveCapacity(max(effectiveFloatingIDs.count, scannedItems.count))

        for id in effectiveFloatingIDs {
            if let scanned = scannedByID[id] {
                hiddenByID[id] = scanned
            } else if let cached = itemRegistryByID[id], shouldUseRegistryFallback(for: cached, itemID: id) {
                let resolved = withCachedIconIfNeeded(cached)
                hiddenByID[id] = resolved
            }
        }

        // Geometry fallback: keep panel content consistent with placement rules
        // when item IDs remap during menu bar reordering.
        for item in scannedItems {
            guard !isMandatoryMenuBarManagerControlItem(item) else { continue }
            if placement(for: item) == .floating, isInFloatingBar(item.id) {
                hiddenByID[item.id] = item
            }
        }

        return Array(hiddenByID.values)
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

        if isHandlingPanelPress {
            if shouldForceRecoverFromPanelPressStall() {
                cancelPendingMenuRestore(using: MenuBarManager.shared)
            }
        }

        if isHandlingPanelPress {
            panelController.hide()
            return
        }

        let hiddenItems = currentlyHiddenItems()
        let isPanelHoveredNow = panelController.containsMouseLocation()
        if isPanelHoveredNow {
            lastPanelHoverAt = Date()
        }
        let isWithinPanelHoverGrace = panelController.isVisible
            && Date().timeIntervalSince(lastPanelHoverAt) <= panelHoverGraceInterval
        let isWithinPanelTransitionGrace = panelController.isVisible
            && !isHiddenSectionVisibleNow
            && Date().timeIntervalSince(lastHiddenSectionVisibleAt) <= panelTransitionGraceInterval
        let shouldStayVisibleBecausePanelHover =
            isPanelHoveredNow || isWithinPanelHoverGrace || isWithinPanelTransitionGrace
        let shouldShowBecauseHover = isHiddenSectionVisibleNow || shouldStayVisibleBecausePanelHover
        let shouldShowBecauseManualPreview = isManualPreviewRequested
        let itemsToShow = shouldShowBecauseManualPreview && hiddenItems.isEmpty
            ? scannedItems.filter { !isMandatoryMenuBarManagerControlItem($0) }
            : hiddenItems
        if isIconDebugEnabled {
            let reason = "showHover=\(shouldShowBecauseHover) showManual=\(shouldShowBecauseManualPreview) hiddenVisible=\(isHiddenSectionVisibleNow)"
            if itemsToShow.isEmpty {
                iconDebugLog("panel skipped reason=\(reason) emptyItems=true")
            } else {
                logPanelIcons(itemsToShow, reason: reason)
            }
        }
        guard (shouldShowBecauseHover || shouldShowBecauseManualPreview), !itemsToShow.isEmpty else {
            panelController.hide()
            return
        }

        let shouldFreezePanelPosition =
            panelController.isVisible
            && (shouldStayVisibleBecausePanelHover || isHiddenSectionVisibleNow)
        panelController.show(items: itemsToShow, allowReposition: !shouldFreezePanelPosition) { [weak self] item in
            self?.performAction(for: item)
        }
    }

    private func performAction(for item: MenuBarFloatingItemSnapshot) {
        let manager = MenuBarManager.shared
        cancelPendingMenuRestore(using: manager)
        clearMenuInteractionMask()
        menuInteractionItem = nil
        isManualPreviewRequested = false
        panelPressStartedAt = Date()
        isHandlingPanelPress = true
        panelController.hide()
        schedulePanelPressWatchdog()

        Task { @MainActor [weak self] in
            guard let self else { return }
            let opened = await self.openMenuForFloatingItem(item)
            if !opened {
                try? await Task.sleep(for: .milliseconds(180))
                self.pendingPanelPressWatchdogTask?.cancel()
                self.pendingPanelPressWatchdogTask = nil
                self.panelPressStartedAt = nil
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

        // Temporarily reveal for interaction. Non-target masking is disabled
        // because it can render as visible blocks on real menu bar backgrounds.
        applyMenuInteractionMask(except: requested, captureBackground: false)
        await applyShowAllShield(using: manager)
        rescan(force: true)
        var liveItem = resolveLiveItem(for: requested)
        itemRegistryByID[liveItem.id] = liveItem

        var didOpenMenu = false

        for attempt in 0 ..< 4 {
            rescan(force: true)
            liveItem = resolveLiveItem(for: liveItem)
            itemRegistryByID[liveItem.id] = liveItem
            applyMenuInteractionMask(except: liveItem, captureBackground: false)

            if case .success = triggerMenuAction(for: liveItem, allowHardwareFallback: true) {
                if await waitForMenuPresentation(for: liveItem) {
                    didOpenMenu = true
                    break
                }
            }

            if attempt < 3 {
                try? await Task.sleep(for: .milliseconds(95))
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
                        self.pendingPanelPressWatchdogTask?.cancel()
                        self.pendingPanelPressWatchdogTask = nil
                        self.pendingMenuRestoreTask = nil
                        self.pendingMenuRestoreToken = nil
                        self.clearMenuInteractionMask()
                        self.menuInteractionItem = nil
                        self.endMenuInteractionLock(using: manager)
                        self.panelPressStartedAt = nil
                        self.isHandlingPanelPress = false
                        self.applyPanel()
                    }
                }
                try? await Task.sleep(for: .milliseconds(120))
                await self.waitForMenuDismissal(maxWaitSeconds: self.panelPressRecoveryTimeout)
                guard !Task.isCancelled else { return }
                guard !self.isInSettingsInspectionMode else { return }
                await self.restoreMoveSession(using: manager, state: sessionState)
                self.rescan(force: true)
            }
        } else {
            pendingPanelPressWatchdogTask?.cancel()
            pendingPanelPressWatchdogTask = nil
            clearMenuInteractionMask()
            menuInteractionItem = nil
            await restoreMoveSession(using: manager, state: sessionState)
            endMenuInteractionLock(using: manager)
            panelPressStartedAt = nil
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

        return hasOnScreenPopupMenuWindow(ownerPIDs: ownerPIDs, requireMouseContainment: false)
    }

    private func hasAnyOnScreenPopupMenuWindowContainingMouse() -> Bool {
        hasOnScreenPopupMenuWindow(ownerPIDs: nil, requireMouseContainment: true)
    }

    private func hasOnScreenPopupMenuWindow(
        ownerPIDs: Set<pid_t>?,
        requireMouseContainment: Bool
    ) -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let currentPID = getpid()

        let popUpLayer = Int(CGWindowLevelForKey(.popUpMenuWindow))
        let acceptedLayers: Set<Int>
        if requireMouseContainment {
            let statusLayer = Int(CGWindowLevelForKey(.statusWindow))
            let mainMenuLayer = Int(CGWindowLevelForKey(.mainMenuWindow))
            acceptedLayers = Set([
                popUpLayer - 1,
                popUpLayer,
                popUpLayer + 1,
                statusLayer,
                mainMenuLayer,
            ])
        } else {
            acceptedLayers = Set([popUpLayer - 1, popUpLayer, popUpLayer + 1])
        }
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

            guard let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  bounds.width > 2,
                  bounds.height > 2 else {
                continue
            }

            if requireMouseContainment {
                if !bounds.contains(mouseQuartzPoint) {
                    continue
                }
            } else {
                // Ignore tiny status-item-sized windows when scanning owner windows globally.
                if bounds.width < 26 || bounds.height < 14 {
                    continue
                }
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
                await dismissActiveMenuIfNeeded()
                return
            }

            try? await Task.sleep(for: .milliseconds(130))
        }

        await dismissActiveMenuIfNeeded()
    }

    private func dismissActiveMenuIfNeeded() async {
        guard hasActiveMenuWindow() else { return }
        guard postEscapeKey() else { return }

        let deadline = Date().addingTimeInterval(0.45)
        while Date() < deadline {
            if !hasActiveMenuWindow() {
                return
            }
            try? await Task.sleep(for: .milliseconds(60))
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
        return isHoveringRevealEligibleMenuBarIcon(
            mouseLocation: mouseLocation,
            screen: screen,
            menuBarHeight: menuBarHeight
        )
    }

    private func interactionScreen(for mouseLocation: CGPoint) -> NSScreen? {
        if let hiddenFrame = MenuBarManager.shared.controlItemFrame(for: .hidden),
           let hiddenScreen = screenContainingMenuBarControlFrame(hiddenFrame) {
            return hiddenScreen
        }
        if let alwaysHiddenFrame = MenuBarManager.shared.controlItemFrame(for: .alwaysHidden),
           let alwaysHiddenScreen = screenContainingMenuBarControlFrame(alwaysHiddenFrame) {
            return alwaysHiddenScreen
        }
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
    }

    private func screenContainingMenuBarControlFrame(_ frame: CGRect) -> NSScreen? {
        let anchorX = menuBarControlAnchorX(for: frame)
        let anchorPoint = CGPoint(x: anchorX, y: frame.midY)
        if let containing = NSScreen.screens.first(where: { $0.frame.contains(anchorPoint) }) {
            return containing
        }
        return NSScreen.screens.first(where: { $0.frame.intersects(frame) })
    }

    private func effectiveMenuBarHeight(for screen: NSScreen) -> CGFloat {
        let inferredHeight = screen.frame.maxY - screen.visibleFrame.maxY
        if inferredHeight > 0 {
            return inferredHeight
        }
        return max(24, NSStatusBar.system.thickness)
    }

    private func isHoveringRevealEligibleMenuBarIcon(
        mouseLocation: CGPoint,
        screen: NSScreen,
        menuBarHeight: CGFloat
    ) -> Bool {
        let isAtTop = mouseLocation.y >= screen.frame.maxY - menuBarHeight
        guard isAtTop else { return false }

        if let hiddenFrame = MenuBarManager.shared.controlItemFrame(for: .hidden),
           screen.frame.intersects(hiddenFrame) {
            let dividerBoundaryX = hiddenDividerBoundaryX(for: hiddenFrame)
            switch hiddenSectionSide() {
            case .leftOfHiddenDivider:
                if mouseLocation.x < dividerBoundaryX - 1 {
                    return false
                }
            case .rightOfHiddenDivider:
                if mouseLocation.x > dividerBoundaryX + 1 {
                    return false
                }
            }
        }

        let mouseQuartzRect = MenuBarFloatingCoordinateConverter.appKitToQuartz(
            CGRect(x: mouseLocation.x, y: mouseLocation.y, width: 1, height: 1)
        )
        let mouseQuartzPoint = CGPoint(x: mouseQuartzRect.midX, y: mouseQuartzRect.midY)
        if MenuBarStatusWindowCache.containsStatusItem(at: mouseQuartzPoint, maxAge: 0.1) {
            return true
        }
        // Fallback for systems where status-item windows report non-standard geometry.
        return MenuBarStatusWindowCache.containsAnyStatusWindow(at: mouseQuartzPoint, maxAge: 0.1)
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
        let shouldDismissMenu =
            pendingMenuRestoreTask != nil
            || pendingMenuRestoreToken != nil
            || menuInteractionItem != nil
            || isHandlingPanelPress
        pendingPanelPressWatchdogTask?.cancel()
        pendingPanelPressWatchdogTask = nil
        pendingMenuRestoreTask?.cancel()
        pendingMenuRestoreTask = nil
        pendingMenuRestoreToken = nil
        if shouldDismissMenu {
            _ = postEscapeKey()
        }
        clearMenuInteractionMask()
        menuInteractionItem = nil
        panelPressStartedAt = nil
        isHandlingPanelPress = false
        resetMenuInteractionLock(using: manager)
    }

    private func shouldForceRecoverFromPanelPressStall() -> Bool {
        guard let startedAt = panelPressStartedAt else { return false }
        guard Date().timeIntervalSince(startedAt) >= panelPressRecoveryTimeout else { return false }
        if hasActiveMenuWindow() {
            return false
        }
        if hasRecentMenuInteraction(threshold: 0.9) {
            return false
        }
        return true
    }

    private func schedulePanelPressWatchdog() {
        pendingPanelPressWatchdogTask?.cancel()
        pendingPanelPressWatchdogTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let waitMs = UInt64((self.panelPressRecoveryTimeout + 1.0) * 1000)
            try? await Task.sleep(for: .milliseconds(Int(waitMs)))
            guard !Task.isCancelled else { return }
            guard self.isHandlingPanelPress else { return }
            guard !self.hasActiveMenuWindow() else { return }
            self.cancelPendingMenuRestore(using: MenuBarManager.shared)
            self.applyPanel()
        }
    }

    private func applyMenuInteractionMask(
        except activeItem: MenuBarFloatingItemSnapshot,
        captureBackground: Bool = false
    ) {
        guard shouldMaskNonTargetIconsDuringInteraction else {
            maskController.hideAll()
            return
        }
        // Mask all other right-side extras while interacting so only the
        // clicked item appears to re-enter temporarily.
        let candidates = scannedItems
            .filter { !isMandatoryMenuBarManagerControlItem($0) }
            .sorted { $0.quartzFrame.minX < $1.quartzFrame.minX }
        var masks = candidates.filter { !isMaskEquivalent($0, activeItem) }
        if masks.count == candidates.count,
           let fallbackExclude = bestMaskExclusionCandidate(for: activeItem, in: candidates) {
            masks = candidates.filter { $0.id != fallbackExclude.id }
        }
        if masks.isEmpty {
            maskController.hideAll()
            return
        }
        if captureBackground {
            // Snapshot capture is intentionally disabled for menu interaction
            // masking because it can produce clipped stale backgrounds.
            maskController.clearPreparedSnapshots()
        }
        maskController.update(hiddenItems: masks, usePreparedSnapshots: false)
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
        func itemClosestToVisibleSide(_ items: [MenuBarFloatingItemSnapshot]) -> MenuBarFloatingItemSnapshot? {
            switch hiddenSectionSide() {
            case .leftOfHiddenDivider:
                return items.max { lhs, rhs in
                    lhs.quartzFrame.midX < rhs.quartzFrame.midX
                }
            case .rightOfHiddenDivider:
                return items.min { lhs, rhs in
                    lhs.quartzFrame.midX < rhs.quartzFrame.midX
                }
            }
        }

        if let axIdentifier = requested.axIdentifier,
           let byIdentifier = itemClosestToVisibleSide(scannedItems.filter {
               $0.ownerBundleID == requested.ownerBundleID && $0.axIdentifier == axIdentifier
           }) {
            return byIdentifier
        }

        if let statusItemIndex = requested.statusItemIndex,
           let byIndex = itemClosestToVisibleSide(scannedItems.filter {
               $0.ownerBundleID == requested.ownerBundleID && $0.statusItemIndex == statusItemIndex
           }) {
            return byIndex
        }

        if let scanned = itemClosestToVisibleSide(scannedItems.filter({ $0.id == requested.id })) {
            return scanned
        }

        if let registry = itemRegistryByID[requested.id] {
            return registry
        }

        if let candidate = relocationCandidate(itemID: requested.id, fallback: requested) {
            return candidate
        }

        if let title = requested.title, !title.isEmpty,
           let bestByTitle = itemClosestToVisibleSide(scannedItems.filter {
               $0.ownerBundleID == requested.ownerBundleID && $0.title == title
           }) {
            return bestByTitle
        }

        return requested
    }

    private func triggerMenuAction(
        for item: MenuBarFloatingItemSnapshot,
        allowHardwareFallback: Bool
    ) -> PressResolution {
        // Prefer accessibility actions first. These open menus without triggering
        // status-item primary click side effects (for example screen capture modes).
        if performBestAXPress(on: item.axElement) {
            return .success
        }

        for child in MenuBarAXTools.copyChildren(item.axElement) {
            if performBestAXPress(on: child) {
                return .success
            }
        }

        // Last-resort hardware fallback uses right click to avoid activating
        // status-item primary actions.
        if allowHardwareFallback,
           let clickPoint = clickPointForItemIfVisible(item),
           postRightClick(at: clickPoint) {
            return .success
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

    private func postRightClick(at point: CGPoint) -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            return false
        }
        guard let down = CGEvent(
            mouseEventSource: source,
            mouseType: .rightMouseDown,
            mouseCursorPosition: point,
            mouseButton: .right
        ),
        let up = CGEvent(
            mouseEventSource: source,
            mouseType: .rightMouseUp,
            mouseCursorPosition: point,
            mouseButton: .right
        ) else {
            return false
        }

        down.post(tap: .cghidEventTap)
        usleep(12_000)
        up.post(tap: .cghidEventTap)
        return true
    }

    private func waitForMenuPresentation(
        for item: MenuBarFloatingItemSnapshot,
        timeout: TimeInterval = 0.34
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            rescan(force: true)
            let liveItem = resolveLiveItem(for: item)

            if isMenuCurrentlyOpen(for: liveItem)
                || hasGlobalMenuWindow(for: liveItem)
                || hasAnyOnScreenPopupMenuWindowContainingMouse()
                || RunLoop.main.currentMode == .eventTracking
                || hasActiveMenuWindow() {
                return true
            }

            try? await Task.sleep(for: .milliseconds(45))
        }

        return false
    }

    private func postEscapeKey() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: false) else {
            return false
        }

        keyDown.post(tap: .cghidEventTap)
        usleep(9_000)
        keyUp.post(tap: .cghidEventTap)
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
            switch hiddenSectionSide() {
            case .leftOfHiddenDivider:
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

            case .rightOfHiddenDivider:
                guard let alwaysHiddenRightEdgeX = alwaysHiddenSeparatorRightEdgeX() else {
                    return nil
                }

                let fallbackBounds = MenuBarFloatingCoordinateConverter
                    .screenContaining(quartzPoint: CGPoint(x: source.quartzFrame.midX, y: source.quartzFrame.midY))
                    .flatMap { MenuBarFloatingCoordinateConverter.displayBounds(of: $0) }
                let hardRight = (fallbackBounds?.maxX ?? alwaysHiddenRightEdgeX + 420) - 8
                let moveOffset = max(80, sourceWidth + 56)
                let targetX = min(hardRight, alwaysHiddenRightEdgeX + moveOffset + (attemptOffset * 42))
                return CGPoint(x: targetX, y: source.quartzFrame.midY)
            }

        case .hidden:
            guard let hiddenOriginX = hiddenSeparatorOriginX(),
                  let hiddenRightEdgeX = hiddenSeparatorRightEdgeX() else {
                return nil
            }

            let edgePadding = max(16, sourceWidth * 0.42)
            let hiddenEdgeInset = max(14, sourceWidth * 0.28)

            switch hiddenSectionSide() {
            case .leftOfHiddenDivider:
                let corridorRight = hiddenOriginX - edgePadding
                if let alwaysHiddenRightEdgeX = alwaysHiddenSeparatorRightEdgeX() {
                    let corridorLeft = alwaysHiddenRightEdgeX + edgePadding
                    if corridorRight > corridorLeft {
                        let midpoint = (corridorLeft + corridorRight) / 2
                        let stride = max(14, sourceWidth * 0.36)
                        let direction: CGFloat = attempt.isMultiple(of: 2) ? 1 : -1
                        let wave = CGFloat((attempt + 1) / 2)
                        let targetX = min(corridorRight, max(corridorLeft, midpoint + (direction * wave * stride)))
                        return CGPoint(x: targetX, y: source.quartzFrame.midY)
                    }

                    // Keep hidden moves between separators even when corridor data is tight.
                    let fallbackNearHidden = hiddenOriginX - hiddenEdgeInset - (attemptOffset * 10)
                    let clampedTargetX = max(corridorLeft, min(corridorRight, fallbackNearHidden))
                    return CGPoint(x: clampedTargetX, y: source.quartzFrame.midY)
                }

                // Fallback when hidden corridor is too narrow or always-hidden separator is unavailable:
                // place immediately left of the hidden divider.
                let fallbackOffset = max(40, sourceWidth + 18) + (attemptOffset * 12)
                let targetX = hiddenOriginX - fallbackOffset
                return CGPoint(x: targetX, y: source.quartzFrame.midY)

            case .rightOfHiddenDivider:
                let corridorLeft = hiddenRightEdgeX + edgePadding
                if let alwaysHiddenOriginX = alwaysHiddenSeparatorOriginX() {
                    let corridorRight = alwaysHiddenOriginX - edgePadding
                    if corridorRight > corridorLeft {
                        let midpoint = (corridorLeft + corridorRight) / 2
                        let stride = max(14, sourceWidth * 0.36)
                        let direction: CGFloat = attempt.isMultiple(of: 2) ? 1 : -1
                        let wave = CGFloat((attempt + 1) / 2)
                        let targetX = min(corridorRight, max(corridorLeft, midpoint + (direction * wave * stride)))
                        return CGPoint(x: targetX, y: source.quartzFrame.midY)
                    }

                    // Keep hidden moves between separators even when corridor data is tight.
                    let fallbackNearHidden = hiddenRightEdgeX + hiddenEdgeInset + (attemptOffset * 10)
                    let clampedTargetX = min(corridorRight, max(corridorLeft, fallbackNearHidden))
                    return CGPoint(x: clampedTargetX, y: source.quartzFrame.midY)
                }

                // Fallback when hidden corridor is too narrow or always-hidden separator is unavailable:
                // place immediately right of the hidden divider.
                let fallbackOffset = max(40, sourceWidth + 18) + (attemptOffset * 12)
                let targetX = hiddenRightEdgeX + fallbackOffset
                return CGPoint(x: targetX, y: source.quartzFrame.midY)
            }

        case .visible:
            let fallbackBounds = MenuBarFloatingCoordinateConverter
                .screenContaining(quartzPoint: CGPoint(x: source.quartzFrame.midX, y: source.quartzFrame.midY))
                .flatMap { MenuBarFloatingCoordinateConverter.displayBounds(of: $0) }
            let moveOffset = max(70, sourceWidth + 40)

            switch hiddenSectionSide() {
            case .leftOfHiddenDivider:
                guard let hiddenRightEdgeX = hiddenSeparatorRightEdgeX() else {
                    return nil
                }
                let hardRight = (fallbackBounds?.maxX ?? hiddenRightEdgeX + 420) - 8
                let targetX = min(hardRight, hiddenRightEdgeX + moveOffset + (attemptOffset * 38))
                return CGPoint(x: targetX, y: source.quartzFrame.midY)
            case .rightOfHiddenDivider:
                guard let hiddenOriginX = hiddenSeparatorOriginX() else {
                    return nil
                }
                let hardLeft = (fallbackBounds?.minX ?? hiddenOriginX - 420) + 8
                let targetX = max(hardLeft, hiddenOriginX - moveOffset - (attemptOffset * 38))
                return CGPoint(x: targetX, y: source.quartzFrame.midY)
            }
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
            let margin = max(4, item.quartzFrame.width * 0.3)
            switch hiddenSectionSide() {
            case .leftOfHiddenDivider:
                guard let alwaysHiddenOriginX = alwaysHiddenSeparatorOriginX() else {
                    return nil
                }
                return item.quartzFrame.midX < (alwaysHiddenOriginX - margin) ? item : nil
            case .rightOfHiddenDivider:
                guard let alwaysHiddenRightEdgeX = alwaysHiddenSeparatorRightEdgeX() else {
                    return nil
                }
                return item.quartzFrame.midX > (alwaysHiddenRightEdgeX + margin) ? item : nil
            }

        case .hidden:
            guard let hiddenOriginX = hiddenSeparatorOriginX(),
                  let hiddenRightEdgeX = hiddenSeparatorRightEdgeX() else {
                return nil
            }
            let midpoint = item.quartzFrame.midX
            switch hiddenSectionSide() {
            case .leftOfHiddenDivider:
                let rightMargin = max(4, item.quartzFrame.width * 0.28)
                guard midpoint < (hiddenOriginX - rightMargin) else {
                    return nil
                }
                if let alwaysHiddenRightEdgeX = alwaysHiddenSeparatorRightEdgeX() {
                    let leftMargin = max(4, item.quartzFrame.width * 0.22)
                    guard midpoint > (alwaysHiddenRightEdgeX + leftMargin) else {
                        return nil
                    }
                }
                return item
            case .rightOfHiddenDivider:
                let leftMargin = max(4, item.quartzFrame.width * 0.28)
                guard midpoint > (hiddenRightEdgeX + leftMargin) else {
                    return nil
                }
                if let alwaysHiddenOriginX = alwaysHiddenSeparatorOriginX() {
                    let rightMargin = max(4, item.quartzFrame.width * 0.22)
                    guard midpoint < (alwaysHiddenOriginX - rightMargin) else {
                        return nil
                    }
                }
                return item
            }

        case .visible:
            let margin = max(4, item.quartzFrame.width * 0.3)
            switch hiddenSectionSide() {
            case .leftOfHiddenDivider:
                guard let hiddenRightEdgeX = hiddenSeparatorRightEdgeX() else {
                    return nil
                }
                return item.quartzFrame.midX > (hiddenRightEdgeX + margin) ? item : nil
            case .rightOfHiddenDivider:
                guard let hiddenOriginX = hiddenSeparatorOriginX() else {
                    return nil
                }
                return item.quartzFrame.midX < (hiddenOriginX - margin) ? item : nil
            }
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
            let wasInFloatingBar = floatingBarItemIDs.contains(oldID)
            alwaysHiddenItemIDs.remove(oldID)
            alwaysHiddenItemIDs.insert(newID)
            floatingBarItemIDs.remove(oldID)
            if wasInFloatingBar {
                floatingBarItemIDs.insert(newID)
            } else {
                floatingBarItemIDs.remove(newID)
            }
        } else {
            floatingBarItemIDs.remove(oldID)
            alwaysHiddenItemIDs.remove(oldID)
            alwaysHiddenItemIDs.remove(newID)
            floatingBarItemIDs.remove(newID)
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
        if alwaysOriginX > hiddenOriginX {
            return .alwaysHiddenRightOfHidden
        }
        return .unknown
    }

    private func ensureControlItemOrder() async -> Bool {
        switch detectControlItemOrder() {
        case .alwaysHiddenLeftOfHidden, .alwaysHiddenRightOfHidden:
            return true
        case .unknown:
            break
        }

        guard await waitForControlItemFrames() else {
            return false
        }
        return detectControlItemOrder() != .unknown
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
        guard Date().timeIntervalSince(lastPlacementRequestAt) <= maxPlacementDragAge else {
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
        itemRegistryByID = itemRegistryByID.filter { key, value in
            if scannedIDs.contains(key) {
                return true
            }
            if keep.contains(key) {
                return shouldUseRegistryFallback(for: value, itemID: key)
            }
            return false
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
                guard shouldUseRegistryFallback(for: cached, itemID: id) else { return false }
                return !isMandatoryMenuBarManagerControlItem(cached)
            }
            if let ownerBundleID = ownerBundleIDFromItemID(id) {
                return isOwnerBundleRunning(ownerBundleID)
            }
            return true
        }

        let sanitizedSet = Set(sanitized)
        if sanitizedSet != alwaysHiddenItemIDs {
            alwaysHiddenItemIDs = sanitizedSet
        }
    }

    private func sanitizeFloatingBarIDs() {
        guard !floatingBarItemIDs.isEmpty else { return }
        let sanitized = floatingBarItemIDs
            .intersection(alwaysHiddenItemIDs)
            .filter { !isMandatoryMenuBarManagerControlID($0) }
        let sanitizedSet = Set(sanitized)
        if sanitizedSet != floatingBarItemIDs {
            floatingBarItemIDs = sanitizedSet
        }
    }

    private func isOwnerBundleRunning(_ ownerBundleID: String) -> Bool {
        guard !ownerBundleID.isEmpty else { return true }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: ownerBundleID).isEmpty
    }

    private func ownerBundleIDFromItemID(_ itemID: String) -> String? {
        guard let separatorRange = itemID.range(of: "::") else { return nil }
        let owner = String(itemID[..<separatorRange.lowerBound])
        guard owner.contains(".") else { return nil }
        return owner
    }

    private func shouldUseRegistryFallback(for item: MenuBarFloatingItemSnapshot, itemID: String) -> Bool {
        if isOwnerBundleRunning(item.ownerBundleID) {
            return true
        }
        if let fallbackOwner = ownerBundleIDFromItemID(itemID) {
            return isOwnerBundleRunning(fallbackOwner)
        }
        return false
    }

    private func pruneTerminatedItems(for bundleID: String) {
        guard !bundleID.isEmpty else { return }
        let normalizedBundleID = bundleID.lowercased()
        var idsToRemove = Set<String>()

        for item in scannedItems where item.ownerBundleID.lowercased() == normalizedBundleID {
            idsToRemove.insert(item.id)
        }

        for (itemID, item) in itemRegistryByID where item.ownerBundleID.lowercased() == normalizedBundleID {
            idsToRemove.insert(itemID)
        }

        for itemID in alwaysHiddenItemIDs.union(floatingBarItemIDs) {
            guard let ownerBundleID = ownerBundleIDFromItemID(itemID),
                  ownerBundleID.lowercased() == normalizedBundleID else {
                continue
            }
            idsToRemove.insert(itemID)
        }

        guard !idsToRemove.isEmpty else { return }

        scannedItems.removeAll { idsToRemove.contains($0.id) }
        itemRegistryByID = itemRegistryByID.filter { key, _ in
            !idsToRemove.contains(key)
        }

        let sanitizedAlwaysHidden = alwaysHiddenItemIDs.subtracting(idsToRemove)
        if sanitizedAlwaysHidden != alwaysHiddenItemIDs {
            alwaysHiddenItemIDs = sanitizedAlwaysHidden
        }

        let sanitizedFloating = floatingBarItemIDs.subtracting(idsToRemove)
        if sanitizedFloating != floatingBarItemIDs {
            floatingBarItemIDs = sanitizedFloating
        }

        if isIconDebugEnabled {
            iconDebugLog("terminated owner pruned bundle=\(bundleID) removed=\(idsToRemove.count)")
        }
        applyPanel()
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
        let distributedCenter = DistributedNotificationCenter.default()

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

        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let application = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = application.bundleIdentifier else {
                return
            }
            Task { @MainActor [weak self, bundleID] in
                self?.handleApplicationTermination(bundleID: bundleID)
            }
        })

        distributedObservers.append(distributedCenter.addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleAppearanceChange()
            }
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

        setupPanelHoverMonitor()
    }

    private func teardownObservers() {
        let notificationCenter = NotificationCenter.default
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let distributedCenter = DistributedNotificationCenter.default()

        for observer in observers {
            notificationCenter.removeObserver(observer)
            workspaceCenter.removeObserver(observer)
        }
        observers.removeAll()

        for observer in distributedObservers {
            distributedCenter.removeObserver(observer)
        }
        distributedObservers.removeAll()

        stateCancellable?.cancel()
        stateCancellable = nil
        removePanelHoverMonitor()
    }

    private func setupPanelHoverMonitor() {
        removePanelHoverMonitor()
        panelHoverMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handlePanelHoverInputEvent()
            }
        }
    }

    private func removePanelHoverMonitor() {
        if let panelHoverMonitor {
            NSEvent.removeMonitor(panelHoverMonitor)
            self.panelHoverMonitor = nil
        }
        lastPanelHoverMonitorProcessTime = 0
    }

    private func handlePanelHoverInputEvent() {
        guard isRunning, isFeatureEnabled else { return }
        guard panelController.isVisible || isHiddenSectionVisibleNow || isManualPreviewRequested else { return }

        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPanelHoverMonitorProcessTime >= panelHoverMonitorMinInterval else { return }
        lastPanelHoverMonitorProcessTime = now

        applyPanel()
    }

    private func handleAppearanceChange() {
        pendingPersistedIconSaveWorkItem?.cancel()
        pendingPersistedIconSaveWorkItem = nil
        iconCacheByID.removeAll()
        persistedIconCacheKeys.removeAll()
        lastScannedWindowSignature.removeAll()
        lastSuccessfulScanAt = Date.distantPast
        MenuBarStatusWindowCache.invalidate()
        MenuBarFloatingFallbackIconProvider.clearCache()
        MenuBarFloatingIconRendering.clearCache()
        savePersistedIconCache(immediate: true)
        requestRescanOnMainActor(force: true, refreshIcons: true)
        applyPanel()
    }

    private func handleApplicationTermination(bundleID: String) {
        guard !bundleID.isEmpty else { return }
        // Wait until the bundle is fully gone (handles edge cases with multiple processes).
        guard NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty else { return }

        pruneTerminatedItems(for: bundleID)
        requestRescanOnMainActor(force: true)
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
            self?.enqueueRescanRequest(force: force, refreshIcons: refreshIcons)
        }
    }

    private func enqueueRescanRequest(force: Bool, refreshIcons: Bool) {
        pendingRescanForce = pendingRescanForce || force
        pendingRescanRefreshIcons = pendingRescanRefreshIcons || refreshIcons
        if pendingRescanWorkItem != nil {
            return
        }

        let isUrgent = force || refreshIcons
        let delay: TimeInterval = isUrgent ? 0 : 0.08
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let pendingForce = self.pendingRescanForce
            let pendingRefreshIcons = self.pendingRescanRefreshIcons
            self.pendingRescanForce = false
            self.pendingRescanRefreshIcons = false
            self.pendingRescanWorkItem = nil
            self.rescan(force: pendingForce, refreshIcons: pendingRefreshIcons)
        }
        pendingRescanWorkItem = workItem
        if isUrgent {
            DispatchQueue.main.async(execute: workItem)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    private func desiredRescanInterval() -> TimeInterval {
        if isInSettingsInspectionMode {
            // Keep settings scrolling/interaction fluid by reducing scan churn while editing.
            return 6.0
        }
        if isHiddenSectionVisibleNow || isManualPreviewRequested || panelController.isVisible {
            return 1.4
        }
        return 3.5
    }

    private func saveConfiguration() {
        let config = Config(
            isFeatureEnabled: isFeatureEnabled,
            alwaysHiddenItemIDs: Array(alwaysHiddenItemIDs),
            floatingBarItemIDs: Array(floatingBarItemIDs)
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
        let restoredAlwaysHidden = Set(config.alwaysHiddenItemIDs.filter { !isMandatoryMenuBarManagerControlID($0) })
        alwaysHiddenItemIDs = restoredAlwaysHidden
        let restoredFloatingBar = Set((config.floatingBarItemIDs ?? config.alwaysHiddenItemIDs).filter {
            restoredAlwaysHidden.contains($0) && !isMandatoryMenuBarManagerControlID($0)
        })
        floatingBarItemIDs = restoredFloatingBar
    }

    private func loadPersistedIconCache() {
        let sourcePayload = loadPersistedIconCacheDataFromDisk() ?? loadPersistedIconCacheDataFromDefaults()
        guard let payload = sourcePayload else {
            Self.clearLegacyIconCacheDefaults(keys: allIconCacheDefaultsKeys)
            return
        }
        if payload.data.count >= userDefaultsHardLimitBytes {
            if payload.source == .disk {
                Self.removePersistedIconCacheFile(at: iconCacheFileURL)
            }
            Self.clearLegacyIconCacheDefaults(keys: allIconCacheDefaultsKeys)
            return
        }

        let stored: [String: Data]
        if let envelope = try? JSONDecoder().decode(PersistedIconCacheEnvelope.self, from: payload.data) {
            let age = Date().timeIntervalSince1970 - envelope.savedAt
            if age > persistedIconCacheMaxAge {
                if payload.source == .disk {
                    Self.removePersistedIconCacheFile(at: iconCacheFileURL)
                }
                Self.clearLegacyIconCacheDefaults(keys: allIconCacheDefaultsKeys)
                return
            }
            stored = envelope.images
        } else if let legacy = try? JSONDecoder().decode([String: Data].self, from: payload.data) {
            stored = legacy
        } else {
            if payload.source == .disk {
                Self.removePersistedIconCacheFile(at: iconCacheFileURL)
            }
            Self.clearLegacyIconCacheDefaults(keys: allIconCacheDefaultsKeys)
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

        if payload.source == .defaults {
            Self.writePersistedIconCache(payload.data, to: iconCacheFileURL)
        }
        Self.clearLegacyIconCacheDefaults(keys: allIconCacheDefaultsKeys)
    }

    private func savePersistedIconCache(immediate: Bool = false) {
        pendingPersistedIconSaveWorkItem?.cancel()
        pendingPersistedIconSaveWorkItem = nil

        let iconSnapshot = iconCacheByID
        let keySnapshot = persistedIconCacheKeys
        let iconCacheFileURL = iconCacheFileURL
        let defaultsKeys = allIconCacheDefaultsKeys
        let maxPayloadBytes = persistedIconCacheMaxPayloadBytes

        let persistBlock = {
            guard let data = Self.encodedPersistedIconCache(
                from: iconSnapshot,
                keys: keySnapshot,
                maxPayloadBytes: maxPayloadBytes
            ) else {
                Self.removePersistedIconCacheFile(at: iconCacheFileURL)
                Self.clearLegacyIconCacheDefaults(keys: defaultsKeys)
                return
            }
            Self.writePersistedIconCache(data, to: iconCacheFileURL)
            Self.clearLegacyIconCacheDefaults(keys: defaultsKeys)
        }

        if immediate {
            persistBlock()
            return
        }

        let workItem = DispatchWorkItem(block: persistBlock)
        pendingPersistedIconSaveWorkItem = workItem
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + iconCacheSaveDebounceInterval,
            execute: workItem
        )
    }

    private static func encodedPersistedIconCache(
        from iconCache: [String: NSImage],
        keys: Set<String>,
        maxPayloadBytes: Int
    ) -> Data? {
        var encodedCache = [String: Data]()
        encodedCache.reserveCapacity(keys.count)

        for cacheKey in keys {
            guard let image = iconCache[cacheKey],
                  let imageData = pngData(for: image) else {
                continue
            }
            encodedCache[cacheKey] = imageData
        }

        guard !encodedCache.isEmpty else { return nil }

        func encodeEnvelope(images: [String: Data]) -> Data? {
            let envelope = PersistedIconCacheEnvelope(
                savedAt: Date().timeIntervalSince1970,
                images: images
            )
            return try? JSONEncoder().encode(envelope)
        }

        guard var data = encodeEnvelope(images: encodedCache) else {
            return nil
        }
        if data.count <= maxPayloadBytes {
            return data
        }

        let keysByDescendingSize = encodedCache.keys.sorted {
            (encodedCache[$0]?.count ?? 0) > (encodedCache[$1]?.count ?? 0)
        }
        for key in keysByDescendingSize {
            encodedCache.removeValue(forKey: key)
            guard !encodedCache.isEmpty else { return nil }
            guard let prunedData = encodeEnvelope(images: encodedCache) else { continue }
            data = prunedData
            if data.count <= maxPayloadBytes {
                return data
            }
        }

        return nil
    }

    private var allIconCacheDefaultsKeys: [String] {
        [iconCacheDefaultsKey] + legacyIconCacheDefaultsKeys
    }

    private func loadPersistedIconCacheDataFromDisk() -> (source: PersistedIconCacheSource, data: Data)? {
        guard let data = try? Data(contentsOf: iconCacheFileURL), !data.isEmpty else { return nil }
        return (.disk, data)
    }

    private func loadPersistedIconCacheDataFromDefaults() -> (source: PersistedIconCacheSource, data: Data)? {
        for key in allIconCacheDefaultsKeys {
            if let data = UserDefaults.standard.data(forKey: key), !data.isEmpty {
                return (.defaults, data)
            }
        }
        return nil
    }

    private static func writePersistedIconCache(_ data: Data, to url: URL) {
        do {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
    }

    private static func removePersistedIconCacheFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private static func clearLegacyIconCacheDefaults(keys: [String]) {
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
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
            if isIconDebugEnabled {
                let summary = MenuBarFloatingIconDiagnostics.summarize(icon)?.compactDescription ?? "icon=none"
                iconDebugLog("cache write key=\(cacheKey) overwrite=\(overwrite) \(summary)")
            }
        }

        if didWrite {
            savePersistedIconCache()
        }
    }

    private static func pngData(for image: NSImage) -> Data? {
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
                if isIconDebugEnabled {
                    let summary = MenuBarFloatingIconDiagnostics.summarize(icon)?.compactDescription ?? "icon=none"
                    iconDebugLog("cache hit key=\(key) \(iconDebugName(for: item)) \(summary)")
                }
                return icon
            }
        }
        if isIconDebugEnabled {
            iconDebugLog("cache miss \(iconDebugName(for: item))")
        }
        return nil
    }

    private func withCachedIconIfNeeded(_ item: MenuBarFloatingItemSnapshot) -> MenuBarFloatingItemSnapshot {
        guard item.icon == nil, let cached = cachedIcon(for: item) else {
            return item
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
            icon: cached
        )
    }

    private func iconCacheKeys(for item: MenuBarFloatingItemSnapshot) -> [String] {
        var keys = [String]()
        keys.reserveCapacity(6)
        let appearanceNamespace = currentAppearanceCacheNamespace()

        func appendScoped(_ key: String) {
            keys.append("\(appearanceNamespace)::\(key)")
        }

        if let axIdentifier = item.axIdentifier, !axIdentifier.isEmpty {
            appendScoped("\(item.ownerBundleID)::axid:\(axIdentifier)")
        }
        if let windowID = item.windowID {
            appendScoped("\(item.ownerBundleID)::window:\(windowID)")
        }
        if let statusItemIndex = item.statusItemIndex {
            appendScoped("\(item.ownerBundleID)::statusItem:\(statusItemIndex)")
        }
        if !item.id.isEmpty {
            appendScoped(item.id)
        }

        // Keep broader textual keys as a low-priority fallback for system-owned items,
        // where identifiers can be absent or unstable between scans.
        if item.ownerBundleID.lowercased().hasPrefix("com.apple.") {
            if let titleToken = stableTextToken(item.title) {
                appendScoped("\(item.ownerBundleID)::title:\(titleToken)")
            }
            if let detailToken = stableTextToken(item.detail) {
                appendScoped("\(item.ownerBundleID)::detail:\(detailToken)")
            }
        }

        var seen = Set<String>()
        return keys.filter { key in
            seen.insert(key).inserted
        }
    }

    private func currentAppearanceCacheNamespace() -> String {
        let candidates: [NSAppearance.Name] = [
            NSAppearance.Name.accessibilityHighContrastDarkAqua,
            NSAppearance.Name.darkAqua,
            NSAppearance.Name.accessibilityHighContrastAqua,
            NSAppearance.Name.aqua,
        ]
        let bestMatch = NSApp.effectiveAppearance.bestMatch(from: candidates) ?? NSAppearance.Name.aqua

        switch bestMatch {
        case NSAppearance.Name.darkAqua, NSAppearance.Name.accessibilityHighContrastDarkAqua:
            return "appearance.dark"
        default:
            return "appearance.light"
        }
    }

    private var isIconDebugEnabled: Bool {
        if let raw = ProcessInfo.processInfo.environment[iconDebugKey]?.lowercased() {
            return raw == "1" || raw == "true" || raw == "yes"
        }
        if UserDefaults.standard.object(forKey: iconDebugKey) != nil {
            return UserDefaults.standard.bool(forKey: iconDebugKey)
        }
        for domain in ["iordv.Droppy", "com.jordyspruit.Droppy", "app.getdroppy.Droppy"] {
            guard let defaults = UserDefaults(suiteName: domain),
                  defaults.object(forKey: iconDebugKey) != nil else {
                continue
            }
            return defaults.bool(forKey: iconDebugKey)
        }
#if DEBUG
        return true
#else
        return false
#endif
    }

    private func iconDebugLog(_ message: @autoclosure () -> String) {
        guard isIconDebugEnabled else { return }
        print("[MenuBarIconDebug] \(message())")
    }

    private func iconDebugName(for item: MenuBarFloatingItemSnapshot) -> String {
        let windowPart = item.windowID.map(String.init) ?? "nil"
        let identifierPart = item.axIdentifier ?? "no-axid"
        let titlePart = stableTextToken(item.title) ?? "-"
        let detailPart = stableTextToken(item.detail) ?? "-"
        return "id=\(item.id) owner=\(item.ownerBundleID) window=\(windowPart) axid=\(identifierPart) title=\(titlePart) detail=\(detailPart)"
    }

    private func logResolvedIcon(
        for item: MenuBarFloatingItemSnapshot,
        source: String,
        icon: NSImage?
    ) {
        guard isIconDebugEnabled else { return }
        let summary = MenuBarFloatingIconDiagnostics.summarize(icon)?.compactDescription ?? "icon=none"
        let useTemplate = icon.map { MenuBarFloatingIconRendering.shouldUseTemplateTint(for: $0) } ?? false
        iconDebugLog("resolved source=\(source) templateTint=\(useTemplate) \(iconDebugName(for: item)) \(summary)")
    }

    private func logPanelIcons(_ items: [MenuBarFloatingItemSnapshot], reason: String) {
        guard isIconDebugEnabled else { return }
        iconDebugLog("panel reason=\(reason) count=\(items.count)")
        for item in items {
            let summary = MenuBarFloatingIconDiagnostics.summarize(item.icon)?.compactDescription ?? "icon=none"
            iconDebugLog("panel item \(iconDebugName(for: item)) \(summary)")
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
