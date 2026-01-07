//
//  AudioSpectrumView.swift
//  Droppy
//
//  Audio visualizer matching BoringNotch's implementation
//  Uses CAShapeLayer with random scale animations
//  Supports dynamic color from album art
//

import AppKit
import SwiftUI

// MARK: - AudioSpectrum NSView (BoringNotch style)

/// Native audio spectrum visualizer using CAShapeLayer animations
/// Matches BoringNotch's implementation for reliable, smooth animation
class AudioSpectrum: NSView {
    private var barLayers: [CAShapeLayer] = []
    private var barScales: [CGFloat] = []
    private var isPlaying: Bool = false
    private var animationTimer: Timer?
    private var currentColor: NSColor = .white
    
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
            barLayer.fillColor = currentColor.cgColor
            barLayer.backgroundColor = currentColor.cgColor
            barLayer.allowsGroupOpacity = false
            barLayer.masksToBounds = true
            
            let path = NSBezierPath(roundedRect: CGRect(x: 0, y: 0, width: barWidth, height: totalHeight),
                                    xRadius: barWidth / 2,
                                    yRadius: barWidth / 2)
            barLayer.path = path.cgPath
            
            barLayers.append(barLayer)
            barScales.append(0.35)
            layer?.addSublayer(barLayer)
        }
    }
    
    private func startAnimating() {
        guard animationTimer == nil else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
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
    
    private func updateBars() {
        for (i, barLayer) in barLayers.enumerated() {
            let currentScale = barScales[i]
            let targetScale = CGFloat.random(in: 0.35...1.0)
            barScales[i] = targetScale
            
            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = currentScale
            animation.toValue = targetScale
            animation.duration = 0.3
            animation.autoreverses = true
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            
            if #available(macOS 13.0, *) {
                animation.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 24, preferred: 24)
            }
            
            barLayer.add(animation, forKey: "scaleY")
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
            barLayer.fillColor = color.cgColor
            barLayer.backgroundColor = color.cgColor
        }
    }
}

// MARK: - SwiftUI Wrapper

/// SwiftUI wrapper for AudioSpectrum (BoringNotch-style visualizer)
struct AudioSpectrumView: NSViewRepresentable {
    let isPlaying: Bool
    var barCount: Int = 5
    var barWidth: CGFloat = 3
    var spacing: CGFloat = 2
    var height: CGFloat = 14
    var color: Color = .white
    
    func makeNSView(context: Context) -> AudioSpectrum {
        let nsColor = NSColor(color)
        let spectrum = AudioSpectrum(barCount: barCount, barWidth: barWidth, spacing: spacing, height: height, color: nsColor)
        spectrum.setPlaying(isPlaying)
        return spectrum
    }
    
    func updateNSView(_ nsView: AudioSpectrum, context: Context) {
        nsView.setPlaying(isPlaying)
        nsView.setColor(NSColor(color))
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
                    let r = color.redComponent
                    let g = color.greenComponent
                    let b = color.blueComponent
                    
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
