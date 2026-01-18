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
        case .checkingHomebrew: return "Checking Homebrew..."
        case .installingFFmpeg: return "Installing FFmpeg..."
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
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
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
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                        .stroke(Color.green.opacity(0.6), lineWidth: 3)
                        .frame(width: 76, height: 76)
                        .scaleEffect(showSuccessGlow ? 1.3 : 1.0)
                        .opacity(showSuccessGlow ? 0 : 1)
                        .animation(.easeOut(duration: 0.8), value: showSuccessGlow)
                }
                
                // Pulse animation while installing
                if manager.isInstalling {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.green.opacity(0.3), .yellow.opacity(0.3)],
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
                CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/video-target-size.png")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "film").font(.system(size: 32)).foregroundStyle(.green)
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: manager.isInstalled ? .green.opacity(0.4) : .green.opacity(0.3), radius: 8, y: 4)
                .scaleEffect(manager.isInstalled ? 1.05 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: manager.isInstalled)
            }
            
            Text(statusTitle)
                .font(.title2.bold())
                .foregroundStyle(manager.isInstalled ? .green : .primary)
                .animation(.easeInOut(duration: 0.3), value: manager.isInstalled)
            
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
                Text("Media")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
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
            return "Installing..."
        } else {
            return "Video Target Size"
        }
    }
    
    // MARK: - Content
    
    private var contentSection: some View {
        Group {
            if manager.isInstalling || (manager.isInstalled && !manager.isInstalling) {
                // Show step progress during/after install
                stepsView
            } else if !manager.isInstalled {
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
            CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/images/video-target-size-screenshot.png")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                    )
                    .padding(.top, 12)
            } placeholder: {
                // Show loading placeholder while image loads
                RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                    .foregroundStyle(.green)
                Text("Homebrew Required")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.green)
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
                            .font(.system(size: 11))
                        Text(copiedCommand ? "Copied!" : "Copy")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(copiedCommand ? .green : .green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isHoveringCopy ? Color.green.opacity(0.2) : Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isHoveringCopy = h
                    }
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
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
        .padding(12)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background((isHoveringCancel ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto))
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isHoveringCancel = h
                    }
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
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHoveringReviews = h
                }
            }
            
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
                            .font(.system(size: 12, weight: .semibold))
                        Text("Install FFmpeg")
                    }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(isHoveringAction ? 1.0 : 0.85))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isHoveringAction = h
                    }
                }
            }
            
            // Disable/Enable Extension button
            DisableExtensionButton(extensionType: .ffmpegVideoCompression)
        }
        .padding(16)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.isInstalled)
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
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isComplete)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCurrent)
    }
}

#Preview {
    FFmpegInstallView()
        .frame(width: 765, height: 600)
}
