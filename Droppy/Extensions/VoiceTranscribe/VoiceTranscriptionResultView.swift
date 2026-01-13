//
//  VoiceTranscriptionResultView.swift
//  Droppy
//
//  Result window showing transcribed text with copy option
//

import SwiftUI
import AppKit

// MARK: - Result Window Controller

@MainActor
final class VoiceTranscriptionResultController {
    static let shared = VoiceTranscriptionResultController()
    
    private var window: NSPanel?
    var isVisible = false
    
    private init() {}
    
    func showResult() {
        let result = VoiceTranscribeManager.shared.transcriptionResult
        guard !result.isEmpty else {
            print("VoiceTranscribe: No transcription result to show")
            return
        }
        
        showWindow()
    }
    
    func showWindow() {
        guard window == nil else {
            window?.makeKeyAndOrderFront(nil)
            return
        }
        
        // Center on screen
        guard let screen = NSScreen.main else { return }
        let windowSize = NSSize(width: 400, height: 300)
        let origin = NSPoint(
            x: screen.visibleFrame.midX - windowSize.width / 2,
            y: screen.visibleFrame.midY - windowSize.height / 2
        )
        
        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: windowSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        panel.title = "Transcription"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        
        let contentView = NSHostingView(rootView: VoiceTranscriptionResultView(controller: self))
        panel.contentView = contentView
        
        window = panel
        panel.makeKeyAndOrderFront(nil)
        isVisible = true
        
        print("VoiceTranscribe: Result window shown")
    }
    
    func hideWindow() {
        window?.close()
        window = nil
        isVisible = false
        
        print("VoiceTranscribe: Result window hidden")
    }
}

// MARK: - Result View

struct VoiceTranscriptionResultView: View {
    let controller: VoiceTranscriptionResultController
    @ObservedObject var manager = VoiceTranscribeManager.shared
    @State private var copied = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
                
                Text("Transcription")
                    .font(.headline)
                
                Spacer()
                
                // Close button
                Button {
                    controller.hideWindow()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
            
            // Text content
            ScrollView {
                Text(manager.transcriptionResult)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .frame(maxHeight: .infinity)
            
            Divider()
            
            // Actions
            HStack(spacing: 12) {
                Text("\(manager.transcriptionResult.count) characters")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                // Copy button
                Button {
                    manager.copyToClipboard()
                    copied = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold))
                        Text(copied ? "Copied!" : "Copy")
                    }
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(copied ? Color.green : Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.2), value: copied)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 400, height: 300)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    VoiceTranscriptionResultView(controller: VoiceTranscriptionResultController.shared)
}
