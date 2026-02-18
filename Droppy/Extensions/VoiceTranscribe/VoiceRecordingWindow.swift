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
    private var completionWatchTask: Task<Void, Never>?
    
    private init() {}
    
    func showAndStartRecording() {
        print("VoiceRecordingWindow: showAndStartRecording called")
        
        // Reset state to ensure clean slate
        let manager = VoiceTranscribeManager.shared
        if case .idle = manager.state {
            // Already idle, good
        } else {
            print("VoiceRecordingWindow: Resetting state from \(manager.state) to idle")
            manager.reset()
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
        let windowSize = NSSize(width: 300, height: 260)
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
            )
        panel.contentView = contentView
        
        window = panel
        AppKitMotion.prepareForPresent(panel, initialScale: 0.94)
        panel.makeKeyAndOrderFront(nil)
        AppKitMotion.animateIn(panel, initialScale: 0.94, duration: 0.2)
        isVisible = true
        
        print("VoiceTranscribe: Recording window shown")
    }
    
    func hideWindow() {
        completionWatchTask?.cancel()
        completionWatchTask = nil

        guard let panel = window else { return }
        window = nil
        isVisible = false

        AppKitMotion.animateOut(panel, targetScale: 0.97, duration: 0.14) {
            panel.orderOut(nil)
            panel.close()
            AppKitMotion.resetPresentationState(panel)
        }
        
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
        completionWatchTask?.cancel()
        completionWatchTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self else { return }

                let state = VoiceTranscribeManager.shared.state
                switch state {
                case .processing, .recording:
                    continue
                case .idle, .complete, .error:
                    // Transcription finished/cancelled/failed - manager handles result presentation.
                    self.hideWindow()
                    return
                }
            }
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
        .droppyTransparentBackground(useTransparentBackground)
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
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                        .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
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
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
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
                        RoundedRectangle(cornerRadius: DroppyRadius.ms, style: .continuous)
                            .fill(Color.blue.opacity(0.2))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DroppyRadius.ms, style: .continuous)
                            .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
                    )
            }
            
            // Progress bar (matching download UI)
            VStack(spacing: 10) {
                // Icon
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse, options: .repeating)
                
                // Progress bar (matching download style)
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: DroppyRadius.sm)
                        .fill(Color.blue.opacity(0.3))
                        .frame(height: 8)
                    
                    // Progress fill (solid blue like download)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: DroppyRadius.sm)
                            .fill(Color.blue)
                            .frame(width: geo.size.width * max(0.02, manager.transcriptionProgress))
                            .animation(DroppyAnimation.viewChange, value: manager.transcriptionProgress)
                    }
                    .frame(height: 8)
                }
                .frame(maxWidth: .infinity)
                
                // Status text
                Text(manager.transcriptionStatus.isEmpty ? (manager.transcriptionProgress < 0.2 ? "Loading model…" : "Processing audio…") : manager.transcriptionStatus)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 8) {
                    Label("Elapsed \(formatDuration(manager.processingElapsed))", systemImage: "clock")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if manager.currentTranscriptionInputDuration > 0 {
                        Text("Audio \(formatDuration(manager.currentTranscriptionInputDuration))")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                if manager.currentTranscriptionInputDuration >= (20 * 60) {
                    Text("Long recording detected. Processing can take several minutes depending on model size.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(DroppySpacing.lg)
            .frame(maxWidth: .infinity)
            .background(AdaptiveColors.buttonBackgroundAuto)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
            
            // AI badge
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                Text("Powered by WhisperKit AI")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.tertiary)

            Button {
                manager.cancelTranscription()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                    Text("Cancel")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
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
