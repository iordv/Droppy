import SwiftUI

// MARK: - AI Install View Components
// Extracted from AIInstallView.swift for faster incremental builds

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
                        .fill(AdaptiveColors.hoverBackgroundAuto)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                        )
                        .transition(.opacity)
                }
            }
            .frame(width: 20, height: 20)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isComplete)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCurrent)
            
            Text(step.title)
                .font(.system(size: 13, weight: isComplete ? .medium : (isCurrent ? .semibold : .regular)))
                .foregroundColor(isPending ? Color.secondary : (isComplete ? Color.green : Color.primary))
            
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
