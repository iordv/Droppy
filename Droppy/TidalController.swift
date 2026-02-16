//
//  TidalController.swift
//  Droppy
//
//  Tidal-specific media controls using System Events UI scripting
//  Tidal has no AppleScript dictionary, so all controls go through System Events
//

import AppKit
import Foundation

/// Manages Tidal-specific features including shuffle, repeat, and like functionality
/// Uses System Events UI scripting for local controls and LRCLIB for lyrics
@Observable
final class TidalController {
    static let shared = TidalController()

    // MARK: - State

    /// Whether shuffle is currently enabled in Tidal
    private(set) var shuffleEnabled: Bool = false

    /// Current repeat mode in Tidal
    private(set) var repeatMode: RepeatMode = .off

    /// Whether the current track is liked (in user's favorites)
    private(set) var isCurrentTrackLiked: Bool = false

    /// Whether we're currently checking/updating liked status
    private(set) var isLikeLoading: Bool = false

    // MARK: - Lyrics State

    /// Parsed synced lyrics for the current track
    private(set) var lyricsLines: [(time: TimeInterval, text: String)]?

    /// The current lyric line matching playback position
    private(set) var currentLyricLine: String?

    /// Whether lyrics display is enabled
    var showingLyrics: Bool = false

    /// The title+artist key for the last track we fetched lyrics for
    private var lastLyricsKey: String?

    /// Tidal bundle identifier
    static let tidalBundleId = "com.tidal.desktop"

    /// Serial queue for AppleScript execution - NSAppleScript is NOT thread-safe
    private let appleScriptQueue = DispatchQueue(label: "com.droppy.TidalController.applescript")

    // MARK: - Repeat Mode

    enum RepeatMode: String, CaseIterable {
        case off = "off"
        case context = "context"  // Repeat playlist/album
        case track = "track"      // Repeat single track

        var displayName: String {
            switch self {
            case .off: return "Off"
            case .context: return "All"
            case .track: return "One"
            }
        }

        var iconName: String {
            switch self {
            case .off: return "repeat"
            case .context: return "repeat"
            case .track: return "repeat.1"
            }
        }

        var next: RepeatMode {
            switch self {
            case .off: return .context
            case .context: return .track
            case .track: return .off
            }
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Tidal Detection

    /// Check if Tidal is currently running (and extension is enabled)
    var isTidalRunning: Bool {
        guard !ExtensionType.tidal.isRemoved else { return false }
        return NSRunningApplication.runningApplications(withBundleIdentifier: Self.tidalBundleId).first != nil
    }

    /// Refresh state when Tidal becomes the active source
    func refreshState() {
        guard !ExtensionType.tidal.isRemoved else { return }
        guard isTidalRunning else { return }

        // Track Tidal integration activation (only once per user)
        if !UserDefaults.standard.bool(forKey: "tidalTracked") {
            AnalyticsService.shared.trackExtensionActivation(extensionId: "tidal")
        }

        fetchShuffleState()
        fetchRepeatState()
        fetchLikedState()

        // Fetch lyrics for current track if not yet fetched
        let manager = MusicManager.shared
        if !manager.songTitle.isEmpty {
            onTrackChange(title: manager.songTitle, artist: manager.artistName)
        }
    }

    /// Called when track changes - fetch lyrics and update liked state
    /// No OAuth needed: lyrics use LRCLIB, like state uses AppleScript
    func onTrackChange(title: String, artist: String) {
        let key = "\(title)|\(artist)".lowercased()

        // Skip if same track
        guard key != lastLyricsKey else { return }

        // Set immediately to prevent duplicate calls from rapid notifications
        lastLyricsKey = key

        // Clear previous track data
        currentLyricLine = nil
        lyricsLines = nil

        // Check liked state via menu checkmark (AppleScript, no auth)
        fetchLikedState()

        // Fetch lyrics via LRCLIB (free, no auth needed)
        let manager = MusicManager.shared
        let duration = Int(manager.songDuration)
        guard !title.isEmpty, duration > 0 else { return }

        TidalAuthManager.shared.fetchLyrics(
            title: title,
            artist: artist,
            album: manager.albumName,
            duration: duration
        ) { [weak self] lrcText, _ in
            DispatchQueue.main.async {
                if let lrcText = lrcText {
                    self?.lyricsLines = TidalLyricsParser.parse(lrcText)
                } else {
                    self?.lyricsLines = nil
                }
            }
        }
    }

    /// Update the current lyric line based on playback position
    func updateCurrentLyric(at elapsed: TimeInterval) {
        guard showingLyrics, let lines = lyricsLines, !lines.isEmpty else {
            if currentLyricLine != nil { currentLyricLine = nil }
            return
        }

        // Find the last line whose timestamp <= elapsed
        var matchedLine: String?
        for line in lines {
            if line.time <= elapsed {
                matchedLine = line.text
            } else {
                break
            }
        }

        if matchedLine != currentLyricLine {
            currentLyricLine = matchedLine
        }
    }

    // MARK: - System Events AppleScript Controls
    // Tidal has NO AppleScript dictionary. All controls go through System Events
    // by clicking menu bar items via accessibility (UI scripting).

    /// Toggle shuffle on/off via Playback menu
    func toggleShuffle() {
        let script = """
        tell application "System Events"
            tell process "TIDAL"
                click menu item "Shuffle" of menu "Playback" of menu bar 1
            end tell
        end tell
        """

        runAppleScript(script) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.fetchShuffleState()
            }
        }
    }

    /// Cycle through repeat modes via Playback menu
    /// Tidal's Repeat menu item cycles: off -> all -> one -> off
    func cycleRepeatMode() {
        let script = """
        tell application "System Events"
            tell process "TIDAL"
                click menu item "Repeat" of menu "Playback" of menu bar 1
            end tell
        end tell
        """

        runAppleScript(script) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Cycle local state since we can't reliably read the exact mode
                DispatchQueue.main.async {
                    self?.repeatMode = self?.repeatMode.next ?? .off
                }
            }
        }
    }

    // MARK: - State Fetching

    /// Read shuffle state from Tidal's Playback menu checkmark
    private func fetchShuffleState() {
        let script = """
        tell application "System Events"
            tell process "TIDAL"
                set shuffleItem to menu item "Shuffle" of menu "Playback" of menu bar 1
                try
                    set markChar to value of attribute "AXMenuItemMarkChar" of shuffleItem
                    if markChar is not missing value then
                        return "on"
                    else
                        return "off"
                    end if
                on error
                    return "off"
                end try
            end tell
        end tell
        """

        runAppleScript(script) { [weak self] result in
            if let state = result as? String {
                DispatchQueue.main.async {
                    self?.shuffleEnabled = (state == "on")
                }
            }
        }
    }

    /// Read repeat state from Tidal's Playback menu
    /// Note: System Events can detect if Repeat has a checkmark but not which mode
    private func fetchRepeatState() {
        let script = """
        tell application "System Events"
            tell process "TIDAL"
                set repeatItem to menu item "Repeat" of menu "Playback" of menu bar 1
                try
                    set markChar to value of attribute "AXMenuItemMarkChar" of repeatItem
                    if markChar is not missing value then
                        return "on"
                    else
                        return "off"
                    end if
                on error
                    return "off"
                end try
            end tell
        end tell
        """

        runAppleScript(script) { [weak self] result in
            if let state = result as? String {
                DispatchQueue.main.async {
                    // We can only detect on/off from menu checkmark
                    // Default to .context when on, since we can't distinguish
                    self?.repeatMode = (state == "on") ? .context : .off
                }
            }
        }
    }

    // MARK: - AppleScript Execution

    private func runAppleScript(_ source: String, completion: @escaping (Any?) -> Void) {
        // Fast check: if accessibility isn't granted, prompt and skip the script
        if !AXIsProcessTrusted() {
            DispatchQueue.main.async {
                PermissionManager.shared.requestAccessibility(context: .automatic)
            }
            completion(nil)
            return
        }

        appleScriptQueue.async {
            let parsed: Any? = AppleScriptRuntime.execute {
                var error: NSDictionary?

                guard let script = NSAppleScript(source: source) else {
                    print("TidalController: Failed to create AppleScript")
                    return nil
                }

                let result = script.executeAndReturnError(&error)

                if let error = error {
                    // Detect assistive access error and prompt user
                    if let message = error["NSAppleScriptErrorBriefMessage"] as? String,
                       message.contains("assistive access") {
                        DispatchQueue.main.async {
                            PermissionManager.shared.requestAccessibility(context: .automatic)
                        }
                    }
                    print("TidalController: AppleScript error: \(error)")
                    return nil
                }

                // System Events scripts typically return strings
                switch result.descriptorType {
                case typeTrue:
                    return true
                case typeFalse:
                    return false
                default:
                    return result.stringValue
                }
            }

            DispatchQueue.main.async { completion(parsed) }
        }
    }

    // MARK: - Like via AppleScript (System Events)

    /// Toggle like/favorite for the current track via Tidal's Playback menu
    func toggleLike() {
        let script = """
        tell application "System Events"
            tell process "TIDAL"
                click menu item "Favorite" of menu "Playback" of menu bar 1
            end tell
        end tell
        """

        runAppleScript(script) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.fetchLikedState()
            }
        }
    }

    /// Read liked state from Tidal's Playback > Favorite menu checkmark
    func fetchLikedState() {
        let script = """
        tell application "System Events"
            tell process "TIDAL"
                set favItem to menu item "Favorite" of menu "Playback" of menu bar 1
                try
                    set markChar to value of attribute "AXMenuItemMarkChar" of favItem
                    if markChar is not missing value then
                        return "on"
                    else
                        return "off"
                    end if
                on error
                    return "off"
                end try
            end tell
        end tell
        """

        runAppleScript(script) { [weak self] result in
            if let state = result as? String {
                DispatchQueue.main.async {
                    self?.isCurrentTrackLiked = (state == "on")
                }
            }
        }
    }

    /// Reset state when extension is removed
    func resetState() {
        isCurrentTrackLiked = false
        lyricsLines = nil
        currentLyricLine = nil
        lastLyricsKey = nil
    }
}
