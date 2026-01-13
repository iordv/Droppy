//
//  VoiceTranscribeManager.swift
//  Droppy
//
//  Core manager for audio recording and transcription using WhisperKit
//

import SwiftUI
import AVFoundation
import Combine
import WhisperKit
import CoreML

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
            // TODO: Show/hide menu bar item
        }
    }
    @Published var isDownloading: Bool = false
    
    // MARK: - Private Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var recordingURL: URL?
    private var whisperKit: WhisperKit?
    
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
        guard state == .idle else { return }
        
        // Request microphone permission
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.beginRecording()
                } else {
                    self?.state = .error("Microphone access denied. Enable in System Settings > Privacy & Security > Microphone.")
                }
            }
        }
    }
    
    /// Stop recording and start transcription
    func stopRecording() {
        guard case .recording = state else { return }
        
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        levelTimer?.invalidate()
        
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
    
    /// Download and initialize the selected model
    func downloadModel() async {
        guard !isDownloading else { return }
        
        isDownloading = true
        downloadProgress = 0.05
        
        do {
            // Create WhisperKit with progress observation
            // We use a timer to poll progress since direct observation is complex from async context
            let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    // WhisperKit.progress is exposed - we estimate progress in phases:
                    // 0-50%: Download, 50-80%: Load, 80-100%: Prewarm
                    // This is approximate since we can't directly observe internal progress
                }
            }
            
            // Phase 1: Download (0-50%)
            downloadProgress = 0.1
            
            whisperKit = try await WhisperKit(
                model: selectedModel.rawValue,
                verbose: true,
                logLevel: .debug,
                prewarm: false,  // We'll prewarm separately to track progress
                load: false,     // We'll load separately
                download: true
            )
            
            // Phase 2: Load models (50-80%)
            downloadProgress = 0.5
            try await whisperKit?.loadModels()
            
            // Phase 3: Prewarm (80-100%)
            downloadProgress = 0.8
            try await whisperKit?.prewarmModels()
            
            progressTimer.invalidate()
            
            downloadProgress = 1.0
            isModelDownloaded = true
            savePreferences()
            
            print("VoiceTranscribe: Model \(selectedModel.rawValue) loaded successfully")
            
        } catch {
            print("VoiceTranscribe: Failed to load model: \(error)")
            state = .error("Failed to download model: \(error.localizedDescription)")
            isModelDownloaded = false
        }
        
        isDownloading = false
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
            
            // Update duration timer
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.recordingDuration += 0.1
                }
            }
            
            // Update audio level timer
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.audioRecorder?.updateMeters()
                    let db = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
                    // Normalize dB to 0-1 range (-60 to 0 dB)
                    let normalized = max(0, min(1, (db + 60) / 60))
                    self.audioLevel = Float(normalized)
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
        
        // Ensure we have a loaded model
        if whisperKit == nil {
            do {
                whisperKit = try await WhisperKit(
                    model: selectedModel.rawValue,
                    verbose: false,
                    logLevel: .none
                )
            } catch {
                state = .error("Failed to load model: \(error.localizedDescription)")
                return
            }
        }
        
        guard let whisper = whisperKit else {
            state = .error("Model not initialized")
            return
        }
        
        do {
            // Configure transcription options
            var options = DecodingOptions()
            
            // Set language if not auto
            if selectedLanguage != "auto" {
                options.language = selectedLanguage
            }
            
            // Transcribe the audio file
            let results = try await whisper.transcribe(audioPath: url.path, decodeOptions: options)
            
            // Extract text from results
            if let result = results.first {
                transcriptionResult = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                state = .complete
                
                print("VoiceTranscribe: Transcription complete - \(result.text.count) chars")
            } else {
                transcriptionResult = ""
                state = .complete
            }
            
        } catch {
            print("VoiceTranscribe: Transcription error: \(error)")
            state = .error("Transcription failed: \(error.localizedDescription)")
        }
        
        // Clean up recording file
        try? FileManager.default.removeItem(at: url)
    }
    
    private func checkModelStatus() {
        // Use UserDefaults to track if model was previously downloaded
        // WhisperKit caches models automatically in its own location
        isModelDownloaded = UserDefaults.standard.bool(forKey: "voiceTranscribeModelDownloaded_\(selectedModel.rawValue)")
    }
    
    private func loadPreferences() {
        if let modelRaw = UserDefaults.standard.string(forKey: "voiceTranscribeModel"),
           let model = WhisperModel(rawValue: modelRaw) {
            selectedModel = model
        }
        if let lang = UserDefaults.standard.string(forKey: "voiceTranscribeLanguage") {
            selectedLanguage = lang
        }
        isMenuBarEnabled = UserDefaults.standard.bool(forKey: "voiceTranscribeMenuBarEnabled")
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

