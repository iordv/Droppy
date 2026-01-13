//
//  VoiceTranscribeManager.swift
//  Droppy
//
//  Core manager for audio recording and transcription using WhisperKit
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Transcription Model

enum WhisperModel: String, CaseIterable, Identifiable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case large = "large-v3"
    
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
    
    // MARK: - Private Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var recordingURL: URL?
    
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
        checkModelStatus()
        loadPreferences()
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
    
    /// Download the selected model
    func downloadModel() async {
        downloadProgress = 0
        
        // TODO: Implement WhisperKit model download
        // WhisperKit handles model downloading automatically when you call WhisperKit()
        // For now, simulate download progress
        
        for i in 0..<100 {
            try? await Task.sleep(nanoseconds: 30_000_000) // 30ms
            downloadProgress = Double(i + 1) / 100.0
        }
        
        isModelDownloaded = true
        savePreferences()
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
        
        // TODO: Implement actual WhisperKit transcription
        // This is where we'll integrate WhisperKit
        //
        // Example WhisperKit usage:
        // let whisper = try await WhisperKit(model: selectedModel.rawValue)
        // let result = try await whisper.transcribe(audioPath: url.path)
        // transcriptionResult = result.text
        
        // For now, simulate processing
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        transcriptionResult = "[WhisperKit integration pending - audio recorded successfully at \(url.lastPathComponent)]"
        state = .complete
        
        // Clean up recording file
        try? FileManager.default.removeItem(at: url)
    }
    
    private func checkModelStatus() {
        // Check if model files exist
        let modelPath = modelsDirectory.appendingPathComponent(selectedModel.rawValue)
        isModelDownloaded = FileManager.default.fileExists(atPath: modelPath.path)
    }
    
    private func loadPreferences() {
        if let modelRaw = UserDefaults.standard.string(forKey: "voiceTranscribeModel"),
           let model = WhisperModel(rawValue: modelRaw) {
            selectedModel = model
        }
        if let lang = UserDefaults.standard.string(forKey: "voiceTranscribeLanguage") {
            selectedLanguage = lang
        }
    }
    
    private func savePreferences() {
        UserDefaults.standard.set(selectedModel.rawValue, forKey: "voiceTranscribeModel")
        UserDefaults.standard.set(selectedLanguage, forKey: "voiceTranscribeLanguage")
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
