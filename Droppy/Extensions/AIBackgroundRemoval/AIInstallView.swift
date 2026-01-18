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
        case .checking: return "Checking Python..."
        case .downloading: return "Downloading packages..."
        case .installing: return "Installing dependencies..."
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
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
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
    
    // Stats passed from parent
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
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
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .aiBackgroundRemoval)
        }
        .onAppear {
            pulseAnimation = true
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
                        .animation(.easeOut(duration: 0.8), value: showSuccessGlow)
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
                CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/ai-bg.jpg")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "brain.head.profile").font(.system(size: 32)).foregroundStyle(.blue)
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: manager.isInstalled ? .green.opacity(0.4) : .blue.opacity(0.3), radius: 8, y: 4)
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
        if manager.installError != nil {
            return "Installation Failed"
        } else if manager.isInstalled && !manager.isInstalling {
            return "Installed & Ready"
        } else if manager.isInstalling {
            return "Installing..."
        } else {
            return "AI Background Removal"
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
            ForEach(AIInstallStep.allCases.filter { $0 != .complete }, id: \.rawValue) { step in
                AIStepRow(
                    step: step,
                    currentStep: currentStep,
                    isAllComplete: manager.isInstalled && !manager.isInstalling,
                    hasError: manager.installError != nil
                )
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
            
            // Screenshot loaded from web (cached to prevent flashing)
            CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/images/ai-bg-screenshot.png")) { image in
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
                EmptyView()
            }
        }
        .padding(.bottom, 20)
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
        VStack(spacing: 8) {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            Text("Make sure Python 3 is installed on your Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
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
                // Install button - gradient style (primary action)
                Button {
                    Task {
                        currentStep = .checking
                        await manager.installTransparentBackground()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Install Now")
                    }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(isHoveringAction ? 1.0 : 0.85))
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
            
            // Disable/Enable Extension button (always visible on right)
            // For AI, Disable also uninstalls the package
            DisableExtensionButton(extensionType: .aiBackgroundRemoval)
        }
        .padding(16)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.isInstalled)
    }
}

// Components moved to AIInstallComponents.swift


#Preview {
    AIInstallView()
        .frame(width: 340, height: 400)
}
