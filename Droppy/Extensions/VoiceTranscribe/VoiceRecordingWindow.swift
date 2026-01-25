//
//  VoiceRecordingWindow.swift
//  Droppy
//
//  Floating recording window for Voice Transcribe quick recording
//

import SwiftUI
import AppKit

// MARK: - Recording Window Controller

@MainActor
final class VoiceRecordingWindowController {
    static let shared = VoiceRecordingWindowController()
    
    private var window: NSPanel?
    var isVisible = false
    
    private init() {}
    
    func showAndStartRecording() {
        print("VoiceRecordingWindow: showAndStartRecording called")
        
        // Reset state to ensure clean slate
        let manager = VoiceTranscribeManager.shared
        if case .idle = manager.state {
            // Already idle, good
        } else {
            print("VoiceRecordingWindow: Resetting state from \(manager.state) to idle")
            manager.state = .idle
        }
        
        // Show window first
        showWindow()
        
        // Then start recording
        manager.startRecording()
    }
    
    func showWindow() {
        guard window == nil else {
            window?.makeKeyAndOrderFront(nil)
            return
        }
        
        // Position in bottom-right corner (matching CapturePreviewView)
        guard let screen = NSScreen.main else { return }
        let windowSize = NSSize(width: 280, height: 220)
        let origin = NSPoint(
            x: screen.visibleFrame.maxX - windowSize.width - 20,
            y: screen.visibleFrame.minY + 20
        )
        
        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: windowSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        
        let contentView = NSHostingView(rootView: VoiceRecordingOverlayView(controller: self)
            .preferredColorScheme(.dark)) // Force dark mode always
        panel.contentView = contentView
        
        window = panel
        panel.makeKeyAndOrderFront(nil)
        isVisible = true
        
        print("VoiceTranscribe: Recording window shown")
    }
    
    func hideWindow() {
        window?.close()
        window = nil
        isVisible = false
        
        print("VoiceTranscribe: Recording window hidden")
    }
    
    func stopRecordingAndTranscribe() {
        // Stop recording but keep window visible (will show processing state)
        VoiceTranscribeManager.shared.stopRecording()
        
        // Watch for transcription completion
        watchForTranscriptionCompletion()
    }
    
    /// Show just the transcribing progress (for invisi-record mode)
    func showTranscribingProgress() {
        // Show window if not already visible
        if window == nil {
            showWindow()
        }
        
        // Watch for transcription completion
        watchForTranscriptionCompletion()
    }
    
    private func watchForTranscriptionCompletion() {
        Task { @MainActor in
            // Poll for completion (max 60 seconds)
            for _ in 0..<120 {
                try? await Task.sleep(for: .milliseconds(500))
                
                let state = VoiceTranscribeManager.shared.state
                if case .idle = state {
                    // Transcription done or cancelled - result window is shown from manager
                    hideWindow()
                    return
                } else if case .error = state {
                    // Error occurred - hide window
                    hideWindow()
                    return
                }
            }
            
            // Timeout - hide window anyway
            hideWindow()
        }
    }
}

// MARK: - Recording Overlay View

struct VoiceRecordingOverlayView: View {
    let controller: VoiceRecordingWindowController
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @ObservedObject var manager = VoiceTranscribeManager.shared
    @State private var isPulsing = false
    @State private var isHoveringButton = false
    
    private let cornerRadius: CGFloat = 28
    private let padding: CGFloat = 16
    
    var body: some View {
        VStack(spacing: 12) {
            if case .processing = manager.state {
                // PROCESSING STATE
                processingContent
            } else {
                // RECORDING STATE
                recordingContent
            }
        }
        .padding(padding)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
        )
        .onAppear {
            isPulsing = true
        }
    }
    
    // MARK: - Recording Content
    
    private var recordingContent: some View {
        Group {
            // Header row (matching CapturePreviewView style)
            HStack {
                Text("Recording")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Recording indicator badge (pulsing)
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isPulsing ? 1.2 : 0.9)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)
                    
                    Text(formatDuration(manager.recordingDuration))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            
            // Waveform animation (in content area like preview image)
            HStack(spacing: 4) {
                ForEach(0..<20, id: \.self) { i in
                    WaveformBar(
                        index: i,
                        level: manager.audioLevel,
                        color: .blue
                    )
                }
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AdaptiveColors.buttonBackgroundAuto)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            
            // Stop button (full width, Droppy hover style)
            Button {
                controller.stopRecordingAndTranscribe()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                    Text("Stop Recording")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DroppyAccentButtonStyle(color: .red, size: .medium))
        }
    }
    
    // MARK: - Processing Content
    
    private var processingContent: some View {
        Group {
            // Header
            HStack {
                Text("Transcribing")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Percentage badge
                Text("\(Int(manager.transcriptionProgress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.blue.opacity(0.2))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
            
            // Progress bar (matching download UI)
            VStack(spacing: 12) {
                // Icon
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse, options: .repeating)
                
                // Progress bar (matching download style)
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.3))
                        .frame(height: 8)
                    
                    // Progress fill (solid blue like download)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue)
                            .frame(width: geo.size.width * max(0.02, manager.transcriptionProgress))
                            .animation(DroppyAnimation.viewChange, value: manager.transcriptionProgress)
                    }
                    .frame(height: 8)
                }
                .frame(maxWidth: .infinity)
                
                // Status text
                Text(manager.transcriptionProgress < 0.2 ? "Loading model..." : "Processing audio...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(AdaptiveColors.buttonBackgroundAuto)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            
            // AI badge
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                Text("Powered by WhisperKit AI")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.tertiary)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Waveform Bar

struct WaveformBar: View {
    let index: Int
    let level: Float
    var color: Color = .blue
    
    @State private var animatedHeight: CGFloat = 0.15
    
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 6, height: max(6, animatedHeight * 50))
            .animation(
                .spring(response: 0.12, dampingFraction: 0.5).delay(Double(index) * 0.015),
                value: animatedHeight
            )
            .onChange(of: level) { _, newLevel in
                // Add randomness for organic feel
                let randomFactor = Float.random(in: 0.6...1.4)
                // Use sine wave offset for flowing effect
                let phaseOffset = sin(Double(index) * 0.5 + Date().timeIntervalSince1970 * 3) * 0.3
                animatedHeight = CGFloat(min(1.0, max(0.1, (newLevel * randomFactor * 2.5) + Float(phaseOffset))))
            }
    }
}

#Preview {
    VoiceRecordingOverlayView(controller: VoiceRecordingWindowController.shared)
        .frame(width: 300, height: 180)
        .background(Color.black)
}
