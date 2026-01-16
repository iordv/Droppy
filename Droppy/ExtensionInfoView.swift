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
    
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringAction = false
    @State private var isHoveringClose = false
    @State private var showReviewsSheet = false
    
    @State private var isHoveringReviews = false
    
    // Alfred needs more width for the workflow content
    private var viewWidth: CGFloat {
        extensionType == .alfred ? 640 : 510
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Features
            featuresSection
            
            Divider()
                .padding(.horizontal, 20)
            
            // Buttons
            buttonSection
        }
        .frame(width: viewWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipped()
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
                .buttonStyle(.plain)
                
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
    
    // MARK: - Features
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(extensionType.description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
            
            ForEach(Array(extensionType.features.enumerated()), id: \.offset) { _, feature in
                featureRow(icon: feature.icon, text: feature.text)
            }
            
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
                        .padding(.top, 8)
                } placeholder: {
                    EmptyView() // Silently fail if network unavailable
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
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
        HStack(spacing: 10) {
            // Close button
            Button {
                dismiss()
            } label: {
                Text("Close")
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background((isHoveringClose ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto))
                    .foregroundStyle(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHoveringClose = h
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
            
            // Action button (optional)
            if let action = onAction {
                Button {
                    // Track extension activation
                    AnalyticsService.shared.trackExtensionActivation(extensionId: extensionType.rawValue)
                    action()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: actionIcon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(actionText)
                    }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(extensionType.categoryColor.opacity(isHoveringAction ? 1.0 : 0.85))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isHoveringAction = h
                    }
                }
            }
            
            // Disable/Enable Extension button (always on right)
            DisableExtensionButton(extensionType: extensionType)
        }
        .padding(16)
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
        }
    }
}

// MARK: - Preview

#Preview {
    ExtensionInfoView(extensionType: .alfred) {
        print("Action")
    }
}


