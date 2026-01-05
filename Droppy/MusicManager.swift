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
    
    // MARK: - Published Properties
    @Published private(set) var songTitle: String = ""
    @Published private(set) var artistName: String = ""
    @Published private(set) var albumName: String = ""
    @Published private(set) var albumArt: NSImage = NSImage()
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var songDuration: Double = 0
    @Published private(set) var elapsedTime: Double = 0
    @Published private(set) var playbackRate: Double = 1.0
    @Published private(set) var timestampDate: Date = .distantPast
    @Published private(set) var bundleIdentifier: String?
    @Published private(set) var avgColor: NSColor = .gray
    
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
        loadMediaRemoteForCommands()
        startAdapterProcess()
        
        // Fetch full metadata after a short delay to solve cold start issue
        // (when app opens while media is already playing, initial stream may miss duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.fetchFullNowPlayingInfo()
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
        
        // Update metadata
        if let title = payload.title {
            // Reset timing values when song changes to prevent stale timestamps
            if title != songTitle {
                songDuration = 0
                elapsedTime = 0
            }
            songTitle = title
        }
        if let artist = payload.artist {
            artistName = artist
        }
        if let album = payload.album {
            albumName = album
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
            // Store the raw elapsed time from adapter
            let rawElapsedTime = elapsed
            
            // Parse ISO 8601 timestamp to get when this elapsed time was captured
            if let ts = payload.timestamp {
                let formatter = ISO8601DateFormatter()
                if let captureDate = formatter.date(from: ts) {
                    // Calculate how much time has passed since the timestamp was captured
                    let timeSinceCapture = Date().timeIntervalSince(captureDate)
                    let rate = payload.playbackRate ?? 1.0
                    
                    // Allow adjustment for up to 5 minutes (300s) if playing
                    // Web sources send stale timestamps on cold start, but if rate > 0 we can extrapolate
                    if timeSinceCapture >= 0 && timeSinceCapture < 300 && rate > 0 {
                        elapsedTime = rawElapsedTime + (timeSinceCapture * rate)
                        print("MusicManager: Adjusted elapsed by \(timeSinceCapture)s: \(rawElapsedTime) -> \(elapsedTime)")
                    } else {
                        elapsedTime = rawElapsedTime
                        if timeSinceCapture >= 300 {
                            print("MusicManager: Timestamp too old (\(Int(timeSinceCapture))s), using raw elapsed")
                        }
                    }
                    timestampDate = Date()
                } else {
                    elapsedTime = rawElapsedTime
                    timestampDate = Date()
                }
            } else {
                elapsedTime = rawElapsedTime
                timestampDate = Date()
            }
        }
        if let rate = payload.playbackRate {
            playbackRate = rate
        }
        if let bundle = payload.launchableBundleIdentifier {
            bundleIdentifier = bundle
        }
        
        // Always update isPlaying from playbackRate (computed property)
        isPlaying = payload.isPlaying
        
        // Handle artwork
        if let base64Art = payload.artworkData,
           let artData = Data(base64Encoded: base64Art),
           let image = NSImage(data: artData) {
            albumArt = image
            avgColor = image.dominantColor ?? .gray
        }
        
        // Debug: Log the update
        print("MusicManager: Updated - title='\(songTitle)', artist='\(artistName)', isPlaying=\(isPlaying), elapsed=\(elapsedTime), duration=\(songDuration), rate=\(playbackRate)")
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
        guard let sendCommand = MRMediaRemoteSendCommandPtr else { return }
        sendCommand(MRCommand.togglePlayPause.rawValue, nil)
    }
    
    /// Skip to next track
    func nextTrack() {
        guard let sendCommand = MRMediaRemoteSendCommandPtr else { return }
        sendCommand(MRCommand.nextTrack.rawValue, nil)
    }
    
    /// Skip to previous track
    func previousTrack() {
        guard let sendCommand = MRMediaRemoteSendCommandPtr else { return }
        sendCommand(MRCommand.previousTrack.rawValue, nil)
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
        
        // For browsers, try to find and activate the tab playing the media
        if bundleId == "com.apple.Safari" {
            activateSafariTab()
        } else if bundleId == "com.google.Chrome" {
            activateChromeTab()
        } else if bundleId.contains("firefox") || bundleId == "org.mozilla.firefox" {
            activateFirefoxTab()
        } else if bundleId.contains("arc") || bundleId == "company.thebrowser.Browser" {
            activateArcTab()
        } else {
            // For non-browser apps, just open the app
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                print("MusicManager: Opening source app: \(bundleId)")
                NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
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
    private func activateChromeTab() {
        let titleMatch = escapeForAppleScript(songTitle)
        let artistMatch = escapeForAppleScript(artistName)
        
        let script = """
        tell application "Google Chrome"
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
        
        print("MusicManager: Chrome AppleScript searching for title='\(titleMatch)' or artist='\(artistMatch)'")
        runAppleScript(script, appName: "Google Chrome")
    }
    
    /// Activate Firefox tab matching the current song title
    private func activateFirefoxTab() {
        // Firefox doesn't have great AppleScript support, just activate the app
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.mozilla.firefox") {
            print("MusicManager: Activating Firefox (limited tab support)")
            NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
        }
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
    
    /// Run AppleScript asynchronously with fallback to just opening the app
    private func runAppleScript(_ source: String, appName: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var error: NSDictionary?
            if let script = NSAppleScript(source: source) {
                let result = script.executeAndReturnError(&error)
                
                if let error = error {
                    print("MusicManager: AppleScript error for \(appName): \(error)")
                    // Fallback: just activate the app
                    DispatchQueue.main.async {
                        if let bundleId = self?.bundleIdentifier,
                           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                            NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
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

// MARK: - NSImage Extension for Color Extraction

extension NSImage {
    /// Extract dominant color from image
    var dominantColor: NSColor? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let width = min(cgImage.width, 50)
        let height = min(cgImage.height, 50)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return nil }
        
        let pointer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        var count: CGFloat = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = CGFloat(pointer[offset]) / 255.0
                let g = CGFloat(pointer[offset + 1]) / 255.0
                let b = CGFloat(pointer[offset + 2]) / 255.0
                
                // Skip very dark or very light pixels
                let brightness = (r + g + b) / 3
                if brightness > 0.1 && brightness < 0.9 {
                    totalR += r
                    totalG += g
                    totalB += b
                    count += 1
                }
            }
        }
        
        guard count > 0 else { return .gray }
        
        return NSColor(
            red: totalR / count,
            green: totalG / count,
            blue: totalB / count,
            alpha: 1.0
        )
    }
}
