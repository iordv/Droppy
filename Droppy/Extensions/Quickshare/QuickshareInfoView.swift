//
//  QuickshareInfoView.swift
//  Droppy
//
//  Quickshare extension configuration view
//

import SwiftUI

struct QuickshareInfoView: View {
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @Environment(\.dismiss) private var dismiss
    
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    @State private var showReviewsSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
                .padding(.horizontal, 24)
            
            // Scrollable content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Features
                    featuresSection
                    
                    // Usage
                    usageSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 500)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Buttons
            buttonSection
        }
        .frame(width: 540)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .quickshare)
        }
    }
    
    // MARK: - Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "drop.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.cyan)
                    .shadow(color: .cyan.opacity(0.4), radius: 4, y: 0)
            }
            .shadow(color: Color.cyan.opacity(0.2), radius: 8, y: 4)
            
            Text("Droppy Quickshare")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            // Stats row
            HStack(spacing: 12) {
                // Installs (Always installed, so maybe hide or show mock/analytics)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text("\(installCount ?? 0)")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
                
                // Rating
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
                Text("Productivity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.cyan.opacity(0.15))
                    )
            }
            
            Text("Quickly upload and share files via 0x0.st")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share screenshots, recordings, and files instantly with short, expiring links. No account required.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(alignment: .leading, spacing: 8) {
                featureRow(icon: "timer", text: "Files expire automatically (30-365 days base on size)")
                featureRow(icon: "link", text: "Instant short links copied to clipboard")
                featureRow(icon: "archivebox", text: "Auto-zips multiple files or folders")
                featureRow(icon: "list.bullet", text: "Built-in history and file management")
            }
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.cyan)
                .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Quickshare is active")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                instructionRow(step: "1", text: "Use menu bar > Quickshare > Select File")
                instructionRow(step: "2", text: "Or select 'Upload from Clipboard' if you have files copied")
                instructionRow(step: "3", text: "Links are auto-copied! Manage them below.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func instructionRow(step: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 20, height: 20)
                Text(step)
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(.black)
            }
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    private var buttonSection: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Text("Close")
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            
            Spacer()
            
            Button {
                QuickshareManagerWindowController.show()
                dismiss() // Optional: dismiss sheet when opening manager? Or keep it?
                // Manager is a separate window, safe to dismiss this sheet.
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "tray.full")
                    Text("Manage Uploads")
                }
            }
            .buttonStyle(DroppyAccentButtonStyle(color: .cyan, size: .small))
            
            // Core extension, disable button shows alert 
            DisableExtensionButton(extensionType: .quickshare)
        }
        .padding(16)
    }
}
