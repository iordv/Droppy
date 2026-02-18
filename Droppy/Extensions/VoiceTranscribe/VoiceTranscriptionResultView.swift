//
//  VoiceTranscriptionResultView.swift
//  Droppy
//
//  Result window showing transcribed text with copy option
//  Styled to match OCRResultView exactly but larger
//

import SwiftUI
import AppKit

// MARK: - Result Window Controller

@MainActor
final class VoiceTranscriptionResultController: NSObject {
    static let shared = VoiceTranscriptionResultController()
    
    private(set) var window: NSPanel?
    
    private override init() {
        super.init()
    }
    
    func showResult() {
        let result = VoiceTranscribeManager.shared.transcriptionResult
        guard !result.isEmpty else {
            print("VoiceTranscribe: No transcription result to show")
            return
        }
        
        show(with: result)
    }
    
    func show(with text: String) {
        // If window already exists, close and recreate to ensure clean state
        hideWindow()
        
        let contentView = VoiceTranscriptionResultView(text: text) { [weak self] in
            self?.hideWindow()
        }

        let hostingView = NSHostingView(rootView: contentView)
        
        let newWindow = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        newWindow.center()
        newWindow.title = "Transcription"
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .visible
        
        newWindow.isMovableByWindowBackground = false
        newWindow.backgroundColor = .clear
        newWindow.isOpaque = false
        newWindow.hasShadow = true
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .screenSaver
        newWindow.hidesOnDeactivate = false
        
        newWindow.contentView = hostingView
        
        // Fade in - use deferred makeKey to avoid NotchWindow conflicts
        newWindow.alphaValue = 0
        newWindow.orderFront(nil)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            newWindow.makeKeyAndOrderFront(nil)
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            newWindow.animator().alphaValue = 1.0
        }
        
        self.window = newWindow
        print("VoiceTranscribe: Result window shown at center")
    }
    
    func hideWindow() {
        guard let panel = window else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor [weak self] in
                panel.close()
                self?.window = nil
            }
        })
    }
}

// MARK: - Result View (matches OCRResultView style exactly)

struct VoiceTranscriptionResultView: View {
    let text: String
    let onClose: () -> Void
    
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @State private var isCopyHovering = false
    @State private var isCloseHovering = false
    @State private var isSaveHovering = false
    @State private var showCopiedFeedback = false
    
    private var hasRecording: Bool {
        VoiceTranscribeManager.shared.lastRecordingURL != nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Transcription")
                        .font(.headline)
                    Text("Speech recognized from audio")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(DroppySpacing.xl)
            
            Divider()
                .padding(.horizontal, 20)
            
            // Content
            ScrollView {
                Text(text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DroppySpacing.xl)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 350)
            
            Divider()
                .padding(.horizontal, 20)
            
            // Action buttons
            HStack(spacing: 10) {
                Button {
                    // Discard recording on close
                    VoiceTranscribeManager.shared.discardRecording()
                    onClose()
                } label: {
                    Text("Close")
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
                
                // Save Audio button
                if hasRecording {
                    Button {
                        VoiceTranscribeManager.shared.saveRecording()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save Audio")
                        }
                    }
                    .buttonStyle(DroppyPillButtonStyle(size: .small))
                }
                
                Spacer()
                
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(text, forType: .string)
                    
                    withAnimation(DroppyAnimation.hover) {
                        showCopiedFeedback = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        onClose()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                        Text(showCopiedFeedback ? "Copied!" : "Copy to Clipboard")
                    }
                }
                .buttonStyle(DroppyAccentButtonStyle(color: showCopiedFeedback ? .green : .blue, size: .small))
            }
            .padding(DroppySpacing.lg)
        }
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
        .droppyTransparentBackground(useTransparentBackground)
    }
}

#Preview {
    VoiceTranscriptionResultView(text: "This is a sample transcription of some spoken audio.") {}
}
