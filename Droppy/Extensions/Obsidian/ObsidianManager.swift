//
//  ObsidianManager.swift
//  Droppy
//
//  Manages Obsidian vault integration: pinned notes, CLI/FS operations,
//  persistence, global hotkey, and external change detection.
//

import SwiftUI
import AppKit

// MARK: - Data Model

struct PinnedNote: Identifiable, Codable, Equatable {
    let id: UUID
    var fileName: String          // "Daily Log.md"
    var relativePath: String      // path relative to vault root
    var defaultHeading: String?   // user's preferred heading
    var displayName: String       // short label for chip
    var isDaily: Bool             // true for the built-in daily note

    init(id: UUID = UUID(), fileName: String, relativePath: String, defaultHeading: String? = nil, displayName: String? = nil, isDaily: Bool = false) {
        self.id = id
        self.fileName = fileName
        self.relativePath = relativePath
        self.defaultHeading = defaultHeading
        self.displayName = displayName ?? String(fileName.dropLast(3)) // Strip .md
        self.isDaily = isDaily
    }

    /// Backward-compatible decoding — older JSON without `isDaily` defaults to false.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        fileName = try container.decode(String.self, forKey: .fileName)
        relativePath = try container.decode(String.self, forKey: .relativePath)
        defaultHeading = try container.decodeIfPresent(String.self, forKey: .defaultHeading)
        displayName = try container.decode(String.self, forKey: .displayName)
        isDaily = try container.decodeIfPresent(Bool.self, forKey: .isDaily) ?? false
    }

    /// Factory for the built-in daily note.
    static func daily() -> PinnedNote {
        PinnedNote(fileName: "Daily.md", relativePath: "", displayName: "Daily", isDaily: true)
    }
}

enum NoteAction: String, Codable {
    case append
    case prepend
}

enum VaultStatus: Equatable {
    case notConfigured
    case valid
    case invalid
    case cliUnavailable
}

// MARK: - ObsidianManager

@Observable
final class ObsidianManager {
    static let shared = ObsidianManager()

    // MARK: - Public State

    var pinnedNotes: [PinnedNote] = []
    var selectedNoteID: UUID?
    var isVisible: Bool = false
    var isQuickPanelExpanded: Bool = false
    var isFullEditorExpanded: Bool = false
    var isEditingText: Bool = false
    var currentNoteContent: String = ""
    var currentNoteHeadings: [String] = []
    var selectedHeading: String?
    var inputText: String = ""
    var lastUsedAction: NoteAction = .append
    var vaultStatus: VaultStatus = .notConfigured
    var errorMessage: String?
    var hasExternalChanges: Bool = false
    var showSuccessFlash: Bool = false

    // MARK: - Computed

    var selectedNote: PinnedNote? {
        guard let id = selectedNoteID else { return nil }
        return pinnedNotes.first { $0.id == id }
    }

    var isUserEditingObsidian: Bool {
        isVisible || isQuickPanelExpanded || isFullEditorExpanded || isEditingText
    }

    // MARK: - Private State

    @ObservationIgnored
    var vaultPath: String {
        get { UserDefaults.standard.string(forKey: AppPreferenceKey.obsidianVaultPath) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: AppPreferenceKey.obsidianVaultPath) }
    }

    @ObservationIgnored
    private var useCLI: Bool {
        get { UserDefaults.standard.bool(forKey: AppPreferenceKey.obsidianUseCLI) }
        set { UserDefaults.standard.set(newValue, forKey: AppPreferenceKey.obsidianUseCLI) }
    }

    @ObservationIgnored
    private var lastSelectedNoteIDFromDefaults: UUID? {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: AppPreferenceKey.obsidianLastSelectedNoteID) else {
                return nil
            }
            return UUID(uuidString: rawValue)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.uuidString, forKey: AppPreferenceKey.obsidianLastSelectedNoteID)
            } else {
                UserDefaults.standard.removeObject(forKey: AppPreferenceKey.obsidianLastSelectedNoteID)
            }
        }
    }

    @ObservationIgnored private var obsidianHotkey: GlobalHotKey?
    @ObservationIgnored private var lastKnownModDates: [UUID: Date] = [:]
    @ObservationIgnored private var persistenceWorkItem: DispatchWorkItem?
    @ObservationIgnored private let persistenceQueue = DispatchQueue(label: "app.getdroppy.obsidian.persistence", qos: .utility)
    @ObservationIgnored private var changeDetectionTimer: Timer?

    private static let cliPath = "/Applications/Obsidian.app/Contents/MacOS/obsidian"
    private static let persistenceFileName = "obsidian_pinned.json"

    // MARK: - Lifecycle

    private init() {
        // Register defaults to match codebase convention
        UserDefaults.standard.register(defaults: [
            AppPreferenceKey.obsidianInstalled: PreferenceDefault.obsidianInstalled,
            AppPreferenceKey.obsidianEnabled: PreferenceDefault.obsidianEnabled,
            AppPreferenceKey.obsidianVaultPath: PreferenceDefault.obsidianVaultPath,
            AppPreferenceKey.obsidianUseCLI: PreferenceDefault.obsidianUseCLI,
            AppPreferenceKey.obsidianLastSelectedNoteID: PreferenceDefault.obsidianLastSelectedNoteID,
        ])
        loadPinnedNotes()
        validateVault()
        loadAndStartHotkey()
    }

    func show() {
        withAnimation(DroppyAnimation.smooth) {
            isVisible = true
            isFullEditorExpanded = false
        }

        openQuickPanelForLastUsedNoteIfNeeded()
    }

    func hide() {
        withAnimation(DroppyAnimation.smooth) {
            isVisible = false
            isQuickPanelExpanded = false
            isFullEditorExpanded = false
            isEditingText = false
        }
    }

    func cleanup() {
        hide()
        obsidianHotkey = nil
        persistenceWorkItem?.cancel()
        stopChangeDetection()
    }

    // MARK: - Note Selection

    func enterFullEditor() {
        if selectedNoteID == nil, let first = pinnedNotes.first {
            selectNote(first)
        }
        isFullEditorExpanded = true
    }

    func selectNote(_ note: PinnedNote) {
        selectedNoteID = note.id
        lastSelectedNoteIDFromDefaults = note.id
        selectedHeading = note.defaultHeading
        hasExternalChanges = false
        startChangeDetection()
        Task { @MainActor in
            await loadNoteContent(note)
        }
    }

    func deselectNote() {
        selectedNoteID = nil
        currentNoteContent = ""
        currentNoteHeadings = []
        selectedHeading = nil
        hasExternalChanges = false
        stopChangeDetection()
        withAnimation(DroppyAnimation.smooth) {
            isQuickPanelExpanded = false
            isFullEditorExpanded = false
        }
    }

    // MARK: - Pinned Notes Management

    func addPinnedNote(fileURL: URL) {
        guard !vaultPath.isEmpty else { return }
        let vaultURL = URL(fileURLWithPath: vaultPath)
        let relativePath = fileURL.path.replacingOccurrences(of: vaultURL.path + "/", with: "")
        let fileName = fileURL.lastPathComponent

        guard !pinnedNotes.contains(where: { $0.relativePath == relativePath }) else { return }

        let note = PinnedNote(fileName: fileName, relativePath: relativePath)
        pinnedNotes.append(note)
        scheduleSave()
    }

    func removePinnedNote(_ note: PinnedNote) {
        pinnedNotes.removeAll { $0.id == note.id }
        if selectedNoteID == note.id {
            deselectNote()
        }
        if lastSelectedNoteIDFromDefaults == note.id {
            lastSelectedNoteIDFromDefaults = pinnedNotes.first?.id
        }
        scheduleSave()
    }

    /// Re-add the built-in daily note (inserts at front).
    func addDailyNote() {
        guard !pinnedNotes.contains(where: { $0.isDaily }) else { return }
        pinnedNotes.insert(PinnedNote.daily(), at: 0)
        scheduleSave()
    }

    func updateDefaultHeading(for noteID: UUID, heading: String?) {
        guard let index = pinnedNotes.firstIndex(where: { $0.id == noteID }) else { return }
        pinnedNotes[index].defaultHeading = heading
        if selectedNoteID == noteID {
            selectedHeading = heading
        }
        scheduleSave()
    }

    func setSelectedHeading(_ heading: String?) {
        selectedHeading = heading
        guard let noteID = selectedNoteID else { return }
        updateDefaultHeading(for: noteID, heading: heading)
    }

    // MARK: - Vault Validation

    func validateVault() {
        guard !vaultPath.isEmpty else {
            vaultStatus = .notConfigured
            return
        }

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: vaultPath, isDirectory: &isDirectory)

        guard exists && isDirectory.boolValue else {
            vaultStatus = .invalid
            return
        }

        if useCLI && !FileManager.default.isExecutableFile(atPath: Self.cliPath) {
            vaultStatus = .cliUnavailable
            return
        }

        vaultStatus = .valid
    }

    func setVaultPath(_ path: String) {
        vaultPath = path
        validateVault()
    }

    // MARK: - Note Operations

    func loadNoteContent(_ note: PinnedNote) async {
        if note.isDaily {
            // Try CLI first, then fall back to filesystem
            if useCLI && vaultStatus != .cliUnavailable {
                do {
                    let content = try await runCLI(["daily:read"])
                    currentNoteContent = content
                    currentNoteHeadings = parseHeadings(from: content)
                    return
                } catch {
                    print("[Obsidian] CLI daily:read failed (\(error.localizedDescription)), falling back to filesystem")
                }
            }
            // Filesystem fallback for daily note
            guard let dailyPath = resolveDailyNotePath() else {
                errorMessage = "Could not resolve daily note path. Ensure today's daily note exists in your vault."
                return
            }
            do {
                let content = try String(contentsOfFile: dailyPath, encoding: .utf8)
                currentNoteContent = content
                currentNoteHeadings = parseHeadings(from: content)
            } catch {
                errorMessage = "Failed to read daily note: \(error.localizedDescription)"
            }
            return
        }

        let fullPath = (vaultPath as NSString).appendingPathComponent(note.relativePath)

        do {
            let content: String
            if useCLI && vaultStatus != .cliUnavailable {
                do {
                    content = try await runCLI(["read", "path=\(note.relativePath)"])
                } catch {
                    // CLI failed at runtime — fall back to filesystem
                    print("[Obsidian] CLI read failed (\(error.localizedDescription)), falling back to filesystem")
                    content = try String(contentsOfFile: fullPath, encoding: .utf8)
                }
            } else {
                content = try String(contentsOfFile: fullPath, encoding: .utf8)
            }
            currentNoteContent = content
            currentNoteHeadings = parseHeadings(from: content)
            updateModDate(for: note)
        } catch {
            errorMessage = "Failed to read note: \(error.localizedDescription)"
        }
    }

    func getHeadings(_ note: PinnedNote) async -> [String] {
        if note.isDaily {
            // Try CLI first, then fall back to filesystem
            if useCLI && vaultStatus != .cliUnavailable {
                do {
                    let content = try await runCLI(["daily:read"])
                    return parseHeadings(from: content)
                } catch {
                    print("[Obsidian] CLI daily:read failed for headings, falling back to filesystem")
                }
            }
            guard let dailyPath = resolveDailyNotePath() else { return [] }
            do {
                let content = try String(contentsOfFile: dailyPath, encoding: .utf8)
                return parseHeadings(from: content)
            } catch {
                return []
            }
        }

        let fullPath = (vaultPath as NSString).appendingPathComponent(note.relativePath)

        do {
            let content: String
            if useCLI && vaultStatus != .cliUnavailable {
                do {
                    content = try await runCLI(["read", "path=\(note.relativePath)"])
                } catch {
                    content = try String(contentsOfFile: fullPath, encoding: .utf8)
                }
            } else {
                content = try String(contentsOfFile: fullPath, encoding: .utf8)
            }
            return parseHeadings(from: content)
        } catch {
            return []
        }
    }

    func appendToHeading(_ note: PinnedNote, heading: String?, content: String) async -> Bool {
        if note.isDaily {
            // Try CLI first for non-heading appends, then fall back to filesystem
            if let heading {
                // CLI doesn't support heading targeting — resolve path and use filesystem
                guard let dailyPath = resolveDailyNotePath() else {
                    errorMessage = "Could not resolve daily note path. Ensure today's daily note exists."
                    return false
                }
                do {
                    try appendViaFileSystem(fullPath: dailyPath, heading: heading, content: content)
                    await loadNoteContent(note)
                    return true
                } catch {
                    errorMessage = "Append to daily note failed: \(error.localizedDescription)"
                    return false
                }
            } else if useCLI && vaultStatus != .cliUnavailable {
                do {
                    _ = try await runCLI(["daily:append", "content=\(content)"])
                    await loadNoteContent(note)
                    return true
                } catch {
                    print("[Obsidian] CLI daily:append failed (\(error.localizedDescription)), falling back to filesystem")
                }
            }
            // Filesystem fallback for non-heading append
            guard let dailyPath = resolveDailyNotePath() else {
                errorMessage = "Could not resolve daily note path. Ensure today's daily note exists."
                return false
            }
            do {
                try appendViaFileSystem(fullPath: dailyPath, heading: nil, content: content)
                await loadNoteContent(note)
                return true
            } catch {
                errorMessage = "Append to daily note failed: \(error.localizedDescription)"
                return false
            }
        }

        let fullPath = (vaultPath as NSString).appendingPathComponent(note.relativePath)

        do {
            if let heading {
                // CLI doesn't support heading targeting — use filesystem directly
                try appendViaFileSystem(fullPath: fullPath, heading: heading, content: content)
            } else if useCLI && vaultStatus != .cliUnavailable {
                do {
                    _ = try await runCLI(["append", "path=\(note.relativePath)", "content=\(content)"])
                } catch {
                    try appendViaFileSystem(fullPath: fullPath, heading: nil, content: content)
                }
            } else {
                try appendViaFileSystem(fullPath: fullPath, heading: nil, content: content)
            }
            await loadNoteContent(note)
            return true
        } catch {
            errorMessage = "Append failed: \(error.localizedDescription)"
            return false
        }
    }

    func prependToHeading(_ note: PinnedNote, heading: String?, content: String) async -> Bool {
        if note.isDaily {
            // Try CLI first for non-heading prepends, then fall back to filesystem
            if let heading {
                // CLI doesn't support heading targeting — resolve path and use filesystem
                guard let dailyPath = resolveDailyNotePath() else {
                    errorMessage = "Could not resolve daily note path. Ensure today's daily note exists."
                    return false
                }
                do {
                    try prependViaFileSystem(fullPath: dailyPath, heading: heading, content: content)
                    await loadNoteContent(note)
                    return true
                } catch {
                    errorMessage = "Prepend to daily note failed: \(error.localizedDescription)"
                    return false
                }
            } else if useCLI && vaultStatus != .cliUnavailable {
                do {
                    _ = try await runCLI(["daily:prepend", "content=\(content)"])
                    await loadNoteContent(note)
                    return true
                } catch {
                    print("[Obsidian] CLI daily:prepend failed (\(error.localizedDescription)), falling back to filesystem")
                }
            }
            // Filesystem fallback for non-heading prepend
            guard let dailyPath = resolveDailyNotePath() else {
                errorMessage = "Could not resolve daily note path. Ensure today's daily note exists."
                return false
            }
            do {
                try prependViaFileSystem(fullPath: dailyPath, heading: nil, content: content)
                await loadNoteContent(note)
                return true
            } catch {
                errorMessage = "Prepend to daily note failed: \(error.localizedDescription)"
                return false
            }
        }

        let fullPath = (vaultPath as NSString).appendingPathComponent(note.relativePath)

        do {
            if let heading {
                // CLI doesn't support heading targeting — use filesystem directly
                try prependViaFileSystem(fullPath: fullPath, heading: heading, content: content)
            } else if useCLI && vaultStatus != .cliUnavailable {
                do {
                    _ = try await runCLI(["prepend", "path=\(note.relativePath)", "content=\(content)"])
                } catch {
                    try prependViaFileSystem(fullPath: fullPath, heading: nil, content: content)
                }
            } else {
                try prependViaFileSystem(fullPath: fullPath, heading: nil, content: content)
            }
            await loadNoteContent(note)
            return true
        } catch {
            errorMessage = "Prepend failed: \(error.localizedDescription)"
            return false
        }
    }

    func writeFullNote(_ note: PinnedNote, content: String) async -> Bool {
        if note.isDaily {
            errorMessage = "Daily notes cannot be saved directly — use append or prepend."
            return false
        }

        let fullPath = (vaultPath as NSString).appendingPathComponent(note.relativePath)

        do {
            try content.write(toFile: fullPath, atomically: true, encoding: .utf8)
            currentNoteContent = content
            updateModDate(for: note)
            return true
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
            return false
        }
    }

    /// Perform the last-used action (append or prepend) for quick repeat.
    func performAction(on note: PinnedNote) async -> Bool {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let text = inputText
        let success: Bool
        switch lastUsedAction {
        case .append:
            success = await appendToHeading(note, heading: selectedHeading, content: text)
        case .prepend:
            success = await prependToHeading(note, heading: selectedHeading, content: text)
        }
        if success {
            inputText = ""
            showSuccessFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.showSuccessFlash = false
            }
        }
        return success
    }

    // MARK: - External Change Detection

    func checkForExternalChanges(_ note: PinnedNote) {
        if note.isDaily { return }
        let fullPath = (vaultPath as NSString).appendingPathComponent(note.relativePath)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
              let modDate = attrs[.modificationDate] as? Date else { return }

        if let lastKnown = lastKnownModDates[note.id], modDate > lastKnown {
            hasExternalChanges = true
        }
    }

    func reloadCurrentNote() async {
        guard let note = selectedNote else { return }
        hasExternalChanges = false
        await loadNoteContent(note)
    }

    /// Check if a pinned note still exists on disk. Daily notes are always "present".
    func noteExists(_ note: PinnedNote) -> Bool {
        if note.isDaily { return true }
        let fullPath = (vaultPath as NSString).appendingPathComponent(note.relativePath)
        return FileManager.default.fileExists(atPath: fullPath)
    }

    // MARK: - Global Hotkey

    func loadAndStartHotkey() {
        guard let data = UserDefaults.standard.data(forKey: AppPreferenceKey.obsidianShortcut),
              let shortcut = try? JSONDecoder().decode(SavedShortcut.self, from: data) else { return }

        obsidianHotkey = GlobalHotKey(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) { [weak self] in
            self?.activateFromHotkey()
        }
    }

    func activateFromHotkey() {
        NotificationCenter.default.post(name: .obsidianHotkeyTriggered, object: nil)
    }

    func updateShortcut(_ shortcut: SavedShortcut?) {
        obsidianHotkey = nil  // Deregister old
        guard let shortcut else {
            UserDefaults.standard.removeObject(forKey: AppPreferenceKey.obsidianShortcut)
            return
        }
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: AppPreferenceKey.obsidianShortcut)
        }
        loadAndStartHotkey()
    }

    private func preferredQuickPanelNote() -> PinnedNote? {
        if let selectedNoteID,
           let currentSelection = pinnedNotes.first(where: { $0.id == selectedNoteID }) {
            return currentSelection
        }

        if let persistedSelectionID = lastSelectedNoteIDFromDefaults,
           let persistedSelection = pinnedNotes.first(where: { $0.id == persistedSelectionID }) {
            return persistedSelection
        }

        return pinnedNotes.first
    }

    private func openQuickPanelForLastUsedNoteIfNeeded() {
        guard let noteToOpen = preferredQuickPanelNote() else { return }

        if selectedNoteID != noteToOpen.id || currentNoteContent.isEmpty {
            selectNote(noteToOpen)
        } else {
            selectedHeading = noteToOpen.defaultHeading
            hasExternalChanges = false
            startChangeDetection()
            // Refresh content so it's never stale when re-opening
            Task { @MainActor in
                await loadNoteContent(noteToOpen)
            }
        }

        withAnimation(DroppyAnimation.smooth) {
            isQuickPanelExpanded = true
        }
    }

    // MARK: - Private — External Change Detection

    private func startChangeDetection() {
        stopChangeDetection()
        changeDetectionTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self, let note = self.selectedNote else { return }
            self.checkForExternalChanges(note)
        }
    }

    private func stopChangeDetection() {
        changeDetectionTimer?.invalidate()
        changeDetectionTimer = nil
    }

    // MARK: - Private — Persistence

    private var persistenceFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let droppyDir = appSupport.appendingPathComponent("Droppy")
        return droppyDir.appendingPathComponent(Self.persistenceFileName)
    }

    private func loadPinnedNotes() {
        let url = persistenceFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            // First launch — seed with the built-in daily note
            pinnedNotes = [PinnedNote.daily()]
            scheduleSave()
            return
        }

        do {
            let data = try Data(contentsOf: url)
            pinnedNotes = try JSONDecoder().decode([PinnedNote].self, from: data)
            if let persistedSelectionID = lastSelectedNoteIDFromDefaults,
               !pinnedNotes.contains(where: { $0.id == persistedSelectionID }) {
                lastSelectedNoteIDFromDefaults = pinnedNotes.first?.id
            }
        } catch {
            print("[Obsidian] Failed to load pinned notes: \(error)")
        }
    }

    private func savePinnedNotes() {
        let url = persistenceFileURL
        do {
            // Ensure directory exists
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(pinnedNotes)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[Obsidian] Failed to save pinned notes: \(error)")
        }
    }

    private func scheduleSave() {
        persistenceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.savePinnedNotes()
        }
        persistenceWorkItem = workItem
        persistenceQueue.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }

    /// Resolves the daily note's absolute filesystem path from the vault's daily-notes config.
    private func resolveDailyNotePath() -> String? {
        let configPath = (vaultPath as NSString).appendingPathComponent(".obsidian/daily-notes.json")

        var folder = ""
        var momentFormat = "YYYY-MM-DD"

        if let data = FileManager.default.contents(atPath: configPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let f = json["folder"] as? String { folder = f }
            if let fmt = json["format"] as? String, !fmt.isEmpty { momentFormat = fmt }
        } else {
            // No config found — use Obsidian defaults
        }

        // Convert Moment.js format tokens to Swift DateFormatter tokens
        let swiftFormat = momentFormat
            .replacingOccurrences(of: "YYYY", with: "yyyy")
            .replacingOccurrences(of: "YY", with: "yy")
            .replacingOccurrences(of: "DD", with: "dd")
            .replacingOccurrences(of: "Do", with: "d")

        let formatter = DateFormatter()
        formatter.dateFormat = swiftFormat
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let datePart = formatter.string(from: Date())

        var relativePath = folder.isEmpty ? datePart : folder + "/" + datePart
        if !relativePath.hasSuffix(".md") { relativePath += ".md" }

        let fullPath = (vaultPath as NSString).appendingPathComponent(relativePath)

        guard FileManager.default.fileExists(atPath: fullPath) else { return nil }

        return fullPath
    }

    // MARK: - Private — Filesystem Operations

    private func parseHeadings(from content: String) -> [String] {
        let lines = content.components(separatedBy: "\n")
        var headings: [String] = []
        var inCodeBlock = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("```") {
                inCodeBlock.toggle()
                continue
            }
            if !inCodeBlock, let match = trimmed.range(of: #"^#{1,6}\s+(.+)$"#, options: .regularExpression) {
                headings.append(String(trimmed[match]))
            }
        }
        return headings
    }

    private func appendViaFileSystem(fullPath: String, heading: String?, content: String) throws {
        let fileContent = try String(contentsOfFile: fullPath, encoding: .utf8)
        let updatedContent = contentByAppending(fileContent, heading: heading, content: content)
        try updatedContent.write(toFile: fullPath, atomically: true, encoding: .utf8)
    }

    private func prependViaFileSystem(fullPath: String, heading: String?, content: String) throws {
        let fileContent = try String(contentsOfFile: fullPath, encoding: .utf8)
        let updatedContent = contentByPrepending(fileContent, heading: heading, content: content)
        try updatedContent.write(toFile: fullPath, atomically: true, encoding: .utf8)
    }

    private func contentByAppending(_ fileContent: String, heading: String?, content: String) -> String {
        guard let heading else {
            var updated = fileContent
            if !updated.hasSuffix("\n") { updated += "\n" }
            updated += content + "\n"
            return updated
        }

        let lines = fileContent.components(separatedBy: "\n")
        var insertIndex = lines.count
        var foundHeading = false
        var inCodeBlock = false

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("```") {
                inCodeBlock.toggle()
                continue
            }
            guard !inCodeBlock else { continue }
            if !foundHeading {
                if trimmed == heading {
                    foundHeading = true
                }
            } else if isHeadingSectionBoundaryLine(trimmed) {
                insertIndex = i
                break
            }
        }

        var mutableLines = lines
        mutableLines.insert(content, at: insertIndex)
        return mutableLines.joined(separator: "\n")
    }

    private func contentByPrepending(_ fileContent: String, heading: String?, content: String) -> String {
        let lines = fileContent.components(separatedBy: "\n")

        guard let heading else {
            let insertIndex = frontmatterEndIndex(in: lines)
            var mutableLines = lines
            mutableLines.insert(content, at: insertIndex)
            return mutableLines.joined(separator: "\n")
        }

        var insertIndex = 0
        var foundHeading = false
        var inCodeBlock = false

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("```") {
                inCodeBlock.toggle()
                continue
            }
            guard !inCodeBlock else { continue }
            if trimmed == heading {
                foundHeading = true
                insertIndex = i + 1
                break
            }
        }

        if !foundHeading {
            // Heading not found — prepend after frontmatter if present
            insertIndex = frontmatterEndIndex(in: lines)
        }

        var mutableLines = lines
        mutableLines.insert(content, at: insertIndex)
        return mutableLines.joined(separator: "\n")
    }

    private func isHeadingSectionBoundaryLine(_ trimmedLine: String) -> Bool {
        if isMarkdownHeadingLine(trimmedLine) { return true }
        let collapsed = trimmedLine.replacingOccurrences(of: " ", with: "")
        return collapsed == "---"
    }

    private func isMarkdownHeadingLine(_ trimmedLine: String) -> Bool {
        trimmedLine.range(of: #"^#{1,6}\s+.+$"#, options: .regularExpression) != nil
    }

    /// Returns the line index immediately after YAML frontmatter, or 0 if none.
    private func frontmatterEndIndex(in lines: [String]) -> Int {
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else { return 0 }
        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                return i + 1
            }
        }
        return 0
    }

    private func updateModDate(for note: PinnedNote) {
        if note.isDaily { return }
        let fullPath = (vaultPath as NSString).appendingPathComponent(note.relativePath)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
           let modDate = attrs[.modificationDate] as? Date {
            lastKnownModDates[note.id] = modDate
        }
    }

    // MARK: - Private — CLI Execution

    private func runCLI(_ arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            // Run via shell to avoid _RegisterApplication crash when Obsidian is already
            // running. Launching the Electron binary directly from a macOS app (Process())
            // inherits AppKit context that triggers a duplicate WindowServer registration.
            // Running through a login shell matches the terminal context where the CLI's
            // single-instance IPC works correctly.
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")

            // Prepend vault= parameter so the CLI targets the correct vault
            var args = arguments
            if !vaultPath.isEmpty {
                let vaultName = URL(fileURLWithPath: vaultPath).lastPathComponent
                args.insert("vault=\(vaultName)", at: 0)
            }

            // Shell-escape each argument and build a single command string
            let escapedArgs = args.map { arg -> String in
                let escaped = arg.replacingOccurrences(of: "'", with: "'\\''")
                return "'\(escaped)'"
            }
            let command = "\(Self.cliPath) \(escapedArgs.joined(separator: " "))"
            process.arguments = ["-l", "-c", command]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            let outputHandle = outputPipe.fileHandleForReading
            let errorHandle = errorPipe.fileHandleForReading

            // Timeout after 5 seconds
            let timeoutWorkItem = DispatchWorkItem {
                if process.isRunning { process.terminate() }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: timeoutWorkItem)

            do {
                // Use terminationHandler instead of blocking waitUntilExit to avoid deadlock
                process.terminationHandler = { terminatedProcess in
                    timeoutWorkItem.cancel()

                    // Read pipe data in terminationHandler (process already exited, safe to drain)
                    let outputData = outputHandle.readDataToEndOfFile()
                    let errorData = errorHandle.readDataToEndOfFile()

                    if terminatedProcess.terminationStatus == 0 {
                        let rawOutput = String(data: outputData, encoding: .utf8) ?? ""
                        // Strip Obsidian's startup log line from stdout
                        let output = rawOutput
                            .components(separatedBy: "\n")
                            .filter { !$0.contains("Loading updated app package") }
                            .joined(separator: "\n")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        continuation.resume(returning: output)
                    } else {
                        let errorString = String(data: errorData, encoding: .utf8) ?? "CLI error"
                        continuation.resume(throwing: NSError(
                            domain: "ObsidianCLI",
                            code: Int(terminatedProcess.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: errorString]
                        ))
                    }
                }
                try process.run()
            } catch {
                timeoutWorkItem.cancel()
                continuation.resume(throwing: error)
            }
        }
    }
}
