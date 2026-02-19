//
//  FFmpegInstallView.swift
//  Droppy
//
//  Installation window for FFmpeg video target size compression
//

import SwiftUI

// MARK: - Install Step Model

enum FFmpegInstallStep: Int, CaseIterable {
    case checkingHomebrew = 0
    case installingFFmpeg
    case complete
    
    var title: String {
        switch self {
        case .checkingHomebrew: return "Checking Homebrew…"
        case .installingFFmpeg: return "Installing FFmpeg…"
        case .complete: return "Installation Complete!"
        }
    }
    
    var icon: String {
        switch self {
        case .checkingHomebrew: return "magnifyingglass"
        case .installingFFmpeg: return "arrow.down.circle"
        case .complete: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Install View

struct FFmpegInstallView: View {
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @ObservedObject var manager = FFmpegInstallManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringAction = false
    @State private var isHoveringCancel = false
    @State private var isHoveringReviews = false
    @State private var isHoveringCopy = false
    @State private var pulseAnimation = false
    @State private var showSuccessGlow = false
    @State private var showReviewsSheet = false
    @State private var currentStep: FFmpegInstallStep = .checkingHomebrew
    @State private var copiedCommand = false
    
    // Stats passed from parent
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    private let homebrewInstallCommand = "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (fixed)
            headerSection
            
            Divider()
                .padding(.horizontal, 24)
            
            // Scrollable content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    contentSection
                    
                    if let error = manager.installError {
                        errorSection(error: error)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 450)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Buttons (fixed)
            buttonSection
        }
        .frame(width: 450)
        .fixedSize(horizontal: true, vertical: true)
        .droppyTransparentBackground(useTransparentBackground)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .ffmpegVideoCompression)
        }
        .onAppear {
            pulseAnimation = true
        }
        .onChange(of: manager.isInstalled) { _, installed in
            if installed && manager.isInstalling == false {
                currentStep = .complete
                showSuccessGlow = true
            }
        }
        .onChange(of: manager.installProgress) { _, progress in
            // Update step based on progress
            if progress.contains("Homebrew") || progress.contains("brew") {
                currentStep = .checkingHomebrew
            } else if progress.contains("FFmpeg") || progress.contains("ffmpeg") {
                currentStep = .installingFFmpeg
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon with pulse animation
            ZStack {
                // Success glow ring when complete
                if manager.isInstalled && !manager.isInstalling {
                    Circle()
                        .stroke(Color.blue.opacity(0.6), lineWidth: 3)
                        .frame(width: 76, height: 76)
                        .scaleEffect(showSuccessGlow ? 1.3 : 1.0)
                        .opacity(showSuccessGlow ? 0 : 1)
                        .animation(DroppyAnimation.transition, value: showSuccessGlow)
                }
                
                // Pulse animation while installing
                if manager.isInstalling {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .cyan.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.5)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: pulseAnimation)
                }
                
                // Main icon
                CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/icons/targeted-video-size.jpg")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "film").font(.system(size: 32)).foregroundStyle(.blue)
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
                .shadow(color: manager.isInstalled ? .blue.opacity(0.4) : .blue.opacity(0.3), radius: 8, y: 4)
                .scaleEffect(manager.isInstalled ? 1.05 : 1.0)
                .animation(DroppyAnimation.stateEmphasis, value: manager.isInstalled)
            }
            
            Text(statusTitle)
                .font(.title2.bold())
                .foregroundStyle(manager.isInstalled ? .green : .primary)
                .animation(DroppyAnimation.viewChange, value: manager.isInstalled)
            
            // Stats row: installs + rating + category badge
            HStack(spacing: 12) {
                // Installs
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text(AnalyticsService.shared.isDisabled ? "–" : "\(installCount ?? 0)")
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
                Text("Media")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.15))
                    )
            }
            
            Text("Compress videos to exact file sizes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    private var statusTitle: String {
        if manager.installError != nil {
            return "Installation Failed"
        } else if manager.isInstalled && !manager.isInstalling {
            return "Installed & Ready"
        } else if manager.isInstalling {
            return "Installing…"
        } else {
            return "Video Target Size"
        }
    }
    
    // MARK: - Content
    
    private var contentSection: some View {
        Group {
            if manager.isInstalling {
                // Show step progress during install
                stepsView
            } else if manager.isInstalled {
                // Show settings when installed
                settingsView
            } else {
                // Show features before install
                featuresView
            }
        }
    }
    
    private var stepsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(FFmpegInstallStep.allCases.filter { $0 != .complete }, id: \.rawValue) { step in
                FFmpegStepRow(
                    step: step,
                    currentStep: currentStep,
                    isAllComplete: manager.isInstalled && !manager.isInstalling,
                    hasError: manager.installError != nil
                )
            }
            
            // Show current progress line
            if manager.isInstalling && !manager.installProgress.isEmpty {
                Text(manager.installProgress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 36)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 20)
    }
    
    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Installed & Ready")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.green)
            }
            
            // Smart Export info card - clickable to open settings
            Button {
                // Open Settings and navigate to Smart Export section
                SettingsWindowController.shared.showSettings()
                // Post notification to navigate to Features tab where Smart Export is located
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: .openSmartExportSettings, object: nil)
                }
            } label: {
                HStack(spacing: 12) {
                    // Use the shared animated Smart Export icon
                    SmartExportAnimatedIcon(size: 40)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Save Compressed Files")
                            .font(.callout.weight(.medium))
                        Text("Configure export settings in Settings → General → Smart Export")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.forward")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(DroppySpacing.lg)
            }
            .buttonStyle(DroppyCardButtonStyle(cornerRadius: DroppyRadius.ml))
            .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 20)
    }
    
    private var featuresView: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "target", text: "Compress videos to exact MB sizes")
            featureRow(icon: "bolt.fill", text: "Two-pass encoding for perfect accuracy")
            featureRow(icon: "film", text: "H.264/AAC output for compatibility")
            
            Divider()
                .padding(.vertical, 12)
            
            // Homebrew requirement - check if installed
            if !manager.isHomebrewInstalled {
                homebrewRequiredSection
            } else {
                homebrewInstalledSection
            }
            
            // Screenshot loaded from web
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/images/video-target-size-screenshot.png")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                            .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                    )
                    .padding(.top, 12)
            } placeholder: {
                // Show loading placeholder while image loads
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 20)
    }
    
    private var homebrewRequiredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Homebrew Required")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            
            Text("Homebrew is a package manager for macOS. Install it first by running this command in Terminal:")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Copyable command
            HStack(spacing: 0) {
                Text(homebrewInstallCommand)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(homebrewInstallCommand, forType: .string)
                    copiedCommand = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copiedCommand = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copiedCommand ? "checkmark" : "doc.on.clipboard")
                        Text(copiedCommand ? "Copied!" : "Copy")
                    }
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .green, size: .small))
            }
            .padding(DroppySpacing.md)
            .background(AdaptiveColors.overlayAuto(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.small)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
            
            Text("After installing Homebrew, click 'Install FFmpeg' below.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var homebrewInstalledSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Homebrew Detected")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                Text("Ready to install FFmpeg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(DroppySpacing.md)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }
    
    private func featureRow(icon: String, text: String, color: Color = .green) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
            
            Spacer()
        }
    }
    
    private func errorSection(error: String) -> some View {
        VStack(spacing: 8) {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            if !manager.isHomebrewInstalled {
                Text("Homebrew is required. See above for installation command.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 16)
    }
    
    // MARK: - Buttons
    
    private var buttonSection: some View {
        HStack(spacing: 10) {
            // Cancel/Close button (only show when not installing)
            if !manager.isInstalling {
                Button {
                    dismiss()
                } label: {
                    Text(manager.isInstalled ? "Close" : "Cancel")
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
            }
            
            // Reviews button
            Button {
                showReviewsSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "star.bubble")
                    Text("Reviews")
                }
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            
            Spacer()
            
            // Action button - only show Install when not installed
            if !manager.isInstalled && !manager.isInstalling {
                Button {
                    Task {
                        await manager.installFFmpeg()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Install FFmpeg")
                    }
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .green, size: .medium))
            }
            
            // Disable/Enable Extension button
            DisableExtensionButton(extensionType: .ffmpegVideoCompression)
        }
        .padding(DroppySpacing.lg)
        .animation(DroppyAnimation.transition, value: manager.isInstalled)
    }
}

// MARK: - Step Row Component

struct FFmpegStepRow: View {
    let step: FFmpegInstallStep
    let currentStep: FFmpegInstallStep
    let isAllComplete: Bool
    let hasError: Bool
    
    private var isComplete: Bool {
        isAllComplete || step.rawValue < currentStep.rawValue
    }
    
    private var isCurrent: Bool {
        step == currentStep && !isAllComplete
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Step indicator
            ZStack {
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                } else if isCurrent {
                    if hasError {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.red)
                    } else {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
            .frame(width: 24, height: 24)
            
            Text(step.title)
                .font(.callout.weight(isCurrent || isComplete ? .medium : .regular))
                .foregroundStyle(isComplete ? .green : (isCurrent ? .primary : .secondary))
            
            Spacer()
        }
        .padding(.vertical, 8)
        .animation(DroppyAnimation.hover, value: isComplete)
        .animation(DroppyAnimation.hover, value: isCurrent)
    }
}

#Preview {
    FFmpegInstallView()
        .frame(width: 765, height: 600)
}
