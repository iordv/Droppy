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
    @State private var isHoveringDelete = false
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
            // Configuration Card (Model + Language)
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
            }
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
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
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: 44)
                    
                    Button {
                        manager.cancelDownload()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.7))
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
                    .foregroundStyle(.white)
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
                    .background(Color.white.opacity(0.03))
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
            
            // Menu Bar toggle button (or Download First if not ready)
            Button {
                if manager.isModelDownloaded {
                    manager.isMenuBarEnabled.toggle()
                    if manager.isMenuBarEnabled {
                        AnalyticsService.shared.trackExtensionActivation(extensionId: "voiceTranscribe")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if !manager.isModelDownloaded {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Download First")
                    } else if manager.isMenuBarEnabled {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Remove")
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Add to Menu Bar")
                    }
                }
                .fixedSize()
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    manager.isModelDownloaded
                        ? (manager.isMenuBarEnabled
                            ? Color.red.opacity(isHoveringAction ? 0.9 : 0.7)
                            : Color.green.opacity(isHoveringAction ? 1.0 : 0.85))
                        : Color.gray.opacity(0.5)
                )
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
