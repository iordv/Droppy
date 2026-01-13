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
    @State private var isHoveringReviews = false
    @State private var isHoveringDownload = false
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
            
            Text("Record and transcribe audio using local AI")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Setup Content
    
    private var setupContent: some View {
        VStack(spacing: 16) {
            // Configuration Card
            VStack(spacing: 0) {
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
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(16)
                
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
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(16)
                
                Divider().padding(.horizontal, 16)
                
                // Menu Bar Toggle Row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Menu Bar Icon")
                            .font(.callout.weight(.medium))
                        Text("Quick access to record")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { manager.isMenuBarEnabled },
                        set: { manager.isMenuBarEnabled = $0 }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .padding(16)
            }
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Download/Status Section
            if !manager.isModelDownloaded {
                Button {
                    isDownloading = true
                    Task {
                        await manager.downloadModel()
                        isDownloading = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        if manager.isDownloading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                            Text("Downloading...")
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Download Model")
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(isHoveringDownload ? 1.0 : 0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(manager.isDownloading)
                .onHover { h in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isHoveringDownload = h
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Model ready")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(16)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
                .background(Color.white.opacity(isHoveringReviews ? 0.15 : 0.1))
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
