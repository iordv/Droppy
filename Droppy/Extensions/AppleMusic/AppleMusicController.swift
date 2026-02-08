//
//  AppleMusicController.swift
//  Droppy
//
//  Manages Apple Music-specific features including shuffle, repeat, replay, and love functionality
//  Uses AppleScript for all controls (no API key needed)
//

import AppKit
import Foundation

/// Manages Apple Music-specific features including shuffle, repeat, and love functionality
/// Uses AppleScript for local controls
@Observable
final class AppleMusicController {
    static let shared = AppleMusicController()
    
    // MARK: - State
    
    /// Whether shuffle is currently enabled in Apple Music
    private(set) var shuffleEnabled: Bool = false
    
    /// Current repeat mode in Apple Music
    private(set) var repeatMode: RepeatMode = .off
    
    /// Whether the current track is loved
    private(set) var isCurrentTrackLoved: Bool = false
    
    /// Whether we're currently checking/updating loved status
    private(set) var isLoveLoading: Bool = false
    
    /// Serial queue for AppleScript execution - NSAppleScript is NOT thread-safe
    /// Concurrent AppleScript calls crash the AppleScript runtime
    private let appleScriptQueue = DispatchQueue(label: "com.droppy.AppleMusicController.applescript")
    
    /// Apple Music bundle identifier
    static let appleMusicBundleId = "com.apple.Music"
    
    // MARK: - Repeat Mode
    
    enum RepeatMode: String, CaseIterable {
        case off = "off"
        case all = "all"      // Repeat playlist/album
        case one = "one"      // Repeat single track
        
        var displayName: String {
            switch self {
            case .off: return "Off"
            case .all: return "All"
            case .one: return "One"
            }
        }
        
        var iconName: String {
            switch self {
            case .off: return "repeat"
            case .all: return "repeat"
            case .one: return "repeat.1"
            }
        }
        
        var next: RepeatMode {
            switch self {
            case .off: return .all
            case .all: return .one
            case .one: return .off
            }
        }
        
        /// AppleScript constant name
        var appleScriptValue: String {
            switch self {
            case .off: return "off"
            case .all: return "all"
            case .one: return "one"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Apple Music Detection
    
    /// Check if Apple Music is currently running (and extension is enabled)
    var isAppleMusicRunning: Bool {
        // If extension is disabled, pretend Apple Music is not running
        guard !ExtensionType.appleMusic.isRemoved else { return false }
        return NSRunningApplication.runningApplications(withBundleIdentifier: Self.appleMusicBundleId).first != nil
    }
    
    /// Check if Apple Music is currently playing (async)
    func isAppleMusicPlaying(completion: @escaping (Bool) -> Void) {
        guard isAppleMusicRunning else {
            completion(false)
            return
        }
        
        let script = """
        tell application "Music"
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
    
    /// Fetch current track info directly from Apple Music via AppleScript
    func fetchCurrentTrackInfo(completion: @escaping (String?, String?, String?, Double?, Double?) -> Void) {
        guard isAppleMusicRunning else {
            completion(nil, nil, nil, nil, nil)
            return
        }
        
        let script = """
        tell application "Music"
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
            let duration = Double(parts[3]) ?? 0
            let position = Double(parts[4]) ?? 0
            
            completion(title, artist, album, duration, position)
        }
    }
    
    /// Refresh state when Apple Music becomes the active source
    func refreshState() {
        // Don't refresh if extension is disabled
        guard !ExtensionType.appleMusic.isRemoved else { return }
        guard isAppleMusicRunning else { return }
        
        // Track Apple Music integration activation (only once per user)
        if !UserDefaults.standard.bool(forKey: "appleMusicTracked") {
            AnalyticsService.shared.trackExtensionActivation(extensionId: "appleMusic")
        }
        
        // Fetch shuffle and repeat state
        fetchShuffleState()
        fetchRepeatState()
        fetchLovedState()
        
        // Start periodic position sync for accurate timestamps
        startPositionSyncTimer()
    }
    
    // MARK: - Position Sync Timer
    
    private var positionSyncTimer: Timer?
    
    /// Start periodic position sync
    private func startPositionSyncTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.stopPositionSyncTimer()
            
            // Poll every 1 second for accurate progress
            self?.positionSyncTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.syncPlayerPosition()
            }
            
            if let timer = self?.positionSyncTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
            
            self?.syncPlayerPosition()
        }
    }
    
    /// Stop the position sync timer
    func stopPositionSyncTimer() {
        positionSyncTimer?.invalidate()
        positionSyncTimer = nil
    }
    
    /// Called when track changes - update loved status
    func onTrackChange() {
        fetchLovedState()
    }
    
    // MARK: - AppleScript Controls
    
    /// Toggle shuffle on/off
    func toggleShuffle() {
        let script = """
        tell application "Music"
            set shuffle enabled to not shuffle enabled
            return shuffle enabled
        end tell
        """
        
        runAppleScript(script) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.fetchShuffleState()
            }
        }
    }
    
    /// Cycle through repeat modes: off → all → one → off
    func cycleRepeatMode() {
        let nextMode = repeatMode.next
        setRepeatMode(nextMode)
    }
    
    /// Set specific repeat mode
    func setRepeatMode(_ mode: RepeatMode) {
        let script = """
        tell application "Music"
            set song repeat to \(mode.appleScriptValue)
            return song repeat as string
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
        tell application "Music"
            set player position to 0
        end tell
        """
        
        runAppleScript(script) { _ in }
    }
    
    /// Skip to previous track
    func previousTrack() {
        let script = """
        tell application "Music"
            previous track
        end tell
        """
        
        runAppleScript(script) { _ in }
    }
    
    // MARK: - State Fetching
    
    private func fetchShuffleState() {
        let script = """
        tell application "Music"
            return shuffle enabled
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
        tell application "Music"
            return song repeat as string
        end tell
        """
        
        runAppleScript(script) { [weak self] result in
            if let repeatString = result as? String {
                DispatchQueue.main.async {
                    switch repeatString.lowercased() {
                    case "off":
                        self?.repeatMode = .off
                    case "all":
                        self?.repeatMode = .all
                    case "one":
                        self?.repeatMode = .one
                    default:
                        self?.repeatMode = .off
                    }
                }
            }
        }
    }
    
    private func fetchLovedState() {
        let script = """
        tell application "Music"
            if player state is not stopped then
                return favorited of current track
            end if
            return false
        end tell
        """
        
        runAppleScript(script) { [weak self] result in
            if let loved = result as? Bool {
                DispatchQueue.main.async {
                    self?.isCurrentTrackLoved = loved
                }
            }
        }
    }
    
    /// Fetch the actual player position from Apple Music
    func fetchPlayerPosition(completion: ((Double) -> Void)? = nil) {
        let script = """
        tell application "Music"
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
    
    /// Sync MusicManager elapsed time with Apple Music's true position
    func syncPlayerPosition() {
        guard isAppleMusicRunning else {
            stopPositionSyncTimer()
            return
        }
        
        fetchPlayerPosition { position in
            MusicManager.shared.forceElapsedTime(position)
        }
    }
    
    // MARK: - Love/Unlove Functionality
    
    /// Love the current track
    func loveCurrentTrack() {
        isLoveLoading = true
        
        let script = """
        tell application "Music"
            set favorited of current track to true
            return favorited of current track
        end tell
        """
        
        runAppleScript(script) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoveLoading = false
                if let loved = result as? Bool {
                    self?.isCurrentTrackLoved = loved
                    print("AppleMusicController: Track favorited successfully")
                }
            }
        }
    }
    
    /// Unlove the current track
    func unloveCurrentTrack() {
        isLoveLoading = true
        
        let script = """
        tell application "Music"
            set favorited of current track to false
            return favorited of current track
        end tell
        """
        
        runAppleScript(script) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoveLoading = false
                if let loved = result as? Bool {
                    self?.isCurrentTrackLoved = loved
                    print("AppleMusicController: Track unfavorited successfully")
                }
            }
        }
    }
    
    /// Toggle love status
    func toggleLove() {
        if isCurrentTrackLoved {
            unloveCurrentTrack()
        } else {
            loveCurrentTrack()
        }
    }
    
    // MARK: - AppleScript Execution
    
    private func runAppleScript(_ source: String, completion: @escaping (Any?) -> Void) {
        // Use serial queue to prevent concurrent AppleScript execution
        // NSAppleScript is NOT thread-safe and concurrent calls crash the runtime
        appleScriptQueue.async {
            let parsed: Any? = AppleScriptRuntime.execute {
                var error: NSDictionary?

                guard let script = NSAppleScript(source: source) else {
                    print("AppleMusicController: Failed to create AppleScript")
                    return nil
                }

                let result = script.executeAndReturnError(&error)

                if let error = error {
                    print("AppleMusicController: AppleScript error: \(error)")
                    return nil
                }

                // Parse result based on descriptor type
                switch result.descriptorType {
                case typeTrue:
                    return true
                case typeFalse:
                    return false
                case typeIEEE64BitFloatingPoint:
                    return result.doubleValue
                case typeIEEE32BitFloatingPoint:
                    let floatBytes = result.data
                    if floatBytes.count >= 4 {
                        var value: Float = 0
                        _ = withUnsafeMutableBytes(of: &value) { floatBytes.copyBytes(to: $0) }
                        return Double(value)
                    } else {
                        return 0.0
                    }
                case typeSInt32:
                    return Int(result.int32Value)
                case typeSInt64:
                    return result.int32Value
                default:
                    return result.stringValue
                }
            }

            DispatchQueue.main.async { completion(parsed) }
        }
    }
    
    /// Clean up when extension is removed
    func cleanup() {
        stopPositionSyncTimer()
    }
}
