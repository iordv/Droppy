//
//  VoiceTranscribeInfoView.swift
//  Droppy
//
//  Voice Transcribe extension setup and configuration view
//

import SwiftUI

struct VoiceTranscribeInfoView: View {
    @ObservedObject private var manager = VoiceTranscribeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringAction = false
    @State private var isHoveringCancel = false
    @State private var showReviewsSheet = false
    @State private var isDownloading = false
    
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
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.black)
        .clipped()
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .voiceTranscribe)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon
            AsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/voice-transcribe.jpg")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "waveform.and.mic").font(.system(size: 32)).foregroundStyle(.blue)
                default:
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(white: 0.2))
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .blue.opacity(0.4), radius: 8, y: 4)
            
            Text("Voice Transcribe")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            // Stats row
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text("\(installCount ?? 0)")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
                
                // Reviews button
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
            
            Text("Record and transcribe audio using local AI")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Setup Content
    
    private var setupContent: some View {
        VStack(spacing: 20) {
            // Step 1: Model Selection & Download
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    stepBadge(number: 1, completed: manager.isModelDownloaded)
                    Text("Choose & Download Model")
                        .font(.headline)
                    Spacer()
                }
                
                HStack {
                    Text("Model")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Menu {
                        ForEach(WhisperModel.allCases) { model in
                            Button {
                                manager.selectedModel = model
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(model.displayName)
                                        Text(model.sizeDescription)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
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
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .menuStyle(.borderlessButton)
                }
                
                // Download button
                if !manager.isModelDownloaded {
                    Button {
                        isDownloading = true
                        Task {
                            await manager.downloadModel()
                            isDownloading = false
                        }
                    } label: {
                        HStack {
                            if isDownloading {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 16, height: 16)
                                Text("Downloading... \(Int(manager.downloadProgress * 100))%")
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Download Model")
                            }
                        }
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(isDownloading)
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Model ready")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Step 2: Language
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    stepBadge(number: 2, completed: true)
                    Text("Select Language")
                        .font(.headline)
                    Spacer()
                }
                
                HStack {
                    Text("Language")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    
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
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .menuStyle(.borderlessButton)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Step 3: Enable Menu Bar
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    stepBadge(number: 3, completed: manager.isMenuBarEnabled)
                    Text("Enable Menu Bar Icon")
                        .font(.headline)
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { manager.isMenuBarEnabled },
                        set: { manager.isMenuBarEnabled = $0 }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                
                Text("Click the menu bar icon to start/stop recording")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    private func stepBadge(number: Int, completed: Bool) -> some View {
        ZStack {
            Circle()
                .fill(completed ? Color.green : Color.white.opacity(0.2))
                .frame(width: 24, height: 24)
            
            if completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Text("\(number)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
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
                    .background(Color.white.opacity(isHoveringCancel ? 0.15 : 0.1))
                    .foregroundStyle(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHoveringCancel = h
                }
            }
            
            Spacer()
            
            // Done button
            Button {
                // Track activation if model is downloaded
                if manager.isModelDownloaded {
                    AnalyticsService.shared.trackExtensionActivation(extensionId: "voiceTranscribe")
                }
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: manager.isModelDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                        .font(.system(size: 12, weight: .semibold))
                    Text(manager.isModelDownloaded ? "Done" : "Download Model First")
                }
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(manager.isModelDownloaded ? Color.green.opacity(isHoveringAction ? 1.0 : 0.85) : Color.gray.opacity(0.5))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!manager.isModelDownloaded)
            .onHover { h in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHoveringAction = h
                }
            }
        }
        .padding(16)
    }
}

#Preview {
    VoiceTranscribeInfoView()
        .frame(height: 600)
}
