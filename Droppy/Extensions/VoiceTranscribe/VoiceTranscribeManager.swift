//
//  VoiceTranscribeManager.swift
//  Droppy
//
//  Core manager for audio recording and transcription using WhisperKit
//

import SwiftUI
@preconcurrency import AVFoundation
import Combine
import WhisperKit
import CoreML
import UniformTypeIdentifiers

// MARK: - Transcription Model

enum WhisperModel: String, CaseIterable, Identifiable {
    case tiny = "openai_whisper-tiny"
    case base = "openai_whisper-base"
    case small = "openai_whisper-small"
    case medium = "openai_whisper-medium"
    case large = "openai_whisper-large-v3"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .tiny: return "Tiny (~75 MB)"
        case .base: return "Base (~142 MB)"
        case .small: return "Small (~466 MB)"
        case .medium: return "Medium (~1.5 GB)"
        case .large: return "Large (~3 GB)"
        }
    }
    
    var sizeDescription: String {
        switch self {
        case .tiny: return "Fastest, basic accuracy"
        case .base: return "Fast, good accuracy"
        case .small: return "Balanced speed & accuracy"
        case .medium: return "Slow, high accuracy"
        case .large: return "Slowest, best accuracy"
        }
    }
}

// MARK: - Recording State

enum VoiceRecordingState: Equatable {
    case idle
    case recording
    case processing
    case complete
    case error(String)
    
    static func == (lhs: VoiceRecordingState, rhs: VoiceRecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recording, .recording), (.processing, .processing), (.complete, .complete):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Voice Transcribe Manager

@MainActor
final class VoiceTranscribeManager: ObservableObject {
    static let shared = VoiceTranscribeManager()
    
    // MARK: - Published Properties
    
    @Published var state: VoiceRecordingState = .idle
    @Published var selectedModel: WhisperModel = .small
    @Published var isModelDownloaded: Bool = false
    @Published var downloadProgress: Double = 0
    @Published var transcriptionResult: String = ""
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var selectedLanguage: String = "auto"
    @Published var isMenuBarEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isMenuBarEnabled, forKey: "voiceTranscribeMenuBarEnabled")
            VoiceTranscribeMenuBar.shared.setVisible(isMenuBarEnabled)
        }
    }
    @Published var isDownloading: Bool = false
    @Published var transcriptionProgress: Double = 0
    @Published private(set) var lastRecordingURL: URL? // Available after transcription for save
    
    // MARK: - Private Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var recordingURL: URL?
    private var whisperKit: WhisperKit?
    private var downloadTask: Task<Void, Never>?
    
    // Model storage directory
    private var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDir = appSupport.appendingPathComponent("Droppy/WhisperModels")
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        return modelsDir
    }
    
    // Recording storage
    private var recordingsDirectory: URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("DroppyRecordings")
    }
    
    // Supported languages
    let supportedLanguages: [(code: String, name: String)] = [
        ("auto", "Auto Detect"),
        ("en", "English"),
        ("nl", "Dutch"),
        ("de", "German"),
        ("fr", "French"),
        ("es", "Spanish"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("pl", "Polish"),
        ("ru", "Russian"),
        ("zh", "Chinese"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("ar", "Arabic"),
        ("hi", "Hindi"),
        ("tr", "Turkish"),
        ("uk", "Ukrainian"),
        ("sv", "Swedish"),
        ("da", "Danish"),
        ("no", "Norwegian"),
        ("fi", "Finnish")
    ]
    
    // MARK: - Initialization
    
    private init() {
        try? FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        loadPreferences()
        checkModelStatus()
    }
    
    // MARK: - Public Methods
    
    /// Start recording audio
    func startRecording() {
        // Don't start if extension is disabled
        guard !ExtensionType.voiceTranscribe.isRemoved else {
            print("[VoiceTranscribe] Extension is disabled, ignoring")
            return
        }
        
        print("VoiceTranscribe: startRecording called, state: \(state), isModelDownloaded: \(isModelDownloaded), whisperKit: \(whisperKit != nil)")
        
        guard state == .idle else {
            print("VoiceTranscribe: Cannot start recording - state is \(state), not idle")
            return
        }
        
        // Start recording immediately - we can transcribe later
        // Model loading happens in parallel if needed
        if whisperKit == nil && isModelDownloaded {
            print("VoiceTranscribe: Model not in memory, loading in background...")
            Task {
                do {
                    // Use download: true - WhisperKit skips download if model exists in cache
                    // This ensures it properly locates the model in HuggingFace cache
                    let kit = try await WhisperKit(
                        model: selectedModel.rawValue,
                        verbose: false,
                        logLevel: .error,
                        prewarm: false,
                        load: false,
                        download: true  // Required to locate model in cache
                    )
                    // Load and prewarm models
                    try await kit.loadModels()
                    try await kit.prewarmModels()
                    whisperKit = kit
                    print("VoiceTranscribe: Model loaded in background")
                } catch {
                    print("VoiceTranscribe: Background model load failed: \(error)")
                    // Model might be corrupted or deleted - clear the flag so user can re-download
                    await MainActor.run {
                        self.isModelDownloaded = false
                        self.savePreferences()
                    }
                }
            }
        }
        
        // Always request mic and start recording
        requestMicAndRecord()
    }
    
    private func requestMicAndRecord() {
        // Use AVAudioApplication for macOS 14+ or fallback to AVCaptureDevice
        if #available(macOS 14.0, *) {
            let status = AVAudioApplication.shared.recordPermission
            
            switch status {
            case .granted:
                print("VoiceTranscribe: Mic already authorized, beginning recording")
                beginRecording()
                
            case .undetermined:
                // First time - this will trigger the system prompt
                print("VoiceTranscribe: Requesting mic permission for first time (AVAudioApplication)")
                AVAudioApplication.requestRecordPermission { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted {
                            print("VoiceTranscribe: Mic access granted, beginning recording")
                            self?.beginRecording()
                        } else {
                            print("VoiceTranscribe: Mic access denied by user via system prompt")
                            self?.state = .idle
                            VoiceRecordingWindowController.shared.hideWindow()
                        }
                    }
                }
                
            case .denied:
                print("VoiceTranscribe: Mic access previously denied, showing alert")
                state = .idle
                showMicPermissionAlert()
                
            @unknown default:
                print("VoiceTranscribe: Unknown mic auth status")
                state = .error("Unable to check microphone permission.")
            }
        } else {
            // Fallback for older macOS
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            
            switch status {
            case .authorized:
                print("VoiceTranscribe: Mic already authorized, beginning recording")
                beginRecording()
                
            case .notDetermined:
                print("VoiceTranscribe: Requesting mic permission for first time")
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted {
                            print("VoiceTranscribe: Mic access granted, beginning recording")
                            self?.beginRecording()
                        } else {
                            print("VoiceTranscribe: Mic access denied by user via system prompt")
                            self?.state = .idle
                            VoiceRecordingWindowController.shared.hideWindow()
                        }
                    }
                }
                
            case .denied, .restricted:
                print("VoiceTranscribe: Mic access previously denied, showing alert")
                state = .idle
                showMicPermissionAlert()
                
            @unknown default:
                print("VoiceTranscribe: Unknown mic auth status")
                state = .error("Unable to check microphone permission.")
            }
        }
    }
    
    private func showMicPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Microphone Access Required"
        alert.informativeText = "Voice Transcribe needs microphone access to record audio. Please enable it in System Settings → Privacy & Security → Microphone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // Open Privacy & Security settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
        
        // Hide recording window since we can't record
        VoiceRecordingWindowController.shared.hideWindow()
    }
    
    /// Stop recording and start transcription
    func stopRecording() {
        guard case .recording = state else { return }
        
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        levelTimer?.invalidate()
        
        // Revert menu bar icon to normal
        VoiceTranscribeMenuBar.shared.setRecordingState(false)
        
        state = .processing
        
        // Start transcription
        Task {
            await transcribeRecording()
        }
    }
    
    /// Toggle recording state
    func toggleRecording() {
        switch state {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .complete, .error:
            reset()
        default:
            break
        }
    }
    
    /// Reset to idle state
    func reset() {
        state = .idle
        transcriptionResult = ""
        recordingDuration = 0
        audioLevel = 0
    }
    
    /// Copy transcription to clipboard
    func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcriptionResult, forType: .string)
    }
    
    /// Save the last recording to a user-selected location
    func saveRecording() {
        guard let sourceURL = lastRecordingURL, FileManager.default.fileExists(atPath: sourceURL.path) else {
            print("VoiceTranscribe: No recording available to save")
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.title = "Save Audio Recording"
        savePanel.nameFieldStringValue = "recording_\(Date().formatted(date: .abbreviated, time: .shortened).replacingOccurrences(of: ":", with: "-")).wav"
        savePanel.allowedContentTypes = [.wav, .audio]
        savePanel.canCreateDirectories = true
        savePanel.level = .screenSaver // Match result window level
        
        savePanel.begin { response in
            guard response == .OK, let destinationURL = savePanel.url else { return }
            
            Task { @MainActor in
                do {
                    // Copy to user's selected location
                    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                    print("VoiceTranscribe: Recording saved to \(destinationURL.path)")
                } catch {
                    print("VoiceTranscribe: Failed to save recording: \(error)")
                }
            }
        }
    }
    
    /// Discard the last recording (clean up temp file)
    func discardRecording() {
        guard let url = lastRecordingURL else { return }
        try? FileManager.default.removeItem(at: url)
        lastRecordingURL = nil
        print("VoiceTranscribe: Recording discarded")
    }
    
    /// Retry transcription of the last recording
    func retryTranscription() {
        guard let url = lastRecordingURL, FileManager.default.fileExists(atPath: url.path) else {
            print("VoiceTranscribe: No recording available to retry")
            state = .error("No recording available to retry")
            return
        }
        
        state = .processing
        recordingURL = url
        
        Task {
            await transcribeRecording()
        }
    }

    
    /// Transcribe an existing audio file
    func transcribeFile(at url: URL) {
        guard state == .idle else {
            print("VoiceTranscribe: Cannot transcribe file - not idle")
            return
        }
        
        state = .processing
        
        Task {
            await transcribeAudioFile(at: url)
        }
    }
    
    /// Download and initialize the selected model
    func downloadModel() {
        guard !isDownloading else { return }
        
        isDownloading = true
        downloadProgress = 0.02
        
        downloadTask = Task {
            do {
                // Start progress polling timer
                var progressObservation: NSKeyValueObservation?
                
                // Phase 1: Download and initialize (0-60%)
                downloadProgress = 0.05
                
                try Task.checkCancellation()
                
                // Create WhisperKit - this triggers the download
                let kit = try await WhisperKit(
                    model: selectedModel.rawValue,
                    verbose: false,
                    logLevel: .none,
                    prewarm: false,
                    load: false,
                    download: true
                )
                whisperKit = kit
                
                // Observe progress for subsequent operations
                progressObservation = kit.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        // Map 0-1 progress to our current phase range
                        let phase = self.downloadProgress
                        if phase < 0.6 {
                            // Download phase: 5% to 60%
                            self.downloadProgress = 0.05 + (progress.fractionCompleted * 0.55)
                        } else if phase < 0.85 {
                            // Load phase: 60% to 85%
                            self.downloadProgress = 0.6 + (progress.fractionCompleted * 0.25)
                        } else {
                            // Prewarm phase: 85% to 100%
                            self.downloadProgress = 0.85 + (progress.fractionCompleted * 0.15)
                        }
                    }
                }
                
                try Task.checkCancellation()
                
                // Phase 2: Load models (60-85%)
                downloadProgress = 0.6
                try await whisperKit?.loadModels()
                
                try Task.checkCancellation()
                
                // Phase 3: Prewarm (85-100%)
                downloadProgress = 0.85
                try await whisperKit?.prewarmModels()
                
                progressObservation?.invalidate()
                
                downloadProgress = 1.0
                isModelDownloaded = true
                savePreferences()
                
                print("VoiceTranscribe: Model \(selectedModel.rawValue) loaded successfully")
                
            } catch is CancellationError {
                print("VoiceTranscribe: Download cancelled by user")
                whisperKit = nil
                downloadProgress = 0
            } catch {
                print("VoiceTranscribe: Failed to load model: \(error)")
                state = .error("Failed to download model: \(error.localizedDescription)")
                isModelDownloaded = false
            }
            
            isDownloading = false
            downloadTask = nil
        }
    }
    
    /// Cancel the current model download
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadProgress = 0
        whisperKit = nil
        print("VoiceTranscribe: Download cancelled")
    }
    
    /// Delete the downloaded model from disk
    func deleteModel() {
        // Clear the WhisperKit instance first
        whisperKit = nil
        isModelDownloaded = false
        isMenuBarEnabled = false
        downloadProgress = 0
        
        // Delete ALL WhisperKit model files from disk
        let fileManager = FileManager.default
        
        // HuggingFace cache location (where WhisperKit stores models)
        if let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let hubDir = cachesDir.appendingPathComponent("huggingface/hub")
            
            // Delete all whisperkit-related directories
            if let contents = try? fileManager.contentsOfDirectory(at: hubDir, includingPropertiesForKeys: nil) {
                for item in contents {
                    // WhisperKit models contain "whisperkit" or "whisper" in the name
                    let name = item.lastPathComponent.lowercased()
                    if name.contains("whisper") {
                        do {
                            try fileManager.removeItem(at: item)
                            print("VoiceTranscribe: Deleted model cache at \(item.path)")
                        } catch {
                            print("VoiceTranscribe: Failed to delete \(item.path): \(error)")
                        }
                    }
                }
            }
        }
        
        // Clear ALL model download states from UserDefaults
        for model in WhisperModel.allCases {
            UserDefaults.standard.removeObject(forKey: "voiceTranscribeModelDownloaded_\(model.rawValue)")
        }
        
        // Update menu bar
        VoiceTranscribeMenuBar.shared.setVisible(false)
        
        print("VoiceTranscribe: All models deleted from disk")
    }
    
    // MARK: - Private Methods
    
    private func beginRecording() {
        let fileName = "recording_\(Date().timeIntervalSince1970).wav"
        recordingURL = recordingsDirectory.appendingPathComponent(fileName)
        
        // Whisper requires 16kHz sample rate
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            state = .recording
            recordingDuration = 0
            
            // Update menu bar icon to recording state
            VoiceTranscribeMenuBar.shared.setRecordingState(true)
            
            // Update duration timer
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.recordingDuration += 0.1
                }
            }
            
            // Update audio level timer
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.audioRecorder?.updateMeters()
                    let db = self?.audioRecorder?.averagePower(forChannel: 0) ?? -160
                    // Normalize dB to 0-1 range (-60 to 0 dB)
                    let normalized = max(0, min(1, (db + 60) / 60))
                    self?.audioLevel = Float(normalized)
                }
            }
        } catch {
            state = .error("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    private func transcribeRecording() async {
        guard let url = recordingURL else {
            state = .error("No recording found")
            return
        }
        
        // Reset progress
        transcriptionProgress = 0
        
        // Ensure we have a loaded model
        if whisperKit == nil {
            transcriptionProgress = 0.1 // Loading model phase
            do {
                let kit = try await WhisperKit(
                    model: selectedModel.rawValue,
                    verbose: false,
                    logLevel: .none,
                    prewarm: false,
                    load: false,
                    download: true  // Required to locate model in cache
                )
                try await kit.loadModels()
                try await kit.prewarmModels()
                whisperKit = kit
            } catch {
                state = .error("Failed to load model: \(error.localizedDescription)")
                return
            }
        }
        
        guard let whisper = whisperKit else {
            state = .error("Model not initialized")
            return
        }
        
        // Observe transcription progress
        let progressObservation = whisper.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Map progress: 0.2 to 0.95 (leave room for loading and completion)
                self.transcriptionProgress = 0.2 + (progress.fractionCompleted * 0.75)
            }
        }
        
        transcriptionProgress = 0.2 // Starting transcription
        
        do {
            // Configure transcription options
            var options = DecodingOptions()
            
            // Set language if not auto
            if selectedLanguage != "auto" {
                options.language = selectedLanguage
            }
            
            // Transcribe the audio file
            let results = try await whisper.transcribe(audioPath: url.path, decodeOptions: options)
            
            // Cancel observation
            progressObservation.invalidate()
            
            transcriptionProgress = 1.0
            
            // Extract text from results
            if let result = results.first {
                transcriptionResult = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Keep recording for "Save Audio" feature
                lastRecordingURL = url
                
                print("VoiceTranscribe: Transcription complete - \(result.text.count) chars")
                
                // Show result window (works for both regular and invisi-record mode)
                VoiceTranscriptionResultController.shared.showResult()
                
                // Reset to idle so new recordings can start
                state = .idle
            } else {
                transcriptionResult = ""
                // No successful result, clean up recording
                lastRecordingURL = nil
                try? FileManager.default.removeItem(at: url)
                state = .idle  // Reset even if no result
            }
            
        } catch {
            progressObservation.invalidate()
            print("VoiceTranscribe: Transcription error: \(error)")
            // Keep recording for retry
            lastRecordingURL = url
            state = .error("Transcription failed: \(error.localizedDescription)")
        }
    }
    
    /// Transcribe an external audio file (does NOT delete the source file)
    private func transcribeAudioFile(at url: URL) async {
        // Reset progress
        transcriptionProgress = 0
        
        // Start security-scoped access (required for files from NSOpenPanel)
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Copy and convert file to WAV format for WhisperKit compatibility
        let tempWavURL = recordingsDirectory.appendingPathComponent("upload_\(Date().timeIntervalSince1970).wav")
        
        do {
            // Convert audio to WAV format (16kHz, mono, 16-bit) - required by WhisperKit
            if let convertedURL = try await convertToWav(source: url, destination: tempWavURL) {
                print("VoiceTranscribe: Converted audio to WAV: \(convertedURL.path)")
            } else {
                // Fallback: just copy the file directly
                try FileManager.default.copyItem(at: url, to: tempWavURL)
                print("VoiceTranscribe: Copied audio file directly: \(tempWavURL.path)")
            }
        } catch {
            print("VoiceTranscribe: Failed to prepare audio file: \(error)")
            state = .error("Failed to process audio file: \(error.localizedDescription)")
            return
        }
        
        // Ensure we have a loaded model
        if whisperKit == nil {
            transcriptionProgress = 0.1 // Loading model phase
            do {
                print("VoiceTranscribe: Loading WhisperKit model...")
                let kit = try await WhisperKit(
                    model: selectedModel.rawValue,
                    verbose: true,  // Enable verbose for debugging
                    logLevel: .info,
                    prewarm: false,
                    load: false,
                    download: true
                )
                try await kit.loadModels()
                try await kit.prewarmModels()
                whisperKit = kit
                print("VoiceTranscribe: Model loaded successfully")
            } catch {
                try? FileManager.default.removeItem(at: tempWavURL)
                state = .error("Failed to load model: \(error.localizedDescription)")
                return
            }
        }
        
        guard let whisper = whisperKit else {
            try? FileManager.default.removeItem(at: tempWavURL)
            state = .error("Model not initialized")
            return
        }
        
        // Observe transcription progress
        let progressObservation = whisper.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.transcriptionProgress = 0.2 + (progress.fractionCompleted * 0.75)
            }
        }
        
        transcriptionProgress = 0.2
        
        do {
            var options = DecodingOptions()
            if selectedLanguage != "auto" {
                options.language = selectedLanguage
            }
            
            print("VoiceTranscribe: Starting transcription of \(tempWavURL.path)")
            let results = try await whisper.transcribe(audioPath: tempWavURL.path, decodeOptions: options)
            print("VoiceTranscribe: Transcription returned \(results.count) results")
            
            progressObservation.invalidate()
            transcriptionProgress = 1.0
            
            if let result = results.first {
                transcriptionResult = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                print("VoiceTranscribe: File transcription complete - \(transcriptionResult.count) chars: '\(transcriptionResult.prefix(100))...'")
                
                VoiceTranscriptionResultController.shared.showResult()
                state = .idle
            } else {
                print("VoiceTranscribe: No transcription results returned")
                transcriptionResult = ""
                state = .idle
            }
            
        } catch {
            progressObservation.invalidate()
            print("VoiceTranscribe: File transcription error: \(error)")
            state = .error("Transcription failed: \(error.localizedDescription)")
        }
        
        // Clean up temp file (NOT the original)
        try? FileManager.default.removeItem(at: tempWavURL)
    }
    
    /// Convert audio file to WAV format required by WhisperKit (16kHz, mono, 16-bit PCM)
    private func convertToWav(source: URL, destination: URL) async throws -> URL? {
        let asset = AVAsset(url: source)
        
        // Check if file has audio track
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw NSError(domain: "VoiceTranscribe", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio track found in file"])
        }
        
        // Create export session
        guard let _ = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            // Can't convert, just copy
            return nil
        }
        
        // For WAV, we need a different approach - use AVAudioFile
        let sourceFile = try AVAudioFile(forReading: source)
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
        
        guard let converter = AVAudioConverter(from: sourceFile.processingFormat, to: format) else {
            return nil
        }
        
        let outputFile = try AVAudioFile(forWriting: destination, settings: format.settings)
        
        let bufferCapacity: AVAudioFrameCount = 4096
        nonisolated(unsafe) let inputBuffer = AVAudioPCMBuffer(pcmFormat: sourceFile.processingFormat, frameCapacity: bufferCapacity)!
        let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferCapacity)!
        
        while true {
            do {
                try sourceFile.read(into: inputBuffer)
            } catch {
                break // End of file
            }
            
            if inputBuffer.frameLength == 0 {
                break
            }
            
            var error: NSError?
            converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return inputBuffer
            }
            
            if let error = error {
                throw error
            }
            
            try outputFile.write(from: outputBuffer)
        }
        
        return destination
    }
    
    private func checkModelStatus() {
        // Use UserDefaults to track if model was previously downloaded
        // WhisperKit caches models automatically in its own location
        isModelDownloaded = UserDefaults.standard.bool(forKey: "voiceTranscribeModelDownloaded_\(selectedModel.rawValue)")
    }
    
    private func loadPreferences() {
        // If extension is disabled, don't load any preferences
        guard !ExtensionType.voiceTranscribe.isRemoved else {
            isMenuBarEnabled = false
            VoiceTranscribeMenuBar.shared.setVisible(false)
            return
        }
        
        if let modelRaw = UserDefaults.standard.string(forKey: "voiceTranscribeModel"),
           let model = WhisperModel(rawValue: modelRaw) {
            selectedModel = model
        }
        if let lang = UserDefaults.standard.string(forKey: "voiceTranscribeLanguage") {
            selectedLanguage = lang
        }
        isMenuBarEnabled = UserDefaults.standard.bool(forKey: "voiceTranscribeMenuBarEnabled")
        
        // Explicitly set menu bar visibility (didSet may not fire on initial load)
        VoiceTranscribeMenuBar.shared.setVisible(isMenuBarEnabled)
    }
    
    private func savePreferences() {
        UserDefaults.standard.set(selectedModel.rawValue, forKey: "voiceTranscribeModel")
        UserDefaults.standard.set(selectedLanguage, forKey: "voiceTranscribeLanguage")
        // Save download state per model
        if isModelDownloaded {
            UserDefaults.standard.set(true, forKey: "voiceTranscribeModelDownloaded_\(selectedModel.rawValue)")
        }
    }
}

// MARK: - Duration Formatting

extension VoiceTranscribeManager {
    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        let tenths = Int((recordingDuration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

// MARK: - Extension Removal Cleanup

extension VoiceTranscribeManager {
    /// Clean up all Voice Transcribe resources when extension is removed
    /// Deletes downloaded WhisperKit model and resets all state
    func cleanup() {
        // Stop any active recording
        if state == .recording {
            stopRecording()
        }
        
        // Cancel any ongoing download
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadProgress = 0
        
        // Release WhisperKit instance
        whisperKit = nil
        
        // Delete model files
        let modelsDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Droppy/WhisperModels")
        
        do {
            if FileManager.default.fileExists(atPath: modelsDir.path) {
                try FileManager.default.removeItem(at: modelsDir)
                print("[VoiceTranscribe] Deleted model directory")
            }
        } catch {
            print("[VoiceTranscribe] Failed to delete models: \(error)")
        }
        
        // Reset state
        isModelDownloaded = false
        transcriptionResult = ""
        
        // Clear preferences
        UserDefaults.standard.removeObject(forKey: "voiceTranscribeModel")
        UserDefaults.standard.removeObject(forKey: "voiceTranscribeLanguage")
        for model in WhisperModel.allCases {
            UserDefaults.standard.removeObject(forKey: "voiceTranscribeModelDownloaded_\(model.rawValue)")
        }
        
        // Hide menu bar item
        VoiceTranscribeMenuBar.shared.setVisible(false)
        isMenuBarEnabled = false
        
        print("[VoiceTranscribe] Cleanup complete")
    }
}

