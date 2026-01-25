//
//  ExtensionInfoView.swift
//  Droppy
//
//  Extension information popups matching AIInstallView styling
//

import SwiftUI
import AppKit

// MARK: - Extension Info View

struct ExtensionInfoView: View {
    let extensionType: ExtensionType
    var onAction: (() -> Void)?
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringAction = false
    @State private var isHoveringClose = false
    @State private var showReviewsSheet = false
    
    @State private var isHoveringReviews = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (fixed)
            headerSection
            
            Divider()
                .padding(.horizontal, 24)
            
            // Scrollable content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Features section
                    featuresSection
                    
                    // Screenshot section
                    screenshotSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 500)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Buttons (fixed)
            buttonSection
        }
        .frame(width: 450)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: extensionType)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon
            extensionType.iconView
                .shadow(color: extensionType.categoryColor.opacity(0.3), radius: 8, y: 4)
            
            // Title
            Text(extensionType.title)
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            // Stats row: installs + rating + category badge
            HStack(spacing: 12) {
                // Installs
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text("\(installCount ?? 0)")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
                
                // Rating (clickable)
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
                
                // Category badge
                Text(extensionType.category)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(extensionType.categoryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(extensionType.categoryColor.opacity(0.15))
                    )
            }
            
            // Subtitle
            Text(extensionType.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: extensionType)
        }
    }
    
    // MARK: - Screenshot Section (Left)
    
    private var screenshotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Screenshot preview loaded from web (cached to prevent flashing)
            if let screenshotURL = extensionType.screenshotURL {
                CachedAsyncImage(url: screenshotURL) { image in
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
            }
        }
    }
    
    // MARK: - Features Section (Right)
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(extensionType.description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            ForEach(Array(extensionType.features.enumerated()), id: \.offset) { _, feature in
                featureRow(icon: feature.icon, text: feature.text)
            }
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(extensionType.categoryColor)
                .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Buttons
    
    private var buttonSection: some View {
        HStack(spacing: 8) {
            // Close button
            Button {
                dismiss()
            } label: {
                Text("Close")
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            
            Spacer()
            
            // Action button (optional)
            if let action = onAction {
                Button {
                    AnalyticsService.shared.trackExtensionActivation(extensionId: extensionType.rawValue)
                    action()
                } label: {
                    Text(shortActionText)
                }
                .buttonStyle(DroppyAccentButtonStyle(color: extensionType.categoryColor, size: .small))
            }
            
            // Disable button
            DisableExtensionButton(extensionType: extensionType)
        }
        .padding(16)
    }
    
    private var shortActionText: String {
        switch extensionType {
        case .aiBackgroundRemoval: return "Install"
        case .alfred: return "Install"
        case .finder, .finderServices: return "Configure"
        case .spotify: return "Connect"
        case .elementCapture: return "Configure"
        case .windowSnap: return "Configure"
        case .voiceTranscribe: return "Configure"
        case .ffmpegVideoCompression: return "Install"
        case .terminalNotch: return "Configure"
        case .menuBarManager: return "Configure"
        case .quickshare: return "Manage"
        }
    }
    
    private var actionText: String {
        switch extensionType {
        case .aiBackgroundRemoval: return "Install"
        case .alfred: return "Install Workflow"
        case .finder, .finderServices: return "Configure"
        case .spotify: return "Connect"
        case .elementCapture: return "Configure Shortcut"
        case .windowSnap: return "Configure Shortcuts"
        case .voiceTranscribe: return "Configure"
        case .ffmpegVideoCompression: return "Install FFmpeg"
        case .terminalNotch: return "Configure"
        case .menuBarManager: return "Configure"
        case .quickshare: return "Manage Uploads"
        }
    }
    
    private var actionIcon: String {
        switch extensionType {
        case .aiBackgroundRemoval: return "arrow.down.circle.fill"
        case .alfred: return "arrow.down.circle.fill"
        case .finder, .finderServices: return "gearshape"
        case .spotify: return "link"
        case .elementCapture: return "keyboard"
        case .windowSnap: return "keyboard"
        case .voiceTranscribe: return "mic.fill"
        case .ffmpegVideoCompression: return "arrow.down.circle.fill"
        case .terminalNotch: return "terminal"
        case .menuBarManager: return "menubar.rectangle"
        case .quickshare: return "tray.full"
        }
    }
}

// MARK: - Preview

#Preview {
    ExtensionInfoView(extensionType: .alfred) {
        print("Action")
    }
}


