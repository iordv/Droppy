//
//  DragMonitor.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//
//  Uses NSPasteboard(name: .drag) polling to detect drag operations.
//  This approach works without Accessibility permissions, unlike NSEvent global monitors.
//

import AppKit
import Combine
import UniformTypeIdentifiers

/// Monitors system-wide drag events to detect when files/items are being dragged
final class DragMonitor: ObservableObject {
    /// Shared instance for app-wide access
    static let shared = DragMonitor()
    
    /// Whether a drag operation with droppable content is in progress
    @Published private(set) var isDragging = false
    
    /// The current mouse location during drag
    @Published private(set) var dragLocation: CGPoint = .zero
    
    /// Whether a jiggle gesture was detected during drag (triggers basket)
    @Published private(set) var didJiggle = false
    
    private var isMonitoring = false
    private var dragStartChangeCount: Int = 0
    private var dragActive = false
    private var dragHasSupportedPayload = false
    private var isDragStartCandidate = false
    private var dragStartCandidateLocation: CGPoint = .zero
    private let dragStartMovementThreshold: CGFloat = 3.5
    
    // Jiggle detection state
    private var lastDragLocation: CGPoint = .zero
    private var lastDragDirection: CGPoint = .zero
    private var directionChanges: [Date] = []
    private let jiggleTimeWindow: TimeInterval = 0.5
    
    // Flags to prevent duplicate notifications
    private var jiggleNotified = false
    private var dragEndNotified = false
    
    /// When true, basket reveal logic is suppressed for the active drag session.
    /// Used for drags that originate from Droppy's own shelf/basket items.
    private var suppressBasketRevealForCurrentDrag = false
    
    // Optional shortcut to reveal basket during active drag
    private var dragRevealHotKey: GlobalHotKey?
    private var dragRevealShortcut: SavedShortcut?
    private var dragRevealShortcutSignature: String = ""
    private var dragRevealLastTriggeredAt: Date = .distantPast
    private var userDefaultsObserver: NSObjectProtocol?
    
    private var isDragRevealShortcutConfigured: Bool {
        dragRevealShortcutSignature != "none"
    }

    private static let mailDragTypes: Set<NSPasteboard.PasteboardType> = [
        NSPasteboard.PasteboardType("com.apple.mail.PasteboardTypeMessageTransfer"),
        NSPasteboard.PasteboardType("com.apple.mail.PasteboardTypeAutomator"),
        NSPasteboard.PasteboardType("com.apple.mail.message"),
        NSPasteboard.PasteboardType(UTType.emailMessage.identifier)
    ]

    private static let filePromiseDragTypes: Set<NSPasteboard.PasteboardType> = Set(
        NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
    )
    
    private init() {}
    
    /// Starts monitoring for drag events
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        configureDragRevealHotKeyIfNeeded(force: true)
        
        if userDefaultsObserver == nil {
            userDefaultsObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: UserDefaults.standard,
                queue: .main
            ) { [weak self] _ in
                self?.configureDragRevealHotKeyIfNeeded()
            }
        }
        
        monitorLoop()
    }
    
    /// Stops monitoring for drag events
    func stopMonitoring() {
        isMonitoring = false
        stopIdleJiggleMonitoring()
        if let observer = userDefaultsObserver {
            NotificationCenter.default.removeObserver(observer)
            userDefaultsObserver = nil
        }
        dragRevealHotKey = nil
        dragRevealShortcut = nil
        dragRevealShortcutSignature = ""
    }
    
    private func monitorLoop() {
        guard isMonitoring else { return }
        
        // CRITICAL: Only access NSEvent class properties if we're truly on the main thread
        // and not during system event dispatch to avoid race conditions with HID event decoding
        if Thread.isMainThread {
            checkForActiveDrag()
        }
        
        // Increased interval from 50ms to 100ms to reduce collision chance with system event processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            self?.monitorLoop()
        }
    }
    
    /// Resets jiggle state (called after basket is shown or drag ends)
    func resetJiggle() {
        didJiggle = false
        jiggleNotified = false
        directionChanges.removeAll()
        lastDragDirection = .zero
    }
    
    // MARK: - Idle Jiggle Monitoring (Disabled)
    
    /// Disabled: no-file jiggle reveal was removed in favor of the basket switcher shortcut.
    func startIdleJiggleMonitoring() {
        // Intentionally no-op.
    }
    
    /// Disabled: retained for compatibility with existing call sites.
    func stopIdleJiggleMonitoring() {
        // Intentionally no-op.
    }
    
    /// Called by settings when shortcut value changes.
    func reloadShortcutConfiguration() {
        configureDragRevealHotKeyIfNeeded(force: true)
    }
    
    /// Suppresses or re-enables basket reveal behavior for the current drag session.
    /// This should be set to true when a drag starts from Droppy's own items.
    func setSuppressBasketRevealForCurrentDrag(_ suppress: Bool) {
        guard suppressBasketRevealForCurrentDrag != suppress else { return }
        suppressBasketRevealForCurrentDrag = suppress
        updateDragRevealHotKeyRegistration()
    }
    
    /// Manually set dragging state for system-initiated drags (e.g., Dock folder drags)
    /// NSPasteboard(name: .drag) polling doesn't work for Dock folder drags - the changeCount
    /// isn't updated until later in the drag. This allows NotchDragContainer.draggingEntered()
    /// to manually activate the drag state when it receives a drag via NSDraggingDestination.
    /// Fixes Issue #136: Dock folder drags not showing shelf action buttons.
    func forceSetDragging(_ isDragging: Bool, location: CGPoint? = nil) {
        guard self.isDragging != isDragging else { return }  // Avoid redundant changes
        
        print("🔧 DragMonitor.forceSetDragging(\(isDragging)) - Dock folder/system drag workaround")
        
        if isDragging {
            dragActive = true
            dragHasSupportedPayload = true
            isDragStartCandidate = false
            self.isDragging = true
            updateDragRevealHotKeyRegistration()
            if let loc = location {
                dragLocation = loc
                lastDragLocation = loc
            }
            dragEndNotified = false
            resetJiggle()
        } else {
            dragActive = false
            dragHasSupportedPayload = false
            isDragStartCandidate = false
            suppressBasketRevealForCurrentDrag = false
            updateDragRevealHotKeyRegistration()
            self.isDragging = false
            dragEndNotified = true
            resetJiggle()
        }
    }
    
    /// Force reset ALL drag state (called after screen unlock when state may be corrupted)
    /// After SkyLight delegation, the drag polling state can get stuck, blocking hover detection
    func forceReset() {
        print("🧹 DragMonitor.forceReset() called - clearing stuck drag state")
        dragActive = false
        dragHasSupportedPayload = false
        isDragStartCandidate = false
        isDragging = false
        dragLocation = .zero
        dragStartChangeCount = 0
        dragEndNotified = true
        suppressBasketRevealForCurrentDrag = false
        resetJiggle()
        updateDragRevealHotKeyRegistration()
        
        // SKYLIGHT DEBUG: Enable verbose logging for a few seconds after unlock
        DragMonitor.unlockTime = Date()
    }
    
    /// Timestamp of last unlock - used to trigger verbose logging in NotchWindow.handleGlobalMouseEvent
    static var unlockTime: Date = .distantPast

    private func checkForActiveDrag() {
        autoreleasepool {
            // SAFETY: Cache NSEvent class properties immediately to minimize
            // repeated access during HID event system contention
            let mouseIsDown = NSEvent.pressedMouseButtons & 1 != 0
            let currentMouseLocation = NSEvent.mouseLocation
            
            // DEBUG: Log state periodically to trace stuck isDragging after SkyLight unlock
            struct DragDebugCounter { static var lastLog = Date.distantPast }
            if Date().timeIntervalSince(DragDebugCounter.lastLog) > 2.0 {
                print("🐉 DragMonitor.checkForActiveDrag: isDragging=\(isDragging), dragActive=\(dragActive), mouseIsDown=\(mouseIsDown)")
                DragDebugCounter.lastLog = Date()
            }
            
            // Optimization: If mouse is not down and we are not tracking a drag, 
            // return early to avoid unnecessary NSPasteboard allocation/release (which caused crashes)
            if !mouseIsDown && !dragActive {
                // Self-heal stale drag state (can happen after lock/unlock or monitor desync).
                if isDragging {
                    print("🧹 DragMonitor: Clearing stale isDragging state")
                    isDragging = false
                    dragEndNotified = true
                    updateDragRevealHotKeyRegistration()
                    resetJiggle()
                }
                dragHasSupportedPayload = false
                isDragStartCandidate = false
                return
            }

            // Retrieve pasteboard handle locally to ensure validity
            let dragPasteboard = NSPasteboard(name: .drag)
            let currentChangeCount = dragPasteboard.changeCount
            
            // Detect drag START
            if mouseIsDown && !dragActive {
                if !isDragStartCandidate {
                    isDragStartCandidate = true
                    dragStartCandidateLocation = currentMouseLocation
                }

                let hasSupportedContent = hasSupportedDragPayload(dragPasteboard)
                if hasSupportedContent {
                    // Some drag sources can reuse pasteboard changeCount across repeated drags.
                    // Only allow movement fallback for known unreliable sources (Mail/file promises);
                    // for regular file/url drags it can false-trigger on stale drag pasteboard data.
                    let movedFromCandidate = hypot(
                        currentMouseLocation.x - dragStartCandidateLocation.x,
                        currentMouseLocation.y - dragStartCandidateLocation.y
                    ) > dragStartMovementThreshold
                    let changeCountChanged = currentChangeCount != dragStartChangeCount
                    let canUseMovementFallback = shouldAllowMovementFallback(for: dragPasteboard)
                    if changeCountChanged || (canUseMovementFallback && movedFromCandidate) {
                        dragActive = true
                        dragHasSupportedPayload = true
                        isDragStartCandidate = false
                        stopIdleJiggleMonitoring()
                        dragStartChangeCount = currentChangeCount
                        resetJiggle()
                        dragEndNotified = false
                        lastDragLocation = currentMouseLocation
                        isDragging = true
                        dragLocation = currentMouseLocation
                        updateDragRevealHotKeyRegistration()
                        
                        // Check if instant basket mode is enabled
                        let instantMode = UserDefaults.standard.preference(
                            AppPreferenceKey.instantBasketOnDrag,
                            default: PreferenceDefault.instantBasketOnDrag
                        )
                        if instantMode && !isDragRevealShortcutConfigured {
                            // Get user-configured delay (minimum 0.15s to let drag "settle")
                            let configuredDelay = UserDefaults.standard.preference(
                                AppPreferenceKey.instantBasketDelay,
                                default: PreferenceDefault.instantBasketDelay
                            )
                            let delay = max(0.15, configuredDelay)
                            
                            // Check if Option key is held (for multi-basket spawn)
                            let optionHeld = NSEvent.modifierFlags.contains(.option)
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                                // Only show if drag is still active (user didn't release)
                                guard self?.dragActive == true else { return }
                                guard self?.dragHasSupportedPayload == true else { return }
                                guard self?.suppressBasketRevealForCurrentDrag != true else { return }
                                let enabled = UserDefaults.standard.preference(
                                    AppPreferenceKey.enableFloatingBasket,
                                    default: PreferenceDefault.enableFloatingBasket
                                )
                                if enabled {
                                    // Option+drag: Spawn new basket only if multi-basket mode enabled
                                    // Normal drag: Use existing basket if one is visible
                                    let multiBasketEnabled = UserDefaults.standard.preference(
                                        AppPreferenceKey.enableMultiBasket,
                                        default: PreferenceDefault.enableMultiBasket
                                    )
                                    if optionHeld && multiBasketEnabled && FloatingBasketWindowController.isAnyBasketVisible {
                                        FloatingBasketWindowController.spawnNewBasket()
                                    } else {
                                        FloatingBasketWindowController.shared.onJiggleDetected()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Update location while dragging (use cached value)
            if dragActive && mouseIsDown {
                dragLocation = currentMouseLocation
                if !isDragRevealShortcutConfigured {
                    detectJiggle(currentLocation: currentMouseLocation)
                }
                lastDragLocation = currentMouseLocation
            }
            
            // Detect drag END
            if !mouseIsDown && dragActive {
                dragActive = false
                dragHasSupportedPayload = false
                isDragStartCandidate = false
                suppressBasketRevealForCurrentDrag = false
                updateDragRevealHotKeyRegistration()
                isDragging = false
                dragEndNotified = true
                
                // Notify all visible baskets so each instance can auto-hide independently.
                for controller in FloatingBasketWindowController.visibleBaskets {
                    controller.onDragEnded()
                }
                
                resetJiggle()
            }
        }
    }
    
    private func detectJiggle(currentLocation: CGPoint) {
        guard dragHasSupportedPayload else { return }
        guard !suppressBasketRevealForCurrentDrag else { return }
        
        let dx = currentLocation.x - lastDragLocation.x
        let dy = currentLocation.y - lastDragLocation.y
        let magnitude = sqrt(dx * dx + dy * dy)
        let sensitivity = UserDefaults.standard.preference(
            AppPreferenceKey.basketJiggleSensitivity,
            default: PreferenceDefault.basketJiggleSensitivity
        )
        let minimumMovement = max(3.0, min(8.0, 9.0 - (sensitivity * 1.25)))
        
        guard magnitude > minimumMovement else { return }
        
        let currentDirection = CGPoint(x: dx / magnitude, y: dy / magnitude)
        
        if lastDragDirection != .zero {
            let dot = currentDirection.x * lastDragDirection.x + currentDirection.y * lastDragDirection.y
            
            if dot < -0.3 {
                let now = Date()
                directionChanges.append(now)
                directionChanges = directionChanges.filter { now.timeIntervalSince($0) < jiggleTimeWindow }
                let requiredDirectionChanges = max(2, min(5, Int(round(6.0 - sensitivity))))
                
                if directionChanges.count >= requiredDirectionChanges && !jiggleNotified {
                    didJiggle = true
                    jiggleNotified = true
                    
                    // Allow re-notifying after a delay (to move basket)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.jiggleNotified = false
                    }
                    
                    // Use async to avoid blocking the timer
                    DispatchQueue.main.async {
                        // Check if basket is enabled before showing
                        let enabled = UserDefaults.standard.preference(
                            AppPreferenceKey.enableFloatingBasket,
                            default: PreferenceDefault.enableFloatingBasket
                        )
                        if enabled {
                            FloatingBasketWindowController.shared.onJiggleDetected()
                        }
                    }
                }
            }
        }
        
        lastDragDirection = currentDirection
    }

    private func hasSupportedDragPayload(_ pasteboard: NSPasteboard) -> Bool {
        guard let types = pasteboard.types, !types.isEmpty else { return false }

        for type in types {
            if Self.mailDragTypes.contains(type) || Self.filePromiseDragTypes.contains(type) {
                return true
            }

            if let utType = UTType(type.rawValue),
               utType.conforms(to: .fileURL) ||
               utType.conforms(to: .url) ||
               utType.conforms(to: .image) ||
               utType.conforms(to: .movie) {
                return true
            }
        }

        // Fallback for drag sources that expose URLs without a canonical UTI type.
        return pasteboard.canReadObject(forClasses: [NSURL.self], options: nil)
    }

    private func shouldAllowMovementFallback(for pasteboard: NSPasteboard) -> Bool {
        guard let types = pasteboard.types, !types.isEmpty else { return false }
        return types.contains { type in
            Self.mailDragTypes.contains(type) || Self.filePromiseDragTypes.contains(type)
        }
    }
    
    private func loadDragRevealShortcut() -> SavedShortcut? {
        guard let data = UserDefaults.standard.data(forKey: AppPreferenceKey.basketDragRevealShortcut),
              let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) else {
            return nil
        }
        return decoded
    }
    
    private func configureDragRevealHotKeyIfNeeded(force: Bool = false) {
        let shortcut = loadDragRevealShortcut()
        let signature = shortcut.map { "\($0.keyCode):\($0.modifiers)" } ?? "none"
        let needsRefresh = force || signature != dragRevealShortcutSignature
        guard needsRefresh else { return }
        
        dragRevealShortcut = shortcut
        dragRevealShortcutSignature = signature
        dragRevealHotKey = nil
        updateDragRevealHotKeyRegistration()
    }
    
    private func updateDragRevealHotKeyRegistration() {
        guard dragActive, !suppressBasketRevealForCurrentDrag, let shortcut = dragRevealShortcut else {
            dragRevealHotKey = nil
            return
        }
        
        guard dragRevealHotKey == nil else { return }
        dragRevealHotKey = GlobalHotKey(
            keyCode: shortcut.keyCode,
            modifiers: shortcut.modifiers
        ) { [weak self] in
            self?.handleDragRevealShortcut()
        }
    }
    
    private func handleDragRevealShortcut() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.dragActive else { return }
            guard self.dragHasSupportedPayload else { return }
            
            // Debounce key repeat
            let now = Date()
            guard now.timeIntervalSince(self.dragRevealLastTriggeredAt) > 0.25 else { return }
            self.dragRevealLastTriggeredAt = now
            
            let enabled = UserDefaults.standard.preference(
                AppPreferenceKey.enableFloatingBasket,
                default: PreferenceDefault.enableFloatingBasket
            )
            guard enabled else { return }
            guard !self.suppressBasketRevealForCurrentDrag else { return }
            
            FloatingBasketWindowController.shared.onJiggleDetected()
        }
    }
}
