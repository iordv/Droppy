//
//  NotificationHUDManager.swift
//  Droppy
//
//  Manages notification capture and display in the notch
//  Uses macOS notification database (requires Full Disk Access)
//

import SwiftUI
import SQLite3
import Observation

/// Represents a captured macOS notification
struct CapturedNotification: Identifiable, Equatable {
    let id: UUID = UUID()
    let appBundleID: String
    let appName: String
    let title: String?
    let subtitle: String?
    let body: String?
    let timestamp: Date
    var appIcon: NSImage?
    
    /// Display title: prefer sender name for messages, fall back to title/app
    var displayTitle: String {
        title ?? appName
    }
    
    /// Display subtitle: for messages, show the actual title; otherwise nil
    var displaySubtitle: String? {
        if title != nil && subtitle != nil {
            return subtitle
        }
        return nil
    }
    
    static func == (lhs: CapturedNotification, rhs: CapturedNotification) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manager for capturing and displaying macOS notifications
/// Polls the notification center database on a background thread
@Observable
final class NotificationHUDManager {
    static let shared = NotificationHUDManager()
    
    // MARK: - Published State
    
    @ObservationIgnored
    @AppStorage(AppPreferenceKey.notificationHUDInstalled) var isInstalled = PreferenceDefault.notificationHUDInstalled
    @ObservationIgnored
    @AppStorage(AppPreferenceKey.notificationHUDEnabled) var isEnabled = PreferenceDefault.notificationHUDEnabled
    @ObservationIgnored
    @AppStorage(AppPreferenceKey.notificationHUDSoundEnabled) var isSoundEnabled = PreferenceDefault.notificationHUDSoundEnabled
    @ObservationIgnored
    @AppStorage(AppPreferenceKey.notificationHUDHapticEnabled) var isHapticsEnabled = PreferenceDefault.notificationHUDHapticEnabled
    @ObservationIgnored
    @AppStorage(AppPreferenceKey.notificationHUDSoundName) var soundName = PreferenceDefault.notificationHUDSoundName
    @ObservationIgnored
    @AppStorage(AppPreferenceKey.notificationHUDShowPreview) var showPreview = PreferenceDefault.notificationHUDShowPreview
    
    private(set) var currentNotification: CapturedNotification?
    private(set) var notificationQueue: [CapturedNotification] = []
    var isExpanded: Bool = false
    private(set) var hasFullDiskAccess: Bool = false
    
    var queueCount: Int { notificationQueue.count }
    
    // Track apps that have sent notifications (bundleID -> (name, icon))
    private(set) var seenApps: [String: (name: String, icon: NSImage?)] = [:]
    
    // MARK: - Private State

    private var pollingTimer: Timer?
    private var lastProcessedRecordID: Int64 = 0
    private var dbConnection: OpaquePointer?
    private let pollingInterval: TimeInterval = 2.0  // Backup polling (file watcher is primary)
    private var dismissWorkItem: DispatchWorkItem?

    // File system monitoring for instant notification detection
    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var walMonitorSource: DispatchSourceFileSystemObject?  // WAL file monitor
    private var fileDescriptor: Int32 = -1
    private var walFileDescriptor: Int32 = -1
    private var fileChangeDebounceWorkItem: DispatchWorkItem?
    private let fileChangeDebounceInterval: TimeInterval = 0.01  // 10ms debounce (optimized for speed)
    
    // Darwin notification observer for instant notification pre-triggering
    // This fires faster than file system events in some cases
    private var darwinNotificationObserver: NSObjectProtocol?

    // App bundle IDs to ignore (Droppy itself, system apps, etc.)
    private let ignoredBundleIDs: Set<String> = [
        "app.getdroppy.Droppy",
        "com.apple.finder"
    ]
    
    private init() {
        // Check FDA on init
        recheckAccess()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Lifecycle
    
    func startMonitoring() {
        guard isInstalled else { return }
        guard pollingTimer == nil else { return }

        recheckAccess()

        guard hasFullDiskAccess else {
            print("NotificationHUD: Cannot start - Full Disk Access not granted")
            return
        }

        // Connect to database
        guard connectToDatabase() else {
            print("NotificationHUD: Failed to connect to notification database")
            return
        }

        // Set initial record ID to avoid processing old notifications
        lastProcessedRecordID = getLatestRecordID()
        print("NotificationHUD: Initial record ID set to \(lastProcessedRecordID)")

        // PRIMARY: Start file system monitoring for instant notification detection
        startFileMonitoring()
        
        // ACCELERATOR: Darwin notification observer (fires faster than file events in some cases)
        startDarwinObserver()

        // BACKUP: Slow polling timer as fallback (in case file monitoring misses something)
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .utility).async {
                self?.pollForNewNotifications()
            }
        }

        print("NotificationHUD: Started monitoring (Darwin + file watcher + backup polling)")
    }

    /// Start monitoring the notification database file for changes
    /// This provides near-instant notification detection
    private func startFileMonitoring() {
        // Guard against double-start (prevents file descriptor leaks)
        guard fileMonitorSource == nil else {
            print("NotificationHUD: File monitoring already active")
            return
        }
        
        let dbPath = Self.notificationDatabasePath
        let walPath = dbPath + "-wal"  // SQLite Write-Ahead Log file

        // Handler for file changes (shared between db and WAL monitors)
        let handleFileChange: () -> Void = { [weak self] in
            guard let self = self else { return }

            // Debounce rapid file changes (database may be written multiple times per notification)
            self.fileChangeDebounceWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.pollForNewNotifications()
            }
            self.fileChangeDebounceWorkItem = workItem
            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + self.fileChangeDebounceInterval,
                execute: workItem
            )
        }

        // Monitor main database file
        fileDescriptor = open(dbPath, O_EVTONLY)
        if fileDescriptor >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: [.write, .extend, .attrib],
                queue: DispatchQueue.global(qos: .userInitiated)
            )
            source.setEventHandler(handler: handleFileChange)
            source.setCancelHandler { [weak self] in
                if let fd = self?.fileDescriptor, fd >= 0 {
                    close(fd)
                    self?.fileDescriptor = -1
                }
            }
            source.resume()
            fileMonitorSource = source
            print("NotificationHUD: ✅ Database file monitoring started")
        } else {
            print("NotificationHUD: ⚠️ Could not open database file for monitoring")
        }

        // Monitor WAL file (SQLite often writes here first for better performance)
        walFileDescriptor = open(walPath, O_EVTONLY)
        if walFileDescriptor >= 0 {
            let walSource = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: walFileDescriptor,
                eventMask: [.write, .extend, .attrib],
                queue: DispatchQueue.global(qos: .userInitiated)
            )
            walSource.setEventHandler(handler: handleFileChange)
            walSource.setCancelHandler { [weak self] in
                if let fd = self?.walFileDescriptor, fd >= 0 {
                    close(fd)
                    self?.walFileDescriptor = -1
                }
            }
            walSource.resume()
            walMonitorSource = walSource
            print("NotificationHUD: ✅ WAL file monitoring started (faster detection)")
        } else {
            print("NotificationHUD: ℹ️ WAL file not found (normal if not in WAL mode)")
        }
    }

    /// Stop file system monitoring
    private func stopFileMonitoring() {
        fileMonitorSource?.cancel()
        fileMonitorSource = nil
        walMonitorSource?.cancel()
        walMonitorSource = nil
        fileChangeDebounceWorkItem?.cancel()
        fileChangeDebounceWorkItem = nil
        // File descriptors are closed in the cancel handlers
    }
    
    // MARK: - Darwin Notification Observer (Pre-Trigger Accelerator)
    
    /// Start observing Darwin notifications for faster notification pre-triggering
    /// These low-level system notifications can fire slightly faster than file system events
    /// Privacy: No new permissions required - these are public system event signals (no payload data)
    private func startDarwinObserver() {
        // Guard against double-start
        guard darwinNotificationObserver == nil else { return }
        
        // Listen for notification center UI changes
        // This Darwin notification fires when the notification center UI updates
        let notificationName = "com.apple.notificationcenterui.bulletin_added" as CFString
        
        // Use CFNotificationCenter for Darwin notifications
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { (_, observer, name, _, _) in
                // Callback when Darwin notification fires
                guard let observer = observer else { return }
                let manager = Unmanaged<NotificationHUDManager>.fromOpaque(observer).takeUnretainedValue()
                
                // Immediately poll database (bypass debounce for speed)
                DispatchQueue.global(qos: .userInitiated).async {
                    manager.pollForNewNotifications()
                }
            },
            notificationName,
            nil,
            .deliverImmediately
        )
        
        print("NotificationHUD: ✅ Darwin notification observer started")
    }
    
    /// Stop Darwin notification observer
    private func stopDarwinObserver() {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
        darwinNotificationObserver = nil
        print("NotificationHUD: Darwin notification observer stopped")
    }
    
    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        stopFileMonitoring()  // Stop file system monitoring
        stopDarwinObserver()  // Stop Darwin notification observer
        closeDatabase()

        DispatchQueue.main.async { [weak self] in
            self?.currentNotification = nil
            self?.notificationQueue.removeAll()
        }
        
        print("NotificationHUD: Stopped monitoring")
    }
    
    // MARK: - Permission Management
    
    func recheckAccess() {
        let testPath = Self.notificationDatabasePath
        hasFullDiskAccess = FileManager.default.isReadableFile(atPath: testPath)
    }
    
    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Database Access
    
    private static var notificationDatabasePath: String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        // Try multiple known locations (varies by macOS version)
        let potentialPaths = [
            // macOS Sequoia/Tahoe (15+/26+): Group Containers
            homeDir.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db").path,
            homeDir.appendingPathComponent("Library/Group Containers/group.com.apple.UserNotifications/db2/db").path,
            homeDir.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db/db").path,
            homeDir.appendingPathComponent("Library/Group Containers/group.com.apple.UserNotifications/db/db").path,
            // Legacy path (older macOS versions)
            homeDir.appendingPathComponent("Library/Application Support/NotificationCenter/db2/db").path
        ]
        
        // Return first existing path
        for path in potentialPaths {
            if FileManager.default.fileExists(atPath: path) {
                print("NotificationHUD: Using database at \(path)")
                return path
            }
        }
        
        // Fallback to first path (will fail with clear error)
        print("NotificationHUD: No database found, tried: \(potentialPaths)")
        return potentialPaths[0]
    }
    
    private func connectToDatabase() -> Bool {
        let path = Self.notificationDatabasePath
        
        guard FileManager.default.fileExists(atPath: path) else {
            print("NotificationHUD: Database not found at \(path)")
            return false
        }
        
        let result = sqlite3_open_v2(path, &dbConnection, SQLITE_OPEN_READONLY, nil)
        if result != SQLITE_OK {
            print("NotificationHUD: Failed to open database: \(result)")
            return false
        }
        
        return true
    }
    
    private func closeDatabase() {
        if let db = dbConnection {
            sqlite3_close(db)
            dbConnection = nil
        }
    }
    
    private func getLatestRecordID() -> Int64 {
        guard let db = dbConnection else { return 0 }
        
        let query = "SELECT MAX(rec_id) FROM record"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return 0
        }
        
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            return sqlite3_column_int64(statement, 0)
        }
        
        return 0
    }
    
    private func pollForNewNotifications() {
        guard let db = dbConnection else { return }
        
        // Query for new notifications since last check
        let query = """
            SELECT r.rec_id, r.app_id, r.data, r.delivered_date
            FROM record r
            JOIN app a ON r.app_id = a.app_id
            WHERE r.rec_id > ?
            ORDER BY r.rec_id ASC
            LIMIT 10
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int64(statement, 1, lastProcessedRecordID)
        
        var newNotifications: [CapturedNotification] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let recID = sqlite3_column_int64(statement, 0)
            lastProcessedRecordID = max(lastProcessedRecordID, recID)
            
            // Get app bundle ID from app table
            let appID = sqlite3_column_int(statement, 1)
            guard let bundleID = getBundleID(for: appID) else { continue }
            
            // Skip ignored apps
            if ignoredBundleIDs.contains(bundleID) { continue }
            
            // Parse notification data (plist blob)
            guard let dataBlob = sqlite3_column_blob(statement, 2) else { continue }
            let dataLength = sqlite3_column_bytes(statement, 2)
            let data = Data(bytes: dataBlob, count: Int(dataLength))
            
            // Parse plist
            guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                continue
            }
            
            // Tahoe: notification content is inside 'req' dictionary
            // Try 'req' first (macOS Tahoe), then fall back to root (older macOS)
            var title: String?
            var subtitle: String?
            var body: String?
            
            if let req = plist["req"] as? [String: Any] {
                // macOS Tahoe format
                title = req["titl"] as? String
                subtitle = req["subt"] as? String
                body = req["body"] as? String
            } else {
                // Pre-Tahoe format (keys at root level)
                title = plist["titl"] as? String
                subtitle = plist["subt"] as? String
                body = plist["body"] as? String
            }
            
            // Also check aps (Apple Push format)
            if title == nil, let aps = plist["aps"] as? [String: Any] {
                if let alert = aps["alert"] as? [String: Any] {
                    title = alert["title"] as? String
                    subtitle = alert["subtitle"] as? String
                    body = alert["body"] as? String
                } else if let alertString = aps["alert"] as? String {
                    body = alertString
                }
            }
            
            // Debug: Log extracted content
            print("NotificationHUD: Notification from \(bundleID) - title: \(title ?? "nil"), subtitle: \(subtitle ?? "nil"), body: \(body ?? "nil")")
            
            // Get app name and icon
            let appName = getAppName(for: bundleID) ?? bundleID.components(separatedBy: ".").last ?? bundleID
            let appIcon = getAppIcon(for: bundleID)
            
            // Get timestamp
            let timestamp = Date() // Use current time since delivered_date format varies
            
            let notification = CapturedNotification(
                appBundleID: bundleID,
                appName: appName,
                title: title,
                subtitle: subtitle,
                body: body,
                timestamp: timestamp,
                appIcon: appIcon
            )
            
            // Track this app as having sent notifications
            if seenApps[bundleID] == nil {
                seenApps[bundleID] = (name: appName, icon: appIcon)
            }
            
            newNotifications.append(notification)
        }
        
        // Update UI on main thread
        if !newNotifications.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.processNewNotifications(newNotifications)
            }
        }
    }
    
    private func getBundleID(for appID: Int32) -> String? {
        guard let db = dbConnection else { return nil }
        
        let query = "SELECT identifier FROM app WHERE app_id = ?"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int(statement, 1, appID)
        
        if sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                return String(cString: cString)
            }
        }
        
        return nil
    }
    
    private func getAppName(for bundleID: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return FileManager.default.displayName(atPath: url.path)
    }
    
    private func getAppIcon(for bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    
    // MARK: - Debug Logging

    /// Debug flag for notification HUD troubleshooting
    /// Set via UserDefaults: defaults write app.getdroppy.Droppy DEBUG_NOTIFICATION_HUD -bool true
    private var isDebugEnabled: Bool {
        UserDefaults.standard.bool(forKey: "DEBUG_NOTIFICATION_HUD")
    }

    private func debugLog(_ message: String) {
        if isDebugEnabled {
            print("🔔 NotificationHUD: \(message)")
        }
    }

    // MARK: - Notification Processing

    private func processNewNotifications(_ notifications: [CapturedNotification]) {
        // Respect the "Notify me!" toggle in HUDs settings
        guard isEnabled else {
            debugLog("Skipping \(notifications.count) notification(s) - extension disabled")
            return
        }

        // Respect Focus mode / DND - don't show notifications when Focus is active
        guard !DNDManager.shared.isDNDActive else {
            debugLog("Skipping \(notifications.count) notification(s) - DND/Focus active")
            return
        }

        debugLog("Processing \(notifications.count) new notification(s), current queue: \(notificationQueue.count)")

        for notification in notifications {
            if currentNotification == nil && !HUDManager.shared.isVisible {
                // Show immediately - no other HUD is active
                debugLog("Showing notification from \(notification.appName) immediately")
                currentNotification = notification
                scheduleAutoDismiss()
                HUDManager.shared.show(.notification)
                triggerFeedback()  // Sound + haptic synced with HUD appearance
            } else if currentNotification == nil && HUDManager.shared.isVisible {
                // Another HUD type is active - queue this notification
                // It will be shown when HUDManager processes its queue
                debugLog("Queueing notification from \(notification.appName) - another HUD type active")
                notificationQueue.append(notification)
            } else {
                // We have a current notification - add to queue
                debugLog("Queueing notification from \(notification.appName) - already showing \(currentNotification?.appName ?? "unknown")")
                notificationQueue.append(notification)
            }
        }
    }

    private func scheduleAutoDismiss() {
        dismissWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.dismissCurrentOnly()
        }
        dismissWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
    }

    func dismissCurrentOnly() {
        debugLog("Dismissing current notification, queue count: \(notificationQueue.count)")

        // CRITICAL FIX: Check for next notification BEFORE dismissing
        // This prevents a race condition where the view observes nil state briefly
        let nextNotification = notificationQueue.isEmpty ? nil : notificationQueue.removeFirst()

        if let next = nextNotification {
            // We have another notification to show - transition smoothly
            debugLog("Transitioning to next notification from \(next.appName)")

            // Dismiss current HUD
            HUDManager.shared.dismiss()

            // CRITICAL: Delay showing next to allow dismiss animation to complete
            // This prevents animation conflicts and ensures clean state transitions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self = self else { return }
                self.currentNotification = next
                self.scheduleAutoDismiss()
                HUDManager.shared.show(.notification)
                self.triggerFeedback()  // Sound + haptic synced with HUD appearance
                self.debugLog("Now showing notification from \(next.appName)")
            }
        } else {
            // No more notifications - clean dismiss
            debugLog("No more notifications in queue, dismissing completely")
            currentNotification = nil
            HUDManager.shared.dismiss()
        }
    }

    func dismissAll() {
        debugLog("Dismissing all notifications")
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        currentNotification = nil
        notificationQueue.removeAll()
        HUDManager.shared.dismiss()
    }

    // MARK: - App Activation (Called from event monitor for reliable click handling)

    /// Opens the source app for the current notification
    /// This is called from the local event monitor to bypass SwiftUI gesture issues on NSPanel
    func openCurrentNotificationApp() {
        guard let notification = currentNotification else {
            print("🔔 NotificationHUDManager: No current notification to open")
            return
        }

        let bundleID = notification.appBundleID
        print("🔔 NotificationHUDManager: Opening app for bundle ID: \(bundleID)")

        // Strategy: NSRunningApplication first (fast), then open -b (reliable)

        // Step 1: Try NSRunningApplication for immediate activation
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if let app = runningApps.first {
            if app.isHidden {
                app.unhide()
            }
            app.activate()
            print("🔔 NotificationHUDManager: Activated via NSRunningApplication")
        }

        // Step 2: ALWAYS use `open -b` as the reliable method
        DispatchQueue.global(qos: .userInteractive).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-b", bundleID]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()
                DispatchQueue.main.async {
                    print("🔔 NotificationHUDManager: ✅ open -b succeeded for \(bundleID)")
                }
            } catch {
                DispatchQueue.main.async {
                    print("🔔 NotificationHUDManager: ⚠️ open -b failed: \(error)")
                }
            }
        }

        // Dismiss the notification after opening
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.dismissCurrentOnly()
        }
    }

    
    // MARK: - Feedback
    
    private func triggerFeedback() {
        // Sound
        if isSoundEnabled {
            playNotificationSound()
        }
        
        // Haptics
        if isHapticsEnabled {
            triggerHaptic()
        }
    }
    
    private func playNotificationSound() {
        // Use custom/selected sound, or fallback to "Pop"
        let soundToPlay = soundName
        if let sound = NSSound(named: soundToPlay) {
            sound.play()
        } else if let defaultSound = NSSound(named: "Pop") {
            // Fallback if custom sound fails
            defaultSound.play()
        }
    }
    
    private func triggerHaptic() {
        // Subtle haptic feedback pattern
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .default
        )
    }
}

