import SwiftUI
import AppKit
import Combine

enum ClipboardType: String, Codable {
    case text
    case image
    case file
    case url
    case color
}

struct ClipboardItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var type: ClipboardType
    var content: String? // Text, URL string, or File path
    var imageData: Data? // LEGACY: For migration only, will be nil after migration
    var imageFilePath: String? // NEW: Relative path to image file (e.g., "images/{uuid}.jpg")
    var date: Date = Date()
    var sourceApp: String?
    var isFavorite: Bool = false
    var isConcealed: Bool = false // Password/sensitive content
    var customTitle: String? // User-defined title for easy finding
    
    var rtfData: Data? // Rich Text Formatting data
    
    // Custom Codable for backwards compatibility
    enum CodingKeys: String, CodingKey {
        case id, type, content, imageData, imageFilePath, rtfData, date, sourceApp, isFavorite, isConcealed, customTitle
    }
    
    init(id: UUID = UUID(), type: ClipboardType, content: String? = nil, imageData: Data? = nil, 
         imageFilePath: String? = nil, rtfData: Data? = nil,
         date: Date = Date(), sourceApp: String? = nil, isFavorite: Bool = false, 
         isConcealed: Bool = false, customTitle: String? = nil) {
        self.id = id
        self.type = type
        self.content = content
        self.imageData = imageData
        self.imageFilePath = imageFilePath
        self.rtfData = rtfData
        self.date = date
        self.sourceApp = sourceApp
        self.isFavorite = isFavorite
        self.isConcealed = isConcealed
        self.customTitle = customTitle
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ClipboardType.self, forKey: .type)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        imageFilePath = try container.decodeIfPresent(String.self, forKey: .imageFilePath)
        rtfData = try container.decodeIfPresent(Data.self, forKey: .rtfData)
        date = try container.decode(Date.self, forKey: .date)
        sourceApp = try container.decodeIfPresent(String.self, forKey: .sourceApp)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        isConcealed = try container.decodeIfPresent(Bool.self, forKey: .isConcealed) ?? false // Default for old data
        customTitle = try container.decodeIfPresent(String.self, forKey: .customTitle)
    }
    
    /// Get the full URL to the image file (lazy loading)
    func getImageFileURL() -> URL? {
        guard let relativePath = imageFilePath else { return nil }
        return ClipboardManager.shared.imagesDirectory.appendingPathComponent(relativePath)
    }
    
    /// Load image data from file (lazy - only when needed)
    func loadImageData() -> Data? {
        // First check if inline data exists (pre-migration)
        if let data = imageData {
            return data
        }
        // Otherwise load from file
        guard let fileURL = getImageFileURL() else { return nil }
        return try? Data(contentsOf: fileURL)
    }
    
    var title: String {
        // Use custom title if set
        if let custom = customTitle, !custom.isEmpty {
            return custom
        }
        // Otherwise generate from content
        switch type {
        case .text:
            // PERFORMANCE: Only process first 100 chars to avoid O(n) on large content
            if let content = content {
                let preview = String(content.prefix(100))
                return preview.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50).description
            }
            return "Text"
        case .image:
            return "Image"
        case .file:
            return URL(fileURLWithPath: content ?? "").lastPathComponent
        case .url:
            if let content = content, LinkPreviewService.shared.isDirectImageURL(content), let url = URL(string: content) {
                return url.lastPathComponent
            }
            return content ?? "Link"
        case .color:
            return "Color"
        }
    }
    
    // MARK: - Hashable & Equatable (PERFORMANCE CRITICAL)
    // Use ID-only comparison to avoid hashing multi-MB content strings
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        // Compare by ID for identity, plus key properties for state changes
        lhs.id == rhs.id &&
        lhs.isFavorite == rhs.isFavorite &&
        lhs.customTitle == rhs.customTitle &&
        lhs.isConcealed == rhs.isConcealed
    }
}

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    private var isLoading = false // Flag to prevent saving during load
    
    @Published var history: [ClipboardItem] = [] {
        didSet {
            // Don't save during initial load
            guard !isLoading else { return }
            scheduleSave() // Debounced save for performance
        }
    }
    @Published var hasAccessibilityPermission: Bool = false
    @Published var showPasteFeedback: Bool = false
    @Published var isEditingContent: Bool = false  // Track if user is editing text content
    
    // MARK: - Settings (UserDefaults)
    // Using direct UserDefaults access instead of @AppStorage to avoid crashes in Timer callbacks
    
    @Published var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "enableClipboardBeta")
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }
    
    @Published var historyLimit: Int = 50 {
        didSet {
            UserDefaults.standard.set(historyLimit, forKey: "clipboardHistoryLimit")
            enforceHistoryLimit()
        }
    }
    
    private var excludedAppsData: Data = Data() {
        didSet {
            UserDefaults.standard.set(excludedAppsData, forKey: "excludedClipboardApps")
        }
    }
    
    @Published var skipConcealedContent: Bool = false {
        didSet {
            UserDefaults.standard.set(skipConcealedContent, forKey: "skipConcealedClipboard")
        }
    }
    
    /// Set of bundle identifiers to exclude from clipboard history
    var excludedApps: Set<String> {
        get {
            guard !excludedAppsData.isEmpty,
                  let decoded = try? JSONDecoder().decode(Set<String>.self, from: excludedAppsData) else {
                return []
            }
            return decoded
        }
        set {
            objectWillChange.send()
            if let encoded = try? JSONEncoder().encode(newValue) {
                excludedAppsData = encoded
            }
        }
    }
    
    private var lastChangeCount: Int
    private var isMonitoring = false
    
    /// Debounce timer for save operations (prevents rapid saves with large content)
    private var saveDebounceTimer: Timer?
    
    private lazy var persistenceURL: URL = {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("Droppy", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent("clipboard_history.json")
    }()
    
    /// Directory for storing clipboard images on disk (lazy loading)
    lazy var imagesDirectory: URL = {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let imagesDir = paths[0].appendingPathComponent("Droppy/images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        return imagesDir
    }()
    
    init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
        
        // Use centralized PermissionManager with caching
        self.hasAccessibilityPermission = PermissionManager.shared.isAccessibilityGranted
        
        // Initial load of settings from UserDefaults
        // Default to enabled if key hasn't been explicitly set
        if UserDefaults.standard.object(forKey: "enableClipboardBeta") == nil {
            self.isEnabled = true
        } else {
            self.isEnabled = UserDefaults.standard.bool(forKey: "enableClipboardBeta")
        }
        let limit = UserDefaults.standard.integer(forKey: "clipboardHistoryLimit")
        self.historyLimit = limit == 0 ? 50 : limit
        self.excludedAppsData = UserDefaults.standard.data(forKey: "excludedClipboardApps") ?? Data()
        self.skipConcealedContent = UserDefaults.standard.bool(forKey: "skipConcealedClipboard")
        
        loadFromDisk()
        
        if isEnabled {
            startMonitoring()
        }
    }
    
    func checkPermission() {
        let effectivelyTrusted = PermissionManager.shared.isAccessibilityGranted
        
        if hasAccessibilityPermission != effectivelyTrusted {
            DispatchQueue.main.async {
                self.hasAccessibilityPermission = effectivelyTrusted
            }
        }
    }
    
    /// Schedules a debounced save operation
    /// Coalesces rapid changes into single save after 0.5s of inactivity
    private func scheduleSave() {
        saveDebounceTimer?.invalidate()
        saveDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.saveToDisk()
        }
    }
    
    private func saveToDisk() {
        // Don't save empty history - this could indicate a bug
        guard !history.isEmpty else {
            print("⚠️ Refusing to save empty clipboard history")
            return
        }
        
        // Run save on background thread to avoid blocking UI
        let historyToSave = history
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let url = self?.persistenceURL else { return }
            do {
                // Create backup before overwriting
                let backupURL = url.deletingLastPathComponent().appendingPathComponent("clipboard_history.backup.json")
                if FileManager.default.fileExists(atPath: url.path) {
                    try? FileManager.default.removeItem(at: backupURL)
                    try? FileManager.default.copyItem(at: url, to: backupURL)
                }
                
                let data = try JSONEncoder().encode(historyToSave)
                try data.write(to: url, options: .atomic)
            } catch {
                print("Failed to save clipboard history: \(error)")
            }
        }
    }
    
    private func loadFromDisk() {
        // CRITICAL: Set isLoading BEFORE any operation to prevent race condition
        // where didSet triggers saveToDisk() with empty/partial data
        isLoading = true
        defer { isLoading = false }
        
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else { return }
        do {
            let data = try Data(contentsOf: persistenceURL)
            var decoded = try JSONDecoder().decode([ClipboardItem].self, from: data)
            
            // MIGRATION: Move inline imageData to files
            var needsSave = false
            for i in decoded.indices {
                if decoded[i].type == .image,
                   decoded[i].imageData != nil,
                   decoded[i].imageFilePath == nil {
                    // Migrate this item's image to file
                    if let filePath = saveImageToFile(decoded[i].imageData!, id: decoded[i].id) {
                        decoded[i].imageFilePath = filePath
                        decoded[i].imageData = nil // Clear inline data to free memory
                        needsSave = true
                        print("📋 Migrated image \(decoded[i].id) to file")
                    }
                }
            }
            
            self.history = decoded
            print("📋 Loaded \(decoded.count) clipboard items from disk")
            
            // Save migrated data (without inline images)
            if needsSave {
                print("📋 Saving migrated history to disk...")
                // Temporarily disable isLoading to allow save
                isLoading = false
                saveToDisk()
                isLoading = true
            }
        } catch {
            print("⚠️ Failed to load clipboard history: \(error)")
            // Don't clear history on load failure - keep whatever is in memory
        }
    }
    
    // MARK: - Image File Management
    
    /// Save image data to file and return relative path
    func saveImageToFile(_ data: Data, id: UUID) -> String? {
        let filename = "\(id.uuidString).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL, options: .atomic)
            return filename // Return just the filename (relative path)
        } catch {
            print("❌ Failed to save image file: \(error)")
            return nil
        }
    }
    
    /// Delete image file for an item
    func deleteImageFile(for item: ClipboardItem) {
        guard let relativePath = item.imageFilePath else { return }
        let fileURL = imagesDirectory.appendingPathComponent(relativePath)
        try? FileManager.default.removeItem(at: fileURL)
        print("🗑️ Deleted image file: \(relativePath)")
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        permissionCheckCounter = 0  // Reset counter on start
        monitorLoop()
    }
    
    func stopMonitoring() {
        isMonitoring = false
    }
    
    /// Counter for throttling permission checks (every 20 cycles = 10 seconds)
    private var permissionCheckCounter = 0
    private let permissionCheckFrequency = 20  // Check every 20 cycles (0.5s * 20 = 10 seconds)
    
    private func monitorLoop() {
        guard isMonitoring else { return }
        
        autoreleasepool {
            checkForChanges()
            
            // Only check permissions every 10 seconds instead of every 0.5s
            // This prevents excessive TCC queries which can cause system issues
            permissionCheckCounter += 1
            if permissionCheckCounter >= permissionCheckFrequency {
                permissionCheckCounter = 0
                checkPermission()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.monitorLoop()
        }
    }
    
    func enforceHistoryLimit() {
        // Separate favorites from non-favorites
        let favorites = history.filter { $0.isFavorite }
        let nonFavorites = history.filter { !$0.isFavorite }
        
        // Calculate how many non-favorites we can keep
        let nonFavoriteLimit = max(0, historyLimit - favorites.count)
        let limitedNonFavorites = Array(nonFavorites.prefix(nonFavoriteLimit))
        
        // Identify items being removed and cleanup their image files
        let keptIds = Set(favorites.map { $0.id } + limitedNonFavorites.map { $0.id })
        for item in history where !keptIds.contains(item.id) {
            deleteImageFile(for: item)
        }
        
        // Rebuild history: favorites first (sorted by date), then non-favorites
        history = favorites.sorted { $0.date > $1.date } + limitedNonFavorites
    }

    private func checkForChanges() {
        guard isEnabled else { return }

        // Snapshot pasteboard and frontmost app state once per cycle
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        // CRITICAL: Immediately copy String values from frontmostApplication 
        // to prevent objc_release crash. The NSRunningApplication can be deallocated
        // at any point, so we must not hold a reference to it across autoreleasepool boundaries.
        // Use String(describing:) or nil-coalescing to force a copy
        var frontmostBundleID: String? = nil
        var frontmostAppName: String? = nil
        if let app = NSWorkspace.shared.frontmostApplication {
            if let bundleID = app.bundleIdentifier {
                frontmostBundleID = String(bundleID)
            }
            if let name = app.localizedName {
                frontmostAppName = String(name)
            }
        }

        // Exclusion check using the snapshot value
        if let bundleID = frontmostBundleID, excludedApps.contains(bundleID) {
            return
        }

        // Snapshot types/items once so we don't race against pasteboard changes mid-read
        let typesSnapshot = pasteboard.types ?? []
        guard let itemsSnapshot = pasteboard.pasteboardItems, !itemsSnapshot.isEmpty else { return }

        // Concealed/Transient checks from snapshot
        let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
        let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
        let hasConcealed = typesSnapshot.contains(concealedType)
        let hasTransient = typesSnapshot.contains(transientType)

        print("📋 Clipboard Change Detected!")
        print("   - Types: \(typesSnapshot.map { $0.rawValue })")
        print("   - Is Concealed: \(hasConcealed)")
        print("   - Is Transient: \(hasTransient)")
        print("   - Skip Setting: \(skipConcealedContent)")

        if skipConcealedContent {
            if hasConcealed { 
                print("   🚫 SKIPPING: Content is Concealed")
                return 
            }
            if hasTransient { 
                print("   🚫 SKIPPING: Content is Transient")
                return 
            }
        }

        // Extract from the snapshot to avoid further pasteboard reads this cycle
        let newItems = extractItems(from: pasteboard, itemsSnapshot: itemsSnapshot, appNameSnapshot: frontmostAppName)
        guard !newItems.isEmpty else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for var item in newItems.reversed() {
                // For images with files, skip duplicate detection (expensive to compare files)
                // For text/url, check if content matches
                if item.type != .image {
                    if let index = self.history.firstIndex(where: {
                        $0.type == item.type &&
                        $0.content == item.content
                    }) {
                        let existing = self.history[index]
                        item.isFavorite = existing.isFavorite
                        item.customTitle = existing.customTitle
                        // Delete old image file if being replaced
                        self.deleteImageFile(for: existing)
                        self.history.remove(at: index)
                    }
                }
                self.history.insert(item, at: 0)
            }
            self.enforceHistoryLimit()
        }
    }
    
    private func extractItems(from pasteboard: NSPasteboard, itemsSnapshot: [NSPasteboardItem], appNameSnapshot: String?) -> [ClipboardItem] {
        let app = appNameSnapshot
        var results: [ClipboardItem] = []

        // Global type markers used per-item
        let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
        let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
        let transientTextType = NSPasteboard.PasteboardType("public.utf8-plain-text.transient")
        let onePasswordType = NSPasteboard.PasteboardType("com.agilebits.onepassword")

        // Iterate using the snapshot to avoid mid-iteration pasteboard mutation
        for item in itemsSnapshot {
            autoreleasepool {
                var isConcealed = false
                let types = item.types
                if types.contains(concealedType) { isConcealed = true }
                if types.contains(transientType) { isConcealed = true }
                if types.contains(transientTextType) { isConcealed = true }
                if types.contains(onePasswordType) { isConcealed = true }

                // 1) File URL
                if let fileURLVal = item.string(forType: .fileURL), let url = URL(string: fileURLVal) {
                    results.append(ClipboardItem(type: .file, content: url.path, sourceApp: app, isConcealed: isConcealed))
                    return
                }

                // 2) Image: Save to file to avoid memory bloat
                if let tiff = item.data(forType: .tiff) {
                    let compressed = compressImageDataIfNeeded(tiff)
                    let itemId = UUID()
                    if let filePath = saveImageToFile(compressed, id: itemId) {
                        results.append(ClipboardItem(id: itemId, type: .image, imageFilePath: filePath, sourceApp: app, isConcealed: isConcealed))
                    }
                    return
                }
                if let png = item.data(forType: .png) {
                    let compressed = compressImageDataIfNeeded(png)
                    let itemId = UUID()
                    if let filePath = saveImageToFile(compressed, id: itemId) {
                        results.append(ClipboardItem(id: itemId, type: .image, imageFilePath: filePath, sourceApp: app, isConcealed: isConcealed))
                    }
                    return
                }

                // 3) URL
                if let urlStr = item.string(forType: .URL) {
                    results.append(ClipboardItem(type: .url, content: urlStr, sourceApp: app, isConcealed: isConcealed))
                    return
                }

                // 4) Text (with optional RTF/RTFD)
                if let str = item.string(forType: .string) {
                    let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
                            let matches = detector.matches(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count))
                            if let firstMatch = matches.first, firstMatch.range.length == trimmed.utf16.count {
                                results.append(ClipboardItem(type: .url, content: trimmed, sourceApp: app, isConcealed: isConcealed))
                                return
                            }
                        }
                        let rtf = item.data(forType: .rtf) ?? item.data(forType: .rtfd)
                        results.append(ClipboardItem(type: .text, content: str, rtfData: rtf, sourceApp: app, isConcealed: isConcealed))
                        return
                    }
                }
            }
        }

        return results
    }
    
    func paste(item: ClipboardItem, targetPID: pid_t? = nil) {
        // Re-check permission right before simulation
        checkPermission()
        
        // Show feedback toast in UI
        DispatchQueue.main.async {
            self.showPasteFeedback = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.showPasteFeedback = false
            }
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .text:
            if let str = item.content {
                // Restore RTF if available
                if let rtf = item.rtfData {
                    pasteboard.setData(rtf, forType: .rtf)
                }
                pasteboard.setString(str, forType: .string)
            }
        case .url:
            if let str = item.content {
                pasteboard.setString(str, forType: .URL)
                pasteboard.setString(str, forType: .string)
            }
        case .file:
            if let path = item.content {
                pasteboard.writeObjects([URL(fileURLWithPath: path) as NSURL])
            }
        case .image:
            if let data = item.loadImageData(), let img = NSImage(data: data) {
                pasteboard.writeObjects([img])
            }
        default: break
        }
        
        // Precisely mirroring ClipBook: The simulation happens immediately here;
        // the caller (WindowController) handles the 150ms "focus settling" delay.
        self.simulatePasteCommand(targetPID: targetPID)
    }
    
    private func simulatePasteCommand(targetPID: pid_t?) {
        // EXACT Mirror of ClipBook Method (V12):
        // Use discrete events for Cmd and V to correctly simulate physical input
        let source = CGEventSource(stateID: .hidSystemState)
        let cmdKey: CGKeyCode = 55 // kVK_Command
        let vKey: CGKeyCode = 9    // kVK_ANSI_V
        
        // 1. Cmd Down
        guard let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: true) else { return }
        cmdDown.flags = .maskCommand
        
        // 2. V Down
        guard let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true) else { return }
        vDown.flags = .maskCommand
        
        // 3. V Up
        guard let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) else { return }
        vUp.flags = .maskCommand
        
        // 4. Cmd Up
        guard let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: false) else { return }
        
        // Post events to the system event tap (works globally)
        let loc = CGEventTapLocation.cghidEventTap
        
        cmdDown.post(tap: loc)
        vDown.post(tap: loc)
        vUp.post(tap: loc)
        cmdUp.post(tap: loc)
        
        print("🪞 Droppy: Paste simulated (Discrete Cmd+V sequence)")
    }
    
    func toggleFavorite(_ item: ClipboardItem) {
        if let index = history.firstIndex(where: { $0.id == item.id }) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                history[index].isFavorite.toggle()
                sortHistory()
            }
        }
    }
    
    private func sortHistory() {
        history.sort { (a, b) -> Bool in
            if a.isFavorite && !b.isFavorite { return true }
            if !a.isFavorite && b.isFavorite { return false }
            return a.date > b.date
        }
    }
    
    func delete(item: ClipboardItem) {
        if let index = history.firstIndex(where: { $0.id == item.id }) {
            // Clean up image file if it exists
            deleteImageFile(for: history[index])
            history.remove(at: index)
        }
    }
    
    func rename(item: ClipboardItem, to newTitle: String) {
        if let index = history.firstIndex(where: { $0.id == item.id }) {
            let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            history[index].customTitle = trimmed.isEmpty ? nil : trimmed
        }
    }

    func updateItemContent(_ item: ClipboardItem, newContent: String) {
        if let index = history.firstIndex(where: { $0.id == item.id }) {
            history[index].content = newContent
        }
    }
    
    // MARK: - App Exclusion Management
    
    func addExcludedApp(_ bundleID: String) {
        var apps = excludedApps
        apps.insert(bundleID)
        excludedApps = apps
    }
    
    func removeExcludedApp(_ bundleID: String) {
        var apps = excludedApps
        apps.remove(bundleID)
        excludedApps = apps
    }
    
    func isAppExcluded(_ bundleID: String) -> Bool {
        excludedApps.contains(bundleID)
    }
    
    // MARK: - Image Compression (for NEW entries only)
    
    /// Compress large image data to reduce memory footprint
    /// Only compresses images > 500KB, converts to JPEG at 80% quality
    /// Maximum stored size: 1MB (further reduces quality if needed)
    private func compressImageDataIfNeeded(_ data: Data) -> Data {
        // Skip if already small enough
        guard data.count > 500 * 1024 else { return data }
        
        // Try to create image
        guard let image = NSImage(data: data),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return data // Can't process, return original
        }
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        
        // Try progressively lower quality until under 1MB
        for quality in stride(from: 0.8, through: 0.4, by: -0.1) {
            if let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality]) {
                if jpegData.count <= 1024 * 1024 {
                    print("📋 Compressed image from \(data.count / 1024)KB to \(jpegData.count / 1024)KB (quality: \(quality))")
                    return jpegData
                }
            }
        }
        
        // Fallback: return lowest quality attempt or original
        if let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.4]) {
            print("📋 Compressed image from \(data.count / 1024)KB to \(jpegData.count / 1024)KB (quality: 0.4)")
            return jpegData
        }
        
        return data
    }
}

