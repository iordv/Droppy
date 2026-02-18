//
//  AIInstallView.swift
//  Droppy
//
//  Native installation window for AI background removal
//  Design matches DroppyUpdater for visual consistency
//

import SwiftUI

// MARK: - Install Step Model

enum AIInstallStep: Int, CaseIterable {
    case checking = 0
    case downloading
    case installing
    case complete
    
    var title: String {
        switch self {
        case .checking: return "Checking Python…"
        case .downloading: return "Downloading packages…"
        case .installing: return "Installing dependencies…"
        case .complete: return "Installation Complete!"
        }
    }
    
    var icon: String {
        switch self {
        case .checking: return "magnifyingglass"
        case .downloading: return "arrow.down.circle"
        case .installing: return "gearshape.2"
        case .complete: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Install View

struct AIInstallView: View {
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @ObservedObject var manager = AIInstallManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringAction = false
    @State private var isHoveringCancel = false
    @State private var isHoveringReviews = false
    @State private var pulseAnimation = false
    @State private var showSuccessGlow = false
    @State private var showConfetti = false
    @State private var currentStep: AIInstallStep = .checking
    @State private var showReviewsSheet = false
    @State private var copiedManualCommand = false
    @State private var showManualSetup = false
    
    // Stats passed from parent
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?

    private var isFailureState: Bool {
        manager.installError != nil && !manager.isInstalling && !manager.isInstalled
    }

    private var shouldShowManualSetupInPrerequisites: Bool {
        !manager.hasDetectedPythonPath || showManualSetup
    }
    
    var body: some View {
        ZStack {
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
                .frame(maxHeight: 400)
                
                Divider()
                    .padding(.horizontal, 24)
                
                // Buttons (fixed)
                buttonSection
            }
            
            // Confetti overlay
            if showConfetti {
                AIConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 450)
        .fixedSize(horizontal: true, vertical: true)
        .droppyTransparentBackground(useTransparentBackground)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .aiBackgroundRemoval)
        }
        .onAppear {
            pulseAnimation = true
            manager.checkInstallationStatus()
        }
        .onChange(of: manager.isInstalled) { _, installed in
            if installed && manager.isInstalling == false {
                currentStep = .complete
                showSuccessGlow = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showConfetti = true
                }
            }
        }
        .onChange(of: manager.installProgress) { _, progress in
            if progress.contains("Downloading") {
                currentStep = .downloading
            } else if progress.contains("Installing") || progress.contains("installing") {
                currentStep = .installing
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
                
                // Main icon - AI icon from remote URL (cached to prevent flashing)
                CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/icons/ai-bg.jpg")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "brain.head.profile").font(.system(size: 32)).foregroundStyle(.blue)
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
                .shadow(color: manager.isInstalled ? .green.opacity(0.4) : .blue.opacity(0.3), radius: 8, y: 4)
                .scaleEffect(manager.isInstalled ? 1.05 : 1.0)
                .animation(DroppyAnimation.stateEmphasis, value: manager.isInstalled)
            }
            
            Text(statusTitle)
                .font(.title2.bold())
                .foregroundStyle(manager.isInstalled ? .green : (isFailureState ? .orange : .primary))
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
                Text("AI")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.15))
                    )
            }
            
            Text("InSPyReNet - State of the Art Quality")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    private var statusTitle: String {
        if isFailureState {
            return "Setup Needs Attention"
        } else if manager.isInstalled && !manager.isInstalling {
            return "Installed & Ready"
        } else if manager.isInstalling {
            return "Installing…"
        } else {
            return "AI Background Removal"
        }
    }
    
    // MARK: - Content
    
    private var contentSection: some View {
        Group {
            if manager.isInstalling || manager.isInstalled || isFailureState {
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
            ForEach(AIInstallStep.allCases.filter { $0 != .complete }, id: \.rawValue) { step in
                AIStepRow(
                    step: step,
                    currentStep: currentStep,
                    isAllComplete: manager.isInstalled && !manager.isInstalling,
                    hasError: manager.installError != nil
                )
            }

            if manager.isInstalling && !manager.installProgress.isEmpty {
                Text(manager.installProgress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 32)
                    .padding(.top, 8)
            } else if isFailureState {
                Text("Install stopped before completion. Use the recovery actions below and retry.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 32)
                    .padding(.top, 8)
            }
        }
        .padding(.bottom, 20)
    }
    
    private var featuresView: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "sparkles", text: "Best-in-class background removal")
            featureRow(icon: "bolt.fill", text: "Works offline after install")
            featureRow(icon: "lock.fill", text: "100% on-device processing")
            featureRow(icon: "arrow.down.circle", text: "One-time download (~400MB)")
            prerequisiteSection
            
            // Screenshot loaded from web (cached to prevent flashing)
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/images/ai-bg-screenshot.png")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                            .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                    )
                    .padding(.top, 8)
            } placeholder: {
                EmptyView()
            }
        }
        .padding(.bottom, 20)
    }
    
    private var prerequisiteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .padding(.vertical, 8)
            
            HStack(spacing: 8) {
                Image(systemName: manager.hasDetectedPythonPath ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(manager.hasDetectedPythonPath ? .green : .orange)
                Text(manager.hasDetectedPythonPath ? "Python detected on your Mac" : "Could not detect Python automatically")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            
            Text(manager.hasDetectedPythonPath
                 ? "Python is available. Install Now creates an isolated AI environment without changing your system Python."
                 : "Python was not found yet. Install Now will still try automatic setup, or you can run the command manually.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let pythonPath = manager.detectedPythonPath, manager.hasDetectedPythonPath {
                Text(pythonPath)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("No `python3` path found in common locations yet.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if shouldShowManualSetupInPrerequisites {
                manualCommandSection
                recoveryActions
            } else {
                HStack(spacing: 8) {
                    Button {
                        manager.checkInstallationStatus()
                    } label: {
                        Label("Re-check", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(DroppyPillButtonStyle(size: .small))

                    Button {
                        showManualSetup = true
                    } label: {
                        Label("Manual Setup", systemImage: "terminal")
                    }
                    .buttonStyle(DroppyPillButtonStyle(size: .small))
                }
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
    
    private func errorSection(error: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Install Needs Attention")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Text(error)
                .font(.caption)
                .foregroundStyle(.primary)

            Text(recoveryHintText)
                .font(.caption)
                .foregroundStyle(.secondary)

            manualCommandSection
            recoveryActions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DroppySpacing.md)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.12), lineWidth: 1)
        )
        .padding(.bottom, 16)
    }

    private var recoveryHintText: String {
        if manager.hasDetectedPythonPath {
            return "Python is already available, so this is usually a dependency or network issue. Retry install, or run the command manually and press Re-check."
        }
        return "Python was not detected yet. Retry install to trigger setup, or run the command manually once Python 3 is available."
    }

    private var manualCommandSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Manual command")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(manager.recommendedManualInstallCommand)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(DroppySpacing.md)
            .background(AdaptiveColors.overlayAuto(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.small)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var recoveryActions: some View {
        HStack(spacing: 8) {
            Button {
                manager.checkInstallationStatus()
            } label: {
                Label("Re-check", systemImage: "arrow.clockwise")
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))

            Button {
                copyManualCommand()
            } label: {
                Label(copiedManualCommand ? "Copied" : "Copy Command", systemImage: copiedManualCommand ? "checkmark" : "doc.on.clipboard")
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
        }
    }
    
    private func copyManualCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(manager.recommendedManualInstallCommand, forType: .string)
        copiedManualCommand = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedManualCommand = false
        }
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
                // Install button - gradient style (primary action)
                Button {
                    Task {
                        currentStep = .checking
                        await manager.installTransparentBackground()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: manager.installError == nil ? "arrow.down.circle.fill" : "arrow.clockwise")
                        Text(manager.installError == nil ? "Install Now" : "Retry Install")
                    }
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .medium))
            }
            
            // Disable/Enable Extension button (always visible on right)
            // For AI, Disable also uninstalls the package
            DisableExtensionButton(extensionType: .aiBackgroundRemoval)
        }
        .padding(DroppySpacing.lg)
        .animation(DroppyAnimation.transition, value: manager.isInstalled)
    }
}

// Components moved to AIInstallComponents.swift


#Preview {
    AIInstallView()
        .frame(width: 340, height: 400)
}
