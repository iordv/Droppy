//
//  MusicManager.swift
//  Droppy
//
//  Created by Droppy on 05/01/2026.
//  Now Playing media integration using MediaRemoteAdapter framework
//  Uses process-based approach to bypass macOS 15.4 restrictions
//

import AppKit
import Combine
import Foundation
import SwiftUI

// MARK: - NowPlaying Update JSON Model

/// Represents an update from the MediaRemoteAdapter
private struct NowPlayingUpdate: Codable {
    let type: String?
    let payload: NowPlayingPayload
    let diff: Bool?
    
    struct NowPlayingPayload: Codable {
        let title: String?
        let artist: String?
        let album: String?
        let duration: Double?
        let elapsedTime: Double?
        let playbackRate: Double?
        let bundleIdentifier: String?
        let parentApplicationBundleIdentifier: String?  // Parent app (e.g., Safari for WebKit.GPU)
        let processIdentifier: Int?
        let artworkData: String?  // Base64 encoded
        let timestamp: String?    // ISO 8601 format: "2026-01-05T18:56:59Z"
        let playing: Bool?        // Explicit playing state from JSON
        
        /// Get isPlaying preferring explicit 'playing' field, fallback to playbackRate
        var isPlaying: Bool {
            playing ?? ((playbackRate ?? 0) > 0)
        }
        
        /// Get the launchable app bundle ID (prefer parent for WebKit processes)
        var launchableBundleIdentifier: String? {
            // WebKit.GPU and similar are not launchable, use parent app
            if let bundle = bundleIdentifier, bundle.contains("WebKit") {
                return parentApplicationBundleIdentifier ?? bundleIdentifier
            }
            return bundleIdentifier
        }
    }
}

/// Manages Now Playing media information and playback control
/// Uses MediaRemoteAdapter framework via external process for macOS 15.4+ compatibility
final class MusicManager: ObservableObject {
    static let shared = MusicManager()
    
    // MARK: - Media Availability
    /// Whether media features are available (requires macOS 15.0+ due to MediaRemoteAdapter framework)
    @Published private(set) var isMediaAvailable: Bool = false
    
    // MARK: - Published Properties
    @Published private(set) var songTitle: String = ""
    @Published private(set) var artistName: String = ""
    @Published private(set) var albumName: String = ""
    @Published private(set) var albumArt: NSImage = NSImage() {
        didSet {
            // Cache dominant color when album art changes to avoid expensive recalculation on every view body
            updateCachedVisualizerColor()
        }
    }
    
    /// Cached dominant color from album art for visualizer
    /// PERFORMANCE: Computed once per track change, not on every view body evaluation
    @Published private(set) var visualizerColor: Color = .white.opacity(0.7)
    @Published private(set) var isPlaying: Bool = false {
        didSet {
            if oldValue && !isPlaying {
                // Was playing, now paused - start the "recently playing" timer
                wasRecentlyPlaying = true
                recentlyPlayingTimer?.invalidate()
                recentlyPlayingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.wasRecentlyPlaying = false
                    }
                }
                
                // FIX #95: When a non-Spotify source pauses, check if Spotify is playing in background
                // macOS doesn't automatically switch Now Playing back, so we check manually
                let isSpotifyBundle = bundleIdentifier == SpotifyController.spotifyBundleId
                
                if !isSpotifyBundle {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        SpotifyController.shared.isSpotifyPlaying { isSpotifyPlaying in
                            if isSpotifyPlaying {
                                // Spotify is playing in background - switch to it
                                self?.forceUpdateFromSpotify()
                            }
                        }
                    }
                }
            } else if isPlaying {
                // Started playing again - cancel timer and keep visible
                recentlyPlayingTimer?.invalidate()
                recentlyPlayingTimer = nil
                wasRecentlyPlaying = false
            }
        }
    }
    @Published private(set) var songDuration: Double = 0
    @Published private(set) var elapsedTime: Double = 0
    @Published private(set) var playbackRate: Double = 1.0
    @Published private(set) var timestampDate: Date = .distantPast
    @Published private(set) var bundleIdentifier: String?
    
    /// Direction of last track skip for directional album art flip
    enum SkipDirection {
        case forward, backward, none
    }
    @Published private(set) var lastSkipDirection: SkipDirection = .none
    
    /// Whether media HUD is manually shown via swipe gesture (overrides auto-show logic)
    /// When true, shows media player even when paused (as long as there's a track to show)
    @Published var isMediaHUDForced: Bool = false
    
    /// Whether media HUD is manually hidden via swipe gesture (even when playing)
    /// This allows users to swipe away from the media player to see the shelf
    @Published var isMediaHUDHidden: Bool = false
    
    /// FIX #95: Flag to bypass HUD visibility safeguards (transition/debounce)
    /// when forcing a source switch from Spotify fallback
    @Published var isMediaSourceForced: Bool = false
    private var sourceForceResetTimer: Timer?
    
    // MARK: - FIX #128: Track Change Debouncing
    /// Debounce timer for track metadata changes to prevent flicker during video seeking
    private var metadataDebounceTimer: Timer?
    /// Pending metadata update waiting for debounce stabilization
    private var pendingMetadataUpdate: (title: String, artist: String, album: String, bundleId: String?)?
    /// Last applied metadata signature to detect true track changes
    private var lastAppliedMetadataSignature: String = ""

    // MARK: - Media Source Filter

    /// Whether media source filtering is enabled
    /// When enabled, only bundle identifiers in the allowed list will be shown
    private var isMediaSourceFilterEnabled: Bool {
        UserDefaults.standard.preference(
            AppPreferenceKey.mediaSourceFilterEnabled,
            default: PreferenceDefault.mediaSourceFilterEnabled
        )
    }

    /// Set of allowed bundle identifiers for media source filtering
    /// Empty set means no filter (show all sources)
    private var allowedMediaBundles: Set<String> {
        let jsonString = UserDefaults.standard.preference(
            AppPreferenceKey.mediaSourceAllowedBundles,
            default: PreferenceDefault.mediaSourceAllowedBundles
        )
        guard let data = jsonString.data(using: .utf8) else { return [] }

        // Try new format (dictionary: bundleId -> appName)
        if let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            return Set(dict.keys)
        }

        // Fallback to old format (array of bundleIds)
        if let array = try? JSONDecoder().decode([String].self, from: data) {
            return Set(array)
        }

        return []
    }

    /// Check if a bundle identifier is allowed by the media source filter
    /// Returns true if filter is disabled, or if the bundle is in the allowed list
    private func isBundleAllowed(_ bundleId: String?) -> Bool {
        guard isMediaSourceFilterEnabled else { return true }
        guard let bundleId = bundleId else { return false }
        let allowed = allowedMediaBundles
        if allowed.isEmpty { return true }  // Empty list = no filter
        return allowed.contains(bundleId)
    }

    // MARK: - Incognito Browser Filtering

    /// Whether to hide media from incognito/private browsing windows
    private var hideIncognitoBrowserMedia: Bool {
        UserDefaults.standard.preference(
            AppPreferenceKey.hideIncognitoBrowserMedia,
            default: PreferenceDefault.hideIncognitoBrowserMedia
        )
    }

    /// Check if the current media source is from an incognito/private browsing window
    /// Uses AppleScript to detect incognito windows in common browsers
    private func isFromIncognitoBrowser(_ bundleId: String?) -> Bool {
        guard hideIncognitoBrowserMedia else { return false }
        guard let bundleId = bundleId, isBrowserBundle(bundleId) else { return false }
        
        // Check each browser for incognito/private mode using AppleScript
        var script: String
        
        switch bundleId {
        case "com.google.Chrome", "com.brave.Browser", "com.microsoft.edgemac":
            // Chromium-based browsers - check for incognito mode
            let appName = getAppName(from: bundleId) ?? "Google Chrome"
            script = """
            tell application "\(appName)"
                repeat with w in windows
                    if mode of w is "incognito" then
                        return "incognito"
                    end if
                end repeat
            end tell
            return "normal"
            """
        case "com.apple.Safari":
            // Safari - check for private browsing windows
            script = """
            tell application "Safari"
                repeat with w in windows
                    if name of w contains "Private" then
                        return "private"
                    end if
                end repeat
            end tell
            return "normal"
            """
        case "org.mozilla.firefox":
            // Firefox - check for private browsing windows
            script = """
            tell application "Firefox"
                repeat with w in windows
                    if name of w contains "Private" then
                        return "private"
                    end if
                end repeat
            end tell
            return "normal"
            """
        case "company.thebrowser.Browser":
            // Arc - check for incognito spaces
            script = """
            tell application "Arc"
                repeat with w in windows
                    if incognito of w then
                        return "incognito"
                    end if
                end repeat
            end tell
            return "normal"
            """
        default:
            return false
        }
        
        // Execute synchronously to check incognito status
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script),
           let result = appleScript.executeAndReturnError(&error).stringValue {
            return result == "incognito" || result == "private"
        }
        
        return false
    }

    /// Track previously detected media sources for settings UI
    @Published private(set) var detectedMediaSources: [MediaSourceInfo] = []

    /// Information about a detected media source
    struct MediaSourceInfo: Identifiable, Hashable {
        let id: String  // bundleIdentifier
        let name: String
        let bundleIdentifier: String

        func hash(into hasher: inout Hasher) {
            hasher.combine(bundleIdentifier)
        }

        static func == (lhs: MediaSourceInfo, rhs: MediaSourceInfo) -> Bool {
            lhs.bundleIdentifier == rhs.bundleIdentifier
        }
    }

    /// Ensure the specified source's app is active before sending playback commands
    /// This is used when filtering to ensure commands go to the displayed app, not the system's active source
    private func ensureDisplayedSourceActive(forBundle displayedBundle: String, completion: @escaping () -> Void) {
        // Check if the displayed source app is running
        let isDisplayedAppRunning = NSRunningApplication.runningApplications(withBundleIdentifier: displayedBundle).first != nil

        if !isDisplayedAppRunning {
            // App is not running - launch it first, then send command
            print("MusicManager: Launching filtered source app: \(displayedBundle)")
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: displayedBundle) {
                NSWorkspace.shared.openApplication(at: appURL, configuration: .init()) { _, error in
                    if let error = error {
                        print("MusicManager: Failed to launch app: \(error)")
                    }
                    // Wait a moment for app to initialize, then send command
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        completion()
                    }
                }
                return
            }
        }

        // App is running, activate it to ensure it receives the command
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: displayedBundle).first {
            app.activate()
        }

        // Small delay to ensure activation, then proceed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion()
        }
    }

    /// WebCatalog YouTube Music bundle identifier
    private static let youTubeMusicWebCatalogBundleId = "com.webcatalog.juli.youtube-music"

    /// Send play/pause command directly to an app via AppleScript
    /// This is more reliable than MediaRemote when the app is not the active Now Playing source
    private func sendPlayPauseViaAppleScript(to bundleId: String) {
        // Native apps with AppleScript support
        if bundleId == SpotifyController.spotifyBundleId {
            runAppleScriptAsync("tell application \"Spotify\" to playpause")
            return
        }
        if bundleId == AppleMusicController.appleMusicBundleId {
            runAppleScriptAsync("tell application \"Music\" to playpause")
            return
        }

        // WebCatalog YouTube Music: activate and send space key
        if bundleId == Self.youTubeMusicWebCatalogBundleId {
            activateAppAndSendKey(appName: "YouTube Music", key: " ")
            return
        }

        // Browser-based sources: find tab, activate, and send space key
        if isBrowserBundle(bundleId) {
            activateBrowserTabAndSendKey(bundleId: bundleId, key: " ") // Space for play/pause
            return
        }

        // For other apps, fall back to MediaRemote
        if let sendCommand = MRMediaRemoteSendCommandPtr {
            sendCommand(MRCommand.togglePlayPause.rawValue, nil)
        }
    }

    /// Activate an app by name and send a key
    private func activateAppAndSendKey(appName: String, key: String) {
        let script = """
        tell application "\(appName)"
            activate
        end tell
        delay 0.3
        tell application "System Events"
            keystroke "\(key)"
        end tell
        """
        runAppleScriptAsync(script)
    }

    /// Check if a bundle identifier is a browser
    private func isBrowserBundle(_ bundleId: String) -> Bool {
        let browserBundles = [
            "com.apple.Safari",
            "com.google.Chrome",
            "company.thebrowser.Browser", // Arc
            "org.mozilla.firefox",
            "com.brave.Browser",
            "com.microsoft.edgemac",
        ]
        return browserBundles.contains(bundleId) || bundleId.lowercased().contains("browser")
    }

    /// Activate a browser tab matching the current song and send a key
    private func activateBrowserTabAndSendKey(bundleId: String, key: String) {
        let titleMatch = songTitle.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let artistMatch = artistName.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")

        var script: String

        if bundleId == "com.apple.Safari" {
            script = """
            tell application "Safari"
                activate
                repeat with w in windows
                    repeat with t in tabs of w
                        if name of t contains "\(titleMatch)" or name of t contains "\(artistMatch)" then
                            set current tab of w to t
                            set index of w to 1
                            delay 0.2
                            tell application "System Events"
                                keystroke "\(key)"
                            end tell
                            return "Found and played"
                        end if
                    end repeat
                end repeat
            end tell
            """
        } else if bundleId == "company.thebrowser.Browser" {
            // Arc browser
            script = """
            tell application "Arc"
                activate
                repeat with w in windows
                    set tabIndex to 1
                    repeat with t in tabs of w
                        if title of t contains "\(titleMatch)" or title of t contains "\(artistMatch)" then
                            tell w to set active tab index to tabIndex
                            set index of w to 1
                            delay 0.2
                            tell application "System Events"
                                keystroke "\(key)"
                            end tell
                            return "Found and played"
                        end if
                        set tabIndex to tabIndex + 1
                    end repeat
                end repeat
            end tell
            """
        } else {
            // Chrome and Chromium-based browsers
            let appName = getAppName(from: bundleId) ?? "Google Chrome"
            script = """
            tell application "\(appName)"
                activate
                repeat with w in windows
                    set tabIndex to 1
                    repeat with t in tabs of w
                        if title of t contains "\(titleMatch)" or title of t contains "\(artistMatch)" then
                            set active tab index of w to tabIndex
                            set index of w to 1
                            delay 0.2
                            tell application "System Events"
                                keystroke "\(key)"
                            end tell
                            return "Found and played"
                        end if
                        set tabIndex to tabIndex + 1
                    end repeat
                end repeat
            end tell
            """
        }

        runAppleScriptAsync(script)
    }

    /// Run AppleScript asynchronously
    private func runAppleScriptAsync(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: source) {
                appleScript.executeAndReturnError(&error)
                if let error = error {
                    print("MusicManager: AppleScript error: \(error)")
                }
            }
        }
    }

    /// Send next track command directly to an app via AppleScript
    private func sendNextTrackViaAppleScript(to bundleId: String) {
        // Native apps with AppleScript support
        if bundleId == SpotifyController.spotifyBundleId {
            runAppleScriptAsync("tell application \"Spotify\" to next track")
            return
        }
        if bundleId == AppleMusicController.appleMusicBundleId {
            runAppleScriptAsync("tell application \"Music\" to next track")
            return
        }

        // WebCatalog YouTube Music: activate and send Shift+N
        if bundleId == Self.youTubeMusicWebCatalogBundleId {
            activateAppAndSendKeyCombo(appName: "YouTube Music", key: "n", modifiers: ["shift"])
            return
        }

        // Browser-based sources: find tab, activate, and send Shift+N (YouTube Music shortcut)
        if isBrowserBundle(bundleId) {
            activateBrowserTabAndSendKeyCombo(bundleId: bundleId, key: "n", modifiers: ["shift"])
            return
        }

        // For other apps, fall back to MediaRemote
        if let sendCommand = MRMediaRemoteSendCommandPtr {
            sendCommand(MRCommand.nextTrack.rawValue, nil)
        }
    }

    /// Send previous track command directly to an app via AppleScript
    private func sendPreviousTrackViaAppleScript(to bundleId: String) {
        // Native apps with AppleScript support
        if bundleId == SpotifyController.spotifyBundleId {
            runAppleScriptAsync("tell application \"Spotify\" to previous track")
            return
        }
        if bundleId == AppleMusicController.appleMusicBundleId {
            runAppleScriptAsync("tell application \"Music\" to previous track")
            return
        }

        // WebCatalog YouTube Music: activate and send Shift+P
        if bundleId == Self.youTubeMusicWebCatalogBundleId {
            activateAppAndSendKeyCombo(appName: "YouTube Music", key: "p", modifiers: ["shift"])
            return
        }

        // Browser-based sources: find tab, activate, and send Shift+P (YouTube Music shortcut)
        if isBrowserBundle(bundleId) {
            activateBrowserTabAndSendKeyCombo(bundleId: bundleId, key: "p", modifiers: ["shift"])
            return
        }

        // For other apps, fall back to MediaRemote
        if let sendCommand = MRMediaRemoteSendCommandPtr {
            sendCommand(MRCommand.previousTrack.rawValue, nil)
        }
    }

    /// Activate an app by name and send a key combination
    private func activateAppAndSendKeyCombo(appName: String, key: String, modifiers: [String]) {
        let modifierStr = modifiers.map { "\($0) down" }.joined(separator: ", ")
        let keystrokeCmd = modifierStr.isEmpty
            ? "keystroke \"\(key)\""
            : "keystroke \"\(key)\" using {\(modifierStr)}"

        let script = """
        tell application "\(appName)"
            activate
        end tell
        delay 0.3
        tell application "System Events"
            \(keystrokeCmd)
        end tell
        """
        runAppleScriptAsync(script)
    }

    /// Activate a browser tab and send a key combination
    private func activateBrowserTabAndSendKeyCombo(bundleId: String, key: String, modifiers: [String]) {
        let titleMatch = songTitle.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let artistMatch = artistName.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")

        // Build modifier string for AppleScript
        let modifierStr = modifiers.map { "\($0) down" }.joined(separator: ", ")
        let keystrokeCmd = modifierStr.isEmpty
            ? "keystroke \"\(key)\""
            : "keystroke \"\(key)\" using {\(modifierStr)}"

        var script: String

        if bundleId == "com.apple.Safari" {
            script = """
            tell application "Safari"
                activate
                repeat with w in windows
                    repeat with t in tabs of w
                        if name of t contains "\(titleMatch)" or name of t contains "\(artistMatch)" then
                            set current tab of w to t
                            set index of w to 1
                            delay 0.2
                            tell application "System Events"
                                \(keystrokeCmd)
                            end tell
                            return "Found"
                        end if
                    end repeat
                end repeat
            end tell
            """
        } else if bundleId == "company.thebrowser.Browser" {
            script = """
            tell application "Arc"
                activate
                repeat with w in windows
                    set tabIndex to 1
                    repeat with t in tabs of w
                        if title of t contains "\(titleMatch)" or title of t contains "\(artistMatch)" then
                            tell w to set active tab index to tabIndex
                            set index of w to 1
                            delay 0.2
                            tell application "System Events"
                                \(keystrokeCmd)
                            end tell
                            return "Found"
                        end if
                        set tabIndex to tabIndex + 1
                    end repeat
                end repeat
            end tell
            """
        } else {
            let appName = getAppName(from: bundleId) ?? "Google Chrome"
            script = """
            tell application "\(appName)"
                activate
                repeat with w in windows
                    set tabIndex to 1
                    repeat with t in tabs of w
                        if title of t contains "\(titleMatch)" or title of t contains "\(artistMatch)" then
                            set active tab index of w to tabIndex
                            set index of w to 1
                            delay 0.2
                            tell application "System Events"
                                \(keystrokeCmd)
                            end tell
                            return "Found"
                        end if
                        set tabIndex to tabIndex + 1
                    end repeat
                end repeat
            end tell
            """
        }

        runAppleScriptAsync(script)
    }

    /// Add a newly detected media source to the list (for settings UI)
    private func recordDetectedSource(_ bundleId: String) {
        guard !detectedMediaSources.contains(where: { $0.bundleIdentifier == bundleId }) else { return }

        // Get app name from bundle identifier
        var appName = bundleId
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            appName = appURL.deletingPathExtension().lastPathComponent
        }

        let sourceInfo = MediaSourceInfo(id: bundleId, name: appName, bundleIdentifier: bundleId)
        DispatchQueue.main.async { [weak self] in
            self?.detectedMediaSources.append(sourceInfo)
        }
    }

    // MARK: - Spotify Integration
    
    /// Whether the current media source is Spotify (and Spotify extension is enabled)
    var isSpotifySource: Bool {
        // If Spotify extension is disabled, pretend it's not Spotify
        guard !ExtensionType.spotify.isRemoved else { return false }
        return bundleIdentifier == SpotifyController.spotifyBundleId
    }
    
    /// Spotify controller for app-specific features (shuffle, repeat, like)
    var spotifyController: SpotifyController {
        SpotifyController.shared
    }
    
    // MARK: - Apple Music Integration
    
    /// Whether the current media source is Apple Music (and Apple Music extension is enabled)
    var isAppleMusicSource: Bool {
        // If Apple Music extension is disabled, pretend it's not Apple Music
        guard !ExtensionType.appleMusic.isRemoved else { return false }
        return bundleIdentifier == AppleMusicController.appleMusicBundleId
    }
    
    /// Apple Music controller for app-specific features (shuffle, repeat, love)
    var appleMusicController: AppleMusicController {
        AppleMusicController.shared
    }
    
    /// Temporarily suppress timing updates after Spotify commands to avoid stale data
    private var suppressTimingUpdatesUntil: Date = .distantPast
    
    /// Call this before executing Spotify commands that affect playback position
    func suppressTimingUpdates(for seconds: Double = 0.5) {
        suppressTimingUpdatesUntil = Date().addingTimeInterval(seconds)
    }
    
    /// Whether timing updates should currently be suppressed
    var isTimingSuppressed: Bool {
        Date() < suppressTimingUpdatesUntil
    }
    
    /// Force set elapsed time (used after Spotify seek commands)
    func forceElapsedTime(_ time: Double) {
        elapsedTime = time
        timestampDate = Date()
        suppressTimingUpdatesUntil = .distantPast // Clear suppression
    }
    
    /// FIX #95: Force switch to Spotify by fetching data directly via AppleScript
    /// This bypasses MediaRemote which may be stuck on a stale source (e.g., paused browser)
    func forceUpdateFromSpotify() {
        print("🎵 MusicManager: Forcing update from Spotify via AppleScript...")
        
        SpotifyController.shared.fetchCurrentTrackInfo { [weak self] title, artist, album, duration, position in
            guard let self = self,
                  let title = title,
                  let artist = artist,
                  let duration = duration,
                  let position = position else {
                return
            }
            
            DispatchQueue.main.async {
                // FIX #95: Set flag to bypass HUD visibility safeguards (transition/debounce)
                self.isMediaSourceForced = true
                
                // Cancel any pending reset timer
                self.sourceForceResetTimer?.invalidate()
                
                // Schedule auto-reset after 2 seconds (HUD should be stable by then)
                self.sourceForceResetTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.isMediaSourceForced = false
                    }
                }
                
                // Update all state to Spotify
                self.songTitle = title
                self.artistName = artist
                self.albumName = album ?? ""
                self.songDuration = duration
                self.elapsedTime = position
                self.timestampDate = Date()
                self.bundleIdentifier = SpotifyController.spotifyBundleId
                self.isPlaying = true
                self.playbackRate = 1.0
                self.isMediaHUDHidden = false
                
                // Refresh Spotify state (shuffle, repeat, etc.)
                SpotifyController.shared.refreshState()
            }
        }
    }

    
    /// Whether playback stopped recently (within 5 seconds) - keeps UI visible
    @Published private(set) var wasRecentlyPlaying: Bool = false
    private var recentlyPlayingTimer: Timer?
    
    /// Whether a player is active (even if paused)
    var isPlayerIdle: Bool {
        songTitle.isEmpty && artistName.isEmpty
    }
    
    // MARK: - Process Management
    private var adapterProcess: Process?
    private var outputPipe: Pipe?
    
    // MediaRemote framework for sending commands (still works for control)
    private var mediaRemoteBundle: CFBundle?
    private var MRMediaRemoteSendCommandPtr: (@convention(c) (Int, AnyObject?) -> Void)?
    private var MRMediaRemoteSetElapsedTimePtr: (@convention(c) (Double) -> Void)?
    
    // MARK: - MRCommand values
    private enum MRCommand: Int {
        case play = 0
        case pause = 1
        case togglePlayPause = 2
        case stop = 3
        case nextTrack = 4
        case previousTrack = 5
    }
    
    // MARK: - Initialization
    private init() {
        // MediaRemoteAdapter.framework requires macOS 15.0 (built with that deployment target)
        if #available(macOS 15.0, *) {
            isMediaAvailable = true
            loadMediaRemoteForCommands()
            startAdapterProcess()
            setupSleepWakeObservers()
            
            // Fetch full metadata after a short delay to solve cold start issue
            // (when app opens while media is already playing, initial stream may miss duration)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.fetchFullNowPlayingInfo()
            }
        } else {
            // Media features unavailable on macOS 14.x
            isMediaAvailable = false
            print("MusicManager: Media features disabled (requires macOS 15.0+)")
        }
    }
    
    // MARK: - Sleep/Wake Handling
    
    /// Set up observers for sleep/wake events to restart the adapter process
    /// FIX: Prevents frozen media HUD after Mac wakes from sleep
    private func setupSleepWakeObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        // Restart adapter when screen wakes to ensure fresh data stream
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleScreenWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )

        // Also restart when session becomes active (after lock screen)
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleScreenWake),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )

        // Monitor app termination to clear stale media display when filter is enabled
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleAppTermination(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )

        print("MusicManager: Sleep/wake observers registered")
    }

    /// Called when an app terminates - clear media display if it was the filtered source
    @objc private func handleAppTermination(_ notification: Notification) {
        guard isMediaSourceFilterEnabled else { return }

        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let terminatedBundleId = app.bundleIdentifier else {
            return
        }

        // Check if the terminated app is our currently displayed source
        if terminatedBundleId == bundleIdentifier {
            print("MusicManager: Filtered source app terminated (\(terminatedBundleId)) - clearing display")
            DispatchQueue.main.async { [weak self] in
                self?.clearMediaDisplay()
            }
        }
    }

    /// Clear the media display (used when filtered source app terminates)
    private func clearMediaDisplay() {
        songTitle = ""
        artistName = ""
        albumName = ""
        albumArt = NSImage()
        isPlaying = false
        songDuration = 0
        elapsedTime = 0
        playbackRate = 0
        bundleIdentifier = nil
        wasRecentlyPlaying = false
        isMediaHUDForced = false
    }
    
    /// Called when screen wakes from sleep - restart the adapter to prevent frozen HUD
    @objc private func handleScreenWake() {
        print("MusicManager: Screen woke - restarting adapter process to refresh media stream...")
        restartAdapterProcess()
    }
    
    /// Restart the MediaRemoteAdapter subprocess
    private func restartAdapterProcess() {
        stopAdapterProcess()
        
        // Brief delay to ensure clean shutdown before restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.startAdapterProcess()
            
            // Fetch fresh metadata after restart
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.fetchFullNowPlayingInfo()
            }
        }
    }
    
    /// Fetch complete now playing info using the "get" command
    /// This solves the cold start problem where duration isn't sent in the initial stream
    private func fetchFullNowPlayingInfo() {
        guard let scriptURL = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl"),
              let frameworkPath = Bundle.main.privateFrameworksPath?.appending("/MediaRemoteAdapter.framework") else {
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptURL.path, frameworkPath, "get"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            
            // Read output in background
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                
                if !data.isEmpty {
                    print("MusicManager: Cold start fetch received \(data.count) bytes")
                    self?.processJSONLine(data)
                }
            }
        } catch {
            print("MusicManager: Cold start fetch failed: \(error)")
        }
    }
    
    deinit {
        stopAdapterProcess()
    }
    
    // MARK: - Process Management
    
    private func startAdapterProcess() {
        // Find script and framework in bundle
        guard let scriptURL = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl") else {
            print("MusicManager: ERROR - mediaremote-adapter.pl not found in bundle resources")
            return
        }
        
        guard let frameworkPath = Bundle.main.privateFrameworksPath?.appending("/MediaRemoteAdapter.framework") else {
            print("MusicManager: ERROR - Could not get privateFrameworksPath")
            return
        }
        
        print("MusicManager: Script path: \(scriptURL.path)")
        print("MusicManager: Framework path: \(frameworkPath)")
        
        // Verify framework exists
        guard FileManager.default.fileExists(atPath: frameworkPath) else {
            print("MusicManager: ERROR - MediaRemoteAdapter.framework not found at \(frameworkPath)")
            return
        }
        
        print("MusicManager: Framework verified to exist")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptURL.path, frameworkPath, "stream", "--no-diff"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        self.adapterProcess = process
        self.outputPipe = pipe
        
        // Set up non-blocking read handler
        var buffer = Data()
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                // Process ended
                print("MusicManager: Adapter process ended (empty data)")
                handle.readabilityHandler = nil
                return
            }
            
            print("MusicManager: Received \(data.count) bytes")
            buffer.append(data)
            
            // Process complete JSON lines
            while let newlineIndex = buffer.firstIndex(of: 0x0A) { // '\n'
                let lineData = Data(buffer[..<newlineIndex])
                buffer = Data(buffer[(newlineIndex + 1)...])
                
                if !lineData.isEmpty {
                    if let lineStr = String(data: lineData, encoding: .utf8) {
                        print("MusicManager: JSON line: \(lineStr.prefix(200))...")
                    }
                    self?.processJSONLine(lineData)
                }
            }
        }
        
        do {
            try process.run()
            print("MusicManager: MediaRemoteAdapter process started with PID: \(process.processIdentifier)")
        } catch {
            print("MusicManager: ERROR - Failed to start adapter process: \(error)")
        }
    }
    
    private func stopAdapterProcess() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        
        if let process = adapterProcess, process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
        adapterProcess = nil
        outputPipe = nil
    }
    
    // MARK: - JSON Stream Processing
    
    private func processJSONLine(_ data: Data) {
        // Debug: Always log raw JSON for timing issues
        if let jsonStr = String(data: data, encoding: .utf8) {
            print("MusicManager: Raw JSON received: \(jsonStr.prefix(500))")
        }
        
        do {
            let decoder = JSONDecoder()
            // Try decoding as full update structure first
            if let update = try? decoder.decode(NowPlayingUpdate.self, from: data) {
                DispatchQueue.main.async { [weak self] in
                    self?.handleUpdate(update)
                }
                return
            }
            
            // Fallback: Try decoding as payload directly (adapter "get" command output format)
            let payload = try decoder.decode(NowPlayingUpdate.NowPlayingPayload.self, from: data)
            let update = NowPlayingUpdate(type: "data", payload: payload, diff: false)
            print("MusicManager: Decoded as direct payload")
            
            DispatchQueue.main.async { [weak self] in
                self?.handleUpdate(update)
            }
        } catch {
            print("MusicManager: Failed to decode JSON: \(error)")
        }
    }
    
    @MainActor
    private func handleUpdate(_ update: NowPlayingUpdate) {
        let payload = update.payload

        // MARK: Media Source Filter
        // Record detected source for settings UI (even if filtered)
        if let bundleId = payload.launchableBundleIdentifier {
            recordDetectedSource(bundleId)
        }

        // Check if this source is allowed by the filter
        if !isBundleAllowed(payload.launchableBundleIdentifier) {
            print("MusicManager: Skipping update from filtered source: \(payload.launchableBundleIdentifier ?? "unknown")")
            
            // FIX: If the blocked source matches the currently displayed source, clear the display
            // This handles the case where filter is enabled while content from a blocked source is already showing
            if payload.launchableBundleIdentifier == bundleIdentifier {
                print("MusicManager: Current display is from blocked source - clearing")
                clearMediaDisplay()
            }
            return
        }

        // Check if this is from an incognito/private browsing window
        if isFromIncognitoBrowser(payload.launchableBundleIdentifier) {
            print("MusicManager: Skipping update from incognito browser: \(payload.launchableBundleIdentifier ?? "unknown")")
            
            // Clear display if incognito source was previously shown
            if payload.launchableBundleIdentifier == bundleIdentifier {
                print("MusicManager: Current display is from incognito browser - clearing")
                clearMediaDisplay()
            }
            return
        }

        // MARK: FIX #128 - Debounced Track Change Detection
        // During video seeking, MediaRemote sends rapid updates that can cause UI flicker.
        // We debounce track changes to wait for stable metadata before updating the display.
        
        let incomingTitle = payload.title ?? songTitle
        let incomingArtist = payload.artist ?? artistName
        let incomingAlbum = payload.album ?? albumName
        let incomingBundleId = payload.launchableBundleIdentifier ?? bundleIdentifier
        
        // Create a signature for the incoming metadata
        let incomingSignature = "\(incomingTitle)||\(incomingArtist)||\(incomingBundleId ?? "")"
        
        // Check if this is a track change (different from currently displayed)
        let isTrackChange = incomingSignature != lastAppliedMetadataSignature && !lastAppliedMetadataSignature.isEmpty
        
        if isTrackChange {
            // Cancel any existing debounce timer
            metadataDebounceTimer?.invalidate()
            
            // Store pending metadata
            pendingMetadataUpdate = (title: incomingTitle, artist: incomingArtist, album: incomingAlbum, bundleId: incomingBundleId)
            
            // Start debounce timer - wait 300ms for metadata to stabilize
            metadataDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                self?.applyPendingMetadataUpdate()
            }
            
            print("MusicManager: FIX #128 - Track change detected, debouncing for 300ms...")
        } else {
            // Same track or first load - apply immediately and update signature
            if let title = payload.title {
                if title != songTitle {
                    // Reset timing values when song changes to prevent stale timestamps
                    songDuration = 0
                    elapsedTime = 0
                    // Notify Spotify controller of track change
                    if isSpotifySource {
                        SpotifyController.shared.onTrackChange()
                    }
                    // Notify Apple Music controller of track change
                    if isAppleMusicSource {
                        AppleMusicController.shared.onTrackChange()
                    }
                }
                songTitle = title
            }
            if let artist = payload.artist {
                artistName = artist
            }
            if let album = payload.album {
                albumName = album
            }
            
            // Update the applied signature
            lastAppliedMetadataSignature = "\(songTitle)||\(artistName)||\(bundleIdentifier ?? "")"
            
            // Clear any pending update since we just applied
            metadataDebounceTimer?.invalidate()
            pendingMetadataUpdate = nil
        }
        if let duration = payload.duration, duration > 0 {
            // Only accept duration if it makes sense (greater than current elapsed time)
            // For web sources, MediaRemote sometimes sends elapsedTime as duration
            let currentElapsed = payload.elapsedTime ?? elapsedTime
            if duration > currentElapsed || currentElapsed < 5 {
                songDuration = duration
            } else {
                print("MusicManager: Rejected invalid duration \(duration) <= elapsed \(currentElapsed)")
            }
        }
        if let elapsed = payload.elapsedTime {
            // SIMPLE TIMING LOGIC:
            // 
            // For Spotify: IGNORE all MediaRemote timing - we use AppleScript polling instead
            // For other sources: Just accept what MediaRemote sends
            
            // Check if this update is from Spotify (check payload directly, not stored value)
            let isFromSpotify = payload.launchableBundleIdentifier == SpotifyController.spotifyBundleId ||
                                (payload.launchableBundleIdentifier == nil && isSpotifySource)
            
            if isFromSpotify {
                // SPOTIFY: Ignore MediaRemote timing completely
                // SpotifyController handles timing via AppleScript polling every 1 second
            } else {
                // OTHER SOURCES: Accept MediaRemote timing directly
                var newElapsedTime = elapsed
                
                // Adjust for timestamp age if available
                if let ts = payload.timestamp {
                    let formatter = ISO8601DateFormatter()
                    if let captureDate = formatter.date(from: ts) {
                        let timeSinceCapture = Date().timeIntervalSince(captureDate)
                        let rate = payload.playbackRate ?? 1.0
                        
                        // Only adjust if timestamp is recent and we're playing
                        if timeSinceCapture >= 0 && timeSinceCapture < 5 && rate > 0 {
                            newElapsedTime = elapsed + (timeSinceCapture * rate)
                        }
                    }
                }
                
                elapsedTime = newElapsedTime
                timestampDate = Date()
            }
        }
        if let rate = payload.playbackRate {
            playbackRate = rate
        }
        if let bundle = payload.launchableBundleIdentifier {
            let wasSpotify = isSpotifySource
            let wasAppleMusic = isAppleMusicSource
            let previousBundle = bundleIdentifier
            bundleIdentifier = bundle
            
            // FIX #95: Reset isMediaHUDHidden when media source changes
            // This ensures the HUD shows when switching back to a previous source
            if previousBundle != nil && previousBundle != bundle {
                isMediaHUDHidden = false
            }
            
            // Refresh Spotify state when source changes to Spotify
            if isSpotifySource && !wasSpotify {
                SpotifyController.shared.refreshState()
            }
            
            // Refresh Apple Music state when source changes to Apple Music
            if isAppleMusicSource && !wasAppleMusic {
                AppleMusicController.shared.refreshState()
            }
            
            // PERFORMANCE FIX: Stop Spotify's position sync timer when switching away
            // This prevents a "zombie timer" from running when another source is active
            if wasSpotify && !isSpotifySource {
                SpotifyController.shared.stopPositionSyncTimer()
            }
            
            // PERFORMANCE FIX: Stop Apple Music's position sync timer when switching away
            if wasAppleMusic && !isAppleMusicSource {
                AppleMusicController.shared.stopPositionSyncTimer()
            }
        }
        
        // Always update isPlaying from playbackRate (computed property)
        isPlaying = payload.isPlaying
        
        // Handle artwork
        if let base64Art = payload.artworkData,
           let artData = Data(base64Encoded: base64Art),
           let image = NSImage(data: artData) {
            albumArt = image

        }
        
        // Debug: Log the update
        print("MusicManager: Updated - title='\(songTitle)', artist='\(artistName)', isPlaying=\(isPlaying), elapsed=\(elapsedTime), duration=\(songDuration), rate=\(playbackRate)")
    }
    
    // MARK: - Cached Visualizer Color
    
    /// Updates the cached visualizer color from current album art
    /// PERFORMANCE: Called once per track change instead of on every view body evaluation
    private func updateCachedVisualizerColor() {
        if albumArt.size.width > 0 {
            visualizerColor = albumArt.dominantColor()
        } else {
            visualizerColor = .white.opacity(0.7)
        }
    }
    
    // MARK: - FIX #128: Apply Pending Metadata Update
    
    /// Applies pending metadata update after debounce period
    /// Called by debounce timer to prevent flicker during video seeking
    private func applyPendingMetadataUpdate() {
        guard let pending = pendingMetadataUpdate else { return }
        
        print("MusicManager: FIX #128 - Applying debounced metadata update: '\(pending.title)' by '\(pending.artist)'")
        
        // Reset timing values for new track
        songDuration = 0
        elapsedTime = 0
        
        // Notify controllers of track change
        if isSpotifySource {
            SpotifyController.shared.onTrackChange()
        }
        if isAppleMusicSource {
            AppleMusicController.shared.onTrackChange()
        }
        
        // Apply the pending metadata
        songTitle = pending.title
        artistName = pending.artist
        albumName = pending.album
        
        // Update signature
        lastAppliedMetadataSignature = "\(songTitle)||\(artistName)||\(bundleIdentifier ?? "")"
        
        // Clear pending state
        pendingMetadataUpdate = nil
    }
    
    // MARK: - Load MediaRemote for Commands
    
    private func loadMediaRemoteForCommands() {
        let frameworkPath = "/System/Library/PrivateFrameworks/MediaRemote.framework"
        guard let url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, frameworkPath as CFString, .cfurlposixPathStyle, true),
              let bundle = CFBundleCreate(kCFAllocatorDefault, url),
              CFBundleLoadExecutable(bundle) else {
            print("MusicManager: Failed to load MediaRemote for commands")
            return
        }
        
        mediaRemoteBundle = bundle
        
        MRMediaRemoteSendCommandPtr = unsafeBitCast(
            CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString),
            to: (@convention(c) (Int, AnyObject?) -> Void)?.self
        )
        
        MRMediaRemoteSetElapsedTimePtr = unsafeBitCast(
            CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetElapsedTime" as CFString),
            to: (@convention(c) (Double) -> Void)?.self
        )
        
        print("MusicManager: MediaRemote commands loaded, seek available: \(MRMediaRemoteSetElapsedTimePtr != nil)")
    }
    
    // MARK: - Public Control API

    /// Toggle play/pause
    func togglePlay() {
        // When filter is enabled, use AppleScript for direct control of the displayed source
        if isMediaSourceFilterEnabled, let displayedBundle = bundleIdentifier {
            ensureDisplayedSourceActive(forBundle: displayedBundle) { [weak self] in
                self?.sendPlayPauseViaAppleScript(to: displayedBundle)
            }
        } else {
            guard let sendCommand = MRMediaRemoteSendCommandPtr else { return }
            sendCommand(MRCommand.togglePlayPause.rawValue, nil)
        }
    }

    /// Skip to next track
    func nextTrack() {
        // Reset first to ensure consecutive same-direction skips trigger onChange
        lastSkipDirection = .none
        // Then set direction after brief delay to ensure SwiftUI observes the change
        DispatchQueue.main.async { [weak self] in
            self?.lastSkipDirection = .forward
        }

        // When filter is enabled, use AppleScript for direct control of the displayed source
        if isMediaSourceFilterEnabled, let displayedBundle = bundleIdentifier {
            ensureDisplayedSourceActive(forBundle: displayedBundle) { [weak self] in
                self?.sendNextTrackViaAppleScript(to: displayedBundle)
            }
        } else {
            guard let sendCommand = MRMediaRemoteSendCommandPtr else { return }
            sendCommand(MRCommand.nextTrack.rawValue, nil)
        }
    }

    /// Skip to previous track
    func previousTrack() {
        // Reset first to ensure consecutive same-direction skips trigger onChange
        lastSkipDirection = .none
        // Then set direction after brief delay to ensure SwiftUI observes the change
        DispatchQueue.main.async { [weak self] in
            self?.lastSkipDirection = .backward
        }

        // When filter is enabled, use AppleScript for direct control of the displayed source
        if isMediaSourceFilterEnabled, let displayedBundle = bundleIdentifier {
            ensureDisplayedSourceActive(forBundle: displayedBundle) { [weak self] in
                self?.sendPreviousTrackViaAppleScript(to: displayedBundle)
            }
        } else {
            guard let sendCommand = MRMediaRemoteSendCommandPtr else { return }
            sendCommand(MRCommand.previousTrack.rawValue, nil)
        }
    }
    
    /// Seek to specific time
    func seek(to time: Double) {
        guard let setElapsedTime = MRMediaRemoteSetElapsedTimePtr else {
            print("MusicManager: Seek failed - MRMediaRemoteSetElapsedTime not available")
            return
        }
        
        let clampedTime = max(0, min(time, songDuration))
        print("MusicManager: Seeking to \(clampedTime)s (duration: \(songDuration)s)")
        
        // Call the MediaRemote function to seek
        setElapsedTime(clampedTime)
        
        // Update local state immediately for responsive UI
        DispatchQueue.main.async {
            self.elapsedTime = clampedTime
            self.timestampDate = Date()
        }
    }
    
    /// Skip forward/backward by seconds
    func skip(seconds: Double) {
        let newTime = elapsedTime + seconds
        seek(to: newTime)
    }
    
    /// Open the source app and try to activate the correct tab for browsers
    func openMusicApp() {
        print("MusicManager: Opening app with bundleId: \(bundleIdentifier ?? "nil")")
        
        guard let bundleId = bundleIdentifier else {
            // Fallback to Apple Music
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") {
                print("MusicManager: Fallback to Apple Music")
                NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
            }
            return
        }
        
        // Normalize bundle ID to lowercase for reliable matching
        let bundleLower = bundleId.lowercased()
        
        // For browsers, try to find and activate the tab playing the media
        if bundleId == "com.apple.Safari" {
            activateSafariTab()
        } else if bundleLower.contains("chrome") || bundleLower.contains("chromium") {
            activateChromeTab(bundleId: bundleId)
        } else if bundleLower.contains("firefox") || bundleLower.contains("zen") {
            // Zen browser is Firefox-based, both use same AppleScript (limited support)
            activateFirefoxTab(bundleId: bundleId)
        } else if bundleLower.contains("arc") || bundleId == "company.thebrowser.Browser" {
            activateArcTab()
        } else if bundleLower.contains("brave") {
            activateBraveTab(bundleId: bundleId)
        } else if bundleLower.contains("edge") {
            activateEdgeTab(bundleId: bundleId)
        } else {
            // For non-browser apps (Spotify, SoundCloud app, etc.), just open the app
            // This works universally for any bundle ID
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                print("MusicManager: Opening source app: \(bundleId)")
                NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
            } else {
                // Last resort: try to find running app by bundle ID and activate it
                if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
                    print("MusicManager: Activating running app: \(bundleId)")
                    app.activate()
                } else {
                    print("MusicManager: Could not find app with bundleId: \(bundleId)")
                }
            }
        }
    }
    
    // MARK: - Browser Tab Activation
    
    /// Activate Safari tab matching the current song title or artist
    private func activateSafariTab() {
        // Prefer title match, then artist match, then just activate Safari
        let titleMatch = escapeForAppleScript(songTitle)
        let artistMatch = escapeForAppleScript(artistName)
        
        let script = """
        tell application "Safari"
            activate
            
            -- First try to match by song title
            repeat with w in windows
                repeat with t in tabs of w
                    if name of t contains "\(titleMatch)" then
                        set current tab of w to t
                        set index of w to 1
                        return "Found by title"
                    end if
                end repeat
            end repeat
            
            -- Then try artist name
            if "\(artistMatch)" is not "" then
                repeat with w in windows
                    repeat with t in tabs of w
                        if name of t contains "\(artistMatch)" then
                            set current tab of w to t
                            set index of w to 1
                            return "Found by artist"
                        end if
                    end repeat
                end repeat
            end if
            
            return "Not found"
        end tell
        """
        
        print("MusicManager: Safari AppleScript searching for title='\(titleMatch)' or artist='\(artistMatch)'")
        runAppleScript(script, appName: "Safari")
    }
    
    /// Activate Chrome tab matching the current song title or artist
    /// Works for Google Chrome and other Chromium-based browsers with similar AppleScript support
    private func activateChromeTab(bundleId: String = "com.google.Chrome") {
        let titleMatch = escapeForAppleScript(songTitle)
        let artistMatch = escapeForAppleScript(artistName)
        
        // Determine app name from bundle ID for AppleScript
        let appName = getAppName(from: bundleId) ?? "Google Chrome"
        
        let script = """
        tell application "\(appName)"
            activate
            
            -- First try to match by song title
            repeat with w in windows
                set tabIndex to 1
                repeat with t in tabs of w
                    if title of t contains "\(titleMatch)" then
                        set active tab index of w to tabIndex
                        set index of w to 1
                        return "Found by title"
                    end if
                    set tabIndex to tabIndex + 1
                end repeat
            end repeat
            
            -- Then try artist name
            if "\(artistMatch)" is not "" then
                repeat with w in windows
                    set tabIndex to 1
                    repeat with t in tabs of w
                        if title of t contains "\(artistMatch)" then
                            set active tab index of w to tabIndex
                            set index of w to 1
                            return "Found by artist"
                        end if
                        set tabIndex to tabIndex + 1
                    end repeat
                end repeat
            end if
            
            return "Not found"
        end tell
        """
        
        print("MusicManager: \(appName) AppleScript searching for title='\(titleMatch)' or artist='\(artistMatch)'")
        runAppleScript(script, appName: appName, bundleId: bundleId)
    }
    
    /// Activate Firefox/Zen tab - limited AppleScript support, just activate the app
    private func activateFirefoxTab(bundleId: String = "org.mozilla.firefox") {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let appName = getAppName(from: bundleId) ?? "Firefox"
            print("MusicManager: Activating \(appName) (limited tab support)")
            NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
        } else if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            print("MusicManager: Activating running Firefox-based browser: \(bundleId)")
            app.activate()
        }
    }
    
    /// Activate Brave tab (Chromium-based, same AppleScript as Chrome)
    private func activateBraveTab(bundleId: String = "com.brave.Browser") {
        activateChromeTab(bundleId: bundleId)
    }
    
    /// Activate Edge tab (Chromium-based, same AppleScript as Chrome)
    private func activateEdgeTab(bundleId: String = "com.microsoft.edgemac") {
        activateChromeTab(bundleId: bundleId)
    }
    
    /// Activate Arc tab matching the current song title
    private func activateArcTab() {
        let script = """
        tell application "Arc"
            activate
            set targetTitle to "\(escapeForAppleScript(songTitle))"
            
            repeat with w in windows
                set tabIndex to 1
                repeat with t in tabs of w
                    if title of t contains targetTitle then
                        tell w to set active tab index to tabIndex
                        set index of w to 1
                        return "Found: " & title of t
                    end if
                    set tabIndex to tabIndex + 1
                end repeat
            end repeat
            
            return "Not found"
        end tell
        """
        
        runAppleScript(script, appName: "Arc")
    }
    
    /// Escape string for AppleScript embedding
    private func escapeForAppleScript(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
    
    /// Get the app name from a bundle identifier (for AppleScript)
    private func getAppName(from bundleId: String) -> String? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return url.deletingPathExtension().lastPathComponent
        }
        return nil
    }
    
    /// Run AppleScript asynchronously with fallback to just opening the app
    private func runAppleScript(_ source: String, appName: String, bundleId: String? = nil) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var error: NSDictionary?
            if let script = NSAppleScript(source: source) {
                let result = script.executeAndReturnError(&error)
                
                if let error = error {
                    print("MusicManager: AppleScript error for \(appName): \(error)")
                    // Fallback: just activate the app
                    DispatchQueue.main.async {
                        let targetBundleId = bundleId ?? self?.bundleIdentifier
                        if let bundleId = targetBundleId {
                            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                                NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
                            } else if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
                                app.activate()
                            }
                        }
                    }
                } else {
                    print("MusicManager: AppleScript result for \(appName): \(result.stringValue ?? "success")")
                }
            }
        }
    }
    
    func estimatedPlaybackPosition(at date: Date = Date()) -> Double {
        guard isPlaying else { return elapsedTime }
        let delta = date.timeIntervalSince(timestampDate)
        let progressed = elapsedTime + (delta * playbackRate)
        // Only clamp to duration if we have a valid duration (> 0)
        if songDuration > 0 {
            return min(max(progressed, 0), songDuration)
        } else {
            return max(progressed, 0)
        }
    }
}
