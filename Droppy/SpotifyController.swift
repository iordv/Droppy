//
//  SpotifyController.swift
//  Droppy
//
//  Created by Droppy on 10/01/2026.
//  Spotify-specific media controls using AppleScript and Web API
//

import AppKit
import Foundation

/// Manages Spotify-specific features including shuffle, repeat, replay, and like functionality
/// Uses AppleScript for local controls and Web API for library features
@Observable
final class SpotifyController {
    static let shared = SpotifyController()
    
    // MARK: - State
    
    /// Whether shuffle is currently enabled in Spotify
    private(set) var shuffleEnabled: Bool = false
    
    /// Current repeat mode in Spotify
    private(set) var repeatMode: RepeatMode = .off
    
    /// Whether the current track is liked (in user's Liked Songs)
    private(set) var isCurrentTrackLiked: Bool = false
    
    /// Whether we're currently checking/updating liked status
    private(set) var isLikeLoading: Bool = false
    
    /// Whether user has authenticated with Spotify Web API
    private(set) var isAuthenticated: Bool = false
    
    /// Current track URI from Spotify (spotify:track:xxxxx)
    private(set) var currentTrackURI: String?
    
    /// Spotify bundle identifier
    static let spotifyBundleId = "com.spotify.client"
    
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
    
    private init() {
        // Check initial authentication state from Keychain
        isAuthenticated = SpotifyAuthManager.shared.isAuthenticated
    }
    
    // MARK: - Spotify Detection
    
    /// Check if Spotify is currently running (and extension is enabled)
    var isSpotifyRunning: Bool {
        // If extension is disabled, pretend Spotify is not running
        guard !ExtensionType.spotify.isRemoved else { return false }
        return NSRunningApplication.runningApplications(withBundleIdentifier: Self.spotifyBundleId).first != nil
    }
    
    /// Check if Spotify is currently playing (async)
    /// Used to detect if Spotify should be switched to when another source stops
    func isSpotifyPlaying(completion: @escaping (Bool) -> Void) {
        guard isSpotifyRunning else {
            completion(false)
            return
        }
        
        let script = """
        tell application "Spotify"
            if player state is playing then
                return true
            else
                return false
            end if
        end tell
        """
        
        runAppleScript(script) { result in
            let isPlaying = (result as? Bool) ?? false
            completion(isPlaying)
        }
    }
    
    /// FIX #95: Fetch current track info directly from Spotify via AppleScript
    /// This bypasses MediaRemote which may be stuck on a stale source
    func fetchCurrentTrackInfo(completion: @escaping (String?, String?, String?, Double?, Double?) -> Void) {
        guard isSpotifyRunning else {
            completion(nil, nil, nil, nil, nil)
            return
        }
        
        let script = """
        tell application "Spotify"
            if player state is not stopped then
                set trackTitle to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                set trackDuration to duration of current track
                set playerPos to player position
                return trackTitle & "|||" & trackArtist & "|||" & trackAlbum & "|||" & (trackDuration as string) & "|||" & (playerPos as string)
            else
                return ""
            end if
        end tell
        """
        
        runAppleScript(script) { result in
            guard let resultString = result as? String, !resultString.isEmpty else {
                completion(nil, nil, nil, nil, nil)
                return
            }
            
            let parts = resultString.components(separatedBy: "|||")
            guard parts.count >= 5 else {
                completion(nil, nil, nil, nil, nil)
                return
            }
            
            let title = parts[0]
            let artist = parts[1]
            let album = parts[2]
            // Spotify returns duration in milliseconds
            let durationMs = Double(parts[3]) ?? 0
            let durationSeconds = durationMs / 1000.0
            let position = Double(parts[4]) ?? 0
            
            completion(title, artist, album, durationSeconds, position)
        }
    }
    
    /// Refresh state when Spotify becomes the active source
    func refreshState() {
        // Don't refresh if extension is disabled
        guard !ExtensionType.spotify.isRemoved else { return }
        guard isSpotifyRunning else { return }
        
        // Track Spotify integration activation (only once per user)
        if !UserDefaults.standard.bool(forKey: "spotifyTracked") {
            AnalyticsService.shared.trackExtensionActivation(extensionId: "spotify")
            // Note: AnalyticsService.trackExtensionActivation also sets this key
        }
        
        // Fetch shuffle and repeat state
        fetchShuffleState()
        fetchRepeatState()
        fetchCurrentTrackURI()
        
        // Start periodic position sync for rock-solid timestamps
        startPositionSyncTimer()
        
        // If authenticated, check liked status
        if isAuthenticated, let uri = currentTrackURI {
            checkIfTrackIsLiked(uri: uri)
        }
    }
    
    // MARK: - Position Sync Timer
    
    private var positionSyncTimer: Timer?
    
    /// Start periodic position sync - Spotify timing is ONLY from AppleScript
    private func startPositionSyncTimer() {
        // Must be on main thread for timer to work
        DispatchQueue.main.async { [weak self] in
            self?.stopPositionSyncTimer()
            
            // Poll every 1 second for rock-solid accuracy
            self?.positionSyncTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.syncPlayerPosition()
            }
            
            // Add to main run loop explicitly
            if let timer = self?.positionSyncTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
            
            // Sync immediately too
            self?.syncPlayerPosition()
        }
    }
    
    /// Stop the position sync timer
    func stopPositionSyncTimer() {
        positionSyncTimer?.invalidate()
        positionSyncTimer = nil
    }
    
    /// Called when track changes - update URI and liked status
    func onTrackChange() {
        fetchCurrentTrackURI()
        
        if isAuthenticated, let uri = currentTrackURI {
            checkIfTrackIsLiked(uri: uri)
        } else {
            isCurrentTrackLiked = false
        }
    }
    
    // MARK: - AppleScript Controls
    
    /// Toggle shuffle on/off
    func toggleShuffle() {
        let script = """
        tell application "Spotify"
            set shuffling to not shuffling
            return shuffling
        end tell
        """
        
        runAppleScript(script) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.fetchShuffleState()
            }
        }
    }
    
    /// Cycle through repeat modes: off → context → track → off
    func cycleRepeatMode() {
        toggleRepeat()
    }
    
    /// Toggle repeat on/off (AppleScript only supports binary)
    func toggleRepeat() {
        let script = """
        tell application "Spotify"
            set repeating to not repeating
            return repeating
        end tell
        """
        
        runAppleScript(script) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.fetchRepeatState()
            }
        }
    }
    
    /// Set specific repeat mode (limited to on/off via AppleScript)
    func setRepeatMode(_ mode: RepeatMode) {
        let shouldRepeat = mode != .off
        
        let script = """
        tell application "Spotify"
            set repeating to \(shouldRepeat)
        end tell
        """
        
        runAppleScript(script) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.fetchRepeatState()
            }
        }
    }
    
    /// Replay current track from beginning
    func replayCurrentTrack() {
        let script = """
        tell application "Spotify"
            set player position to 0
        end tell
        """
        
        runAppleScript(script) { _ in
            // Timer will pick up the new position
        }
    }
    
    /// Skip to previous track (or restart if > 3s in)
    func previousTrack() {
        let script = """
        tell application "Spotify"
            previous track
        end tell
        """
        
        runAppleScript(script) { _ in
            // Timer will pick up the new position
        }
    }
    
    // MARK: - State Fetching
    
    private func fetchShuffleState() {
        let script = """
        tell application "Spotify"
            return shuffling
        end tell
        """
        
        runAppleScript(script) { [weak self] result in
            if let shuffling = result as? Bool {
                DispatchQueue.main.async {
                    self?.shuffleEnabled = shuffling
                }
            }
        }
    }
    
    private func fetchRepeatState() {
        let script = """
        tell application "Spotify"
            return repeating
        end tell
        """
        
        runAppleScript(script) { [weak self] result in
            if let repeating = result as? Bool {
                DispatchQueue.main.async {
                    // Spotify AppleScript only tells us if repeating is on/off
                    // We can't distinguish between context and track repeat
                    self?.repeatMode = repeating ? .context : .off
                }
            }
        }
    }
    
    private func fetchCurrentTrackURI() {
        let script = """
        tell application "Spotify"
            if player state is not stopped then
                return id of current track
            end if
            return ""
        end tell
        """
        
        runAppleScript(script) { [weak self] result in
            if let uri = result as? String, !uri.isEmpty {
                DispatchQueue.main.async {
                    self?.currentTrackURI = uri
                }
            }
        }
    }
    
    /// Fetch the actual player position from Spotify (true source of elapsed time)
    func fetchPlayerPosition(completion: ((Double) -> Void)? = nil) {
        let script = """
        tell application "Spotify"
            return player position
        end tell
        """
        
        runAppleScript(script) { result in
            var position: Double = 0
            
            if let pos = result as? Double {
                position = pos
            } else if let pos = result as? Int {
                position = Double(pos)
            }
            
            completion?(position)
        }
    }
    
    /// Sync MusicManager elapsed time with Spotify's true position
    func syncPlayerPosition() {
        guard isSpotifyRunning else { return }
        
        fetchPlayerPosition { position in
            // ALWAYS update to Spotify's true position
            MusicManager.shared.forceElapsedTime(position)
        }
    }
    
    // MARK: - AppleScript Execution
    
    private func runAppleScript(_ source: String, completion: @escaping (Any?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            
            guard let script = NSAppleScript(source: source) else {
                print("SpotifyController: Failed to create AppleScript")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let result = script.executeAndReturnError(&error)
            
            if let error = error {
                print("SpotifyController: AppleScript error: \(error)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // Parse result based on descriptor type
            let parsed: Any?
            switch result.descriptorType {
            case typeTrue:
                parsed = true
            case typeFalse:
                parsed = false
            case typeIEEE64BitFloatingPoint:
                // Handle double/float (player position returns this!)
                parsed = result.doubleValue
            case typeIEEE32BitFloatingPoint:
                // Handle 32-bit float
                let floatBytes = result.data
                if floatBytes.count >= 4 {
                    var value: Float = 0
                    _ = withUnsafeMutableBytes(of: &value) { floatBytes.copyBytes(to: $0) }
                    parsed = Double(value)
                } else {
                    parsed = 0.0
                }
            case typeSInt32:
                parsed = Int(result.int32Value)
            case typeSInt64:
                // Handle 64-bit integer
                parsed = result.int32Value // Best we can do
            default:
                // Try string as fallback
                parsed = result.stringValue
            }
            
            DispatchQueue.main.async { completion(parsed) }
        }
    }
    
    // MARK: - Web API (Like Functionality)
    
    /// Like the current track (add to Liked Songs)
    func likeCurrentTrack() {
        guard isAuthenticated else {
            print("SpotifyController: Not authenticated, cannot like track")
            // Could trigger auth flow here
            return
        }
        
        guard let uri = currentTrackURI else {
            print("SpotifyController: No current track URI")
            return
        }
        
        isLikeLoading = true
        
        SpotifyAuthManager.shared.saveTrack(uri: uri) { [weak self] success in
            DispatchQueue.main.async {
                self?.isLikeLoading = false
                if success {
                    self?.isCurrentTrackLiked = true
                    print("SpotifyController: Track liked successfully")
                } else {
                    print("SpotifyController: Failed to like track")
                }
            }
        }
    }
    
    /// Unlike the current track (remove from Liked Songs)
    func unlikeCurrentTrack() {
        guard isAuthenticated else { return }
        guard let uri = currentTrackURI else { return }
        
        isLikeLoading = true
        
        SpotifyAuthManager.shared.removeTrack(uri: uri) { [weak self] success in
            DispatchQueue.main.async {
                self?.isLikeLoading = false
                if success {
                    self?.isCurrentTrackLiked = false
                    print("SpotifyController: Track unliked successfully")
                } else {
                    print("SpotifyController: Failed to unlike track")
                }
            }
        }
    }
    
    /// Toggle like status
    func toggleLike() {
        if isCurrentTrackLiked {
            unlikeCurrentTrack()
        } else {
            likeCurrentTrack()
        }
    }
    
    /// Check if a track is in user's Liked Songs
    private func checkIfTrackIsLiked(uri: String) {
        SpotifyAuthManager.shared.checkIfTrackIsSaved(uri: uri) { [weak self] isSaved in
            DispatchQueue.main.async {
                self?.isCurrentTrackLiked = isSaved
            }
        }
    }
    
    /// Trigger Spotify authentication
    func authenticate() {
        SpotifyAuthManager.shared.startAuthentication()
    }
    
    /// Sign out from Spotify
    func signOut() {
        SpotifyAuthManager.shared.signOut()
        isAuthenticated = false
        isCurrentTrackLiked = false
    }
    
    /// Update authentication state (called after OAuth callback)
    func updateAuthState() {
        isAuthenticated = SpotifyAuthManager.shared.isAuthenticated
        
        if isAuthenticated, let uri = currentTrackURI {
            checkIfTrackIsLiked(uri: uri)
        }
    }
}
