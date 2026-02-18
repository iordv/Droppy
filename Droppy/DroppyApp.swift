//
//  DroppyApp.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI
import Combine
import Darwin

/// Main application entry point for Droppy
@main
struct DroppyApp: App {
    /// App delegate for handling app lifecycle and notch window setup
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage(AppPreferenceKey.showInMenuBar) private var showInMenuBar = PreferenceDefault.showInMenuBar
    @AppStorage(AppPreferenceKey.showQuickshareInMenuBar) private var showQuickshareInMenuBar = PreferenceDefault.showQuickshareInMenuBar
    
    var body: some Scene {
        MenuBarExtra("Droppy", image: "MenuBarIcon", isInserted: $showInMenuBar) {
            DroppyMenuContent()
        }
    }
}

enum MemoryRecoveryCoordinator {
    private static var lastReclaimDate: Date = .distantPast
    private static let minimumReclaimInterval: TimeInterval = 1.5

    static func reclaimTransientMemory(forceAllocatorTrim: Bool = false) {
        let now = Date()
        if !forceAllocatorTrim,
           now.timeIntervalSince(lastReclaimDate) < minimumReclaimInterval {
            return
        }

        lastReclaimDate = now
        ThumbnailCache.shared.clearTransientPreviews()
        LinkPreviewService.shared.clearCache(cancelPending: true)
        ExtensionIconCache.shared.clearCache()
        DroppedItem.clearAvailableAppsCache()
        clearSharingServicesCache()
        MenuBarFloatingFallbackIconProvider.clearCache()
        URLCache.shared.removeAllCachedResponses()

        if forceAllocatorTrim {
            _ = malloc_zone_pressure_relief(nil, 0)
        }
    }
}

/// Menu content with Element Capture (shows configured shortcut)
struct DroppyMenuContent: View {
    // Track shortcut changes via notification
    @State private var shortcutRefreshId = UUID()
    @State private var todoManager = ToDoManager.shared
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    
    // Observe NotchWindowController for hide state
    @ObservedObject private var notchController = NotchWindowController.shared
    
    // Check if shelf is enabled (to conditionally show hide/show option)
    @AppStorage(AppPreferenceKey.enableNotchShelf) private var enableNotchShelf = PreferenceDefault.enableNotchShelf
    @AppStorage(AppPreferenceKey.showIdleNotchOnExternalDisplays) private var showIdleNotchOnExternalDisplays = PreferenceDefault.showIdleNotchOnExternalDisplays
    
    // Check if Quickshare menu bar is enabled
    // Check if Quickshare menu bar is enabled
    @AppStorage(AppPreferenceKey.showQuickshareInMenuBar) private var showQuickshareInMenuBar = PreferenceDefault.showQuickshareInMenuBar

    // Check if Clipboard menu bar is enabled
    @AppStorage(AppPreferenceKey.showClipboardInMenuBar) private var showClipboardInMenuBar = PreferenceDefault.showClipboardInMenuBar
    @AppStorage(AppPreferenceKey.todoInstalled) private var todoInstalled = PreferenceDefault.todoInstalled
    @AppStorage(AppPreferenceKey.todoShowUpcomingInMenuBar) private var showUpcomingInMenuBar = PreferenceDefault.todoShowUpcomingInMenuBar
    @ObservedObject private var licenseManager = LicenseManager.shared
    
    // Check if extensions are disabled
    private var isElementCaptureDisabled: Bool {
        _ = shortcutRefreshId // Force refresh
        return ExtensionType.elementCapture.isRemoved
    }
    
    private var isWindowSnapDisabled: Bool {
        _ = shortcutRefreshId // Force refresh
        return ExtensionType.windowSnap.isRemoved
    }
    
    // Load saved shortcut for native keyboard shortcut display
    private var savedShortcut: SavedShortcut? {
        // Force re-evaluation when shortcutRefreshId changes
        _ = shortcutRefreshId
        if let data = UserDefaults.standard.data(forKey: "elementCaptureShortcut"),
           let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
            return decoded
        }
        return nil
    }
    
    var body: some View {
        if licenseManager.requiresLicenseEnforcement && !licenseManager.hasAccess {
            Button {
                LicenseWindowController.shared.show()
            } label: {
                Label("Activate License…", systemImage: "key.fill")
            }
            
            if licenseManager.canStartTrial {
                Button {
                    if licenseManager.needsEmailForTrialStart {
                        LicenseWindowController.shared.show()
                    } else {
                        Task {
                            if await licenseManager.startTrial() {
                                HapticFeedback.expand()
                            } else {
                                HapticFeedback.error()
                            }
                        }
                    }
                } label: {
                    Label("Start 3-Day Trial", systemImage: "clock.badge.checkmark")
                }

                if licenseManager.needsEmailForTrialStart {
                    Text("Enter purchase email in Activate window to start trial.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(licenseManager.trialStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Droppy", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        } else {
            Group {
            if licenseManager.requiresLicenseEnforcement && licenseManager.isTrialActive && !licenseManager.isActivated {
                Text(licenseManager.trialStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    LicenseWindowController.shared.show()
                } label: {
                    Label("Activate License…", systemImage: "key.fill")
                }
                Divider()
            }

            // Show/Hide Notch or Dynamic Island toggle
            // Also available when idle surface is kept visible without shelf interactions.
            if enableNotchShelf || showIdleNotchOnExternalDisplays {
                if notchController.isTemporarilyHidden {
                    Button {
                        notchController.setTemporarilyHidden(false)
                    } label: {
                        Label("Show \(notchController.displayModeLabel)", systemImage: "eye")
                    }
                } else {
                    Button {
                        notchController.setTemporarilyHidden(true)
                    } label: {
                        Label("Hide \(notchController.displayModeLabel)", systemImage: "eye.slash")
                    }
                }
                
                Divider()
            }
            
            Button {
                UpdateChecker.shared.checkAndNotify()
            } label: {
                Label("Check for Updates…", systemImage: "arrow.clockwise")
            }
            
            Divider()
            
            if showQuickshareInMenuBar && !ExtensionType.quickshare.isRemoved {
                Menu {
                    QuickshareMenuContent()
                } label: {
                    Label("Quickshare", systemImage: "drop.fill")
                }
            }
            
            // Clipboard Menu (New)
            if showClipboardInMenuBar {
                Menu {
                    if clipboardMenuItems.isEmpty {
                        Text("Clipboard is empty")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(clipboardMenuItems) { item in
                            Button {
                                ClipboardManager.shared.paste(item: item)
                            } label: {
                                // Show icon based on type
                                Label(item.title, systemImage: iconFor(item: item))
                            }
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            clipboardManager.clearAllHistory()
                        } label: {
                            Label("Clear History", systemImage: "trash")
                        }
                    }
                    
                    Divider()
                    
                    Button {
                        ClipboardWindowController.shared.show()
                    } label: {
                        Label("Manage…", systemImage: "list.bullet.rectangle")
                    }
                    
                } label: {
                    Label("Clipboard", systemImage: "clipboard")
                }
            }

            if shouldShowUpcomingMenu {
                Menu {
                    if upcomingTaskItems.isEmpty && upcomingEventItems.isEmpty {
                        Text("No upcoming tasks or events")
                            .foregroundStyle(.secondary)
                    } else {
                        if !upcomingTaskItems.isEmpty {
                            Text("Tasks")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(upcomingTaskItems) { item in
                                Button {
                                    SettingsWindowController.shared.showSettings(openingExtension: .todo)
                                } label: {
                                    Label(upcomingTitle(for: item), systemImage: "checklist")
                                }
                            }
                        }

                        if !upcomingEventItems.isEmpty {
                            if !upcomingTaskItems.isEmpty {
                                Divider()
                            }
                            Text("Events")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(upcomingEventItems) { item in
                                Button {
                                    SettingsWindowController.shared.showSettings(openingExtension: .todo)
                                } label: {
                                    Label(upcomingTitle(for: item), systemImage: "calendar.badge.clock")
                                }
                            }
                        }
                    }

                    Divider()

                    Button {
                        todoManager.syncExternalSourcesNow()
                    } label: {
                        Label("Refresh Upcoming", systemImage: "arrow.clockwise")
                    }

                    Button {
                        SettingsWindowController.shared.showSettings(openingExtension: .todo)
                    } label: {
                        Label("Open Reminders", systemImage: "checklist")
                    }
                } label: {
                    Label("Upcoming", systemImage: "calendar.badge.clock")
                }
            }
            
            // Element Capture with native keyboard shortcut styling (hidden when disabled)
            if !isElementCaptureDisabled {
                elementCaptureButton
                    .id(shortcutRefreshId)  // Force rebuild when shortcut changes
            }
            
            // Window Snap submenu with quick actions (hidden when disabled)
            if !isWindowSnapDisabled {
                Menu {
                    Button {
                        WindowSnapManager.shared.executeAction(.leftHalf)
                    } label: {
                        Label("Left Half", systemImage: "rectangle.lefthalf.filled")
                    }
                    Button {
                        WindowSnapManager.shared.executeAction(.rightHalf)
                    } label: {
                        Label("Right Half", systemImage: "rectangle.righthalf.filled")
                    }
                    Button {
                        WindowSnapManager.shared.executeAction(.maximize)
                    } label: {
                        Label("Maximize", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    Button {
                        WindowSnapManager.shared.executeAction(.center)
                    } label: {
                        Label("Center", systemImage: "rectangle.center.inset.filled")
                    }
                    Divider()
                    Button {
                        SettingsWindowController.shared.showSettings(openingExtension: .windowSnap)
                    } label: {
                        Label("Configure Window Snap…", systemImage: "keyboard")
                    }
                } label: {
                    Label("Window Snap", systemImage: "rectangle.split.2x1")
                }
            }
            
            Divider()
            
            Button {
                SettingsWindowController.shared.showSettings()
            } label: {
                Label("Settings…", systemImage: "gear")
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Droppy", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
            .onReceive(NotificationCenter.default.publisher(for: .elementCaptureShortcutChanged)) { _ in
                shortcutRefreshId = UUID()
            }
            .onReceive(NotificationCenter.default.publisher(for: .windowSnapShortcutChanged)) { _ in
                shortcutRefreshId = UUID()
            }
            .onReceive(NotificationCenter.default.publisher(for: .extensionStateChanged)) { _ in
                // Refresh when extension is disabled/enabled
                shortcutRefreshId = UUID()
            }
            }
        }
    }
    
    @ViewBuilder
    private var elementCaptureButton: some View {
        if let shortcut = savedShortcut, let key = shortcut.keyEquivalent {
            Button {
                ElementCaptureManager.shared.startCaptureMode()
            } label: {
                Label("Element Capture", systemImage: "viewfinder")
            }
            .keyboardShortcut(key, modifiers: shortcut.eventModifiers)
        } else {
            Button {
                ElementCaptureManager.shared.startCaptureMode()
            } label: {
                Label("Element Capture", systemImage: "viewfinder")
            }
        }
    }
    
    // Helper for icon based on type
    private func iconFor(item: ClipboardItem) -> String {
        switch item.type {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .file: return "doc"
        case .url: return "link"
        case .color: return "paintpalette"
        }
    }

    private var clipboardMenuItems: [ClipboardItem] {
        Array(clipboardManager.history.prefix(15))
    }

    private var shouldShowUpcomingMenu: Bool {
        showUpcomingInMenuBar && todoInstalled && !ExtensionType.todo.isRemoved
    }

    private var upcomingTaskItems: [ToDoItem] {
        let items = todoManager.overviewTaskItems.filter {
            !$0.isCompleted && $0.externalSource != .calendar
        }
        return Array(items.prefix(6))
    }

    private var upcomingEventItems: [ToDoItem] {
        Array(todoManager.upcomingCalendarItems.prefix(6))
    }

    private func upcomingTitle(for item: ToDoItem) -> String {
        let baseTitle: String
        if item.title.count > 52 {
            baseTitle = String(item.title.prefix(49)) + "…"
        } else {
            baseTitle = item.title
        }

        guard let dueDate = item.dueDate else { return baseTitle }
        return "\(baseTitle) - \(upcomingDueText(for: dueDate))"
    }

    private func upcomingDueText(for dueDate: Date) -> String {
        let calendar = Calendar.current
        let hasTime = dueDateHasTime(dueDate)
        if calendar.isDateInToday(dueDate) {
            return hasTime ? "Today \(Self.todoMenuTimeFormatter.string(from: dueDate))" : "Today"
        }
        if calendar.isDateInTomorrow(dueDate) {
            return hasTime ? "Tomorrow \(Self.todoMenuTimeFormatter.string(from: dueDate))" : "Tomorrow"
        }
        return hasTime
            ? Self.todoMenuDateFormatter.string(from: dueDate)
            : Self.todoMenuDateOnlyFormatter.string(from: dueDate)
    }

    private func dueDateHasTime(_ dueDate: Date) -> Bool {
        let components = Calendar.current.dateComponents([.hour, .minute], from: dueDate)
        return (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0
    }

    private static let todoMenuTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return formatter
    }()

    private static let todoMenuDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("d MMM jm")
        return formatter
    }()

    private static let todoMenuDateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter
    }()
}

/// App delegate to manage application lifecycle and notch window
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var isTerminationRequested = false

    /// Must be stored as property to stay alive (services won't work if deallocated)
    private let serviceProvider = ServiceProvider()
    private var didStartLicensedFeatures = false
    private var didStartBackgroundUpdates = false
    private var isRetryingTerminateAfterClosingSheets = false
    private var backgroundMemoryReclaimWorkItem: DispatchWorkItem?
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    private func reclaimIdleMemory() {
        MemoryRecoveryCoordinator.reclaimTransientMemory(forceAllocatorTrim: false)
    }

    private func startMemoryPressureMonitoring() {
        guard memoryPressureSource == nil else { return }

        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: DispatchQueue.global(qos: .utility)
        )
        source.setEventHandler {
            DispatchQueue.main.async {
                MemoryRecoveryCoordinator.reclaimTransientMemory(forceAllocatorTrim: true)
            }
        }
        source.resume()
        memoryPressureSource = source
    }

    private func stopMemoryPressureMonitoring() {
        memoryPressureSource?.setEventHandler {}
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // FIX #123: Force LaunchServices re-registration on first launch
        // macOS Tahoe has a bug where apps with LSUIElement=true fail to launch from Finder/Spotlight/Dock
        // due to stale LaunchServices cache. Running lsregister once after install fixes this.
        Self.registerWithLaunchServicesIfNeeded()
        
        // CRITICAL: Register default preference values BEFORE any @AppStorage is read
        // This ensures UserDefaults returns correct defaults for missing keys (fixes #110)
        UserDefaults.standard.register(defaults: [
            AppPreferenceKey.showInMenuBar: PreferenceDefault.showInMenuBar,
            AppPreferenceKey.showInDock: PreferenceDefault.showInDock,
            AppPreferenceKey.showQuickshareInMenuBar: PreferenceDefault.showQuickshareInMenuBar,
            AppPreferenceKey.todoShowUpcomingInMenuBar: PreferenceDefault.todoShowUpcomingInMenuBar,
            AppPreferenceKey.quickshareRequireUploadConfirmation: PreferenceDefault.quickshareRequireUploadConfirmation,
            AppPreferenceKey.enableNotchShelf: PreferenceDefault.enableNotchShelf,
            AppPreferenceKey.showIdleNotchOnExternalDisplays: PreferenceDefault.showIdleNotchOnExternalDisplays,
            AppPreferenceKey.enableHUDReplacement: PreferenceDefault.enableHUDReplacement,
            AppPreferenceKey.enableVolumeHUDReplacement: PreferenceDefault.enableVolumeHUDReplacement,
            AppPreferenceKey.enableBrightnessHUDReplacement: PreferenceDefault.enableBrightnessHUDReplacement,
            AppPreferenceKey.enableVolumeKeyFeedbackSound: PreferenceDefault.enableVolumeKeyFeedbackSound,
            AppPreferenceKey.enableBetterDisplayCompatibility: PreferenceDefault.enableBetterDisplayCompatibility,
            AppPreferenceKey.showMediaPlayer: PreferenceDefault.showMediaPlayer,
            AppPreferenceKey.enableMediaAlbumArtGlow: PreferenceDefault.enableMediaAlbumArtGlow,
            AppPreferenceKey.enableRealAudioVisualizer: PreferenceDefault.enableRealAudioVisualizer,
            AppPreferenceKey.enableGradientVisualizer: PreferenceDefault.enableGradientVisualizer,
            AppPreferenceKey.enableClipboard: PreferenceDefault.enableClipboard,
            AppPreferenceKey.enableMultiBasket: PreferenceDefault.enableMultiBasket,
            AppPreferenceKey.quickActionsMailApp: PreferenceDefault.quickActionsMailApp,
            AppPreferenceKey.quickActionsCloudProvider: PreferenceDefault.quickActionsCloudProvider,
            AppPreferenceKey.gumroadLicenseActive: PreferenceDefault.gumroadLicenseActive,
            AppPreferenceKey.gumroadLicenseEmail: PreferenceDefault.gumroadLicenseEmail,
            AppPreferenceKey.gumroadLicenseKeyHint: PreferenceDefault.gumroadLicenseKeyHint,
            AppPreferenceKey.gumroadLicenseDeviceName: PreferenceDefault.gumroadLicenseDeviceName,
            AppPreferenceKey.gumroadLicenseLastValidatedAt: PreferenceDefault.gumroadLicenseLastValidatedAt,
            AppPreferenceKey.licenseTrialConsumed: PreferenceDefault.licenseTrialConsumed,
            AppPreferenceKey.licenseTrialStartedAt: PreferenceDefault.licenseTrialStartedAt,
            AppPreferenceKey.licenseTrialExpiresAt: PreferenceDefault.licenseTrialExpiresAt,
            AppPreferenceKey.licenseTrialLastRemoteSyncAt: PreferenceDefault.licenseTrialLastRemoteSyncAt,
            AppPreferenceKey.licenseTrialAccountHash: PreferenceDefault.licenseTrialAccountHash,
            AppPreferenceKey.terminalNotchExternalApp: PreferenceDefault.terminalNotchExternalApp,
            AppPreferenceKey.cameraPreferredDeviceID: PreferenceDefault.cameraPreferredDeviceID,
            AppPreferenceKey.disableAnalytics: PreferenceDefault.disableAnalytics,
            AppPreferenceKey.windowSnapPointerModeEnabled: PreferenceDefault.windowSnapPointerModeEnabled,
            AppPreferenceKey.windowSnapMoveModifierMask: PreferenceDefault.windowSnapMoveModifierMask,
            AppPreferenceKey.windowSnapResizeModifierMask: PreferenceDefault.windowSnapResizeModifierMask,
            AppPreferenceKey.windowSnapBringToFrontWhenHandling: PreferenceDefault.windowSnapBringToFrontWhenHandling,
            AppPreferenceKey.windowSnapResizeMode: PreferenceDefault.windowSnapResizeMode,
        ])
        Self.normalizeVisualizerPreferencesIfNeeded()
        
        
        // Crash detection: Check if last session crashed and offer to report
        CrashReporter.shared.checkForCrashAndPrompt()
        
        // Crash detection: Mark this session as started (will be cleared on clean exit)
        CrashReporter.shared.markSessionStarted()
        
        // MIGRATION (Issue #57): Re-enable menu bar for users who locked themselves out
        // This runs once per user to unlock anyone who disabled the menu bar before this fix
        if !UserDefaults.standard.bool(forKey: "didMigrateMenuBarLockout") {
            UserDefaults.standard.set(true, forKey: "didMigrateMenuBarLockout")
            // If menu bar was hidden, re-enable it to prevent lock-out
            if !UserDefaults.standard.bool(forKey: "showInMenuBar") {
                UserDefaults.standard.set(true, forKey: "showInMenuBar")
                print("🔓 Droppy: Re-enabled menu bar icon (Issue #57 migration)")
            }
        }
        
        // Apply Dock visibility preference (hidden by default).
        AppVisibilityManager.applyDockVisibilityFromPreferences()
        
        // Register Finder Services (right-click menu integration)
        // Note: User must manually enable in System Settings > Keyboard > Keyboard Shortcuts > Services
        NSApp.servicesProvider = serviceProvider
        // Never block launch on services refresh.
        DispatchQueue.global(qos: .utility).async {
            NSUpdateDynamicServices()  // Refresh Services cache so menu items appear in the list
        }
        
        // Register for URL scheme events (droppy://)
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        
        // Touch singletons on main thread to ensure proper @AppStorage / UI initialization
        _ = DroppyState.shared
        DroppyState.shared.restorePinnedFolders()  // Restore pinned folders from previous session
        _ = DragMonitor.shared
        _ = NotchWindowController.shared
        _ = FloatingBasketWindowController.shared
        _ = BasketSwitcherWindowController.shared
        _ = UpdateChecker.shared
        _ = ClipboardManager.shared
        _ = ClipboardWindowController.shared
        _ = ThumbnailCache.shared  // Warmup QuickLook Metal shaders early
        
        // Start analytics (anonymous launch tracking)
        AnalyticsService.shared.logAppLaunch()

        startMemoryPressureMonitoring()
        configureLicenseFlow()
    }

    private func configureLicenseFlow() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLicenseStateDidChange(_:)),
            name: .licenseStateDidChange,
            object: nil
        )

        let licenseManager = LicenseManager.shared
        licenseManager.bootstrap()

        if !licenseManager.requiresLicenseEnforcement || licenseManager.hasAccess {
            startLicensedFeaturesIfNeeded()
            showOnboardingIfNeeded()
        } else {
            stopLicensedFeatures()
            ClipboardManager.shared.stopMonitoring()
            SettingsWindowController.shared.close()
            LicenseWindowController.shared.show(activationMode: .onlyIfAlreadyActive)
        }
    }

    @objc
    private func handleLicenseStateDidChange(_ notification: Notification) {
        let licenseManager = LicenseManager.shared
        guard licenseManager.requiresLicenseEnforcement else { return }

        if licenseManager.hasAccess {
            let licenseWindowWasVisible = LicenseWindowController.shared.isVisible
            startLicensedFeaturesIfNeeded()
            if !licenseWindowWasVisible {
                showOnboardingIfNeeded()
            }
        } else {
            stopLicensedFeatures()
            SettingsWindowController.shared.close()
            DispatchQueue.main.async {
                LicenseWindowController.shared.show(activationMode: .onlyIfAlreadyActive)
            }
        }
    }

    private func startLicensedFeaturesIfNeeded() {
        guard !didStartLicensedFeatures else { return }
        didStartLicensedFeatures = true

        if !didStartBackgroundUpdates {
            didStartBackgroundUpdates = true
            UpdateChecker.shared.startBackgroundChecking()
        }

        // Load Element Capture and Window Snap shortcuts (after all other singletons are ready)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.didStartLicensedFeatures else { return }
            ElementCaptureManager.shared.loadAndStartMonitoring()
            WindowSnapManager.shared.loadAndStartMonitoring()

            // Initialize Voice Transcribe (restores menu bar if it was enabled)
            _ = VoiceTranscribeManager.shared

            // Initialize Menu Bar Manager (restores status items if it was enabled)
            _ = MenuBarManager.shared
        }

        // Start monitoring for drag events (polling-based, safe)
        DragMonitor.shared.startMonitoring()
        if ClipboardManager.shared.isEnabled {
            ClipboardManager.shared.startMonitoring()
        }

        // Setup UI components on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self, self.didStartLicensedFeatures else { return }
            // 1. Notch Window (needed for Shelf, HUD replacement, and Media Player)
            // The notch window is required for any of these features to work
            let enableNotch = UserDefaults.standard.bool(forKey: "enableNotchShelf")
            let notchIsSet = UserDefaults.standard.object(forKey: "enableNotchShelf") != nil
            let notchShelfEnabled = enableNotch || !notchIsSet  // Default true
            let keepIdleNotchVisible = UserDefaults.standard.preference(
                AppPreferenceKey.showIdleNotchOnExternalDisplays,
                default: PreferenceDefault.showIdleNotchOnExternalDisplays
            )

            let hudEnabled = MediaKeyInterceptor.shouldRunForCurrentPreferences()

            let mediaEnabled = UserDefaults.standard.object(forKey: "showMediaPlayer") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "showMediaPlayer")

            // Create notch window if ANY of these features are enabled
            if notchShelfEnabled || keepIdleNotchVisible || hudEnabled || mediaEnabled {
                NotchWindowController.shared.setupNotchWindow()
            }

            // 2. Clipboard Global Shortcut
            // This MUST start even if no windows are visible
            // Default to enabled if key not set
            let clipboardEnabled = UserDefaults.standard.object(forKey: "enableClipboardBeta") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "enableClipboardBeta")
            if clipboardEnabled {
                print("⌨️ Droppy: Starting Global Clipboard Monitor")
                ClipboardWindowController.shared.startMonitoringShortcut()
            }

            // 3. Media Key Interceptor for HUD replacement
            // Start if HUD replacement is enabled to suppress system HUD
            // (hudEnabled already calculated above)
            if MediaKeyInterceptor.shouldRunForCurrentPreferences() {
                print("🎛️ Droppy: Starting Media Key Interceptor for HUD")
                MediaKeyInterceptor.shared.start()
            }

            // 4. AirPods HUD monitoring (Bluetooth connection detection)
            let airPodsEnabled = UserDefaults.standard.object(forKey: "enableAirPodsHUD") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "enableAirPodsHUD")
            if airPodsEnabled {
                print("🎧 Droppy: Starting AirPods Connection Monitor")
                AirPodsManager.shared.startMonitoring()
            }

            // 5. Lock Screen Features
            // Lock HUD: Shows lock/unlock animation in the notch + dedicated SkyLight window on lock screen
            // Uses separate-window architecture — main notch window is NEVER delegated to SkyLight
            let lockScreenHUDEnabled = UserDefaults.standard.preference(
                AppPreferenceKey.enableLockScreenHUD,
                default: PreferenceDefault.enableLockScreenHUD
            )
            if lockScreenHUDEnabled {
                print("🔒 Droppy: Starting Lock Screen HUD")
                LockScreenManager.shared.enable()
            }
            
            // Lock Screen Media Widget: Shows music controls on lock screen (separate feature)
            let lockScreenMediaEnabled = UserDefaults.standard.preference(
                AppPreferenceKey.enableLockScreenMediaWidget,
                default: PreferenceDefault.enableLockScreenMediaWidget
            )
            if lockScreenMediaEnabled {
                print("🔒 Droppy: Initializing Lock Screen Media Widget")
                LockScreenMediaPanelManager.shared.configure(musicManager: MusicManager.shared)
            }

            // 6. Tracked Folders (monitors folders for new files)
            let folderObservationEnabled = UserDefaults.standard.bool(forKey: AppPreferenceKey.enableTrackedFolders)
            if folderObservationEnabled {
                print("📁 Droppy: Starting Tracked Folders Monitor")
                TrackedFoldersManager.shared.startMonitoring()
            }

            // 7. Notification HUD (captures macOS notifications for notch display)
            let notificationHUDInstalled = UserDefaults.standard.bool(forKey: AppPreferenceKey.notificationHUDInstalled)
            let notificationHUDEnabled = !ExtensionType.notificationHUD.isRemoved
            if notificationHUDInstalled && notificationHUDEnabled {
                print("🔔 Droppy: Starting Notification HUD Monitor")
                NotificationHUDManager.shared.startMonitoring()
            }

            // 8. Hide Physical Notch (black bar to hide the notch cutout)
            let hidePhysicalNotchEnabled = UserDefaults.standard.bool(forKey: AppPreferenceKey.hidePhysicalNotch)
            if hidePhysicalNotchEnabled {
                print("⬛ Droppy: Enabling Hide Physical Notch")
                HideNotchManager.shared.enable()
            }

            // 6. AUTO-PROMPT FOR PERMISSIONS
            // If any accessibility-dependent feature is enabled but permission not granted, prompt
            let needsAccessibility = MediaKeyInterceptor.shouldRunForCurrentPreferences() || clipboardEnabled
            let axTrusted = AXIsProcessTrusted()
            let cacheValue = UserDefaults.standard.bool(forKey: "accessibilityGranted")
            let isGranted = PermissionManager.shared.isAccessibilityGranted

            print("🔐 DEBUG: needsAccessibility=\(needsAccessibility) hudEnabled=\(hudEnabled) clipboardEnabled=\(clipboardEnabled)")
            print("🔐 DEBUG: AXIsProcessTrusted()=\(axTrusted) cache=\(cacheValue) isGranted=\(isGranted)")

            if needsAccessibility && !isGranted {
                print("🔐 Droppy: Accessibility needed for enabled features - prompting…")
                PermissionManager.shared.requestAccessibility(context: .automatic)
            } else {
                print("🔐 DEBUG: NOT prompting - needsAccessibility=\(needsAccessibility) isGranted=\(isGranted)")
            }
        }
    }

    private func stopLicensedFeatures() {
        guard didStartLicensedFeatures else { return }
        didStartLicensedFeatures = false

        DragMonitor.shared.stopMonitoring()
        AirPodsManager.shared.stopMonitoring()
        TrackedFoldersManager.shared.stopMonitoring()
        NotificationHUDManager.shared.stopMonitoring()
        ClipboardManager.shared.stopMonitoring()
        ClipboardWindowController.shared.stopMonitoringShortcut()
        MediaKeyInterceptor.shared.stop()
        VoiceTranscribeManager.shared.stopGlobalKeyMonitoring()
        MenuBarManager.shared.disable()
        ElementCaptureManager.shared.stopMonitoringAllShortcuts()
        WindowSnapManager.shared.stopMonitoringAllShortcuts()
        HideNotchManager.shared.disable()
        NotchWindowController.shared.closeWindow()
    }

    private func showOnboardingIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: AppPreferenceKey.hasCompletedOnboarding) else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            OnboardingWindowController.shared.show(activationMode: .onlyIfAlreadyActive)
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        backgroundMemoryReclaimWorkItem?.cancel()
        backgroundMemoryReclaimWorkItem = nil

        let licenseManager = LicenseManager.shared
        if licenseManager.requiresLicenseEnforcement && !licenseManager.hasAccess {
            LicenseWindowController.shared.show()
            return
        }

        showOnboardingIfNeeded()

        // Poll only when accessibility is still missing.
        // Avoid restarting a 20s polling timer on every app activation.
        if !PermissionManager.shared.isAccessibilityGranted {
            PermissionManager.shared.startPollingForAccessibility()
        }
    }

    func applicationDidResignActive(_ notification: Notification) {
        backgroundMemoryReclaimWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !FloatingBasketWindowController.isAnyBasketVisible else { return }
            guard !DroppyState.shared.isFileOperationInProgress,
                  !DroppyState.shared.isSharingInProgress else { return }
            self.reclaimIdleMemory()
        }

        backgroundMemoryReclaimWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: work)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        stopMemoryPressureMonitoring()
        backgroundMemoryReclaimWorkItem?.cancel()
        backgroundMemoryReclaimWorkItem = nil

        // Mark clean exit (no crash prompt on next launch)
        CrashReporter.shared.markCleanExit()
        
        // Stop drag monitoring
        DragMonitor.shared.stopMonitoring()
        
        // Stop AirPods monitoring
        AirPodsManager.shared.stopMonitoring()
        
        // Close notch window
        NotchWindowController.shared.closeWindow()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isRetryingTerminateAfterClosingSheets {
            isRetryingTerminateAfterClosingSheets = false
            Self.isTerminationRequested = true
            return .terminateNow
        }

        let visibleAttachedSheets = sender.windows.compactMap { $0.attachedSheet }.filter { $0.isVisible }
        guard !visibleAttachedSheets.isEmpty else {
            Self.isTerminationRequested = true
            return .terminateNow
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Close open dialog and quit Droppy?"
        alert.informativeText = "Droppy can't quit while this dialog is open."
        alert.addButton(withTitle: "Close and Quit")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            Self.isTerminationRequested = false
            return .terminateCancel
        }

        for sheet in visibleAttachedSheets {
            if let parent = sheet.sheetParent {
                parent.endSheet(sheet, returnCode: .cancel)
            } else {
                sheet.close()
            }
        }

        isRetryingTerminateAfterClosingSheets = true
        Self.isTerminationRequested = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            sender.terminate(nil)
        }

        return .terminateCancel
    }
    
    // Prevent app from closing when the settings window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // MARK: - URL Scheme Handling
    
    /// Handles incoming droppy:// URL events from Alfred and other apps
    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            print("⚠️ AppDelegate: Failed to parse URL from event")
            return
        }
        
        // Route to URLSchemeHandler
        URLSchemeHandler.handle(url)
    }
    
    // MARK: - LaunchServices Registration (Fix #123)

    /// Keep visualizer preferences in a valid single-selection state.
    /// Issue #210: exactly one mode must stay enabled at all times.
    private static func normalizeVisualizerPreferencesIfNeeded() {
        let defaults = UserDefaults.standard
        let realAudioEnabled = defaults.preference(
            AppPreferenceKey.enableRealAudioVisualizer,
            default: PreferenceDefault.enableRealAudioVisualizer
        )
        let gradientEnabled = defaults.preference(
            AppPreferenceKey.enableGradientVisualizer,
            default: PreferenceDefault.enableGradientVisualizer
        )

        if realAudioEnabled && gradientEnabled {
            defaults.set(false, forKey: AppPreferenceKey.enableGradientVisualizer)
        } else if !realAudioEnabled && !gradientEnabled {
            defaults.set(true, forKey: AppPreferenceKey.enableGradientVisualizer)
        }
    }
    
    /// Key for tracking if LaunchServices registration has been performed
    private static let launchServicesRegisteredKey = "didRegisterWithLaunchServices"
    
    /// Forces LaunchServices to re-register the app bundle on first launch.
    /// This fixes macOS Tahoe bug where apps with LSUIElement=true fail to launch
    /// from Finder/Spotlight/Dock due to stale/corrupted LaunchServices cache.
    private static func registerWithLaunchServicesIfNeeded() {
        // Only run once per installation
        guard !UserDefaults.standard.bool(forKey: launchServicesRegisteredKey) else {
            return
        }
        let registeredKey = launchServicesRegisteredKey
        
        // The lsregister tool is in the CoreServices framework
        let lsregisterPath = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        
        // Run lsregister asynchronously so app launch can never block on this system tool.
        DispatchQueue.global(qos: .utility).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: lsregisterPath)
            task.arguments = ["-f", Bundle.main.bundlePath]

            let finished = DispatchSemaphore(value: 0)
            task.terminationHandler = { _ in
                finished.signal()
            }

            do {
                try task.run()
            } catch {
                print("⚠️ LaunchServices: Failed to run lsregister - \(error.localizedDescription)")
                return
            }

            // Guard against lsregister hanging on some systems.
            let timeoutResult = finished.wait(timeout: .now() + 5)
            if timeoutResult == .timedOut {
                task.terminate()
                print("⚠️ LaunchServices: lsregister timed out after 5s; skipping to avoid launch stalls")
                return
            }

            if task.terminationStatus == 0 {
                print("✅ LaunchServices: Successfully registered Droppy with LaunchServices (Fix #123)")
                UserDefaults.standard.set(true, forKey: registeredKey)
            } else {
                print("⚠️ LaunchServices: lsregister exited with status \(task.terminationStatus)")
            }
        }
    }
}
