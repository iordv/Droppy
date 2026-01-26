//
//  AudioSpectrumView.swift
//  Droppy
//
//  Audio visualizer for Droppy
//  Uses CAShapeLayer with random scale animations
//  Supports dynamic color from album art
//

import AppKit
import SwiftUI

// MARK: - AudioSpectrum NSView

/// Native audio spectrum visualizer using CAShapeLayer animations
/// Supports real audio levels from SystemAudioAnalyzer or enhanced simulation fallback
class AudioSpectrum: NSView {
    private var barLayers: [CAShapeLayer] = []
    private var barScales: [CGFloat] = []
    private var isPlaying: Bool = false
    private var animationTimer: Timer?
    private var currentColor: NSColor = .white
    
    // Audio-reactive pattern generation
    private var trackProgress: CGFloat = 0.5 // 0.0-1.0 track position
    private var wavePhase: CGFloat = 0 // Creates wave-like motion across bars
    private var externalAudioLevel: CGFloat? // Real audio level from SystemAudioAnalyzer
    
    private let barCount: Int
    private let barWidth: CGFloat
    private let spacing: CGFloat
    private let totalHeight: CGFloat
    
    init(barCount: Int = 5, barWidth: CGFloat = 3, spacing: CGFloat = 2, height: CGFloat = 14, color: NSColor = .white) {
        self.barCount = barCount
        self.barWidth = barWidth
        self.spacing = spacing
        self.totalHeight = height
        self.currentColor = color
        
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
        super.init(frame: NSRect(x: 0, y: 0, width: totalWidth, height: height))
        
        wantsLayer = true
        setupBars()
    }
    
    required init?(coder: NSCoder) {
        self.barCount = 5
        self.barWidth = 3
        self.spacing = 2
        self.totalHeight = 14
        super.init(coder: coder)
        wantsLayer = true
        setupBars()
    }
    
    private func setupBars() {
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
        frame.size = CGSize(width: totalWidth, height: totalHeight)
        
        for i in 0..<barCount {
            let xPosition = CGFloat(i) * (barWidth + spacing)
            let barLayer = CAShapeLayer()
            barLayer.frame = CGRect(x: xPosition, y: 0, width: barWidth, height: totalHeight)
            barLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            barLayer.position = CGPoint(x: xPosition + barWidth / 2, y: totalHeight / 2)
            barLayer.allowsGroupOpacity = false
            barLayer.masksToBounds = true
            
            // PREMIUM: Fully rounded pill-shaped bars
            // cornerRadius = full barWidth for maximum rounded ends
            barLayer.cornerRadius = barWidth
            
            // PREMIUM: Vertical gradient from full opacity (bottom) to lighter (top)
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = CGRect(x: 0, y: 0, width: barWidth, height: totalHeight)
            gradientLayer.colors = [
                currentColor.withAlphaComponent(0.5).cgColor,  // Top: lighter
                currentColor.withAlphaComponent(1.0).cgColor   // Bottom: full opacity
            ]
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
            gradientLayer.cornerRadius = barWidth
            barLayer.addSublayer(gradientLayer)
            
            barLayers.append(barLayer)
            barScales.append(0.35)
            layer?.addSublayer(barLayer)
        }
    }
    
    private func startAnimating() {
        guard animationTimer == nil else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateBars()
        }
        // Trigger immediate update
        updateBars()
    }
    
    private func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
        resetBars()
    }
    
    override func removeFromSuperview() {
        stopAnimating()
        super.removeFromSuperview()
    }
    
    private func updateBars() {
        // Advance wave phase for organic motion (simulation mode only)
        wavePhase += 0.3
        if wavePhase > 2 * .pi { wavePhase -= 2 * .pi }
        
        for (i, barLayer) in barLayers.enumerated() {
            let currentScale = barScales[i]
            let targetScale: CGFloat
            
            if let audioLevel = externalAudioLevel {
                // REAL AUDIO MODE: iPhone-like reactive bars
                // Each bar gets independent variation for natural look
                let barVariation = CGFloat.random(in: -0.25...0.25)
                
                // Apply audio level with variation - more reactive to loud music
                // Minimum 0.15 (small bars when quiet), max 1.0 (full height when loud)
                let baseScale = 0.15 + (audioLevel * 0.85)
                targetScale = max(0.15, min(1.0, baseScale + barVariation))
            } else {
                // SIMULATION MODE: Enhanced wave patterns with track progress
                let energyMultiplier: CGFloat
                let baseMin: CGFloat
                let baseMax: CGFloat
                
                if trackProgress < 0.2 {
                    let introProgress = trackProgress / 0.2
                    energyMultiplier = 0.6 + (introProgress * 0.4)
                    baseMin = 0.3
                    baseMax = 0.7 + (introProgress * 0.3)
                } else if trackProgress > 0.8 {
                    let outroProgress = 1.0 - ((trackProgress - 0.8) / 0.2)
                    energyMultiplier = 0.6 + (outroProgress * 0.4)
                    baseMin = 0.3
                    baseMax = 0.7 + (outroProgress * 0.3)
                } else {
                    energyMultiplier = 1.0
                    baseMin = 0.35
                    baseMax = 1.0
                }
                
                let barPhase = wavePhase + (CGFloat(i) * 0.4)
                let waveInfluence = (sin(barPhase) + 1) / 2 * 0.3
                let randomComponent = CGFloat.random(in: baseMin...baseMax)
                targetScale = max(0.25, min(1.0, (randomComponent * 0.7 + waveInfluence) * energyMultiplier))
            }
            
            barScales[i] = targetScale
            
            if externalAudioLevel != nil {
                // REAL AUDIO: Spring animation for smooth, natural motion
                let spring = CASpringAnimation(keyPath: "transform.scale.y")
                spring.fromValue = currentScale
                spring.toValue = targetScale
                spring.damping = 12 // Higher = less bounce
                spring.stiffness = 300 // Higher = faster response
                spring.mass = 0.8
                spring.initialVelocity = 0
                spring.duration = spring.settlingDuration
                spring.fillMode = .forwards
                spring.isRemovedOnCompletion = false
                
                // PERFORMANCE: Cap at 60fps - 120fps isn't needed for small bar animations
                if #available(macOS 13.0, *) {
                    spring.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
                }
                
                barLayer.add(spring, forKey: "scaleY")
            } else {
                // SIMULATION: Basic animation with easeOut
                let animation = CABasicAnimation(keyPath: "transform.scale.y")
                animation.fromValue = currentScale
                animation.toValue = targetScale
                animation.duration = 0.3
                // PERFORMANCE: Removed autoreverses - was causing double animation work
                animation.fillMode = .forwards
                animation.isRemovedOnCompletion = false
                animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
                
                // PERFORMANCE: Cap at 60fps - 120fps isn't needed for small bar animations
                if #available(macOS 13.0, *) {
                    animation.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
                }
                
                barLayer.add(animation, forKey: "scaleY")
            }
        }
    }
    
    private func resetBars() {
        for (i, barLayer) in barLayers.enumerated() {
            barLayer.removeAllAnimations()
            barLayer.transform = CATransform3DMakeScale(1, 0.35, 1)
            barScales[i] = 0.35
        }
    }
    
    func setPlaying(_ playing: Bool) {
        guard isPlaying != playing else { return }
        isPlaying = playing
        if isPlaying {
            startAnimating()
        } else {
            stopAnimating()
        }
    }
    
    func setColor(_ color: NSColor) {
        guard currentColor != color else { return }
        currentColor = color
        for barLayer in barLayers {
            // Update gradient sublayer colors
            if let gradientLayer = barLayer.sublayers?.first as? CAGradientLayer {
                gradientLayer.colors = [
                    color.withAlphaComponent(0.5).cgColor,  // Top: lighter
                    color.withAlphaComponent(1.0).cgColor   // Bottom: full opacity
                ]
            }
        }
    }
    
    /// Update track progress for pattern variation (simulation mode)
    func setTrackProgress(_ progress: CGFloat) {
        trackProgress = max(0, min(1, progress))
    }
    
    /// Set external audio level from SystemAudioAnalyzer (real audio mode)
    /// Pass nil to use simulation mode
    func setAudioLevel(_ level: CGFloat?) {
        externalAudioLevel = level
    }
}

// MARK: - SwiftUI Wrapper

/// SwiftUI wrapper for AudioSpectrum (supports real audio or simulation)
struct AudioSpectrumView: NSViewRepresentable {
    let isPlaying: Bool
    var barCount: Int = 5
    var barWidth: CGFloat = 3
    var spacing: CGFloat = 2
    var height: CGFloat = 14
    var color: Color = .white
    var trackProgress: CGFloat = 0.5 // 0.0-1.0 track position for simulation mode
    var audioLevel: CGFloat? = nil   // Real audio level (nil = use simulation)
    
    func makeNSView(context: Context) -> AudioSpectrum {
        let nsColor = NSColor(color)
        let spectrum = AudioSpectrum(barCount: barCount, barWidth: barWidth, spacing: spacing, height: height, color: nsColor)
        spectrum.setPlaying(isPlaying)
        spectrum.setTrackProgress(trackProgress)
        spectrum.setAudioLevel(audioLevel)
        return spectrum
    }
    
    func updateNSView(_ nsView: AudioSpectrum, context: Context) {
        nsView.setPlaying(isPlaying)
        nsView.setColor(NSColor(color))
        nsView.setTrackProgress(trackProgress)
        nsView.setAudioLevel(audioLevel)
    }
}

// MARK: - Color Extraction from Image

extension NSImage {
    /// Extract dominant/average color from image (brightness-enhanced for visibility)
    func dominantColor() -> Color {
        guard let tiffData = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return .white
        }
        
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        
        guard width > 0 && height > 0 else { return .white }
        
        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        var count: CGFloat = 0
        
        // Sample a grid of pixels for efficiency
        let step = max(1, min(width, height) / 10)
        
        for x in stride(from: 0, to: width, by: step) {
            for y in stride(from: 0, to: height, by: step) {
                if let color = bitmap.colorAt(x: x, y: y) {
                    // Convert to RGB color space to safely access components
                    guard let rgbColor = color.usingColorSpace(.deviceRGB) else { continue }
                    
                    let r = rgbColor.redComponent
                    let g = rgbColor.greenComponent
                    let b = rgbColor.blueComponent
                    
                    // Weight by saturation - prefer colorful pixels
                    let maxC = max(r, g, b)
                    let minC = min(r, g, b)
                    let saturation = maxC > 0 ? (maxC - minC) / maxC : 0
                    let weight = 0.3 + saturation * 0.7
                    
                    totalR += r * weight
                    totalG += g * weight
                    totalB += b * weight
                    count += weight
                }
            }
        }
        
        guard count > 0 else { return .white }
        
        var avgR = totalR / count
        var avgG = totalG / count
        var avgB = totalB / count
        
        // Boost brightness for visibility (target ~0.7 brightness)
        let brightness = (avgR + avgG + avgB) / 3
        if brightness < 0.5 {
            let boost = min(2.0, 0.7 / max(brightness, 0.1))
            avgR = min(1.0, avgR * boost)
            avgG = min(1.0, avgG * boost)
            avgB = min(1.0, avgB * boost)
        }
        
        return Color(red: avgR, green: avgG, blue: avgB)
    }
}

#Preview {
    AudioSpectrumView(isPlaying: true, color: .blue)
        .frame(width: 25, height: 20)
        .padding()
        .background(Color.black)
}
