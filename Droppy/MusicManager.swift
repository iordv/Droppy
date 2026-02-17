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

private let musicManagerVerboseLogs = false

@inline(__always)
private func musicManagerLog(_ message: @autoclosure () -> String) {
    guard musicManagerVerboseLogs else { return }
    print(message())
}

// MARK: - NowPlaying Update JSON Model

/// Represents an update from the MediaRemoteAdapter
private struct NowPlayingUpdate: Codable, Sendable {
    let type: String?
    let payload: NowPlayingPayload
    let diff: Bool?
    
    struct NowPlayingPayload: Codable, Sendable {
        let title: String?
        let artist: String?
        let album: String?
        let duration: Double?
        let elapsedTime: Double?
        let elapsedTimeNow: Double?  // More accurate estimated current position from adapter
        let playbackRate: Double?
        let bundleIdentifier: String?
        let parentApplicationBundleIdentifier: String?  // Parent app (e.g., Safari for WebKit.GPU)
        let contentItemIdentifier: String?  // Stable track identifier
        let processIdentifier: Int?
        let artworkData: String?  // Base64 encoded
        let timestamp: String?    // ISO 8601 format: "2026-01-05T18:56:59Z"
        let playing: Bool?        // Explicit playing state from JSON
        
        /// Get isPlaying preferring explicit 'playing' field, fallback to playbackRate.
        var isPlaying: Bool {
            if let playing {
                return playing
            }
            return (playbackRate ?? 0) > 0
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
    /// Cached secondary color from album art for gradient visualizer mode
    @Published private(set) var visualizerSecondaryColor: Color = .gray.opacity(0.7)
    @Published private(set) var isPlaying: Bool = false {
        didSet {
            guard oldValue != isPlaying else { return }
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
                } else {
                    scheduleSpotifyPausedSourceReacquire()
                }
            } else if isPlaying {
                // Started playing again - cancel timer and keep visible
                recentlyPlayingTimer?.invalidate()
                recentlyPlayingTimer = nil
                wasRecentlyPlaying = false
                stopSpotifyPausedSourceReacquire()
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
    
    // MARK: - Track Identity
    /// Stable identity for the currently shown track (content item id preferred).
    private var currentTrackIdentity: String = ""
    private var currentContentItemIdentifier: String?
    private var lastArtworkTrackIdentity: String = ""
    private var lastArtworkContentItemIdentifier: String?
    private var lastParsedEventTimestampString: String?
    private var lastParsedEventTimestampDate: Date?
    private let iso8601DateFormatter = ISO8601DateFormatter()

    // Cache decoded media-source filter bundles to avoid JSON parsing on every stream update.
    private var allowedMediaBundlesCacheRawValue = ""
    private var allowedMediaBundlesCache = Set<String>()

    // Cache incognito checks for a short time to avoid blocking AppleScript calls on every update.
    private var incognitoBrowserCache: [String: (value: Bool, checkedAt: Date)] = [:]
    private let incognitoBrowserCacheTTL: TimeInterval = 1.0

    // MARK: - Apple Music Metadata Sync
    /// Periodic AppleScript sync to keep Apple Music metadata accurate
    private var appleMusicMetadataSyncTimer: Timer?
    
    /// Serial queue for AppleScript execution - NSAppleScript is NOT thread-safe
    /// Concurrent AppleScript calls crash the AppleScript runtime
    private let appleScriptQueue = DispatchQueue(label: "com.droppy.MusicManager.applescript")

    // MARK: - Media Source Filter

    /// Whether media source filtering is enabled
    /// When enabled, only bundle identifiers in the allowed list will be shown
    private var isMediaSourceFilterEnabled: Bool {
        UserDefaults.standard.preference(
            AppPreferenceKey.mediaSourceFilterEnabled,
            default: PreferenceDefault.mediaSourceFilterEnabled
        )
    }

    /// Set of allowed bundle identifiers for media source filtering.
    /// Empty set means no filter (show all sources).
    private func getAllowedMediaBundles() -> Set<String> {
        let jsonString = UserDefaults.standard.preference(
            AppPreferenceKey.mediaSourceAllowedBundles,
            default: PreferenceDefault.mediaSourceAllowedBundles
        )
        if jsonString == allowedMediaBundlesCacheRawValue {
            return allowedMediaBundlesCache
        }

        guard let data = jsonString.data(using: .utf8) else {
            allowedMediaBundlesCacheRawValue = jsonString
            allowedMediaBundlesCache = []
            return []
        }
        let decoded: Set<String>

        // Try new format (dictionary: bundleId -> appName)
        if let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            decoded = Set(dict.keys)
            allowedMediaBundlesCacheRawValue = jsonString
            allowedMediaBundlesCache = decoded
            return decoded
        }

        // Fallback to old format (array of bundleIds)
        if let array = try? JSONDecoder().decode([String].self, from: data) {
            decoded = Set(array)
            allowedMediaBundlesCacheRawValue = jsonString
            allowedMediaBundlesCache = decoded
            return decoded
        }

        allowedMediaBundlesCacheRawValue = jsonString
        allowedMediaBundlesCache = []
        return []
    }

    /// Check if a bundle identifier is allowed by the media source filter
    /// Returns true if filter is disabled, or if the bundle is in the allowed list
    private func isBundleAllowed(_ bundleId: String?) -> Bool {
        guard isMediaSourceFilterEnabled else { return true }
        guard let bundleId = bundleId else { return false }
        let allowed = getAllowedMediaBundles()
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

        let now = Date()
        if let cached = incognitoBrowserCache[bundleId],
           now.timeIntervalSince(cached.checkedAt) < incognitoBrowserCacheTTL {
            return cached.value
        }
        
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
        
        // Execute synchronously on serial queue to check incognito status
        // Note: This still blocks caller but ensures thread safety
        var result: String?
        appleScriptQueue.sync {
            result = AppleScriptRuntime.execute {
                var error: NSDictionary?
                guard let appleScript = NSAppleScript(source: script) else {
                    return nil
                }
                let descriptor = appleScript.executeAndReturnError(&error)
                if let error {
                    print("MusicManager: AppleScript error: \(error)")
                    return nil
                }
                return descriptor.stringValue
            }
        }
        let isIncognito = result == "incognito" || result == "private"
        incognitoBrowserCache[bundleId] = (isIncognito, now)
        return isIncognito
    }

    /// Track previously detected media sources for settings UI
    @Published private(set) var detectedMediaSources: [MediaSourceInfo] = []
    private var detectedMediaSourceBundleIDs = Set<String>()

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

        // Apple Music does not need activation to receive AppleScript commands
        if displayedBundle == AppleMusicController.appleMusicBundleId {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                completion()
            }
            return
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
                delay 0.1
                tell application "System Events"
                    keystroke "\(key)"
                end tell
                return "Fallback played active tab"
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
                delay 0.1
                tell application "System Events"
                    keystroke "\(key)"
                end tell
                return "Fallback played active tab"
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
                delay 0.1
                tell application "System Events"
                    keystroke "\(key)"
                end tell
                return "Fallback played active tab"
            end tell
            """
        }

        runAppleScriptAsync(script)
    }

    /// Run AppleScript asynchronously
    private func runAppleScriptAsync(_ source: String) {
        // Use serial queue to prevent concurrent AppleScript execution
        // NSAppleScript is NOT thread-safe and concurrent calls crash the runtime
        appleScriptQueue.async {
            let errorDescription: String? = AppleScriptRuntime.execute {
                var error: NSDictionary?
                guard let appleScript = NSAppleScript(source: source) else {
                    return "Failed to create AppleScript"
                }
                appleScript.executeAndReturnError(&error)
                return error.map { "\($0)" }
            }
            if let errorDescription {
                print("MusicManager: AppleScript error: \(errorDescription)")
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
                delay 0.1
                tell application "System Events"
                    \(keystrokeCmd)
                end tell
                return "Fallback"
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
                delay 0.1
                tell application "System Events"
                    \(keystrokeCmd)
                end tell
                return "Fallback"
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
                delay 0.1
                tell application "System Events"
                    \(keystrokeCmd)
                end tell
                return "Fallback"
            end tell
            """
        }

        runAppleScriptAsync(script)
    }

    /// Add a newly detected media source to the list (for settings UI)
    private func recordDetectedSource(_ bundleId: String) {
        guard detectedMediaSourceBundleIDs.insert(bundleId).inserted else { return }

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
    
    /// Current accepted source bundle identifier (used by controllers for source arbitration)
    var currentAcceptedBundleIdentifier: String? {
        bundleIdentifier
    }
    
    /// Duration for UI display - always returns songDuration, never 0 when we have a known value
    var displayDurationForUI: Double {
        max(songDuration, 0)
    }

    private func makeTrackIdentity(
        title: String,
        artist: String,
        album: String,
        bundleId: String?
    ) -> String {
        return "meta:\(title)|\(artist)|\(album)|bundle:\(bundleId ?? "")"
    }
    
    /// Check whether a direct position update from a specific source should be accepted.
    /// Returns true if the source matches the currently active media source.
    func shouldAcceptDirectPositionUpdate(from sourceBundleId: String) -> Bool {
        guard let active = bundleIdentifier else { return true }
        return active == sourceBundleId
    }
    
    /// Force set elapsed time (used after Spotify/Apple Music seek commands)
    /// sourceBundle parameter allows callers to identify themselves for logging.
    func forceElapsedTime(_ time: Double, sourceBundle: String? = nil) {
        // Reject updates from non-active sources
        if let sourceBundle, !shouldAcceptDirectPositionUpdate(from: sourceBundle) {
            return
        }
        // During timing suppression, reject updates that look like stale pre-seek positions
        if isTimingSuppressed {
            return
        }
        let clamped = max(0, min(time, songDuration > 0 ? songDuration : time))
        if abs(elapsedTime - clamped) > 0.001 {
            elapsedTime = clamped
            timestampDate = Date()
        }
    }
    
    /// FIX #95: Force switch to Spotify by fetching data directly via AppleScript
    /// This bypasses MediaRemote which may be stuck on a stale source (e.g., paused browser)
    func forceUpdateFromSpotify() {
        print("🎵 MusicManager: Forcing update from Spotify via AppleScript…")
        
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
                self.currentTrackIdentity = self.makeTrackIdentity(
                    title: title,
                    artist: artist,
                    album: album ?? "",
                    bundleId: SpotifyController.spotifyBundleId
                )
                self.currentContentItemIdentifier = nil
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
    private var hasReceivedStreamUpdate: Bool = false
    private var fallbackTimingTimer: Timer?
    private var isFallbackFetchInFlight = false
    private var lastFallbackFetchAt: Date = .distantPast
    private let fallbackTimingSyncInterval: TimeInterval = 1.0
    private let fallbackStaleThreshold: TimeInterval = 1.25
    private let fallbackFetchCooldown: TimeInterval = 0.75
    private var spotifyPausedSourceReacquireTimer: Timer?
    private var spotifyPausedSourceReacquireDeadline: Date = .distantPast
    private var isSpotifyPausedSourceReacquireFetchInFlight = false
    private let spotifyPausedSourceReacquireInterval: TimeInterval = 0.7
    private let spotifyPausedSourceReacquireWindow: TimeInterval = 6.0

    // Defer high-frequency media updates while NSMenu is actively tracking.
    // This keeps status-item menu highlight responsive.
    private var menuTrackingDepth: Int = 0
    private var deferredUpdateDuringMenuTracking: NowPlayingUpdate?
    private var menuTrackingObservers: [NSObjectProtocol] = []
    
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
        setupMenuTrackingObservers()

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
        stopSpotifyPausedSourceReacquire()
        songTitle = ""
        artistName = ""
        albumName = ""
        albumArt = NSImage()
        isPlaying = false
        songDuration = 0
        elapsedTime = 0
        playbackRate = 0
        timestampDate = .distantPast
        bundleIdentifier = nil
        currentTrackIdentity = ""
        currentContentItemIdentifier = nil
        lastArtworkTrackIdentity = ""
        lastArtworkContentItemIdentifier = nil
        lastParsedEventTimestampString = nil
        lastParsedEventTimestampDate = nil
        wasRecentlyPlaying = false
        isMediaHUDForced = false
        stopAppleMusicMetadataSyncTimer()
        stopFallbackTimingSync()
    }
    
    /// Called when screen wakes from sleep - restart the adapter to prevent frozen HUD
    @objc private func handleScreenWake() {
        print("MusicManager: Screen woke - restarting adapter process to refresh media stream…")
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
    private func fetchFullNowPlayingInfo(
        allowPayloadDuringActiveStream: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        guard let scriptURL = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl"),
              let frameworkPath = Bundle.main.privateFrameworksPath?.appending("/MediaRemoteAdapter.framework") else {
            completion?()
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptURL.path, frameworkPath, "get", "--now"]
        
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
                    musicManagerLog("MusicManager: Metadata fetch received \(data.count) bytes")
                    self?.processJSONLine(data, allowPayloadDuringActiveStream: allowPayloadDuringActiveStream)
                }
                DispatchQueue.main.async {
                    completion?()
                }
            }
        } catch {
            print("MusicManager: Cold start fetch failed: \(error)")
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    /// When Spotify is paused, periodically re-query Now Playing so browser playback
    /// (for example Safari/YouTube) can reclaim the active source without killing Spotify.
    private func scheduleSpotifyPausedSourceReacquire() {
        guard bundleIdentifier == SpotifyController.spotifyBundleId else { return }
        guard !songTitle.isEmpty || !artistName.isEmpty else { return }

        let now = Date()
        if spotifyPausedSourceReacquireTimer != nil,
           spotifyPausedSourceReacquireDeadline.timeIntervalSince(now) > 0.25 {
            return
        }

        stopSpotifyPausedSourceReacquire()
        spotifyPausedSourceReacquireDeadline = now.addingTimeInterval(spotifyPausedSourceReacquireWindow)

        attemptSpotifyPausedSourceReacquire()

        let timer = Timer.scheduledTimer(withTimeInterval: spotifyPausedSourceReacquireInterval, repeats: true) { [weak self] _ in
            self?.attemptSpotifyPausedSourceReacquire()
        }
        RunLoop.main.add(timer, forMode: .common)
        spotifyPausedSourceReacquireTimer = timer
    }

    private func stopSpotifyPausedSourceReacquire() {
        spotifyPausedSourceReacquireTimer?.invalidate()
        spotifyPausedSourceReacquireTimer = nil
        spotifyPausedSourceReacquireDeadline = .distantPast
        isSpotifyPausedSourceReacquireFetchInFlight = false
    }

    private func attemptSpotifyPausedSourceReacquire() {
        guard bundleIdentifier == SpotifyController.spotifyBundleId else {
            stopSpotifyPausedSourceReacquire()
            return
        }
        guard Date() <= spotifyPausedSourceReacquireDeadline else {
            stopSpotifyPausedSourceReacquire()
            return
        }
        guard !isSpotifyPausedSourceReacquireFetchInFlight else { return }

        SpotifyController.shared.isSpotifyPlaying { [weak self] isSpotifyPlaying in
            guard let self else { return }
            guard self.bundleIdentifier == SpotifyController.spotifyBundleId else {
                self.stopSpotifyPausedSourceReacquire()
                return
            }

            // Spotify is active again, so no fallback probing is needed.
            if isSpotifyPlaying {
                self.stopSpotifyPausedSourceReacquire()
                return
            }

            if self.isPlaying {
                self.isPlaying = false
                self.playbackRate = 0
            }

            guard Date() <= self.spotifyPausedSourceReacquireDeadline else {
                self.stopSpotifyPausedSourceReacquire()
                return
            }

            self.isSpotifyPausedSourceReacquireFetchInFlight = true
            self.fetchFullNowPlayingInfo(allowPayloadDuringActiveStream: true) { [weak self] in
                guard let self else { return }
                self.isSpotifyPausedSourceReacquireFetchInFlight = false
                if self.bundleIdentifier != SpotifyController.spotifyBundleId {
                    self.stopSpotifyPausedSourceReacquire()
                } else if Date() > self.spotifyPausedSourceReacquireDeadline {
                    self.stopSpotifyPausedSourceReacquire()
                }
            }
        }
    }
    
    deinit {
        removeMenuTrackingObservers()
        stopSpotifyPausedSourceReacquire()
        stopFallbackTimingSync()
        stopAdapterProcess()
    }

    private func setupMenuTrackingObservers() {
        let center = NotificationCenter.default

        let beginObserver = center.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.menuTrackingDepth += 1
        }
        menuTrackingObservers.append(beginObserver)

        let endObserver = center.addObserver(
            forName: NSMenu.didEndTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.menuTrackingDepth = max(0, self.menuTrackingDepth - 1)

            guard self.menuTrackingDepth == 0,
                  let deferred = self.deferredUpdateDuringMenuTracking else {
                return
            }

            self.deferredUpdateDuringMenuTracking = nil
            Task { @MainActor [weak self] in
                self?.handleUpdate(deferred)
            }
        }
        menuTrackingObservers.append(endObserver)
    }

    private func removeMenuTrackingObservers() {
        let center = NotificationCenter.default
        for observer in menuTrackingObservers {
            center.removeObserver(observer)
        }
        menuTrackingObservers.removeAll()
        menuTrackingDepth = 0
        deferredUpdateDuringMenuTracking = nil
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
                musicManagerLog("MusicManager: Adapter process ended (empty data)")
                handle.readabilityHandler = nil
                return
            }
            
            musicManagerLog("MusicManager: Received \(data.count) bytes")
            buffer.append(data)
            
            // Process complete JSON lines
            while let newlineIndex = buffer.firstIndex(of: 0x0A) { // '\n'
                let lineData = Data(buffer[..<newlineIndex])
                buffer = Data(buffer[(newlineIndex + 1)...])
                
                if !lineData.isEmpty {
                    if let lineStr = String(data: lineData, encoding: .utf8) {
                        musicManagerLog("MusicManager: JSON line: \(lineStr.prefix(200))…")
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
        stopSpotifyPausedSourceReacquire()
        
        if let process = adapterProcess, process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
        adapterProcess = nil
        outputPipe = nil
    }

    private var shouldRunFallbackTimingSync: Bool {
        guard isPlaying else { return false }
        guard bundleIdentifier != nil else { return false }
        return !isAppleMusicSource
    }

    private func stopFallbackTimingSync() {
        fallbackTimingTimer?.invalidate()
        fallbackTimingTimer = nil
        isFallbackFetchInFlight = false
        lastFallbackFetchAt = .distantPast
    }

    private func requestTimingResyncIfNeeded(reason: String, force: Bool = false) {
        _ = reason // Reserved for MUSYMUSY diagnostics.
        guard !isTimingSuppressed else { return }
        guard !isFallbackFetchInFlight else { return }

        let now = Date()
        if !force {
            guard now.timeIntervalSince(lastFallbackFetchAt) >= fallbackFetchCooldown else { return }
            guard now.timeIntervalSince(timestampDate) > fallbackStaleThreshold else { return }
        }

        if isSpotifySource {
            SpotifyController.shared.isSpotifyPlaying { [weak self] isSpotifyPlaying in
                guard let self else { return }
                guard self.bundleIdentifier == SpotifyController.spotifyBundleId else { return }
                if !isSpotifyPlaying && self.isPlaying {
                    self.isPlaying = false
                    self.playbackRate = 0
                }
            }
        }

        isFallbackFetchInFlight = true
        lastFallbackFetchAt = now
        fetchFullNowPlayingInfo(allowPayloadDuringActiveStream: true) { [weak self] in
            self?.isFallbackFetchInFlight = false
        }
    }

    private func updateFallbackTimingSyncState() {
        if shouldRunFallbackTimingSync {
            if fallbackTimingTimer == nil {
                let timer = Timer.scheduledTimer(withTimeInterval: fallbackTimingSyncInterval, repeats: true) { [weak self] _ in
                    self?.requestTimingResyncIfNeeded(reason: "fallback_timer")
                }
                RunLoop.main.add(timer, forMode: .common)
                fallbackTimingTimer = timer
            }
            requestTimingResyncIfNeeded(reason: "fallback_start")
        } else {
            stopFallbackTimingSync()
        }
    }
    
    // MARK: - JSON Stream Processing
    
    private func processJSONLine(_ data: Data, allowPayloadDuringActiveStream: Bool = false) {
        // Debug: Optional raw JSON logging for timing investigations.
        if musicManagerVerboseLogs, let jsonStr = String(data: data, encoding: .utf8) {
            musicManagerLog("MusicManager: Raw JSON received: \(jsonStr.prefix(500))")
        }
        
        do {
            let decoder = JSONDecoder()
            // Try decoding as full update structure first
            if let update = try? decoder.decode(NowPlayingUpdate.self, from: data) {
                DispatchQueue.main.async { [weak self] in
                    self?.hasReceivedStreamUpdate = true
                    self?.handleUpdate(update)
                }
                return
            }
            
            // Fallback: Try decoding as payload directly (adapter "get" command output format)
            let payload = try decoder.decode(NowPlayingUpdate.NowPlayingPayload.self, from: data)
            let update = NowPlayingUpdate(type: "data", payload: payload, diff: false)
            musicManagerLog("MusicManager: Decoded as direct payload")
            
            DispatchQueue.main.async { [weak self] in
                // Ignore cold-start "get" snapshots once stream updates are active.
                if self?.hasReceivedStreamUpdate == true && !allowPayloadDuringActiveStream {
                    return
                }
                self?.handleUpdate(update)
            }
        } catch {
            print("MusicManager: Failed to decode JSON: \(error)")
        }
    }
    
    @MainActor
    private func handleUpdate(_ update: NowPlayingUpdate) {
        if menuTrackingDepth > 0 {
            // Safety net: if tracking notifications became unbalanced, recover automatically.
            if RunLoop.main.currentMode != .eventTracking {
                let hasVisibleMenuWindow = NSApp.windows.contains { window in
                    guard window.isVisible else { return false }
                    guard window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue else { return false }
                    return NSStringFromClass(type(of: window)).lowercased().contains("menu")
                }
                if !hasVisibleMenuWindow {
                    menuTrackingDepth = 0
                }
            }
        }

        if menuTrackingDepth > 0 {
            deferredUpdateDuringMenuTracking = update
            return
        }

        let payload = update.payload

        // MARK: Media Source Filter
        // Record detected source for settings UI (even if filtered)
        if let bundleId = payload.launchableBundleIdentifier {
            recordDetectedSource(bundleId)
        }

        // Check if this source is allowed by the filter
        if !isBundleAllowed(payload.launchableBundleIdentifier) {
            musicManagerLog("MusicManager: Skipping update from filtered source: \(payload.launchableBundleIdentifier ?? "unknown")")
            
            // FIX: If the blocked source matches the currently displayed source, clear the display
            // This handles the case where filter is enabled while content from a blocked source is already showing
            if payload.launchableBundleIdentifier == bundleIdentifier {
                musicManagerLog("MusicManager: Current display is from blocked source - clearing")
                clearMediaDisplay()
            }
            return
        }

        // Check if this is from an incognito/private browsing window
        if isFromIncognitoBrowser(payload.launchableBundleIdentifier) {
            musicManagerLog("MusicManager: Skipping update from incognito browser: \(payload.launchableBundleIdentifier ?? "unknown")")
            
            // Clear display if incognito source was previously shown
            if payload.launchableBundleIdentifier == bundleIdentifier {
                musicManagerLog("MusicManager: Current display is from incognito browser - clearing")
                clearMediaDisplay()
            }
            return
        }

        // MARK: - Track + Timing State
        let previousBundleIdentifier = bundleIdentifier
        let incomingBundleFromPayload = payload.launchableBundleIdentifier
        let incomingBundleId = incomingBundleFromPayload ?? previousBundleIdentifier
        let sourceChanged = incomingBundleFromPayload != nil && incomingBundleFromPayload != previousBundleIdentifier
        let payloadContentItemChanged = payload.contentItemIdentifier != nil &&
            payload.contentItemIdentifier != currentContentItemIdentifier

        // Never carry text metadata from an old source/track into a new source snapshot.
        // This prevents mixed state such as "new artwork + old YouTube title".
        let incomingTitle = (sourceChanged || payloadContentItemChanged) ? (payload.title ?? "") : (payload.title ?? songTitle)
        let incomingArtist = (sourceChanged || payloadContentItemChanged) ? (payload.artist ?? "") : (payload.artist ?? artistName)
        let incomingAlbum = (sourceChanged || payloadContentItemChanged) ? (payload.album ?? "") : (payload.album ?? albumName)

        let incomingIdentity = makeTrackIdentity(
            title: incomingTitle,
            artist: incomingArtist,
            album: incomingAlbum,
            bundleId: incomingBundleId
        )
        let metadataChanged = !currentTrackIdentity.isEmpty && incomingIdentity != currentTrackIdentity
        let rawElapsed = payload.elapsedTimeNow ?? payload.elapsedTime
        let payloadLooksIdle = payload.title == nil &&
            payload.artist == nil &&
            payload.album == nil &&
            payload.contentItemIdentifier == nil &&
            (payload.duration ?? 0) <= 0 &&
            rawElapsed == nil &&
            !payload.isPlaying &&
            (payload.playbackRate ?? 0) <= 0

        // Source switched (or current source went idle) but payload has no active media:
        // clear stale metadata so the notch can collapse instead of staying "stuck".
        if payloadLooksIdle && (sourceChanged || (!songTitle.isEmpty || !artistName.isEmpty || !albumName.isEmpty)) {
            clearMediaDisplay()
            updateFallbackTimingSyncState()
            return
        }

        let hasReadableMetadata = !incomingTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !incomingArtist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !incomingAlbum.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasStrongMediaIdentity = payload.contentItemIdentifier != nil || (payload.duration ?? 0) > 0 || rawElapsed != nil
        let shouldAcceptArtworkForPayload = !sourceChanged || hasReadableMetadata || hasStrongMediaIdentity

        let incomingElapsed = rawElapsed
        let elapsedRestarted = (incomingElapsed ?? elapsedTime) + 1.0 < elapsedTime
        let implicitBoundary = !isTimingSuppressed && payload.isPlaying && elapsedRestarted && elapsedTime > 5
        // Never treat content-item churn during seek as a track change.
        let isTrackChange = metadataChanged || implicitBoundary
        let previousIsPlaying = isPlaying
        let previousPlaybackRate = playbackRate
        let previousProjectedPosition = estimatedPlaybackPosition(at: Date())
        let staleEndSnapshot = isTrackChange && {
            guard let elapsed = rawElapsed, let duration = payload.duration, duration > 0 else { return false }
            guard elapsed.isFinite, duration.isFinite else { return false }
            // Some sources emit stale "end of previous track" timing right after metadata switch.
            return elapsed > 10 && elapsed >= (duration - 0.35)
        }()

        if isTrackChange {
            // Hard reset timing on track change to prevent carrying over stale values.
            songDuration = 0
            elapsedTime = 0
            timestampDate = Date()

            let nextBundle = incomingBundleId ?? bundleIdentifier
            if nextBundle == SpotifyController.spotifyBundleId {
                SpotifyController.shared.onTrackChange()
            }
            if nextBundle == AppleMusicController.appleMusicBundleId {
                AppleMusicController.shared.onTrackChange()
            }
            let timingIncomplete = (payload.elapsedTimeNow == nil && payload.elapsedTime == nil) || ((payload.duration ?? 0) <= 0)
            if timingIncomplete || staleEndSnapshot {
                requestTimingResyncIfNeeded(reason: "track_change_seed", force: true)
            }
        }

        if songTitle != incomingTitle {
            songTitle = incomingTitle
        }
        if artistName != incomingArtist {
            artistName = incomingArtist
        }
        if albumName != incomingAlbum {
            albumName = incomingAlbum
        }
        if currentTrackIdentity != incomingIdentity {
            currentTrackIdentity = incomingIdentity
        }
        currentContentItemIdentifier = payload.contentItemIdentifier

        if let duration = payload.duration, duration > 0 {
            // Ignore stale end-boundary duration that belongs to the previous track.
            if !staleEndSnapshot {
                if abs(songDuration - duration) > 0.001 {
                    songDuration = duration
                }
            }
        } else if isTrackChange {
            songDuration = 0
        }

        let eventTimestamp = parsedEventTimestamp(from: payload.timestamp)

        // Accept adapter timing directly; projection happens in estimatedPlaybackPosition().
        if let elapsed = rawElapsed, !isTimingSuppressed, !staleEndSnapshot {
            var newElapsedTime = elapsed

            // If adapter didn't provide elapsedTimeNow, compensate elapsedTime to "now"
            // using timestamp age. Anchor final state to Date() to avoid stale timestamp drift.
            if payload.elapsedTimeNow == nil {
                let age = Date().timeIntervalSince(eventTimestamp)
                let rate = payload.playbackRate ?? playbackRate
                if payload.isPlaying && age >= 0 && age < 8 && rate > 0 {
                    newElapsedTime += age * rate
                }
            }
            // Clamp to duration if available
            if songDuration > 0 {
                newElapsedTime = min(max(0, newElapsedTime), songDuration)
            } else {
                newElapsedTime = max(0, newElapsedTime)
            }

            if abs(elapsedTime - newElapsedTime) > 0.001 {
                elapsedTime = newElapsedTime
            }
            timestampDate = Date()
        } else if isTrackChange {
            elapsedTime = 0
            timestampDate = Date()
        }

        let newPlaybackRate: Double = {
            if let rate = payload.playbackRate { return rate }
            if let playing = payload.playing { return playing ? max(previousPlaybackRate, 1.0) : 0 }
            return previousPlaybackRate
        }()
        let newIsPlaying = payload.isPlaying

        if rawElapsed == nil && !isTrackChange && !isTimingSuppressed &&
            (newPlaybackRate != previousPlaybackRate || newIsPlaying != previousIsPlaying) {
            var anchored = previousProjectedPosition
            if songDuration > 0 {
                anchored = min(max(0, anchored), songDuration)
            } else {
                anchored = max(0, anchored)
            }
            if abs(elapsedTime - anchored) > 0.001 {
                elapsedTime = anchored
            }
            timestampDate = Date()
        }

        if abs(playbackRate - newPlaybackRate) > 0.0001 {
            playbackRate = newPlaybackRate
        }
        if let bundle = payload.launchableBundleIdentifier {
            let previousBundle = bundleIdentifier
            let wasSpotify = isSpotifySource
            let wasAppleMusic = isAppleMusicSource

            if previousBundle != bundle {
                bundleIdentifier = bundle
            }
            
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
                startAppleMusicMetadataSyncTimer()
            }
            
            // PERFORMANCE FIX: Stop Spotify's position sync timer when switching away
            // This prevents a "zombie timer" from running when another source is active
            if wasSpotify && !isSpotifySource {
                SpotifyController.shared.stopPositionSyncTimer()
                stopSpotifyPausedSourceReacquire()
            }
            
            // PERFORMANCE FIX: Stop Apple Music's position sync timer when switching away
            if wasAppleMusic && !isAppleMusicSource {
                AppleMusicController.shared.stopPositionSyncTimer()
                stopAppleMusicMetadataSyncTimer()
            }
        }
        
        // Keep play state aligned with adapter payload.
        if isPlaying != newIsPlaying {
            isPlaying = newIsPlaying
        }
        if bundleIdentifier == SpotifyController.spotifyBundleId && !isPlaying {
            scheduleSpotifyPausedSourceReacquire()
        } else {
            stopSpotifyPausedSourceReacquire()
        }
        
        // Handle artwork only when track identity changes or when artwork is missing.
        if let base64Art = payload.artworkData, shouldAcceptArtworkForPayload {
            let contentItemChanged = payload.contentItemIdentifier != nil &&
                payload.contentItemIdentifier != lastArtworkContentItemIdentifier
            let artworkTrackChanged = incomingIdentity != lastArtworkTrackIdentity
            let hasNoArtwork = albumArt.size.width <= 0 || albumArt.size.height <= 0

            if isTrackChange || contentItemChanged || artworkTrackChanged || hasNoArtwork,
               let artData = Data(base64Encoded: base64Art),
               let image = NSImage(data: artData) {
                albumArt = image
                lastArtworkTrackIdentity = incomingIdentity
                lastArtworkContentItemIdentifier = payload.contentItemIdentifier
            }
        } else if isTrackChange {
            lastArtworkTrackIdentity = ""
            lastArtworkContentItemIdentifier = nil
        }
        
        // Debug: Log the update
        musicManagerLog(
            "MusicManager: Updated - title='\(songTitle)', artist='\(artistName)', isPlaying=\(isPlaying), elapsed=\(elapsedTime), duration=\(songDuration), rate=\(playbackRate)"
        )
        updateFallbackTimingSyncState()
    }

    private func parsedEventTimestamp(from rawTimestamp: String?) -> Date {
        guard let rawTimestamp else { return Date() }

        if rawTimestamp == lastParsedEventTimestampString,
           let cachedDate = lastParsedEventTimestampDate {
            return cachedDate
        }

        let parsed = iso8601DateFormatter.date(from: rawTimestamp) ?? Date()
        lastParsedEventTimestampString = rawTimestamp
        lastParsedEventTimestampDate = parsed
        return parsed
    }
    
    // MARK: - Cached Visualizer Color
    
    /// Updates the cached visualizer colors from current album art
    /// PERFORMANCE: Called once per track change instead of on every view body evaluation
    private func updateCachedVisualizerColor() {
        if albumArt.size.width > 0 {
            let colors = albumArt.extractTwoColors()
            visualizerColor = colors.primary
            visualizerSecondaryColor = colors.secondary
        } else {
            visualizerColor = .white.opacity(0.7)
            visualizerSecondaryColor = .gray.opacity(0.7)
        }
    }
    
    // MARK: - Apple Music Metadata Sync

    /// Start periodic Apple Music metadata reconciliation
    private func startAppleMusicMetadataSyncTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.stopAppleMusicMetadataSyncTimer()

            let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.syncAppleMusicTrackInfo()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.appleMusicMetadataSyncTimer = timer

            self.syncAppleMusicTrackInfo()
        }
    }

    /// Stop periodic Apple Music metadata reconciliation
    private func stopAppleMusicMetadataSyncTimer() {
        appleMusicMetadataSyncTimer?.invalidate()
        appleMusicMetadataSyncTimer = nil
    }

    /// Reconcile Apple Music track info via AppleScript when MediaRemote is stale
    private func syncAppleMusicTrackInfo() {
        guard isAppleMusicSource else {
            stopAppleMusicMetadataSyncTimer()
            return
        }

        guard AppleMusicController.shared.isAppleMusicRunning else { return }

        AppleMusicController.shared.fetchCurrentTrackInfo { [weak self] title, artist, album, duration, position in
            guard let self = self else { return }
            guard self.isAppleMusicSource else { return }
            guard let title = title, let artist = artist else { return }

            let resolvedAlbum = album ?? ""
            let didChange = title != self.songTitle || artist != self.artistName || resolvedAlbum != self.albumName

            if didChange {
                self.songTitle = title
                self.artistName = artist
                self.albumName = resolvedAlbum

                if let duration = duration, duration > 0 {
                    self.songDuration = duration
                }
                if let position = position {
                    self.elapsedTime = position
                    self.timestampDate = Date()
                }

                self.bundleIdentifier = AppleMusicController.appleMusicBundleId
                self.currentTrackIdentity = self.makeTrackIdentity(
                    title: title,
                    artist: artist,
                    album: resolvedAlbum,
                    bundleId: AppleMusicController.appleMusicBundleId
                )
                self.currentContentItemIdentifier = nil

                AppleMusicController.shared.onTrackChange()
            }
        }
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
        // FIX: Use displayDurationForUI instead of songDuration for clamping.
        // When songDuration is 0 (not yet loaded), don't clamp to 0.
        let duration = displayDurationForUI
        let clampedTime = duration > 0 ? max(0, min(time, duration)) : max(0, time)
        print("MusicManager: Seeking to \(clampedTime)s (duration: \(duration)s)")
        
        // FIX: Suppress timing updates briefly so stale payloads from the old position
        // don't overwrite our seek target.
        suppressTimingUpdates(for: 2.0)
        
        // Update local state immediately for responsive UI (synchronous, not async)
        elapsedTime = clampedTime
        timestampDate = Date()

        // When source filtering is enabled, seek directly in the displayed source app.
        if isMediaSourceFilterEnabled, let displayedBundle = bundleIdentifier {
            if displayedBundle == SpotifyController.spotifyBundleId {
                runAppleScriptAsync("tell application \"Spotify\" to set player position to \(clampedTime)")
                return
            }
            if displayedBundle == AppleMusicController.appleMusicBundleId {
                runAppleScriptAsync("tell application \"Music\" to set player position to \(clampedTime)")
                return
            }
        }

        guard let setElapsedTime = MRMediaRemoteSetElapsedTimePtr else {
            print("MusicManager: Seek failed - MRMediaRemoteSetElapsedTime not available")
            return
        }

        // Call the MediaRemote function to seek
        setElapsedTime(clampedTime)
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
            print("MusicManager: Fallback to Apple Music")
            _ = bringAppToFront(bundleId: "com.apple.Music")
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
            if !bringAppToFront(bundleId: bundleId) {
                print("MusicManager: Could not find app with bundleId: \(bundleId)")
            }
        }
    }

    /// Strongly activate an app and bring its windows to the front.
    @discardableResult
    private func bringAppToFront(bundleId: String) -> Bool {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            print("MusicManager: Bringing running app to front: \(bundleId)")
            app.unhide()
            let activated = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            if !activated {
                print("MusicManager: Initial activate() returned false for \(bundleId)")
            }

            // For web-wrapper/process-hosted apps, a reopen event often brings the
            // user-facing window forward more reliably than activate() alone.
            forceFrontmostActivation(bundleId: bundleId, appName: app.localizedName, includeReopen: true)

            // Retry once on the next runloop tick to beat race conditions with
            // non-activating panels and transient focus changes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                app.unhide()
                _ = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            }
            return true
        }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return false
        }

        print("MusicManager: Opening and activating app: \(bundleId)")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, error in
            if let error {
                print("MusicManager: Failed to open app \(bundleId): \(error.localizedDescription)")
                return
            }
            if let app {
                app.unhide()
                _ = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                self.forceFrontmostActivation(bundleId: bundleId, appName: app.localizedName, includeReopen: true)
            }
        }
        return true
    }

    /// Extra activation nudge for apps that ignore standard NSRunningApplication.activate.
    private func forceFrontmostActivation(bundleId: String, appName: String?, includeReopen: Bool) {
        let escapedBundle = escapeForAppleScript(bundleId)
        let escapedName = escapeForAppleScript(appName ?? "")
        let reopenLine = includeReopen ? "reopen" : ""

        let script: String
        if escapedName.isEmpty {
            script = """
            tell application id "\(escapedBundle)"
                activate
                \(reopenLine)
            end tell
            """
        } else {
            script = """
            tell application id "\(escapedBundle)"
                activate
                \(reopenLine)
            end tell
            tell application "System Events"
                if exists process "\(escapedName)" then
                    set frontmost of process "\(escapedName)" to true
                end if
            end tell
            """
        }

        runAppleScriptAsync(script)
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
        runAppleScript(script, appName: "Safari", bundleId: "com.apple.Safari")
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
        let appName = getAppName(from: bundleId) ?? "Firefox"
        print("MusicManager: Activating \(appName) (limited tab support)")
        _ = bringAppToFront(bundleId: bundleId)
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
        
        runAppleScript(script, appName: "Arc", bundleId: "company.thebrowser.Browser")
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
    
    /// Run AppleScript asynchronously, then force source-app activation.
    private func runAppleScript(_ source: String, appName: String, bundleId: String? = nil) {
        // Use serial queue to prevent concurrent AppleScript execution
        // NSAppleScript is NOT thread-safe and concurrent calls crash the runtime
        appleScriptQueue.async { [weak self] in
            let (resultString, errorDescription): (String?, String?) = AppleScriptRuntime.execute {
                var error: NSDictionary?
                guard let script = NSAppleScript(source: source) else {
                    return (nil, "Failed to create AppleScript")
                }
                let result = script.executeAndReturnError(&error)
                if let error {
                    return (nil, "\(error)")
                }
                return (result.stringValue, nil)
            }

            if let errorDescription {
                print("MusicManager: AppleScript error for \(appName): \(errorDescription)")
            } else {
                print("MusicManager: AppleScript result for \(appName): \(resultString ?? "success")")
            }

            // Always force app activation afterwards. If tab matching failed, users still
            // expect the source app/window to come to the front from an album-art click.
            DispatchQueue.main.async {
                let targetBundleId = bundleId ?? self?.bundleIdentifier
                if let bundleId = targetBundleId {
                    _ = self?.bringAppToFront(bundleId: bundleId)
                }
            }
        }
    }
    
    func estimatedPlaybackPosition(at date: Date = Date()) -> Double {
        guard isPlaying else {
            if songDuration > 0 {
                return min(max(elapsedTime, 0), songDuration)
            } else {
                return max(elapsedTime, 0)
            }
        }
        let delta = max(0, date.timeIntervalSince(timestampDate))
        let progressed = elapsedTime + (delta * playbackRate)
        if songDuration > 0 {
            return min(max(progressed, 0), songDuration)
        } else {
            return max(progressed, 0)
        }
    }
}
