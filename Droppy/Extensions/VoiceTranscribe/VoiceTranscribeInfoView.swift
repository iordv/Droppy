//
//  VoiceTranscribeInfoView.swift
//  Droppy
//
//  Voice Transcribe extension setup and configuration view
//

import SwiftUI

struct VoiceTranscribeInfoView: View {
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    @ObservedObject private var manager = VoiceTranscribeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringAction = false
    @State private var isHoveringCancel = false
    @State private var isHoveringReviews = false
    @State private var isHoveringDownload = false
    @State private var isHoveringDelete = false
    @State private var showReviewsSheet = false
    @State private var isDownloading = false
    @State private var recordingMode: VoiceRecordingMode?
    @State private var recordMonitor: Any?
    
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
                .padding(.horizontal, 20)
            
            // Content - Setup flow
            setupContent
            
            Divider()
                .padding(.horizontal, 20)
            
            // Action Buttons
            buttonSection
        }
        .frame(width: 540)  // Wider for horizontal config layout
        .fixedSize(horizontal: false, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipped()
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .voiceTranscribe)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon (cached to prevent flashing)
            CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/voice-transcribe.jpg")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "waveform.and.mic").font(.system(size: 32)).foregroundStyle(.blue)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .blue.opacity(0.4), radius: 8, y: 4)
            
            Text("Voice Transcribe")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            // Stats row
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text("\(installCount ?? 0)")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
                
                Button {
                    showReviewsSheet = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                        if let r = rating, r.ratingCount > 0 {
                            Text(String(format: "%.1f", r.averageRating))
                                .font(.caption.weight(.medium))
                            Text("(\(r.ratingCount))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("–")
                                .font(.caption.weight(.medium))
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Text("AI")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.blue.opacity(0.15)))
            }
            
            Text("On-device speech-to-text transcription")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Setup Content
    
    private var setupContent: some View {
        VStack(spacing: 16) {
            // Configuration Card - Horizontal layout (3 columns)
            HStack(alignment: .top, spacing: 0) {
                // Menu Bar Column
                VStack(alignment: .center, spacing: 8) {
                    Text("Menu Bar")
                        .font(.callout.weight(.medium))
                    Text("Show in menu bar")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    
                    Toggle("", isOn: $manager.isMenuBarEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(!manager.isModelDownloaded)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                
                Divider().frame(height: 70)
                
                // Model Column
                VStack(alignment: .center, spacing: 8) {
                    Text("Model")
                        .font(.callout.weight(.medium))
                    Text(manager.selectedModel.sizeDescription)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    Menu {
                        ForEach(WhisperModel.allCases) { model in
                            Button {
                                manager.selectedModel = model
                            } label: {
                                HStack {
                                    Text(model.displayName)
                                    if manager.selectedModel == model {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(manager.selectedModel.displayName)
                                .font(.callout.weight(.medium))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AdaptiveColors.subtleBorderAuto)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .menuStyle(.borderlessButton)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                
                Divider().frame(height: 70)
                
                // Language Column
                VStack(alignment: .center, spacing: 8) {
                    Text("Language")
                        .font(.callout.weight(.medium))
                    Text("Auto-detect recommended")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    Menu {
                        ForEach(manager.supportedLanguages, id: \.code) { lang in
                            Button {
                                manager.selectedLanguage = lang.code
                            } label: {
                                HStack {
                                    Text(lang.name)
                                    if manager.selectedLanguage == lang.code {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(manager.supportedLanguages.first { $0.code == manager.selectedLanguage }?.name ?? "Auto")
                                .font(.callout.weight(.medium))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AdaptiveColors.subtleBorderAuto)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .menuStyle(.borderlessButton)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .background(AdaptiveColors.buttonBackgroundAuto)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Screenshot loaded from web (cached to prevent flashing)
            CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/images/voice-transcribe-screenshot.png")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                    )
            } placeholder: {
                EmptyView()
            }
            
            // Download Section
            if manager.isDownloading {
                // Progress bar with cancel button
                HStack(spacing: 12) {
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.blue.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                        
                        // Progress fill - use percentage width with clipping
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.blue)
                            .frame(height: 44)
                            .mask(alignment: .leading) {
                                GeometryReader { geo in
                                    Rectangle()
                                        .frame(width: geo.size.width * max(0.02, manager.downloadProgress))
                                }
                            }
                            .animation(.easeInOut(duration: 0.3), value: manager.downloadProgress)
                        
                        // Label overlay
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                            Text("Downloading \(Int(manager.downloadProgress * 100))%")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: 44)
                    
                    Button {
                        manager.cancelDownload()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color(NSColor.labelColor).opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            } else if !manager.isModelDownloaded {
                // Download button
                Button {
                    manager.downloadModel()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Download Model")
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(isHoveringDownload ? 1.0 : 0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isHoveringDownload = h
                    }
                }
            }
            
            // Keyboard Shortcuts Section (only when model is installed)
            if manager.isModelDownloaded {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Keyboard Shortcuts")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                    
                    HStack(spacing: 10) {
                        // Quick Record shortcut
                        shortcutRow(for: .quick)
                        
                        // Invisi-Record shortcut
                        shortcutRow(for: .invisi)
                    }
                }
            }
            
            // Installed Models Section (only when model is installed)
            if manager.isModelDownloaded {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Installed Models")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                    
                    // Current installed model row
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 14))
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(manager.selectedModel.displayName)
                                    .font(.callout.weight(.medium))
                                Text(manager.selectedModel.sizeDescription)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        
                        Spacer()
                        
                        // Delete button with hover effect
                        Button {
                            manager.deleteModel()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                Text("Delete")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(.red.opacity(0.9))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(isHoveringDelete ? 0.2 : 0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .onHover { h in
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                isHoveringDelete = h
                            }
                        }
                    }
                    .padding(14)
                    .background(AdaptiveColors.buttonBackgroundAuto)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    // MARK: - Buttons
    
    private var buttonSection: some View {
        HStack(spacing: 10) {
            // Close button
            Button {
                dismiss()
            } label: {
                Text("Close")
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background((isHoveringCancel ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto))
                    .foregroundStyle(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHoveringCancel = h
                }
            }
            
            // Reviews button
            Button {
                showReviewsSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "star.bubble")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Reviews")
                }
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background((isHoveringReviews ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto))
                .foregroundStyle(.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHoveringReviews = h
                }
            }
            
            Spacer()
            
            // Disable Extension button
            DisableExtensionButton(extensionType: .voiceTranscribe)
        }
        .padding(16)
    }
    
    // MARK: - Shortcut Recording
    
    private func shortcutRow(for mode: VoiceRecordingMode) -> some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: mode.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 20)
            
            // Title
            VStack(alignment: .leading, spacing: 1) {
                Text(mode.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(mode.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Shortcut button
            Button {
                if recordingMode == mode {
                    stopRecording()
                } else {
                    startRecording(for: mode)
                }
            } label: {
                HStack(spacing: 4) {
                    if recordingMode == mode {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("...")
                            .font(.system(size: 11, weight: .medium))
                    } else if let shortcut = shortcut(for: mode) {
                        Text(shortcut.description)
                            .font(.system(size: 11, weight: .semibold))
                    } else {
                        Text("Click")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(recordingMode == mode ? .primary : (shortcut(for: mode) != nil ? .primary : .secondary))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(recordingMode == mode ? Color.red.opacity(0.85) : AdaptiveColors.buttonBackgroundAuto)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AdaptiveColors.buttonBackgroundAuto)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    private func shortcut(for mode: VoiceRecordingMode) -> SavedShortcut? {
        switch mode {
        case .quick:
            return manager.quickRecordShortcut
        case .invisi:
            return manager.invisiRecordShortcut
        }
    }
    
    private func startRecording(for mode: VoiceRecordingMode) {
        stopRecording()
        recordingMode = mode
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Ignore just modifier keys pressed alone
            if event.keyCode == 54 || event.keyCode == 55 || event.keyCode == 56 ||
               event.keyCode == 58 || event.keyCode == 59 || event.keyCode == 60 ||
               event.keyCode == 61 || event.keyCode == 62 {
                return nil
            }
            
            // Capture the shortcut
            DispatchQueue.main.async {
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let shortcut = SavedShortcut(keyCode: Int(event.keyCode), modifiers: flags.rawValue)
                self.manager.setShortcut(shortcut, for: mode)
                self.stopRecording()
            }
            return nil
        }
    }
    
    private func stopRecording() {
        recordingMode = nil
        if let m = recordMonitor {
            NSEvent.removeMonitor(m)
            recordMonitor = nil
        }
    }
}

#Preview {
    VoiceTranscribeInfoView()
        .frame(height: 600)
}
