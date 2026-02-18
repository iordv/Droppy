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
    @Published var transcriptionStatus: String = ""
    @Published var processingElapsed: TimeInterval = 0
    @Published var currentTranscriptionInputDuration: TimeInterval = 0
    @Published private(set) var lastRecordingURL: URL? // Available after transcription for save
    
    // Keyboard shortcuts for recording modes
    @Published var quickRecordShortcut: SavedShortcut? {
        didSet { saveShortcutPreferences() }
    }
    @Published var invisiRecordShortcut: SavedShortcut? {
        didSet { saveShortcutPreferences() }
    }
    
    // MARK: - Private Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var recordingURL: URL?
    private var whisperKit: WhisperKit?
    private var downloadTask: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?
    private var quickRecordHotkey: GlobalHotKey?   // Carbon-based for reliability
    private var invisiRecordHotkey: GlobalHotKey?  // Carbon-based for reliability
    private var processingTimer: Timer?
    private var processingStartedAt: Date?
    private var lastObservedProgressAt: Date?
    
    // Model storage directory
    private var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
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
        loadShortcutPreferences()
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
            print("VoiceTranscribe: Model not in memory, loading in background…")
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
        // Open System Settings directly without custom Droppy dialog
        // macOS handles all permission prompts natively
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
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
        recordingTimer = nil
        levelTimer = nil
        
        // Revert menu bar icon to normal
        VoiceTranscribeMenuBar.shared.setRecordingState(false)
        
        beginProcessingSession(
            inputDuration: recordingDuration,
            initialStatus: "Preparing recording…"
        )
        
        // Start transcription
        transcriptionTask?.cancel()
        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            await self.transcribeRecording()
            self.clearTranscriptionTaskReference()
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
        transcriptionTask?.cancel()
        transcriptionTask = nil
        finishProcessingSession()
        state = .idle
        transcriptionResult = ""
        transcriptionProgress = 0
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
        
        beginProcessingSession(
            inputDuration: audioDuration(at: url),
            initialStatus: "Retrying transcription…"
        )
        recordingURL = url
        
        transcriptionTask?.cancel()
        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            await self.transcribeRecording()
            self.clearTranscriptionTaskReference()
        }
    }

    
    /// Transcribe an existing audio file
    func transcribeFile(at url: URL) {
        guard state == .idle else {
            print("VoiceTranscribe: Cannot transcribe file - not idle")
            return
        }
        
        beginProcessingSession(
            inputDuration: 0,
            initialStatus: "Preparing audio file…"
        )
        
        transcriptionTask?.cancel()
        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            await self.transcribeAudioFile(at: url)
            self.clearTranscriptionTaskReference()
        }
    }

    func cancelTranscription() {
        guard case .processing = state else { return }
        transcriptionTask?.cancel()
        transcriptionTask = nil
        if let recordingURL {
            lastRecordingURL = recordingURL
        }
        finishProcessingSession()
        state = .idle
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
                
                // Track extension activation for analytics (only track once per install)
                AnalyticsService.shared.trackExtensionActivation(extensionId: "voiceTranscribe")
                
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
            finishProcessingSession()
            state = .error("No recording found")
            return
        }
        
        if case .processing = state {
            // already in processing state
        } else {
            beginProcessingSession(
                inputDuration: audioDuration(at: url),
                initialStatus: "Preparing recording…"
            )
        }
        setTranscriptionProgress(0.05, status: "Preparing recording…")
        
        // Ensure we have a loaded model
        if whisperKit == nil {
            setTranscriptionProgress(0.1, status: "Loading AI model…")
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
                try Task.checkCancellation()
                whisperKit = kit
                setTranscriptionProgress(0.2, status: "Model ready. Transcribing audio…")
            } catch is CancellationError {
                finishProcessingSession()
                state = .idle
                return
            } catch {
                finishProcessingSession()
                state = .error("Failed to load model: \(error.localizedDescription)")
                return
            }
        }
        
        guard let whisper = whisperKit else {
            finishProcessingSession()
            state = .error("Model not initialized")
            return
        }
        
        // Observe transcription progress
        let progressObservation = whisper.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Map progress: 0.2 to 0.95 (leave room for loading and completion)
                self.setTranscriptionProgress(
                    0.2 + (progress.fractionCompleted * 0.75),
                    status: "Transcribing audio…"
                )
            }
        }
        defer { progressObservation.invalidate() }
        setTranscriptionProgress(0.2, status: "Transcribing audio…")
        
        do {
            // Configure transcription options
            var options = DecodingOptions()
            
            // Set language if not auto
            if selectedLanguage != "auto" {
                options.language = selectedLanguage
            }
            
            // Transcribe the audio file
            let results = try await whisper.transcribe(audioPath: url.path, decodeOptions: options)
            try Task.checkCancellation()
            setTranscriptionProgress(0.98, status: "Finalizing transcript…")
            
            // Extract text from results
            if let result = results.first {
                transcriptionResult = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Keep recording for "Save Audio" feature
                lastRecordingURL = url
                
                print("VoiceTranscribe: Transcription complete - \(result.text.count) chars")
                
                presentTranscriptionResult()
                
                // Reset to idle so new recordings can start
                finishProcessingSession()
                state = .idle
            } else {
                transcriptionResult = ""
                // No successful result, clean up recording
                lastRecordingURL = nil
                try? FileManager.default.removeItem(at: url)
                finishProcessingSession()
                state = .idle  // Reset even if no result
            }
            
        } catch is CancellationError {
            finishProcessingSession()
            state = .idle
        } catch {
            print("VoiceTranscribe: Transcription error: \(error)")
            // Keep recording for retry
            lastRecordingURL = url
            finishProcessingSession()
            state = .error("Transcription failed: \(error.localizedDescription)")
        }
    }
    
    /// Transcribe an external audio file (does NOT delete the source file)
    private func transcribeAudioFile(at url: URL) async {
        setTranscriptionProgress(0.05, status: "Preparing audio file…")
        
        // Start security-scoped access (required for files from NSOpenPanel)
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if currentTranscriptionInputDuration <= 0 {
            currentTranscriptionInputDuration = audioDuration(at: url)
        }
        
        // Copy and convert file to WAV format for WhisperKit compatibility
        let tempWavURL = recordingsDirectory.appendingPathComponent("upload_\(Date().timeIntervalSince1970).wav")
        
        do {
            // Convert audio to WAV format (16kHz, mono, 16-bit) - required by WhisperKit
            setTranscriptionProgress(0.08, status: "Converting audio…")
            if let convertedURL = try await convertToWav(source: url, destination: tempWavURL) {
                print("VoiceTranscribe: Converted audio to WAV: \(convertedURL.path)")
            } else {
                // Fallback: just copy the file directly
                try FileManager.default.copyItem(at: url, to: tempWavURL)
                print("VoiceTranscribe: Copied audio file directly: \(tempWavURL.path)")
            }
        } catch {
            print("VoiceTranscribe: Failed to prepare audio file: \(error)")
            finishProcessingSession()
            state = .error("Failed to process audio file: \(error.localizedDescription)")
            return
        }
        
        // Ensure we have a loaded model
        if whisperKit == nil {
            setTranscriptionProgress(0.1, status: "Loading AI model…")
            do {
                print("VoiceTranscribe: Loading WhisperKit model…")
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
                try Task.checkCancellation()
                whisperKit = kit
                print("VoiceTranscribe: Model loaded successfully")
                setTranscriptionProgress(0.2, status: "Model ready. Transcribing audio…")
            } catch is CancellationError {
                try? FileManager.default.removeItem(at: tempWavURL)
                finishProcessingSession()
                state = .idle
                return
            } catch {
                try? FileManager.default.removeItem(at: tempWavURL)
                finishProcessingSession()
                state = .error("Failed to load model: \(error.localizedDescription)")
                return
            }
        }
        
        guard let whisper = whisperKit else {
            try? FileManager.default.removeItem(at: tempWavURL)
            finishProcessingSession()
            state = .error("Model not initialized")
            return
        }
        
        // Observe transcription progress
        let progressObservation = whisper.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.setTranscriptionProgress(
                    0.2 + (progress.fractionCompleted * 0.75),
                    status: "Transcribing audio…"
                )
            }
        }
        defer { progressObservation.invalidate() }
        setTranscriptionProgress(0.2, status: "Transcribing audio…")
        
        do {
            var options = DecodingOptions()
            if selectedLanguage != "auto" {
                options.language = selectedLanguage
            }
            
            print("VoiceTranscribe: Starting transcription of \(tempWavURL.path)")
            let results = try await whisper.transcribe(audioPath: tempWavURL.path, decodeOptions: options)
            try Task.checkCancellation()
            print("VoiceTranscribe: Transcription returned \(results.count) results")
            
            setTranscriptionProgress(0.98, status: "Finalizing transcript…")
            
            if let result = results.first {
                transcriptionResult = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                print("VoiceTranscribe: File transcription complete - \(transcriptionResult.count) chars: '\(transcriptionResult.prefix(100))…'")
                
                presentTranscriptionResult()
                finishProcessingSession()
                state = .idle
            } else {
                print("VoiceTranscribe: No transcription results returned")
                transcriptionResult = ""
                finishProcessingSession()
                state = .idle
            }
            
        } catch is CancellationError {
            finishProcessingSession()
            state = .idle
        } catch {
            print("VoiceTranscribe: File transcription error: \(error)")
            finishProcessingSession()
            state = .error("Transcription failed: \(error.localizedDescription)")
        }
        
        // Clean up temp file (NOT the original)
        try? FileManager.default.removeItem(at: tempWavURL)
    }

    private func presentTranscriptionResult() {
        guard !transcriptionResult.isEmpty else { return }

        let shouldAutoCopy = UserDefaults.standard.preference(
            AppPreferenceKey.voiceTranscribeAutoCopyResult,
            default: PreferenceDefault.voiceTranscribeAutoCopyResult
        )

        if shouldAutoCopy {
            VoiceTranscriptionResultController.shared.hideWindow()
            TextCopyFeedback.copyTranscriptionText(transcriptionResult)
            discardRecording()
        } else {
            VoiceTranscriptionResultController.shared.show(with: transcriptionResult)
        }
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

    private func beginProcessingSession(inputDuration: TimeInterval, initialStatus: String) {
        state = .processing
        processingStartedAt = Date()
        processingElapsed = 0
        currentTranscriptionInputDuration = max(0, inputDuration)
        transcriptionStatus = initialStatus
        transcriptionProgress = 0.01
        lastObservedProgressAt = Date()

        processingTimer?.invalidate()
        processingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard case .processing = self.state else { return }

                if let startedAt = self.processingStartedAt {
                    self.processingElapsed = Date().timeIntervalSince(startedAt)
                }

                if let lastProgress = self.lastObservedProgressAt,
                   Date().timeIntervalSince(lastProgress) > 8,
                   self.transcriptionProgress < 0.92 {
                    self.transcriptionProgress = min(0.92, self.transcriptionProgress + 0.003)
                    if self.processingElapsed > 12 {
                        self.transcriptionStatus = "Still transcribing. Large recordings can take several minutes."
                    }
                }
            }
        }
        if let processingTimer {
            RunLoop.main.add(processingTimer, forMode: .common)
        }
    }

    private func finishProcessingSession() {
        processingTimer?.invalidate()
        processingTimer = nil
        processingStartedAt = nil
        lastObservedProgressAt = nil
        transcriptionProgress = 0
        processingElapsed = 0
        currentTranscriptionInputDuration = 0
        transcriptionStatus = ""
    }

    private func setTranscriptionProgress(_ value: Double, status: String? = nil) {
        transcriptionProgress = min(max(value, 0), 1)
        if let status {
            transcriptionStatus = status
        }
        lastObservedProgressAt = Date()
    }

    private func clearTranscriptionTaskReference() {
        transcriptionTask = nil
    }

    private func audioDuration(at url: URL) -> TimeInterval {
        guard let file = try? AVAudioFile(forReading: url) else { return 0 }
        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0 else { return 0 }
        return Double(file.length) / sampleRate
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

        transcriptionTask?.cancel()
        transcriptionTask = nil
        finishProcessingSession()
        
        // Cancel any ongoing download
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadProgress = 0
        
        // Release WhisperKit instance
        whisperKit = nil
        
        // Delete model files
        let modelsDir = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support"))
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

// MARK: - Keyboard Shortcuts

extension VoiceTranscribeManager {
    private static let disallowedUnmodifiedShortcutKeyCodes: Set<Int> = [
        96,  // F5 (Dictation / Keyboard brightness down)
        97,  // F6 (Do Not Disturb / Keyboard brightness up)
        98,  // F7 (Previous track)
        99,  // F3 (Mission Control)
        100, // F8 (Play/Pause)
        101, // F9 (Next track)
        103, // F11 (Volume down)
        109, // F10 (Mute)
        111, // F12 (Volume up)
        118, // F4 (Spotlight)
        120, // F2 (Brightness up)
        122  // F1 (Brightness down)
    ]

    private static func sanitizeShortcut(_ shortcut: SavedShortcut?) -> SavedShortcut? {
        guard let shortcut else { return nil }
        let flags = NSEvent.ModifierFlags(rawValue: shortcut.modifiers)
            .intersection([.command, .shift, .option, .control, .function])

        // Unmodified top-row hardware/media keys still trigger system actions (OSD/sound/volume),
        // so they are not safe global shortcuts for recording toggles.
        if flags.isEmpty && disallowedUnmodifiedShortcutKeyCodes.contains(shortcut.keyCode) {
            print("[VoiceTranscribe] Ignoring unsupported unmodified media key shortcut: \(shortcut.keyCode)")
            return nil
        }

        return SavedShortcut(keyCode: shortcut.keyCode, modifiers: flags.rawValue)
    }

    /// Load shortcut preferences from UserDefaults
    func loadShortcutPreferences() {
        if let data = UserDefaults.standard.data(forKey: "voiceTranscribeQuickRecordShortcut"),
           let shortcut = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
            quickRecordShortcut = Self.sanitizeShortcut(shortcut)
        }
        if let data = UserDefaults.standard.data(forKey: "voiceTranscribeInvisiRecordShortcut"),
           let shortcut = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
            invisiRecordShortcut = Self.sanitizeShortcut(shortcut)
        }
        
        // Start monitoring if we have any shortcuts
        if quickRecordShortcut != nil || invisiRecordShortcut != nil {
            startGlobalKeyMonitoring()
        }
    }
    
    /// Save shortcut preferences to UserDefaults
    func saveShortcutPreferences() {
        if let shortcut = quickRecordShortcut,
           let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: "voiceTranscribeQuickRecordShortcut")
        } else {
            UserDefaults.standard.removeObject(forKey: "voiceTranscribeQuickRecordShortcut")
        }
        
        if let shortcut = invisiRecordShortcut,
           let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: "voiceTranscribeInvisiRecordShortcut")
        } else {
            UserDefaults.standard.removeObject(forKey: "voiceTranscribeInvisiRecordShortcut")
        }
        
        // Update monitoring based on shortcut availability
        if quickRecordShortcut != nil || invisiRecordShortcut != nil {
            startGlobalKeyMonitoring()
        } else {
            stopGlobalKeyMonitoring()
        }
    }
    
    /// Start global keyboard monitoring for shortcuts
    func startGlobalKeyMonitoring() {
        // Register Quick Record shortcut
        if let shortcut = quickRecordShortcut, quickRecordHotkey == nil {
            quickRecordHotkey = GlobalHotKey(
                keyCode: shortcut.keyCode,
                modifiers: shortcut.modifiers,
                enableIOHIDFallback: false
            ) { [weak self] in
                guard let self = self else { return }
                guard !ExtensionType.voiceTranscribe.isRemoved else { return }
                guard self.isModelDownloaded else { return }
                
                print("[VoiceTranscribe] ✅ Quick Record triggered via GlobalHotKey")
                self.triggerQuickRecord()
            }
        }
        
        // Register Invisi-Record shortcut
        if let shortcut = invisiRecordShortcut, invisiRecordHotkey == nil {
            invisiRecordHotkey = GlobalHotKey(
                keyCode: shortcut.keyCode,
                modifiers: shortcut.modifiers,
                enableIOHIDFallback: false
            ) { [weak self] in
                guard let self = self else { return }
                guard !ExtensionType.voiceTranscribe.isRemoved else { return }
                guard self.isModelDownloaded else { return }
                
                print("[VoiceTranscribe] ✅ Invisi-Record triggered via GlobalHotKey")
                self.triggerInvisiRecord()
            }
        }
        
        print("[VoiceTranscribe] Global key monitoring started (using GlobalHotKey/Carbon)")
    }
    
    /// Stop global keyboard monitoring
    func stopGlobalKeyMonitoring() {
        quickRecordHotkey = nil   // GlobalHotKey deinit handles unregistration
        invisiRecordHotkey = nil
        print("[VoiceTranscribe] Global key monitoring stopped")
    }
    
    /// Handle global key events (unused with GlobalHotKey, kept for reference)
    private func handleGlobalKeyEvent(_ event: NSEvent) {
        // No longer used - GlobalHotKey handles matching internally
    }
    
    /// Trigger quick record via shortcut (shows recording window)
    private func triggerQuickRecord() {
        if state == .recording {
            VoiceRecordingWindowController.shared.stopRecordingAndTranscribe()
        } else if state == .idle {
            VoiceRecordingWindowController.shared.showAndStartRecording()
        }
    }
    
    /// Trigger invisi-record via shortcut (no window)
    private func triggerInvisiRecord() {
        if state == .recording {
            stopRecording()
            VoiceRecordingWindowController.shared.showTranscribingProgress()
        } else if state == .idle {
            startRecording()
        }
    }
    
    /// Set shortcut for a recording mode
    func setShortcut(_ shortcut: SavedShortcut?, for mode: VoiceRecordingMode) {
        let sanitized = Self.sanitizeShortcut(shortcut)
        switch mode {
        case .quick:
            quickRecordShortcut = sanitized
        case .invisi:
            invisiRecordShortcut = sanitized
        }
    }
    
    /// Remove shortcut for a recording mode
    func removeShortcut(for mode: VoiceRecordingMode) {
        setShortcut(nil, for: mode)
    }
}

/// Recording modes for Voice Transcribe
enum VoiceRecordingMode: String, CaseIterable, Identifiable {
    case quick = "quick"
    case invisi = "invisi"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .quick: return "Quick Record"
        case .invisi: return "Invisi-Record"
        }
    }
    
    var icon: String {
        switch self {
        case .quick: return "record.circle"
        case .invisi: return "eye.slash.circle"
        }
    }
    
    var description: String {
        switch self {
        case .quick: return "Record with visible window"
        case .invisi: return "Background recording (no window)"
        }
    }
}
