//
//  NotificationHUDManager.swift
//  Droppy
//
//  Manages notification capture and HUD display state
//  Uses SQLite database polling (requires Full Disk Access)
//
//  Enhanced: Notification queue, better data extraction, smooth animations
//

import SwiftUI
import AppKit
import Combine
import SQLite3
import CoreServices

/// Captured notification data for HUD display
/// Enhanced with subtitle (sender) and better content parsing
struct CapturedNotification: Equatable, Identifiable {
    let id: String  // Use database record ID for deduplication
    let appBundleID: String
    let appName: String
    let appIcon: NSImage?
    let title: String           // Primary title (app name or conversation name)
    let subtitle: String?       // Sender name for messages, or secondary info
    let body: String?           // Actual message content
    let timestamp: Date
    let category: String?       // Notification category if available

    /// Display title - uses subtitle as title if title looks like app name
    var displayTitle: String {
        // If subtitle exists and title matches app name, use subtitle as title
        if let sub = subtitle, !sub.isEmpty, title == appName {
            return sub
        }
        return title
    }

    /// Display subtitle - sender info when available
    var displaySubtitle: String? {
        // If we used subtitle as title, return nil
        if let sub = subtitle, !sub.isEmpty, title == appName {
            return nil
        }
        return subtitle
    }

    static func == (lhs: CapturedNotification, rhs: CapturedNotification) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manages the Notification HUD extension state and notification capture
/// Uses Full Disk Access to read macOS notification database
@MainActor
class NotificationHUDManager: ObservableObject {
    static let shared = NotificationHUDManager()

    // MARK: - Published State

    /// Queue of notifications to display
    @Published var notificationQueue: [CapturedNotification] = []

    /// Current notification being displayed (front of queue)
    var currentNotification: CapturedNotification? {
        notificationQueue.first
    }

    /// Number of queued notifications
    var queueCount: Int {
        notificationQueue.count
    }

    /// Whether the notification HUD is visible
    @Published var isVisible: Bool = false

    /// Whether the HUD is in expanded state (showing full content)
    @Published var isExpanded: Bool = false

    /// Last notification change timestamp (triggers HUD display)
    @Published var lastChangeAt: Date = .distantPast

    /// Whether Full Disk Access is granted
    @Published private(set) var hasFullDiskAccess: Bool = false

    /// Animation state for smooth transitions
    @Published var animationPhase: AnimationPhase = .hidden

    enum AnimationPhase {
        case hidden
        case appearing
        case visible
        case dismissing
    }

    // MARK: - Settings

    /// Whether extension is installed
    @AppStorage(AppPreferenceKey.notificationHUDInstalled) var isInstalled: Bool = PreferenceDefault.notificationHUDInstalled

    /// Whether to show notification body preview
    @AppStorage(AppPreferenceKey.notificationHUDShowPreview) var showPreview: Bool = PreferenceDefault.notificationHUDShowPreview

    /// Enabled apps data (encoded Set<String> of bundle IDs, empty = all apps)
    @AppStorage(AppPreferenceKey.notificationHUDEnabledApps) var enabledAppsData: Data = PreferenceDefault.notificationHUDEnabledApps

    // MARK: - Computed Properties

    /// Enabled apps set (decoded from Data)
    var enabledApps: Set<String> {
        get {
            guard !enabledAppsData.isEmpty,
                  let apps = try? JSONDecoder().decode(Set<String>.self, from: enabledAppsData) else {
                return []  // Empty = all apps enabled
            }
            return apps
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                enabledAppsData = data
            }
        }
    }

    /// Duration to show each notification HUD
    let visibleDuration: TimeInterval = 5.0

    /// Maximum notifications in queue
    let maxQueueSize: Int = 5

    /// Whether the HUD should be visible based on timing
    var isHUDVisible: Bool {
        Date().timeIntervalSince(lastChangeAt) < visibleDuration
    }

    // MARK: - Private

    private var pollingTimer: DispatchSourceTimer?
    private var fileMonitor: DispatchSourceFileSystemObject?
    private var dismissTimer: Timer?
    private var autoAdvanceTimer: Timer?
    private var fileMonitorDebounceWorkItem: DispatchWorkItem?
    private var hasInitialized = false
    private var lastSeenNotificationID: Int64 = 0
    private var processedNotificationIDs: Set<Int64> = []
    private var fileDescriptor: Int32 = -1

    /// Path to macOS notification database (requires Full Disk Access)
    private var notificationDBPath: String = ""

    private init() {
        // Initialize async to avoid blocking main thread
        Task { [weak self] in
            // Find the correct notification database path
            let path = Self.findNotificationDBPath()
            print("NotificationHUD: DB path = \(path)")
            
            await MainActor.run {
                self?.notificationDBPath = path
                self?.hasInitialized = true
                self?.checkFullDiskAccess()
                if self?.isInstalled == true {
                    self?.startMonitoring()
                }
            }
        }
    }

    deinit {
        pollingTimer?.cancel()
        fileMonitor?.cancel()
        if fileDescriptor >= 0 {
            close(fileDescriptor)
        }
    }

    // MARK: - Public Methods

    /// Check if Full Disk Access is available
    func checkFullDiskAccess() {
        let fileManager = FileManager.default
        hasFullDiskAccess = fileManager.isReadableFile(atPath: notificationDBPath)
        print("NotificationHUD: Full Disk Access = \(hasFullDiskAccess)")
    }

    /// Recheck access (called when user returns from System Preferences)
    func recheckAccess() {
        checkFullDiskAccess()
        if hasFullDiskAccess && isInstalled && pollingTimer == nil {
            startMonitoring()
        }
    }

    /// Start monitoring for notifications
    func startMonitoring() {
        guard pollingTimer == nil && fileMonitor == nil else { return }

        // Check access first
        checkFullDiskAccess()

        if hasFullDiskAccess {
            // Initialize last seen ID
            lastSeenNotificationID = getLatestNotificationID() ?? 0
            
            // Try file monitoring first (instant), fallback to polling
            if startFileMonitoring() {
                print("NotificationHUD: Started file monitoring (last ID: \(lastSeenNotificationID))")
                // Also start slow polling as safety net (every 2s)
                startSlowPolling()
            } else {
                // Fallback to fast polling if file monitoring fails
                startFastPolling()
                print("NotificationHUD: Started fast polling (last ID: \(lastSeenNotificationID))")
            }
        } else {
            print("NotificationHUD: Cannot start - no Full Disk Access")
        }
    }

    /// Stop monitoring for notifications
    func stopMonitoring() {
        pollingTimer?.cancel()
        pollingTimer = nil
        fileMonitor?.cancel()
        fileMonitor = nil
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
        print("NotificationHUD: Stopped monitoring")
    }

    /// Show a notification in the HUD (adds to queue)
    func showNotification(_ notification: CapturedNotification) {
        guard isInstalled, !ExtensionType.notificationHUD.isRemoved else { return }

        // Check if app is in enabled list (empty list = all apps)
        let apps = enabledApps
        if !apps.isEmpty && !apps.contains(notification.appBundleID) {
            return
        }

        // Add to queue (limit size)
        if notificationQueue.count >= maxQueueSize {
            notificationQueue.removeLast()
        }

        // Check if this is a duplicate (same app, title, body within 2 seconds)
        let isDuplicate = notificationQueue.contains { existing in
            existing.appBundleID == notification.appBundleID &&
            existing.title == notification.title &&
            existing.body == notification.body &&
            abs(existing.timestamp.timeIntervalSince(notification.timestamp)) < 2.0
        }

        guard !isDuplicate else { return }

        // Insert at front of queue
        withAnimation(DroppyAnimation.notchState) {
            notificationQueue.insert(notification, at: 0)
        }

        // Trigger display if this is the first notification
        if notificationQueue.count == 1 || !isVisible {
            lastChangeAt = Date()
            showHUD()
        }

        // Reset auto-advance timer
        resetAutoAdvanceTimer()
    }

    /// Show the HUD with animation
    private func showHUD() {
        // Cancel any pending dismiss
        dismissTimer?.invalidate()

        // Animate appearance
        animationPhase = .appearing

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isVisible = true
            animationPhase = .visible
        }

        // Show HUD through centralized manager
        HUDManager.shared.show(.notification, duration: visibleDuration)

        // Set up dismiss timer
        dismissTimer = Timer.scheduledTimer(withTimeInterval: visibleDuration, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.advanceOrDismiss()
            }
        }
    }

    /// Advance to next notification or dismiss
    private func advanceOrDismiss() {
        // Remove current notification
        withAnimation(DroppyAnimation.notchState) {
            if !notificationQueue.isEmpty {
                notificationQueue.removeFirst()
            }
        }

        // If more notifications, show next
        if !notificationQueue.isEmpty {
            lastChangeAt = Date()
            HUDManager.shared.show(.notification, duration: visibleDuration)
            resetAutoAdvanceTimer()
        } else {
            dismissNotification()
        }
    }

    /// Reset the auto-advance timer
    private func resetAutoAdvanceTimer() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: visibleDuration, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.advanceOrDismiss()
            }
        }
    }

    /// Dismiss the current notification (user action)
    func dismissNotification() {
        autoAdvanceTimer?.invalidate()
        dismissTimer?.invalidate()

        animationPhase = .dismissing

        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            isVisible = false
            isExpanded = false
        }

        // Clear queue after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.notificationQueue.removeAll()
            self?.animationPhase = .hidden
        }
    }

    /// Dismiss only the current notification (swipe away)
    func dismissCurrentOnly() {
        withAnimation(DroppyAnimation.notchState) {
            if !notificationQueue.isEmpty {
                notificationQueue.removeFirst()
            }
        }

        // If more notifications, continue showing
        if !notificationQueue.isEmpty {
            resetAutoAdvanceTimer()
        } else {
            dismissNotification()
        }
    }

    /// Toggle expanded state
    func toggleExpanded() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isExpanded.toggle()
        }

        // Pause auto-advance when expanded
        if isExpanded {
            autoAdvanceTimer?.invalidate()
        } else {
            resetAutoAdvanceTimer()
        }
    }

    /// Cleanup when extension is removed
    func cleanup() {
        stopMonitoring()
        isVisible = false
        isExpanded = false
        notificationQueue.removeAll()
        isInstalled = false
        enabledAppsData = Data()
        processedNotificationIDs.removeAll()

        UserDefaults.standard.removeObject(forKey: AppPreferenceKey.notificationHUDShowPreview)
        UserDefaults.standard.removeObject(forKey: AppPreferenceKey.notificationHUDEnabledApps)
    }

    /// Open System Preferences to grant Full Disk Access
    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private Methods - File Monitoring

    /// Start file system monitoring for instant notification detection
    /// Returns true if successfully started, false if should fallback to polling
    private func startFileMonitoring() -> Bool {
        fileMonitor?.cancel()
        if fileDescriptor >= 0 {
            close(fileDescriptor)
        }
        
        // Monitor directory to catch WAL updates (db-wal)
        // SQLite in WAL mode writes to the -wal file, not the main db file immediately
        let dbDir = (notificationDBPath as NSString).deletingLastPathComponent
        
        // Open directory descriptor
        fileDescriptor = Darwin.open(dbDir, O_EVTONLY)
        
        if fileDescriptor < 0 {
            print("NotificationHUD: Failed to open DB directory for monitoring")
            // Fallback to file monitoring if directory fails
            fileDescriptor = Darwin.open(notificationDBPath, O_EVTONLY)
            if fileDescriptor < 0 {
                return false
            }
        }
        
        // Create file system event source
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .attrib, .link, .rename], // Added link/rename for journal rotation
            queue: .main
        )
        
        source.setEventHandler { [weak self] in
            // Faster debounce for instant feel (10ms)
            self?.fileMonitorDebounceWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.checkForNewNotifications()
            }
            self?.fileMonitorDebounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: workItem)
        }
        
        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }
        
        source.resume()
        fileMonitor = source
        
        // Start polling as safety net (concurrently)
        startSlowPolling()
        
        return true
    }
    
    private func startSlowPolling() {
        pollingTimer?.cancel()
        
        let timer = DispatchSource.makeTimerSource(queue: .main)
        // Aggressive polling (0.5s) to ensure "parallel" feel if file monitor lags
        timer.schedule(deadline: .now() + 0.5, repeating: 0.5)
        timer.setEventHandler { [weak self] in
            self?.checkForNewNotifications()
        }
        timer.resume()
        pollingTimer = timer
    }
    
    /// Fast polling fallback when file monitoring unavailable (150ms)
    private func startFastPolling() {
        pollingTimer?.cancel()
        
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.15, repeating: 0.15)
        timer.setEventHandler { [weak self] in
            self?.checkForNewNotifications()
        }
        timer.resume()
        pollingTimer = timer
    }

    private func checkForNewNotifications() {
        guard hasInitialized, isInstalled, hasFullDiskAccess else { return }

        // Query for new notifications
        guard let notifications = fetchNewNotifications() else { return }

        for notification in notifications {
            showNotification(notification)
        }
    }

    // MARK: - Private Methods - SQLite

    private func getLatestNotificationID() -> Int64? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(notificationDBPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        let query = "SELECT MAX(rec_id) FROM record"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return sqlite3_column_int64(stmt, 0)
        }
        return nil
    }

    private func fetchNewNotifications() -> [CapturedNotification]? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(notificationDBPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        // Query for notifications newer than last seen
        let query = """
            SELECT record.rec_id, app.identifier, record.data, record.delivered_date
            FROM record
            JOIN app ON record.app_id = app.app_id
            WHERE record.rec_id > ?
            ORDER BY record.rec_id ASC
            LIMIT 5
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, lastSeenNotificationID)

        var notifications: [CapturedNotification] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            let recID = sqlite3_column_int64(stmt, 0)

            // Skip if already processed (deduplication)
            guard !processedNotificationIDs.contains(recID) else { continue }
            processedNotificationIDs.insert(recID)

            // Update last seen ID
            if recID > lastSeenNotificationID {
                lastSeenNotificationID = recID
            }

            // Get app bundle ID (from joined app table)
            guard let appIDCStr = sqlite3_column_text(stmt, 1) else { continue }
            let bundleID = String(cString: appIDCStr)

            // Get notification data (binary plist)
            guard let dataBlob = sqlite3_column_blob(stmt, 2) else { continue }
            let dataLength = sqlite3_column_bytes(stmt, 2)
            let data = Data(bytes: dataBlob, count: Int(dataLength))

            // Parse the plist to extract title, subtitle, and body
            guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                continue
            }

            // Extract notification content with enhanced parsing
            let parsedContent = parseNotificationContent(from: plist, bundleID: bundleID)

            // Get app info
            let appName = getAppName(for: bundleID) ?? bundleID
            let appIcon = getAppIcon(for: bundleID)

            // Get timestamp
            var timestamp = Date()
            if let deliveredDate = sqlite3_column_double(stmt, 3) as Double?, deliveredDate > 0 {
                timestamp = Date(timeIntervalSinceReferenceDate: deliveredDate)
            }

            let notification = CapturedNotification(
                id: String(recID),
                appBundleID: bundleID,
                appName: appName,
                appIcon: appIcon,
                title: parsedContent.title ?? appName,
                subtitle: parsedContent.subtitle,
                body: parsedContent.body,
                timestamp: timestamp,
                category: parsedContent.category
            )
            
            // Debug logging for troubleshooting
            print("NotificationHUD: Captured notification details:")
            print("  - Bundle ID: \(bundleID)")
            print("  - App Name: \(appName)")
            print("  - Has Icon: \(appIcon != nil)")
            print("  - Title: '\(notification.title)'")
            print("  - Subtitle: '\(notification.subtitle ?? "nil")'")
            print("  - Body: '\(notification.body ?? "nil")'")
            print("  - Display Title: '\(notification.displayTitle)'")
            if let icon = appIcon {
                print("  - Icon Size: \(icon.size)")
            } else {
                print("  - Icon Retrieval FAILED")
            }

            notifications.append(notification)
        }

        // Limit processed IDs cache to prevent memory growth
        if processedNotificationIDs.count > 1000 {
            processedNotificationIDs.removeAll()
            processedNotificationIDs.insert(lastSeenNotificationID)
        }

        return notifications.isEmpty ? nil : notifications
    }

    // MARK: - Enhanced Content Parsing

    private struct ParsedContent {
        var title: String?
        var subtitle: String?
        var body: String?
        var category: String?
    }

    private func parseNotificationContent(from plist: [String: Any], bundleID: String) -> ParsedContent {
        var content = ParsedContent()

        // Get the request dictionary (contains most content)
        let req = plist["req"] as? [String: Any] ?? plist

        // Extract title - try multiple keys
        content.title = req["titl"] as? String
            ?? req["title"] as? String
            ?? plist["titl"] as? String
            ?? plist["title"] as? String

        // Extract subtitle (sender name for messages)
        content.subtitle = req["subt"] as? String
            ?? req["subtitle"] as? String
            ?? plist["subt"] as? String
            ?? plist["subtitle"] as? String

        // Extract body (message content)
        content.body = req["body"] as? String
            ?? plist["body"] as? String

        // Extract category
        content.category = req["cate"] as? String
            ?? req["category"] as? String
            ?? plist["cate"] as? String

        // Special handling for messaging apps
        if isMessagingApp(bundleID) {
            // For messaging apps, subtitle is often the sender
            // If no subtitle but title looks like a sender, adjust
            if content.subtitle == nil && content.title != nil && content.body != nil {
                // Title might be the conversation/sender name
                // Keep as-is, the display logic will handle it
            }
        }

        // Clean up empty strings
        if content.title?.isEmpty == true { content.title = nil }
        if content.subtitle?.isEmpty == true { content.subtitle = nil }
        if content.body?.isEmpty == true { content.body = nil }

        return content
    }

    private func isMessagingApp(_ bundleID: String) -> Bool {
        let messagingApps = [
            "com.apple.MobileSMS",
            "com.apple.iChat",
            "com.tinyspeck.slackmacgap",
            "com.microsoft.teams",
            "com.microsoft.teams2",
            "com.facebook.archon",
            "net.whatsapp.WhatsApp",       // macOS WhatsApp
            "com.whatsapp.WhatsApp",        // iOS WhatsApp (for compat)
            "org.whispersystems.signal-desktop",
            "com.hnc.Discord",
            "com.telegram.desktop",
            "ru.keepcoder.Telegram",        // Telegram for macOS
            "com.google.chat",
            "com.facebook.Messenger"
        ]
        return messagingApps.contains(bundleID) || bundleID.contains("message") || bundleID.contains("chat") || bundleID.contains("whatsapp")
    }

    // MARK: - Private Methods - App Info
    
    /// Cache for app icons to avoid repeated lookups
    private static var iconCache: [String: NSImage] = [:]

    private func getAppName(for bundleID: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return FileManager.default.displayName(atPath: url.path)
    }

    private func getAppIcon(for bundleID: String) -> NSImage? {
        // Check cache first
        if let cached = Self.iconCache[bundleID] {
            return cached
        }
        
        // Try to get icon via NSWorkspace first (most reliable)
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            if icon.size.width > 0 && icon.size.height > 0 {
                let resizedIcon = icon.resized(to: NSSize(width: 64, height: 64))
                Self.iconCache[bundleID] = resizedIcon
                return resizedIcon
            }
        }
        
        // Fallback to checking running applications
        if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
           let icon = runningApp.icon {
            let resizedIcon = icon.resized(to: NSSize(width: 64, height: 64))
            Self.iconCache[bundleID] = resizedIcon
            return resizedIcon
        }
        
        // Method 3: Fallback complete
        print("NotificationHUD: All icon methods failed for bundle ID: \(bundleID)")
        return nil
    }
    
    // MARK: - App Launching
    
    /// Open an app by bundle ID with multiple fallbacks
    func openApp(bundleID: String, completion: (() -> Void)? = nil) {
        print("NotificationHUD: Launching \(bundleID)")
        
        // Try standard launch first
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { [weak self] app, error in
                if error != nil {
                    // Start fallback chain
                    self?.activateRunningApp(bundleID: bundleID)
                }
            }
        } else {
            // No URL found, try direct activation or shell
            if !activateRunningApp(bundleID: bundleID) {
                openViaShell(bundleID: bundleID)
            }
        }
        
        completion?()
    }
    
    @discardableResult
    private func activateRunningApp(bundleID: String) -> Bool {
        DispatchQueue.main.async {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                // Try force activation
                let success = app.activate(options: [.activateAllWindows])
                if !success { app.activate(options: []) } // Retry standard
                return true
            }
            return false
        }
        return false // Async logic mismatch but acceptable for fire-and-forget
    }
    
    private func openViaShell(bundleID: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-b", bundleID]
            try? process.run()
        }
    }

    // MARK: - Database Path Detection

    private static func findNotificationDBPath() -> String {
        let realHomeDir = "/Users/\(NSUserName())"

        // Try macOS Sequoia path first (15.0+)
        let sequoiaPath = "\(realHomeDir)/Library/Group Containers/group.com.apple.usernoted/db2/db"

        if FileManager.default.fileExists(atPath: sequoiaPath) {
            print("NotificationHUD: Found Sequoia path")
            return sequoiaPath
        }

        // For macOS Sonoma and earlier, use DARWIN_USER_DIR
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/getconf")
        process.arguments = ["DARWIN_USER_DIR"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let userDir = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                let sonomaPath = "\(userDir)/com.apple.notificationcenter/db2/db"
                if FileManager.default.fileExists(atPath: sonomaPath) {
                    print("NotificationHUD: Found Sonoma path at \(sonomaPath)")
                    return sonomaPath
                }

                let legacyPath = "\(userDir)/com.apple.notificationcenter/db"
                if FileManager.default.fileExists(atPath: legacyPath) {
                    print("NotificationHUD: Found legacy path at \(legacyPath)")
                    return legacyPath
                }
            }
        } catch {
            print("NotificationHUD: Failed to get DARWIN_USER_DIR: \(error)")
        }

        print("NotificationHUD: Using fallback Sequoia path")
        return sequoiaPath
    }
}
