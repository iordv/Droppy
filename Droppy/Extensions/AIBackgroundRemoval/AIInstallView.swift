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
                // Header
                headerSection
                
                // Content - either steps during install or feature list
                contentSection
                
                // Error Message
                if let error = manager.installError {
                    errorSection(error: error)
                }
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Action Buttons
                buttonSection
            }
            
            // Confetti overlay
            if showConfetti {
                AIConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 510)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.black)
        .clipped()
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
                                colors: [.purple.opacity(0.3), .cyan.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.5)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: pulseAnimation)
                }
                
                // Main icon - Droppy with magic sparkle overlay
                AIExtensionIcon(size: 64)
                    .shadow(color: manager.isInstalled ? .green.opacity(0.4) : .purple.opacity(0.3), radius: 8, y: 4)
                    .scaleEffect(manager.isInstalled ? 1.05 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: manager.isInstalled)
            }
            
            Text(statusTitle)
                .font(.title2.bold())
                .foregroundStyle(manager.isInstalled ? .green : .white)
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
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.purple.opacity(0.15))
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
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    private var featuresView: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "sparkles", text: "Best-in-class background removal")
            featureRow(icon: "bolt.fill", text: "Works offline after install")
            featureRow(icon: "lock.fill", text: "100% on-device processing")
            featureRow(icon: "arrow.down.circle", text: "One-time download (~400MB)")
            
            // Screenshot loaded from web (keeps app size minimal)
            AsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/images/ai-bg-screenshot.png")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .padding(.top, 8)
                case .failure:
                    EmptyView()
                case .empty:
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 150)
                        .overlay(ProgressView().scaleEffect(0.8))
                        .padding(.top, 8)
                @unknown default:
                    EmptyView()
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
            
            // Action button
            if manager.isInstalled && !manager.isInstalling {
                // Uninstall button - red style
                Button {
                    Task {
                        currentStep = .checking
                        await manager.uninstallTransparentBackground()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Uninstall")
                    }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(isHoveringAction ? 1.0 : 0.8))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isHoveringAction = h
                    }
                }
            } else if !manager.isInstalling {
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
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isHoveringAction = h
                    }
                }
            }
        }
        .padding(16)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.isInstalled)
    }
}

// MARK: - Step Row

struct AIStepRow: View {
    let step: AIInstallStep
    let currentStep: AIInstallStep
    let isAllComplete: Bool
    let hasError: Bool
    
    private var isComplete: Bool {
        if isAllComplete { return true }
        return step.rawValue < currentStep.rawValue
    }
    
    private var isCurrent: Bool {
        if isAllComplete { return false }
        return step.rawValue == currentStep.rawValue
    }
    
    private var isPending: Bool {
        if isAllComplete { return false }
        return step.rawValue > currentStep.rawValue
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                } else if isCurrent {
                    if hasError {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.red)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.8)
                            .transition(.opacity)
                    }
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .transition(.opacity)
                }
            }
            .frame(width: 20, height: 20)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isComplete)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCurrent)
            
            Text(step.title)
                .font(.system(size: 13, weight: isComplete ? .medium : (isCurrent ? .semibold : .regular)))
                .foregroundColor(isPending ? Color.secondary : (isComplete ? Color.green : Color.white))
            
            Spacer()
        }
        .padding(.vertical, 8)
        .opacity(isPending ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isComplete)
        .animation(.easeInOut(duration: 0.2), value: isCurrent)
    }
}

// MARK: - Confetti View

struct AIConfettiView: View {
    @State private var particles: [AIConfettiParticle] = []
    @State private var isVisible = true
    
    var body: some View {
        GeometryReader { geo in
            if isVisible {
                Canvas { context, size in
                    for particle in particles {
                        let rect = CGRect(
                            x: particle.currentX - particle.size / 2,
                            y: particle.currentY - particle.size * 0.75,
                            width: particle.size,
                            height: particle.size * 1.5
                        )
                        context.fill(
                            RoundedRectangle(cornerRadius: 1).path(in: rect),
                            with: .color(particle.color.opacity(particle.opacity))
                        )
                    }
                }
                .onAppear {
                    createParticles(in: geo.size)
                    startAnimation()
                }
            }
        }
    }
    
    private func createParticles(in size: CGSize) {
        let colors: [Color] = [.green, .purple, .cyan, .blue, .pink]
        
        for i in 0..<15 {
            var particle = AIConfettiParticle(
                id: i,
                x: CGFloat.random(in: 20...(size.width - 20)),
                startY: size.height + 10,
                endY: CGFloat.random(in: -20...size.height * 0.4),
                color: colors[i % colors.count],
                size: CGFloat.random(in: 5...7),
                delay: Double(i) * 0.02
            )
            particle.currentX = particle.x
            particle.currentY = particle.startY
            particles.append(particle)
        }
    }
    
    private func startAnimation() {
        for i in 0..<particles.count {
            let delay = particles[i].delay
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard i < particles.count else { return }
                
                withAnimation(.easeOut(duration: 1.0)) {
                    particles[i].currentY = particles[i].endY
                    particles[i].currentX = particles[i].x + CGFloat.random(in: -25...25)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.7) {
                guard i < particles.count else { return }
                withAnimation(.easeIn(duration: 0.3)) {
                    particles[i].opacity = 0
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isVisible = false
        }
    }
}

struct AIConfettiParticle: Identifiable {
    let id: Int
    let x: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let color: Color
    let size: CGFloat
    let delay: Double
    var currentX: CGFloat = 0
    var currentY: CGFloat = 0
    var opacity: Double = 1
}

#Preview {
    AIInstallView()
        .frame(width: 340, height: 400)
}
