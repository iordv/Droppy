//
//  VoiceTranscribeInfoView.swift
//  Droppy
//
//  Voice Transcribe extension setup and configuration view
//

import SwiftUI

struct VoiceTranscribeInfoView: View {
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.voiceTranscribeAutoCopyResult) private var autoCopyTranscriptionResult = PreferenceDefault.voiceTranscribeAutoCopyResult
    @ObservedObject private var manager = VoiceTranscribeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringAction = false
    @State private var isHoveringCancel = false
    @State private var isHoveringReviews = false
    @State private var isHoveringDownload = false
    @State private var isHoveringDelete = false
    @State private var isHoveringRecord: [VoiceRecordingMode: Bool] = [:]
    @State private var showReviewsSheet = false
    @State private var isDownloading = false
    @State private var recordingMode: VoiceRecordingMode?
    @State private var recordMonitor: Any?
    
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (fixed, non-scrolling)
            headerSection
            
            Divider()
                .padding(.horizontal, 24)
            
            // Scrollable content area
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Features
                    screenshotSection
                    
                    // Settings (config card)
                    settingsSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 520)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Buttons (fixed, non-scrolling)
            buttonSection
        }
        .frame(width: 450)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .voiceTranscribe)
        }
        .onDisappear {
            stopRecording()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon (cached to prevent flashing)
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/icons/voice-transcribe.jpg")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "waveform.and.mic").font(.system(size: 32)).foregroundStyle(.blue)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
            .shadow(color: .blue.opacity(0.4), radius: 8, y: 4)
            
            Text("Voice Transcribe")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            // Stats row
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text(AnalyticsService.shared.isDisabled ? "–" : "\(installCount ?? 0)")
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
                .buttonStyle(DroppySelectableButtonStyle(isSelected: false))
                
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
    
    // MARK: - Screenshot Section (Left)
    
    private var screenshotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Feature rows
            featureRow(icon: "waveform", text: "On-device transcription using Whisper")
            featureRow(icon: "bolt.fill", text: "Fast and accurate speech recognition")
            featureRow(icon: "lock.fill", text: "100% private, no data leaves your Mac")
            
            // Screenshot
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/images/voice-transcribe-screenshot.png")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                            .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                    )
            } placeholder: {
                EmptyView()
            }
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Settings Section (Right)
    
    private var settingsSection: some View {
        VStack(spacing: 16) {
            // Configuration Card (Menu Bar + Model + Language)
            VStack(spacing: 0) {
                // Menu Bar Toggle Row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Menu Bar")
                            .font(.callout.weight(.medium))
                        Text("Show recording icon in menu bar")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $manager.isMenuBarEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(!manager.isModelDownloaded)
                }
                .padding(DroppySpacing.lg)
                
                Divider().padding(.horizontal, 16)
                
                // Model Selection Row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Model")
                            .font(.callout.weight(.medium))
                        Text(manager.selectedModel.sizeDescription)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Spacer()
                    
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
                        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small))
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(DroppySpacing.lg)
                
                Divider().padding(.horizontal, 16)
                
                // Language Row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Language")
                            .font(.callout.weight(.medium))
                        Text("Auto-detect recommended")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Spacer()
                    
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
                        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small))
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(DroppySpacing.lg)

                Divider().padding(.horizontal, 16)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Copy Result")
                            .font(.callout.weight(.medium))
                        Text("Skip result window and copy transcription instantly")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Toggle("", isOn: $autoCopyTranscriptionResult)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .padding(DroppySpacing.lg)
            }
            .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
            

            // Download Section
            if manager.isDownloading {
                // Progress bar with cancel button
                HStack(spacing: 12) {
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                            .fill(Color.blue.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                        
                        // Progress fill - use percentage width with clipping
                        RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                            .fill(Color.blue)
                            .frame(height: 44)
                            .mask(alignment: .leading) {
                                GeometryReader { geo in
                                    Rectangle()
                                        .frame(width: geo.size.width * max(0.02, manager.downloadProgress))
                                }
                            }
                            .animation(DroppyAnimation.viewChange, value: manager.downloadProgress)
                        
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
                    .buttonStyle(DroppyCircleButtonStyle(size: 22))
                }
            } else if !manager.isModelDownloaded {
                // Download button
                Button {
                    manager.downloadModel()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Download Model")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .medium))
            }
            
            // Keyboard Shortcuts Section (only when model is installed)
            if manager.isModelDownloaded {
                VStack(spacing: 12) {
                    HStack {
                        Text("Keyboard Shortcuts")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 10) {
                        // Quick Record shortcut
                        shortcutRow(for: .quick)
                        
                        // Invisi-Record shortcut
                        shortcutRow(for: .invisi)
                    }
                }
                .padding(DroppySpacing.lg)
                .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                        .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
                )
            }
            
            // Installed Models Section (only when model is installed)
            if manager.isModelDownloaded {
                VStack(spacing: 12) {
                    HStack {
                        Text("Installed Models")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    
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
                                Text("Delete")
                            }
                        }
                        .buttonStyle(DroppyAccentButtonStyle(color: .red, size: .small))
                    }
                }
                .padding(DroppySpacing.lg)
                .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                        .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Buttons
    
    @State private var isHoveringReset = false
    
    private var buttonSection: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Text("Close")
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            
            Spacer()
            
            // Reset
            Button {
                manager.removeShortcut(for: .quick)
                manager.removeShortcut(for: .invisi)
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 32))
            .help("Reset Shortcuts")
            
            DisableExtensionButton(extensionType: .voiceTranscribe)
        }
        .padding(DroppySpacing.lg)
    }
    
    // MARK: - Shortcut Recording
    
    private func shortcutRow(for mode: VoiceRecordingMode) -> some View {
        VStack(spacing: 12) {
            // Header: Icon + Title
            HStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            // Shortcut display + Record button (matches KeyShortcutRecorder style)
            HStack(spacing: 8) {
                // Shortcut display
                Text(shortcut(for: mode)?.description ?? "None")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(AdaptiveColors.buttonBackgroundAuto)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(recordingMode == mode ? Color.blue : AdaptiveColors.subtleBorderAuto, lineWidth: recordingMode == mode ? 2 : 1)
                    )
                
                // Record button
                Button {
                    if recordingMode == mode {
                        stopRecording()
                    } else {
                        startRecording(for: mode)
                    }
                } label: {
                    Text(recordingMode == mode ? "Press…" : "Record")
                }
                .buttonStyle(DroppyAccentButtonStyle(color: recordingMode == mode ? .red : .blue, size: .small))
            }
        }
        .padding(DroppySpacing.mdl)
        .background(AdaptiveColors.buttonBackgroundAuto)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
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
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            let supportedFlags = ShortcutFlags.supported
            let normalizedFlags = event.modifierFlags.intersection(supportedFlags)

            // Modifier-only shortcuts are emitted as .flagsChanged.
            if event.type == .flagsChanged {
                guard ShortcutFlags.modifierKeyCodes.contains(event.keyCode) else { return nil }
                // Wait until at least 2 modifier families are down to avoid capturing the first key press.
                guard ShortcutFlags.activeModifierFamilyCount(in: normalizedFlags) >= 2 else { return nil }

                DispatchQueue.main.async {
                    let shortcut = SavedShortcut(keyCode: Int(event.keyCode), modifiers: normalizedFlags.rawValue)
                    self.manager.setShortcut(shortcut, for: mode)
                    self.stopRecording()
                }
                return nil
            }

            // For keyDown capture regular key + modifier shortcuts.
            if ShortcutFlags.modifierKeyCodes.contains(event.keyCode) {
                return nil
            }

            DispatchQueue.main.async {
                let shortcut = SavedShortcut(keyCode: Int(event.keyCode), modifiers: normalizedFlags.rawValue)
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

private enum ShortcutFlags {
    static let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 58, 59, 60, 61, 62]
    static let supported: NSEvent.ModifierFlags = [
        .command, .shift, .option, .control
    ]

    static func activeModifierFamilyCount(in flags: NSEvent.ModifierFlags) -> Int {
        var count = 0
        if flags.contains(.command) { count += 1 }
        if flags.contains(.option) { count += 1 }
        if flags.contains(.control) { count += 1 }
        if flags.contains(.shift) { count += 1 }
        return count
    }
}

#Preview {
    VoiceTranscribeInfoView()
        .frame(height: 600)
}
