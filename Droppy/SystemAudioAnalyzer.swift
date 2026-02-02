//
//  SystemAudioAnalyzer.swift
//  Droppy
//
//  Real-time system audio analysis using ScreenCaptureKit
//  Provides audio levels for visualizers without recording anything
//  CPU-efficient: audio-only capture, 30fps max, observer counting
//

import AppKit
import AVFoundation
import Combine
import ScreenCaptureKit
import Accelerate

// MARK: - System Audio Analyzer

/// Captures system audio output and provides real-time audio levels for visualizers
/// - Requires macOS 13+ and Screen Recording permission
/// - Does NOT record or store any audio data
/// - CPU-efficient: only runs when observers are present
@available(macOS 13.0, *)
@MainActor
final class SystemAudioAnalyzer: NSObject, ObservableObject {
    static let shared = SystemAudioAnalyzer()
    
    // MARK: - Published Properties
    
    /// Current audio level (0.0-1.0) - smoothed for visualizer use
    @Published private(set) var audioLevel: CGFloat = 0
    
    /// Whether real audio capture is active and working
    @Published private(set) var isActive: Bool = false
    
    /// Whether permission is granted
    @Published private(set) var hasPermission: Bool = false
    
    // MARK: - Private Properties
    
    private var stream: SCStream?
    private var streamOutput: AudioStreamOutput?
    private var videoOutput: SilentVideoOutput?
    private var streamDelegate: StreamDelegate?
    private var observerCount: Int = 0
    private let observerLock = NSLock()
    private var hasLoggedError: Bool = false // Prevent log spam
    
    // Level smoothing for visualizer
    private var rawLevel: CGFloat = 0
    private var smoothedLevel: CGFloat = 0
    private let smoothingFactor: CGFloat = 0.3
    private let decayFactor: CGFloat = 0.85
    
    // Update timer (30fps max)
    private var updateTimer: Timer?
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        Task { await checkPermission() }
    }
    
    // MARK: - Public API
    
    /// Register an observer - starts capture when first observer registers
    func addObserver() {
        observerLock.lock()
        observerCount += 1
        let shouldStart = observerCount == 1
        observerLock.unlock()
        
        if shouldStart {
            Task { await startCapture() }
        }
    }
    
    /// Unregister an observer - stops capture when last observer leaves
    func removeObserver() {
        observerLock.lock()
        observerCount = max(0, observerCount - 1)
        let shouldStop = observerCount == 0
        observerLock.unlock()
        
        if shouldStop {
            Task { await stopCapture() }
        }
    }
    
    /// Check and request permission if needed
    func requestPermission() async {
        do {
            _ = try await SCShareableContent.current
            await MainActor.run { self.hasPermission = true }
        } catch {
            await MainActor.run { self.hasPermission = false }
        }
    }
    
    /// Open System Settings to grant permission
    func openPermissionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Private Methods
    
    private func checkPermission() async {
        do {
            _ = try await SCShareableContent.current
            await MainActor.run { self.hasPermission = true }
        } catch {
            await MainActor.run { self.hasPermission = false }
        }
    }
    
    private func startCapture() async {
        guard stream == nil else { return }
        
        // PERMISSION CHECK: Verify screen recording permission BEFORE calling ScreenCaptureKit
        // This prevents macOS from showing repeated permission prompts
        guard CGPreflightScreenCaptureAccess() else {
            if !hasLoggedError {
                print("SystemAudioAnalyzer: Screen recording permission not granted - skipping capture")
                hasLoggedError = true
            }
            hasPermission = false
            isActive = false
            return
        }
        
        do {
            // Get shareable content - this checks permission
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            
            // Find main display
            guard let display = content.displays.first else {
                if !hasLoggedError { print("SystemAudioAnalyzer: No display found") }
                hasLoggedError = true
                return
            }
            
            // Create content filter for display (required for audio capture)
            let filter = SCContentFilter(display: display, excludingWindows: [])
            
            // Configure stream for audio-only capture
            let config = SCStreamConfiguration()
            config.capturesAudio = true
            config.excludesCurrentProcessAudio = false
            
            // Minimal video configuration (required but we don't use it)
            config.width = 2
            config.height = 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
            config.showsCursor = false
            
            // Audio configuration
            config.sampleRate = 48000
            config.channelCount = 2
            
            // Create delegate for stream lifecycle
            let delegate = StreamDelegate { [weak self] in
                guard let self = self else { return }
                Task { @MainActor [self] in
                    self.handleStreamError()
                }
            }
            
            // Create stream with delegate
            let newStream = SCStream(filter: filter, configuration: config, delegate: delegate)
            
            // Create audio output handler
            let audioOutput = AudioStreamOutput { [weak self] level in
                guard let self = self else { return }
                Task { @MainActor [self] in
                    self.updateLevel(level)
                }
            }
            
            // Create silent video output to prevent "frame dropped" spam
            let silentOutput = SilentVideoOutput()
            
            try newStream.addStreamOutput(audioOutput, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))
            try newStream.addStreamOutput(silentOutput, type: .screen, sampleHandlerQueue: .global(qos: .background))
            
            // Start stream
            try await newStream.startCapture()
            
            stream = newStream
            streamOutput = audioOutput
            self.videoOutput = silentOutput
            streamDelegate = delegate
            isActive = true
            hasPermission = true
            hasLoggedError = false
            
            // Start update timer for smoothing (30fps)
            startUpdateTimer()
            
            print("SystemAudioAnalyzer: Started real audio capture")
            
        } catch {
            // Only log once to prevent spam
            if !hasLoggedError {
                print("SystemAudioAnalyzer: Failed to start - \(error.localizedDescription)")
                hasLoggedError = true
            }
            isActive = false
            
            // Check if it's a permission error
            let errorDesc = error.localizedDescription.lowercased()
            if errorDesc.contains("permission") || errorDesc.contains("denied") || errorDesc.contains("not authorized") {
                hasPermission = false
            }
        }
    }
    
    /// Handle stream errors (e.g., permission revoked)
    private func handleStreamError() {
        print("SystemAudioAnalyzer: Stream error - stopping capture")
        Task {
            await stopCapture()
            // Re-check permission
            await checkPermission()
        }
    }
    
    private func stopCapture() async {
        stopUpdateTimer()
        
        if let stream = stream {
            do {
                try await stream.stopCapture()
            } catch {
                // Ignore stop errors
            }
        }
        
        stream = nil
        streamOutput = nil
        videoOutput = nil
        streamDelegate = nil
        isActive = false
        audioLevel = 0
        rawLevel = 0
        smoothedLevel = 0
        
        print("SystemAudioAnalyzer: Stopped")
    }
    
    private func startUpdateTimer() {
        stopUpdateTimer()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [self] in
                self.smoothUpdate()
            }
        }
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func updateLevel(_ newLevel: CGFloat) {
        rawLevel = newLevel
    }
    
    private func smoothUpdate() {
        if rawLevel > smoothedLevel {
            smoothedLevel = smoothedLevel + (rawLevel - smoothedLevel) * smoothingFactor
        } else {
            smoothedLevel = smoothedLevel * decayFactor
        }
        
        audioLevel = max(0, min(1, smoothedLevel))
    }
}

// MARK: - Stream Delegate

@available(macOS 13.0, *)
private class StreamDelegate: NSObject, SCStreamDelegate {
    private let errorHandler: () -> Void
    
    init(errorHandler: @escaping () -> Void) {
        self.errorHandler = errorHandler
        super.init()
    }
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("SystemAudioAnalyzer: Stream stopped with error - \(error.localizedDescription)")
        errorHandler()
    }
}

// MARK: - Audio Stream Output Handler

@available(macOS 13.0, *)
private class AudioStreamOutput: NSObject, SCStreamOutput {
    private let levelCallback: (CGFloat) -> Void
    
    init(levelCallback: @escaping (CGFloat) -> Void) {
        self.levelCallback = levelCallback
        super.init()
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        
        // Get the raw data buffer from the sample buffer
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return
        }
        
        // Get the data length
        let dataLength = CMBlockBufferGetDataLength(dataBuffer)
        guard dataLength > 0 else { return }
        
        // Create a buffer to copy audio data into
        var audioData = [Float](repeating: 0, count: dataLength / MemoryLayout<Float>.size)
        
        // Copy the audio data
        let status = CMBlockBufferCopyDataBytes(
            dataBuffer,
            atOffset: 0,
            dataLength: dataLength,
            destination: &audioData
        )
        
        guard status == noErr else {
            return
        }
        
        let frameCount = audioData.count
        guard frameCount > 0 else { return }
        
        // Calculate RMS using Accelerate framework (SIMD-optimized)
        var rms: Float = 0
        vDSP_rmsqv(audioData, 1, &rms, vDSP_Length(frameCount))
        
        // Convert to dB and normalize to 0-1
        let db = 20 * log10(max(rms, 0.00001))
        
        // Map dB to 0-1 with wide range for sensitivity
        let minDb: Float = -50
        let maxDb: Float = -5
        let normalizedDb = (db - minDb) / (maxDb - minDb)
        let level = CGFloat(max(0, min(1, normalizedDb)))
        
        levelCallback(level)
    }
}

// MARK: - Silent Video Output (prevents frame drop spam)

@available(macOS 13.0, *)
private class SilentVideoOutput: NSObject, SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Silently discard video frames - we only need audio
    }
}

// MARK: - Fallback for older macOS

/// Fallback analyzer for macOS < 13 - uses enhanced simulation
@MainActor
final class FallbackAudioAnalyzer: ObservableObject {
    static let shared = FallbackAudioAnalyzer()
    
    @Published private(set) var audioLevel: CGFloat = 0
    @Published private(set) var isActive: Bool = false
    
    private var wavePhase: CGFloat = 0
    private var timer: Timer?
    private var observerCount: Int = 0
    private let observerLock = NSLock()
    
    private init() {}
    
    func addObserver() {
        observerLock.lock()
        observerCount += 1
        let shouldStart = observerCount == 1
        observerLock.unlock()
        
        if shouldStart { startSimulation() }
    }
    
    func removeObserver() {
        observerLock.lock()
        observerCount = max(0, observerCount - 1)
        let shouldStop = observerCount == 0
        observerLock.unlock()
        
        if shouldStop { stopSimulation() }
    }
    
    private func startSimulation() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [self] in
                self.updateSimulation()
            }
        }
        isActive = true
    }
    
    private func stopSimulation() {
        timer?.invalidate()
        timer = nil
        audioLevel = 0
        isActive = false
    }
    
    private func updateSimulation() {
        wavePhase += 0.15
        if wavePhase > 2 * .pi { wavePhase -= 2 * .pi }
        
        // Multi-wave simulation for organic movement
        let wave1 = (sin(wavePhase) + 1) / 2
        let wave2 = (sin(wavePhase * 1.7 + 1) + 1) / 2
        let wave3 = (sin(wavePhase * 0.5 + 2) + 1) / 2
        
        let combined = (wave1 * 0.4 + wave2 * 0.35 + wave3 * 0.25)
        let randomNoise = CGFloat.random(in: -0.1...0.1)
        
        audioLevel = max(0.1, min(0.9, combined + randomNoise))
    }
}
