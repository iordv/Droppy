//
//  VoiceTranscribeExtension.swift
//  Droppy
//
//  Self-contained definition for Voice Transcribe extension
//

import SwiftUI

struct VoiceTranscribeExtension: ExtensionDefinition {
    static let id = "voiceTranscribe"
    static let title = "Voice Transcribe"
    static let subtitle = "On-device speech-to-text transcription"
    static let category: ExtensionGroup = .ai
    static let categoryColor: Color = .blue
    
    static let description = "Transcribe audio recordings to text using WhisperKit AI. 100% on-device processing means your voice never leaves your Mac—completely private."
    
    static let features: [(icon: String, text: String)] = [
        ("mic.fill", "One-tap Quick Record from menu bar"),
        ("cpu", "100% on-device AI processing"),
        ("globe", "99+ languages supported"),
        ("lock.fill", "Private—audio never leaves your Mac")
    ]
    
    static var screenshotURL: URL? {
        URL(string: "https://getdroppy.app/assets/images/voice-transcribe-screenshot.png")
    }
    
    static var iconURL: URL? {
        URL(string: "https://getdroppy.app/assets/icons/voice-transcribe.jpg")
    }
    
    static let iconPlaceholder = "waveform.and.mic"
    static let iconPlaceholderColor: Color = .blue
    
    static func cleanup() {
        VoiceTranscribeManager.shared.cleanup()
    }
}
