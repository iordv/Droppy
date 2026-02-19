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
import CryptoKit

enum CapturedNotificationOrigin {
    case system
    case dueSoon
}

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
    let origin: CapturedNotificationOrigin
    
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

    private enum InteractionHitZone {
        static let notchStyleWidth: CGFloat = 450
        static let dynamicIslandWidth: CGFloat = 260
        static let dynamicIslandHeight: CGFloat = 70
        static let builtInNotchHeight: CGFloat = 110
        static let externalNotchHeightCompact: CGFloat = 78
        static let externalNotchHeightWithPreview: CGFloat = 84
    }
    
    // MARK: - Published State
    
    @ObservationIgnored
    @AppStorage(AppPreferenceKey.notificationHUDInstalled) var isInstalled = PreferenceDefault.notificationHUDInstalled
    @ObservationIgnored
    @AppStorage(AppPreferenceKey.notificationHUDEnabled) var isEnabled = PreferenceDefault.notificationHUDEnabled
    @ObservationIgnored
    @AppStorage(AppPreferenceKey.notificationHUDShowPreview) var showPreview = PreferenceDefault.notificationHUDShowPreview
    
    private(set) var currentNotification: CapturedNotification?
    private(set) var notificationQueue: [CapturedNotification] = []
    var isExpanded: Bool = false
    private(set) var hasFullDiskAccess: Bool = false
    
    var queueCount: Int { notificationQueue.count }
    var canRenderNotificationHUD: Bool {
        if isInstalled { return true }
        if currentNotification?.origin == .dueSoon { return true }
        return notificationQueue.contains(where: { $0.origin == .dueSoon })
    }
    
    // Track apps that have sent notifications (bundleID -> (name, icon))
    private(set) var seenApps: [String: (name: String, icon: NSImage?)] = [:]
    
    // MARK: - Private State

    private var pollingTimer: Timer?
    private var lastProcessedRecordID: Int64 = 0
    private var dbConnection: OpaquePointer?
    private let pollingInterval: TimeInterval = 2.0  // Backup polling (file watcher is primary)
    private var dismissWorkItem: DispatchWorkItem?
    private var queueDrainWorkItem: DispatchWorkItem?
    private let autoDismissDelay: TimeInterval = 5.0
    private var isUserInteractingWithHUD = false
    @ObservationIgnored
    private var dueSoonChimeSound: NSSound?
    private var recentSystemPayloadFingerprints: [String: Date] = [:]
    private let systemPayloadDuplicateWindow: TimeInterval = 12 * 60 * 60
    private let staleSystemNotificationWindow: TimeInterval = 10 * 60
    private let futureDeliveredDateTolerance: TimeInterval = 30

    // File system monitoring for instant notification detection
    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var walMonitorSource: DispatchSourceFileSystemObject?  // WAL file monitor
    private var fileDescriptor: Int32 = -1
    private var walFileDescriptor: Int32 = -1
    private var fileChangeDebounceWorkItem: DispatchWorkItem?
    private let fileChangeDebounceInterval: TimeInterval = 0.02  // 20ms debounce (reduced for speed)
    private var recoveryTimer: Timer?
    private let recoveryInterval: TimeInterval = 3.0
    @ObservationIgnored
    private var appDidBecomeActiveObserver: NSObjectProtocol?
    
    // Serial queue to ensure thread-safe SQLite and state access (fixes crashes #152, #156)
    private let databaseQueue = DispatchQueue(label: "app.getdroppy.NotificationHUD.database")
    
    // Darwin notification observer to pre-trigger database polling for lower latency.
    private var isDarwinObserverActive = false

    // App bundle IDs to ignore (Droppy itself, system apps, etc.)
    private let ignoredBundleIDs: Set<String> = [
        "app.getdroppy.Droppy",
        "com.apple.finder"
    ]
    
    private init() {
        dueSoonChimeSound = Self.makeDueSoonChimeSound()
        // Check FDA on init
        recheckAccess()
        
        appDidBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.recheckAccess()
            self?.attemptAutoRecovery(trigger: "app activated")
        }
    }
    
    deinit {
        if let observer = appDidBecomeActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        stopRecoveryTimer()
        stopMonitoring()
    }
    
    // MARK: - Lifecycle
    
    func startMonitoring() {
        guard isInstalled else { return }
        guard !ExtensionType.notificationHUD.isRemoved else { return }
        guard pollingTimer == nil else { return }
        isUserInteractingWithHUD = false

        recheckAccess()

        guard hasFullDiskAccess else {
            print("NotificationHUD: Cannot start - Full Disk Access not granted")
            startRecoveryTimer()
            return
        }

        // Connect to database
        guard connectToDatabase() else {
            print("NotificationHUD: Failed to connect to notification database")
            startRecoveryTimer()
            return
        }
        
        stopRecoveryTimer()

        // Set initial record ID to avoid processing old notifications
        lastProcessedRecordID = getLatestRecordID()
        print("NotificationHUD: Initial record ID set to \(lastProcessedRecordID)")

        // PRIMARY: Start file system monitoring for instant notification detection
        startFileMonitoring()
        
        // ACCELERATOR: Darwin pre-trigger can fire before file events on some systems.
        startDarwinObserver()

        // BACKUP: Slow polling timer as fallback (in case file monitoring misses something)
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.databaseQueue.async {
                self?.pollForNewNotifications()
            }
        }

        print("NotificationHUD: Started monitoring for notifications (Darwin + file watcher + backup polling)")
    }

    /// Start monitoring the notification database file for changes
    /// This provides near-instant notification detection
    private func startFileMonitoring() {
        // Guard against double-start (prevents duplicate monitors + fd leaks)
        guard fileMonitorSource == nil, walMonitorSource == nil else {
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
            self.databaseQueue.asyncAfter(
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
    
    // MARK: - Darwin Pre-Trigger
    
    private func startDarwinObserver() {
        guard !isDarwinObserverActive else { return }
        
        let observer = Unmanaged.passUnretained(self).toOpaque()
        let notificationName = "com.apple.notificationcenterui.bulletin_added" as CFString
        
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let manager = Unmanaged<NotificationHUDManager>.fromOpaque(observer).takeUnretainedValue()
                manager.databaseQueue.async {
                    manager.pollForNewNotifications()
                }
            },
            notificationName,
            nil,
            .deliverImmediately
        )
        
        isDarwinObserverActive = true
        print("NotificationHUD: ✅ Darwin observer started")
    }
    
    private func stopDarwinObserver() {
        guard isDarwinObserverActive else { return }
        
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
        
        isDarwinObserverActive = false
        print("NotificationHUD: Darwin observer stopped")
    }
    
    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        stopRecoveryTimer()
        stopFileMonitoring()  // Stop file system monitoring
        stopDarwinObserver()
        closeDatabase()
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        queueDrainWorkItem?.cancel()
        queueDrainWorkItem = nil
        isUserInteractingWithHUD = false

        DispatchQueue.main.async { [weak self] in
            self?.currentNotification = nil
            self?.notificationQueue.removeAll()
        }
        
        print("NotificationHUD: Stopped monitoring")
    }
    
    // MARK: - Permission Management
    
    func recheckAccess() {
        let previous = hasFullDiskAccess
        hasFullDiskAccess = Self.resolveNotificationDatabasePath(requireReadable: true) != nil
        
        if previous != hasFullDiskAccess {
            print("NotificationHUD: Full Disk Access state changed -> \(hasFullDiskAccess ? "granted" : "missing")")
        }
        
        if !hasFullDiskAccess {
            let bundlePath = Bundle.main.bundleURL.path
            let executablePath = Bundle.main.executableURL?.path ?? "unknown"
            print("NotificationHUD: Full Disk Access probe failed for bundle=\(bundlePath), executable=\(executablePath)")
        }
    }
    
    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Database Access
    
    private static var notificationDatabaseCandidatePaths: [String] {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        return [
            // macOS Sequoia/Tahoe (15+/26+): Group Containers
            homeDir.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db").path,
            homeDir.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db/db").path,
            homeDir.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db/db").path,
            homeDir.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db/db/db").path,
            homeDir.appendingPathComponent("Library/Group Containers/group.com.apple.UserNotifications/db2/db").path,
            homeDir.appendingPathComponent("Library/Group Containers/group.com.apple.UserNotifications/db2/db/db").path,
            homeDir.appendingPathComponent("Library/Group Containers/group.com.apple.UserNotifications/db/db").path,
            homeDir.appendingPathComponent("Library/Group Containers/group.com.apple.UserNotifications/db/db/db").path,
            // Legacy paths (older macOS versions)
            homeDir.appendingPathComponent("Library/Application Support/NotificationCenter/db2/db").path,
            homeDir.appendingPathComponent("Library/Application Support/NotificationCenter/db/db").path
        ]
    }
    
    private static func resolveNotificationDatabasePath(requireReadable: Bool) -> String? {
        for path in notificationDatabaseCandidatePaths where FileManager.default.fileExists(atPath: path) {
            if !requireReadable || canReadNotificationDatabase(at: path) {
                return path
            }
        }
        return nil
    }
    
    /// Full Disk Access checks should verify real read capability, not only filesystem metadata.
    /// Attempt to open and prepare a trivial query against the notification DB.
    private static func canReadNotificationDatabase(at path: String) -> Bool {
        var database: OpaquePointer?
        defer {
            if let database {
                sqlite3_close(database)
            }
        }
        
        let openFlags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(path, &database, openFlags, nil) == SQLITE_OK, let database else {
            return false
        }
        
        var statement: OpaquePointer?
        defer {
            if let statement {
                sqlite3_finalize(statement)
            }
        }
        
        let probeQuery = "SELECT name FROM sqlite_master LIMIT 1;"
        guard sqlite3_prepare_v2(database, probeQuery, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        let stepResult = sqlite3_step(statement)
        return stepResult == SQLITE_ROW || stepResult == SQLITE_DONE
    }
    
    private static var notificationDatabasePath: String {
        if let readablePath = resolveNotificationDatabasePath(requireReadable: true) {
            print("NotificationHUD: Using readable database at \(readablePath)")
            return readablePath
        }
        
        if let existingPath = resolveNotificationDatabasePath(requireReadable: false) {
            print("NotificationHUD: Database exists but is unreadable (likely missing Full Disk Access): \(existingPath)")
            return existingPath
        }
        
        print("NotificationHUD: No database found, tried: \(notificationDatabaseCandidatePaths)")
        return notificationDatabaseCandidatePaths[0]
    }
    
    private func startRecoveryTimer() {
        guard recoveryTimer == nil else { return }
        guard isInstalled else { return }
        guard !ExtensionType.notificationHUD.isRemoved else { return }
        
        recoveryTimer = Timer.scheduledTimer(withTimeInterval: recoveryInterval, repeats: true) { [weak self] _ in
            self?.attemptAutoRecovery(trigger: "timer")
        }
        
        print("NotificationHUD: Started auto-recovery timer")
    }
    
    private func stopRecoveryTimer() {
        recoveryTimer?.invalidate()
        recoveryTimer = nil
    }
    
    private func attemptAutoRecovery(trigger: String) {
        guard isInstalled else {
            stopRecoveryTimer()
            return
        }
        guard !ExtensionType.notificationHUD.isRemoved else {
            stopRecoveryTimer()
            return
        }
        guard pollingTimer == nil else {
            stopRecoveryTimer()
            return
        }
        
        recheckAccess()
        if !hasFullDiskAccess {
            return
        }
        
        print("NotificationHUD: Access restored, retrying start (\(trigger))")
        startMonitoring()
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
        let now = Date()
        pruneRecentSystemPayloadFingerprints(now: now)
        
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
        var newlySeenApps: [String: (name: String, icon: NSImage?)] = [:]
        
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
            let deliveredDateRaw = sqlite3_column_double(statement, 3)
            let deliveredDate = decodedDeliveredDate(from: deliveredDateRaw, referenceNow: now)
            
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
            
            let canonicalBundleID = canonicalBundleIdentifier(from: bundleID)

            if let deliveredDate, isLikelyStaleNotification(deliveredDate, referenceNow: now) {
                debugLog("Skipping stale notification from \(canonicalBundleID) delivered at \(deliveredDate)")
                continue
            }

            if shouldSuppressSystemPayload(
                data: data,
                bundleID: canonicalBundleID,
                referenceNow: now
            ) {
                debugLog("Skipping duplicate payload notification from \(canonicalBundleID)")
                continue
            }
            debugLog(
                "Notification from \(canonicalBundleID) parsed (title=\(title != nil), subtitle=\(subtitle != nil), body=\(body != nil))"
            )
            // Get app name and icon
            let appName = getAppName(for: canonicalBundleID) ?? canonicalBundleID.components(separatedBy: ".").last ?? canonicalBundleID
            let appIcon = getAppIcon(for: canonicalBundleID)

            // Get timestamp
            let timestamp = deliveredDate ?? now
            
            let notification = CapturedNotification(
                appBundleID: canonicalBundleID,
                appName: appName,
                title: title,
                subtitle: subtitle,
                body: body,
                timestamp: timestamp,
                appIcon: appIcon,
                origin: .system
            )
            
            if newlySeenApps[canonicalBundleID] == nil {
                newlySeenApps[canonicalBundleID] = (name: appName, icon: appIcon)
            }
            
            newNotifications.append(notification)
        }
        
        // Update UI on main thread
        if !newNotifications.isEmpty || !newlySeenApps.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if !newlySeenApps.isEmpty {
                    for (bundleID, payload) in newlySeenApps where self.seenApps[bundleID] == nil {
                        self.seenApps[bundleID] = payload
                    }
                }
                if !newNotifications.isEmpty {
                    self.processNewNotifications(newNotifications)
                }
            }
        }
    }

    private func decodedDeliveredDate(from rawValue: Double, referenceNow now: Date) -> Date? {
        guard rawValue.isFinite, rawValue > 0 else { return nil }

        let candidates: [Date] = [
            Date(timeIntervalSinceReferenceDate: rawValue),
            Date(timeIntervalSince1970: rawValue),
            Date(timeIntervalSince1970: rawValue / 1_000),
            Date(timeIntervalSince1970: rawValue / 1_000_000),
            Date(timeIntervalSince1970: rawValue / 1_000_000_000)
        ]

        let fifteenYears: TimeInterval = 15 * 365 * 24 * 60 * 60
        let lowerBound = now.addingTimeInterval(-fifteenYears)
        let upperBound = now.addingTimeInterval(fifteenYears)
        let plausible = candidates.filter { $0 >= lowerBound && $0 <= upperBound }

        guard !plausible.isEmpty else { return nil }
        return plausible.min {
            abs($0.timeIntervalSince(now)) < abs($1.timeIntervalSince(now))
        }
    }

    private func isLikelyStaleNotification(_ deliveredDate: Date, referenceNow now: Date) -> Bool {
        let age = now.timeIntervalSince(deliveredDate)
        if age < -futureDeliveredDateTolerance {
            return true
        }
        return age > staleSystemNotificationWindow
    }

    private func shouldSuppressSystemPayload(data: Data, bundleID: String, referenceNow now: Date) -> Bool {
        var hasher = SHA256()
        hasher.update(data: data)
        hasher.update(data: Data(bundleID.utf8))
        let fingerprint = Data(hasher.finalize()).base64EncodedString()

        if let lastSeen = recentSystemPayloadFingerprints[fingerprint],
           now.timeIntervalSince(lastSeen) <= systemPayloadDuplicateWindow {
            return true
        }

        recentSystemPayloadFingerprints[fingerprint] = now
        return false
    }

    private func pruneRecentSystemPayloadFingerprints(now: Date) {
        recentSystemPayloadFingerprints = recentSystemPayloadFingerprints.filter {
            now.timeIntervalSince($0.value) <= systemPayloadDuplicateWindow
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

    private func runningApplicationCaseInsensitive(forBundleID bundleID: String) -> NSRunningApplication? {
        let normalized = bundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return NSWorkspace.shared.runningApplications.first { app in
            guard let runningBundleID = app.bundleIdentifier?.lowercased() else { return false }
            return runningBundleID == normalized && !app.isTerminated
        }
    }

    private func canonicalBundleIdentifier(from rawBundleID: String) -> String {
        let trimmed = rawBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return rawBundleID }

        if let running = runningApplicationCaseInsensitive(forBundleID: trimmed),
           let bundleID = running.bundleIdentifier, !bundleID.isEmpty {
            return bundleID
        }

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: trimmed),
           let bundleID = Bundle(url: url)?.bundleIdentifier, !bundleID.isEmpty {
            return bundleID
        }

        return trimmed
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
        processIncomingNotifications(
            notifications,
            bypassEnabledCheck: false,
            bypassFocusCheck: false
        )
    }

    func showDueSoonNotification(title: String, subtitle: String, body: String?, playChime: Bool) {
        let bundleID = Bundle.main.bundleIdentifier ?? "app.getdroppy.Droppy"
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Droppy"
        let notification = CapturedNotification(
            appBundleID: bundleID,
            appName: appName,
            title: title,
            subtitle: subtitle,
            body: body,
            timestamp: Date(),
            appIcon: NSApp.applicationIconImage,
            origin: .dueSoon
        )

        DispatchQueue.main.async { [weak self] in
            self?.processIncomingNotifications(
                [notification],
                bypassEnabledCheck: true,
                bypassFocusCheck: true
            )
            if playChime {
                self?.playDueSoonChime()
            }
        }
    }

    private func processIncomingNotifications(
        _ notifications: [CapturedNotification],
        bypassEnabledCheck: Bool,
        bypassFocusCheck: Bool
    ) {
        // Respect the "Notify me!" toggle in HUDs settings
        guard bypassEnabledCheck || isEnabled else {
            debugLog("Skipping \(notifications.count) notification(s) - extension disabled")
            return
        }

        // Respect Focus mode / DND - don't show notifications when Focus is active
        guard bypassFocusCheck || !DNDManager.shared.isDNDActive else {
            debugLog("Skipping \(notifications.count) notification(s) - DND/Focus active")
            return
        }

        debugLog("Processing \(notifications.count) new notification(s), current queue: \(notificationQueue.count)")

        for notification in notifications {
            if currentNotification == nil && !HUDManager.shared.isVisible {
                // Show immediately - no other HUD is active
                debugLog("Showing notification from \(notification.appName) immediately")
                queueDrainWorkItem?.cancel()
                queueDrainWorkItem = nil
                currentNotification = notification
                scheduleAutoDismiss()
                HUDManager.shared.show(.notification)
            } else if currentNotification == nil && HUDManager.shared.isVisible {
                // Another HUD type is active - queue this notification
                // Retry until HUDManager goes idle, then surface this queue.
                debugLog("Queueing notification from \(notification.appName) - another HUD type active")
                notificationQueue.append(notification)
                scheduleQueueDrainIfNeeded()
            } else {
                // We have a current notification - add to queue
                debugLog("Queueing notification from \(notification.appName) - already showing \(currentNotification?.appName ?? "unknown")")
                notificationQueue.append(notification)
            }
        }
    }

    private func scheduleQueueDrainIfNeeded() {
        guard currentNotification == nil, !notificationQueue.isEmpty else { return }
        queueDrainWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.drainQueuedNotificationIfPossible()
        }
        queueDrainWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private func drainQueuedNotificationIfPossible() {
        queueDrainWorkItem = nil
        guard currentNotification == nil else { return }
        guard !HUDManager.shared.isVisible else {
            scheduleQueueDrainIfNeeded()
            return
        }
        guard !notificationQueue.isEmpty else { return }

        let next = notificationQueue.removeFirst()
        debugLog("Draining queued notification from \(next.appName)")
        currentNotification = next
        scheduleAutoDismiss()
        HUDManager.shared.show(.notification)
    }

    private func playDueSoonChime() {
        guard let sound = dueSoonChimeSound else {
            NSSound.beep()
            return
        }
        sound.stop()
        sound.volume = 0.42
        if !sound.play() {
            NSSound.beep()
        }
    }

    private static func makeDueSoonChimeSound() -> NSSound? {
        let pathCandidates = [
            "/System/Library/Sounds/Glass.aiff",
            "/System/Library/Sounds/Pop.aiff",
            "/System/Library/Sounds/Funk.aiff"
        ]
        for path in pathCandidates {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path),
               let sound = NSSound(contentsOf: url, byReference: true) {
                return sound
            }
        }

        let nameCandidates: [NSSound.Name] = [
            NSSound.Name("Glass"),
            NSSound.Name("Pop"),
            NSSound.Name("Funk")
        ]
        for name in nameCandidates {
            if let sound = NSSound(named: name) {
                return sound
            }
        }
        return nil
    }

    private func scheduleAutoDismiss() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        
        guard currentNotification != nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            self?.autoDismissCurrentIfIdle()
        }
        dismissWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissDelay, execute: workItem)
    }

    private func autoDismissCurrentIfIdle() {
        let cursorInsideHUD = isCursorInsideNotificationHUDZone()

        guard !cursorInsideHUD else {
            debugLog("Auto-dismiss paused while cursor is inside Notification HUD")
            scheduleAutoDismiss()
            return
        }

        // Self-heal stale interaction state when hover-exit events are missed.
        if isUserInteractingWithHUD {
            isUserInteractingWithHUD = false
        }
        dismissCurrentOnly()
    }
    
    func setUserInteractingWithHUD(_ isInteracting: Bool) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.setUserInteractingWithHUD(isInteracting)
            }
            return
        }
        
        guard isUserInteractingWithHUD != isInteracting else { return }
        isUserInteractingWithHUD = isInteracting
        
        // Keep periodic idle checks active even while interacting so stale hover
        // states cannot keep notifications pinned forever.
        scheduleAutoDismiss()
    }

    func dismissCurrentOnly() {
        debugLog("Dismissing current notification, queue count: \(notificationQueue.count)")
        dismissWorkItem?.cancel()
        dismissWorkItem = nil

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
        queueDrainWorkItem?.cancel()
        queueDrainWorkItem = nil
        isUserInteractingWithHUD = false
        currentNotification = nil
        notificationQueue.removeAll()
        HUDManager.shared.dismiss()
    }

    // MARK: - Click Handling

    func openCurrentNotificationApp() {
        guard let notification = currentNotification else {
            print("🔔 NotificationHUDManager: No current notification to open")
            return
        }
        let bundleID = canonicalBundleIdentifier(from: notification.appBundleID)
        openNotificationApp(bundleID: bundleID, dismissAfterOpen: true)
    }
    
    private func openNotificationApp(bundleID: String, dismissAfterOpen: Bool) {
        print("🔔 NotificationHUDManager: Opening app for bundle ID: \(bundleID)")
        
        if let app = runningApplicationCaseInsensitive(forBundleID: bundleID) {
            if app.isHidden {
                app.unhide()
            }
            app.activate()
            print("🔔 NotificationHUDManager: Activated via NSRunningApplication")
        }
        
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
        
        guard dismissAfterOpen else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.dismissCurrentOnly()
        }
    }

    private func isCursorInsideNotificationHUDZone() -> Bool {
        guard currentNotification != nil else { return false }

        let mouseLocation = NSEvent.mouseLocation
        guard let activeScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) else {
            return false
        }
        guard let zone = notificationInteractionZone(on: activeScreen) else { return false }

        return zone.insetBy(dx: -10, dy: -10).contains(mouseLocation)
    }

    private func notificationInteractionZone(on screen: NSScreen) -> NSRect? {
        guard currentNotification != nil else { return nil }

        let isDynamicIslandMode = notificationHUDUsesDynamicIsland(on: screen)
        let width = isDynamicIslandMode
            ? InteractionHitZone.dynamicIslandWidth
            : InteractionHitZone.notchStyleWidth
        let height = notificationHUDHeight(on: screen, isDynamicIslandMode: isDynamicIslandMode)
        let topMargin = isDynamicIslandMode ? NotchLayoutConstants.dynamicIslandTopMargin : 0

        return NSRect(
            x: screen.notchAlignedCenterX - (width / 2),
            y: screen.frame.maxY - topMargin - height,
            width: width,
            height: height
        )
    }

    private func notificationHUDUsesDynamicIsland(on screen: NSScreen) -> Bool {
        NotchLayoutConstants.usesDynamicIslandStyle(for: screen)
    }

    private func notificationHUDHeight(on screen: NSScreen, isDynamicIslandMode: Bool) -> CGFloat {
        let baseHeight: CGFloat

        if isDynamicIslandMode {
            baseHeight = InteractionHitZone.dynamicIslandHeight
        } else {
            let isExternalNotchStyle = !screen.isBuiltIn &&
                !UserDefaults.standard.preference(
                    AppPreferenceKey.externalDisplayUseDynamicIsland,
                    default: PreferenceDefault.externalDisplayUseDynamicIsland
                )
            if !isExternalNotchStyle {
                baseHeight = InteractionHitZone.builtInNotchHeight
            } else {
                let hasPreviewTextLine: Bool = {
                    guard showPreview, let notification = currentNotification else { return false }
                    let previewText = [notification.displaySubtitle, notification.body]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return !previewText.isEmpty
                }()
                baseHeight = hasPreviewTextLine
                    ? InteractionHitZone.externalNotchHeightWithPreview
                    : InteractionHitZone.externalNotchHeightCompact
            }
        }

        return baseHeight
    }
}
