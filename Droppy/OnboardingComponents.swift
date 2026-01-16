import SwiftUI

// MARK: - Onboarding Components
// Extracted from OnboardingView.swift for faster incremental builds

struct OnboardingToggle: View {
    let icon: String
    let title: String
    let color: Color
    @Binding var isOn: Bool
    
    @State private var iconBounce = false
    @State private var isHovering = false
    
    var body: some View {
        Button {
            // Trigger icon bounce
            withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                iconBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    iconBounce = false
                    isOn.toggle()
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isOn ? color.opacity(0.2) : AdaptiveColors.buttonBackgroundAuto)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isOn ? color : .secondary)
                        .scaleEffect(iconBounce ? 1.3 : 1.0)
                        .rotationEffect(.degrees(iconBounce ? -8 : 0))
                }
                .frame(width: 40, height: 40)
                
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isOn ? .primary : .secondary)
                
                Spacer()
                
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isOn ? .green : .secondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background((isOn ? AdaptiveColors.buttonBackgroundAuto : AdaptiveColors.buttonBackgroundAuto))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isOn ? color.opacity(0.3) : AdaptiveColors.buttonBackgroundAuto, lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Onboarding Display Mode Button

/// Display mode button for onboarding with icon bounce animation
/// Designed for the Notch/Dynamic Island selection
struct OnboardingDisplayModeButton<Icon: View>: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    let icon: Icon
    
    @State private var iconBounce = false
    @State private var isHovering = false
    
    init(title: String, isSelected: Bool, action: @escaping () -> Void, @ViewBuilder icon: () -> Icon) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
        self.icon = icon()
    }
    
    var body: some View {
        Button {
            // Trigger icon bounce
            withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                iconBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    iconBounce = false
                    action()
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.blue.opacity(0.2) : AdaptiveColors.buttonBackgroundAuto)
                    
                    icon
                        .scaleEffect(iconBounce ? 1.2 : 1.0)
                        .rotationEffect(.degrees(iconBounce ? -5 : 0))
                }
                .frame(width: 70, height: 40)
                
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? .green : .secondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background((isSelected ? AdaptiveColors.buttonBackgroundAuto : AdaptiveColors.buttonBackgroundAuto))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.blue.opacity(0.3) : AdaptiveColors.buttonBackgroundAuto, lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Onboarding View

struct OnboardingConfettiView: View {
    @State private var particles: [OnboardingParticle] = []
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
        let colors: [Color] = [.blue, .green, .yellow, .orange, .pink, .purple, .cyan]
        
        for i in 0..<24 {
            var particle = OnboardingParticle(
                id: i,
                x: CGFloat.random(in: 40...(size.width - 40)),
                startY: size.height + 10,
                endY: CGFloat.random(in: -20...size.height * 0.3),
                color: colors[i % colors.count],
                size: CGFloat.random(in: 5...8),
                delay: Double(i) * 0.015
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
                withAnimation(.easeOut(duration: 1.2)) {
                    particles[i].currentY = particles[i].endY
                    particles[i].currentX = particles[i].x + CGFloat.random(in: -30...30)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.9) {
                guard i < particles.count else { return }
                withAnimation(.easeIn(duration: 0.3)) {
                    particles[i].opacity = 0
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isVisible = false
        }
    }
}

struct OnboardingParticle: Identifiable {
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

// MARK: - Window Controller

final class OnboardingWindowController: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindowController()
    
    private var window: NSWindow?
    
    private override init() {
        super.init()
    }
    
    func show() {
        // If window exists and is visible, just bring to front
        if let existingWindow = window {
            if existingWindow.isVisible {
                existingWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            } else {
                // Window exists but not visible - clear it
                window = nil
            }
        }
        
        let contentView = OnboardingView { [weak self] in
            // Defer to next runloop to avoid releasing view while callback is in progress
            DispatchQueue.main.async {
                // Mark onboarding as complete first
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                self?.close()
            }
        }
        .preferredColorScheme(.dark) // Force dark mode always
        
        let hostingView = NSHostingView(rootView: contentView)
        
        // Use NSPanel with borderless style to match extension windows (no traffic lights)
        let newWindow = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 580),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.backgroundColor = .clear  // Clear to allow SwiftUI transparency mode
        newWindow.isOpaque = false
        newWindow.hasShadow = true
        newWindow.isMovableByWindowBackground = true
        newWindow.isReleasedWhenClosed = false  // Prevent premature deallocation
        newWindow.delegate = self  // Handle window close
        newWindow.contentView = hostingView
        newWindow.center()
        newWindow.level = .floating
        
        // Store reference AFTER setup
        window = newWindow
        
        // Fade in - use deferred makeKey to avoid NotchWindow conflicts
        newWindow.alphaValue = 0
        newWindow.orderFront(nil)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            newWindow.makeKeyAndOrderFront(nil)
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            newWindow.animator().alphaValue = 1.0
        }
    }
    
    func close() {
        guard let panel = window else { return }
        
        // Capture and nil reference AFTER animation to keep window alive
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // Now safe to release - animation is done
            self?.window = nil
            panel.orderOut(nil)
        })
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        // Clear reference when window is closed via X button
        window = nil
    }
}
