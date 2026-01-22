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
    var isFlagged: Bool = false // Flag as important - appears at top with red tint
    var isConcealed: Bool = false // Password/sensitive content
    var customTitle: String? // User-defined title for easy finding
    
    var rtfData: Data? // Rich Text Formatting data
    
    // Custom Codable for backwards compatibility
    enum CodingKeys: String, CodingKey {
        case id, type, content, imageData, imageFilePath, rtfData, date, sourceApp, isFavorite, isFlagged, isConcealed, customTitle
    }
    
    init(id: UUID = UUID(), type: ClipboardType, content: String? = nil, imageData: Data? = nil, 
         imageFilePath: String? = nil, rtfData: Data? = nil,
         date: Date = Date(), sourceApp: String? = nil, isFavorite: Bool = false, 
         isFlagged: Bool = false, isConcealed: Bool = false, customTitle: String? = nil) {
        self.id = id
        self.type = type
        self.content = content
        self.imageData = imageData
        self.imageFilePath = imageFilePath
        self.rtfData = rtfData
        self.date = date
        self.sourceApp = sourceApp
        self.isFavorite = isFavorite
        self.isFlagged = isFlagged
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
        isFlagged = try container.decodeIfPresent(Bool.self, forKey: .isFlagged) ?? false // Default for old data
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
        lhs.isFlagged == rhs.isFlagged &&
        lhs.customTitle == rhs.customTitle &&
        lhs.isConcealed == rhs.isConcealed
    }
}

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    private var isLoading = false // Flag to prevent saving during load
    private var wasExplicitlyCleared = false // Flag to allow saving empty history when user clears all
    
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
    
    /// Flag to mark next captured clipboard item as favorite (Issue #43 Copy+Favorite)
    private var favoriteNextCapture: Bool = false
    
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
        // Don't save empty history UNLESS user explicitly cleared it
        // This prevents accidental data loss from bugs while allowing intentional clears
        guard !history.isEmpty || wasExplicitlyCleared else {
            print("⚠️ Refusing to save empty clipboard history (use clearAll to intentionally clear)")
            return
        }
        
        // Reset the explicit clear flag after saving
        wasExplicitlyCleared = false
        
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
        // Pre-initialize lazy properties on main thread to ensure thread safety
        // during concurrent background loading and foreground monitoring
        _ = self.persistenceURL
        _ = self.imagesDirectory

        // CRITICAL: Set isLoading BEFORE any operation to prevent race condition
        // where didSet triggers saveToDisk() with empty/partial data
        isLoading = true
        
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else {
            isLoading = false
            return
        }

        // PERFORMANCE: Offload file I/O and JSON decoding to background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try Data(contentsOf: self.persistenceURL)
                var decoded = try JSONDecoder().decode([ClipboardItem].self, from: data)

                // MIGRATION: Move inline imageData to files
                var needsSave = false
                for i in decoded.indices {
                    if decoded[i].type == .image,
                       decoded[i].imageData != nil,
                       decoded[i].imageFilePath == nil {
                        // Migrate this item's image to file
                        if let filePath = self.saveImageToFile(decoded[i].imageData!, id: decoded[i].id) {
                            decoded[i].imageFilePath = filePath
                            decoded[i].imageData = nil // Clear inline data to free memory
                            needsSave = true
                            print("📋 Migrated image \(decoded[i].id) to file")
                        }
                    }
                }

                // Update state on Main Thread
                DispatchQueue.main.async {
                    print("📋 Loaded \(decoded.count) clipboard items from disk")

                    // Merge Strategy: Combine loaded items with current history
                    // 1. Preserve new items captured during load (they are in self.history)
                    // 2. If a loaded item matches a new item, preserve the loaded item's metadata (favorites/flags)
                    // 3. Append remaining loaded items

                    var mergedHistory = self.history
                    var itemsToAdd: [ClipboardItem] = []

                    for loadedItem in decoded {
                        // Check for duplicates in the current (fresh) history
                        if let index = mergedHistory.firstIndex(where: { currentItem in
                            // Match by ID
                            if loadedItem.id == currentItem.id { return true }
                            // Match by content (for text/url/etc)
                            if loadedItem.type != .image,
                               loadedItem.type == currentItem.type,
                               loadedItem.content == currentItem.content {
                                return true
                            }
                            return false
                        }) {
                            // Match found! Restore metadata from disk if the fresh item lacks it
                            // (e.g. user copied a Favorite item before history loaded - we want to keep it Favorited)
                            if loadedItem.isFavorite && !mergedHistory[index].isFavorite {
                                mergedHistory[index].isFavorite = true
                            }
                            if loadedItem.isFlagged && !mergedHistory[index].isFlagged {
                                mergedHistory[index].isFlagged = true
                            }
                            if let title = loadedItem.customTitle, mergedHistory[index].customTitle == nil {
                                mergedHistory[index].customTitle = title
                            }
                        } else {
                            // No match, this is an old item to add
                            itemsToAdd.append(loadedItem)
                        }
                    }

                    // Apply changes
                    if !itemsToAdd.isEmpty || mergedHistory.count != self.history.count {
                        // We have additions.
                        // Note: We don't detect if we *only* updated metadata on existing items,
                        // but that's fine, we'll just append and re-sort.
                        mergedHistory.append(contentsOf: itemsToAdd)
                        self.history = mergedHistory
                        self.enforceHistoryLimit() // Sorts and trims
                    } else {
                        // Even if no items added, we might have updated metadata (favorites restored)
                        // Assigning to self.history triggers observers
                        self.history = mergedHistory
                    }

                    // Save if we migrated data or merged new items/metadata
                    // (Simplification: just save if we touched anything)
                    if needsSave || !itemsToAdd.isEmpty {
                        if needsSave { print("📋 Saving migrated history to disk...") }
                        self.scheduleSave()
                    }

                    self.isLoading = false
                }
            } catch {
                print("⚠️ Failed to load clipboard history: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
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
        // Separate flagged, favorites, and regular items
        let flagged = history.filter { $0.isFlagged }
        let favorites = history.filter { $0.isFavorite && !$0.isFlagged }
        let regular = history.filter { !$0.isFavorite && !$0.isFlagged }
        
        // Calculate how many regular items we can keep
        let protectedCount = flagged.count + favorites.count
        let regularLimit = max(0, historyLimit - protectedCount)
        let limitedRegular = Array(regular.prefix(regularLimit))
        
        // Identify items being removed and cleanup their image files
        let keptIds = Set(flagged.map { $0.id } + favorites.map { $0.id } + limitedRegular.map { $0.id })
        for item in history where !keptIds.contains(item.id) {
            deleteImageFile(for: item)
        }
        
        // Rebuild history: flagged first, then favorites, then regular (all sorted by date)
        history = flagged.sorted { $0.date > $1.date } + 
                  favorites.sorted { $0.date > $1.date } + 
                  limitedRegular
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
            
            // Check if we should favorite the next capture (Issue #43)
            let shouldFavorite = self.favoriteNextCapture
            if shouldFavorite {
                self.favoriteNextCapture = false
                print("⭐ Droppy: Will favorite this capture")
            }
            
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
                
                // Issue #43: Mark as favorite if flag is set
                if shouldFavorite {
                    item.isFavorite = true
                    print("⭐ Droppy: Favorited: \(item.title)")
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
        HapticFeedback.copy()
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
            withAnimation(DroppyAnimation.listChange) {
                history[index].isFavorite.toggle()
                sortHistory()
                // Force SwiftUI to detect the isFavorite change on rows
                objectWillChange.send()
            }
            HapticFeedback.toggle()
        }
    }
    
    func toggleFlag(_ item: ClipboardItem) {
        if let index = history.firstIndex(where: { $0.id == item.id }) {
            withAnimation(DroppyAnimation.listChange) {
                history[index].isFlagged.toggle()
                sortHistory()
                // Force SwiftUI to detect the isFlagged change on rows
                objectWillChange.send()
            }
            HapticFeedback.toggle()
        }
    }
    
    private func sortHistory() {
        // Priority order: Flagged > Favorites > Regular (all sorted by date within group)
        history.sort { (a, b) -> Bool in
            // Flagged items always come first
            if a.isFlagged && !b.isFlagged { return true }
            if !a.isFlagged && b.isFlagged { return false }
            // Then favorites
            if a.isFavorite && !b.isFavorite { return true }
            if !a.isFavorite && b.isFavorite { return false }
            // Finally by date
            return a.date > b.date
        }
    }
    
    func delete(item: ClipboardItem) {
        if let index = history.firstIndex(where: { $0.id == item.id }) {
            // Clean up image file if it exists
            deleteImageFile(for: history[index])
            history.remove(at: index)
            HapticFeedback.delete()
            
            // If history is now empty, mark as explicitly cleared so it persists to disk
            if history.isEmpty {
                wasExplicitlyCleared = true
                scheduleSave() // Force save the empty state
            }
        }
    }
    
    func rename(item: ClipboardItem, to newTitle: String) {
        if let index = history.firstIndex(where: { $0.id == item.id }) {
            let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            history[index].customTitle = trimmed.isEmpty ? nil : trimmed
            // Force SwiftUI to re-render after mutation
            objectWillChange.send()
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
    
    // MARK: - Copy + Favorite (Issue #43)
    
    /// Simulates Cmd+C to copy current selection, then marks it as favorite
    /// Called by the global Copy+Favorite shortcut
    func copyAndFavoriteCurrentClipboard() {
        print("⭐ Droppy: Copy+Favorite triggered")
        
        // Set flag to favorite the next captured item
        favoriteNextCapture = true
        
        // Issue #61: Clear any held modifiers first, then wait before simulating Cmd+C
        // This breaks the detection window for apps like DeepL that listen for key sequences
        // Step 1: Release all modifiers to reset the keyboard state
        clearModifierState()
        
        // Step 2: Wait for DeepL's detection window to expire (200ms is safer than 100ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.simulateCopyCommand()
        }
    }
    
    /// Clears all modifier keys to reset keyboard state
    /// This helps prevent third-party apps from detecting our simulated keys as part of a sequence
    private func clearModifierState() {
        // Use privateState to make events less visible to other apps
        let source = CGEventSource(stateID: .privateState)
        
        // Post events to release all modifier keys
        let modifierKeys: [CGKeyCode] = [55, 56, 58, 59, 60, 61, 62] // Cmd, Shift, Option, Control variants
        for key in modifierKeys {
            if let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) {
                event.post(tap: .cghidEventTap)
            }
        }
    }
    
    /// Simulates Cmd+C key press to copy current selection
    /// Uses privateState source to minimize interference from third-party apps
    private func simulateCopyCommand() {
        // Use privateState - these events are less visible to event taps from other apps
        let source = CGEventSource(stateID: .privateState)
        source?.localEventsSuppressionInterval = 0.0
        
        let cmdKey: CGKeyCode = 55 // kVK_Command
        let cKey: CGKeyCode = 8    // kVK_ANSI_C
        
        // 1. Cmd Down
        guard let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: true) else { return }
        cmdDown.flags = .maskCommand
        
        // 2. C Down
        guard let cDown = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: true) else { return }
        cDown.flags = .maskCommand
        
        // 3. C Up
        guard let cUp = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: false) else { return }
        cUp.flags = .maskCommand
        
        // 4. Cmd Up
        guard let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: false) else { return }
        
        // Post events
        let loc = CGEventTapLocation.cghidEventTap
        cmdDown.post(tap: loc)
        cDown.post(tap: loc)
        cUp.post(tap: loc)
        cmdUp.post(tap: loc)
        
        print("⭐ Droppy: Simulated Cmd+C (privateState source)")
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

