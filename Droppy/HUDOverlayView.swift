//
//  HUDOverlayView.swift
//  Droppy
//
//  Created by Droppy on 05/01/2026.
//  System HUD replacement that expands inside the notch
//

import SwiftUI

// HUDContentType is defined in LiquidSlider.swift

/// Embedded HUD view that appears inside the expanded notch
/// Icon on left wing, percentage on right wing, slider at bottom (full width)
/// Layout matches MediaHUDView for consistent positioning
struct NotchHUDView: View {
    @Binding var hudType: HUDContentType
    @Binding var value: CGFloat
    var isActive: Bool = true // Whether value is currently changing (for slider thickening)
    let notchWidth: CGFloat   // Physical notch width (passed from parent)
    let notchHeight: CGFloat  // Physical notch height (passed from parent)
    let hudWidth: CGFloat     // Total HUD width (passed from parent)
    var onValueChange: ((CGFloat) -> Void)?
    
    /// Width of each "wing" (area left/right of physical notch)
    private var wingWidth: CGFloat {
        (hudWidth - notchWidth) / 2
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Main HUD: Two wings separated by the notch space
            // Same layout pattern as MediaHUDView
            HStack(spacing: 0) {
                // Left wing: Icon centered
                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: hudType.icon(for: value))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(hudType == .brightness ? .yellow : .white)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolVariant(.fill)
                        .frame(width: 26, height: 26)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hudType.icon(for: value))
                    Spacer(minLength: 0)
                }
                .frame(width: wingWidth)
                
                // Camera notch area (spacer)
                Spacer()
                    .frame(width: notchWidth)
                
                // Right wing: Percentage centered
                HStack {
                    Spacer(minLength: 0)
                    Text("\(Int(value * 100))%")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: value))
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: value)
                    Spacer(minLength: 0)
                }
                .frame(width: wingWidth)
            }
            .frame(height: notchHeight) // Match physical notch for proper vertical centering
            
            // Below notch: Slider (same style as seek slider in expanded media player)
            HUDSlider(
                value: $value,
                accentColor: hudType == .brightness ? .yellow : .white,
                isActive: isActive,
                onChange: onValueChange
            )
            .frame(height: 20)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            .animation(.spring(response: 0.15, dampingFraction: 0.8), value: value)
        }
    }
}

// MARK: - HUD Slider (matches seek slider in expanded media player)

/// Interactive slider matching MediaPlayerView's seek slider style
/// Simple solid colors, 4px→6px height when active, subtle glow
struct HUDSlider: View {
    @Binding var value: CGFloat
    var accentColor: Color = .white
    var isActive: Bool = false
    var onChange: ((CGFloat) -> Void)?
    
    @State private var isDragging = false
    
    /// Whether slider should be expanded (dragging OR externally active)
    private var isExpanded: Bool { isDragging || isActive }
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let progress = max(0, min(1, value))
            let progressWidth = max(0, min(width, width * progress))
            // Expand track height when active/dragging
            let trackHeight: CGFloat = isExpanded ? 6 : 4
            
            ZStack(alignment: .leading) {
                // Track background (dark gray, matches seek slider)
                Capsule()
                    .fill(accentColor.opacity(isExpanded ? 0.3 : 0.2))
                    .frame(height: trackHeight)
                
                // Filled portion (solid color with glow when active)
                if progress > 0 {
                    Capsule()
                        .fill(accentColor)
                        .frame(width: max(trackHeight, progressWidth), height: trackHeight)
                        .shadow(color: isExpanded ? accentColor.opacity(0.4) : .clear, radius: isExpanded ? 4 : 0)
                }
            }
            .frame(height: trackHeight)
            .frame(maxHeight: .infinity, alignment: .center)
            .scaleEffect(y: isExpanded ? 1.1 : 1.0, anchor: .center)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isExpanded)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isDragging = true
                        }
                        let fraction = max(0, min(1, gesture.location.x / width))
                        value = fraction
                        onChange?(fraction)
                    }
                    .onEnded { gesture in
                        let fraction = max(0, min(1, gesture.location.x / width))
                        value = fraction
                        onChange?(fraction)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            isDragging = false
                        }
                    }
            )
        }
        .frame(height: 20)
    }
}

// MARK: - Media Player HUD

/// Compact media HUD that sits inside the notch
/// Album art and visualizer are centered within each wing, with consistent padding
struct MediaHUDView: View {
    @ObservedObject var musicManager: MusicManager
    @Binding var isHovered: Bool
    let notchWidth: CGFloat  // Physical notch width
    let notchHeight: CGFloat // Physical notch height (for vertical centering)
    let hudWidth: CGFloat    // Total HUD width
    
    /// Combined song info for marquee
    private var songInfo: String {
        if musicManager.songTitle.isEmpty {
            return "Not Playing"
        }
        return "\(musicManager.songTitle) - \(musicManager.artistName)"
    }
    
    /// Dominant color extracted from album art for visualizer
    private var visualizerColor: Color {
        if musicManager.albumArt.size.width > 0 {
            return musicManager.albumArt.dominantColor()
        }
        return .white.opacity(0.7)
    }
    
    /// Width of each "wing" (area left/right of physical notch)
    private var wingWidth: CGFloat {
        (hudWidth - notchWidth) / 2
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Main HUD: Two wings separated by the notch space
            HStack(spacing: 0) {
                // Left wing: Album art centered
                HStack {
                    Spacer(minLength: 0)
                    Group {
                        if musicManager.albumArt.size.width > 0 {
                            Image(nsImage: musicManager.albumArt)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.2))
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.5))
                                )
                        }
                    }
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    Spacer(minLength: 0)
                }
                .frame(width: wingWidth)
                
                // Camera notch area (spacer)
                Spacer()
                    .frame(width: notchWidth)
                
                // Right wing: Visualizer centered
                HStack {
                    Spacer(minLength: 0)
                    MiniAudioVisualizerBars(isPlaying: musicManager.isPlaying, color: visualizerColor)
                    Spacer(minLength: 0)
                }
                .frame(width: wingWidth)
            }
            .frame(height: notchHeight) // Match physical notch for proper vertical centering
            
            // Hover: Scrolling song info (appears below album art / visualizer row)
            if isHovered {
                MarqueeText(text: songInfo, speed: 40)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(height: 20)
                    .padding(.vertical, 4) // Equal spacing above and below title
                    .padding(.horizontal, 8)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isHovered)
        .allowsHitTesting(true)
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                DroppyState.shared.isExpanded = true
            }
        }
    }
}

/// Mini audio visualizer bars for compact HUD
/// Uses BoringNotch-style CAShapeLayer animation with album art color
struct MiniAudioVisualizerBars: View {
    let isPlaying: Bool
    var color: Color = .white
    
    var body: some View {
        AudioSpectrumView(isPlaying: isPlaying, barCount: 5, barWidth: 3, spacing: 2, height: 18, color: color)
            .frame(width: 5 * 3 + 4 * 2, height: 18) // 5 bars * 3px + 4 gaps * 2px = 23px
    }
}

/// Scrolling marquee text view using TimelineView for efficiency
struct MarqueeText: View {
    let text: String
    let speed: Double // Points per second
    
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var startTime: Date = Date()
    
    private var needsScroll: Bool {
        textWidth > containerWidth && containerWidth > 0
    }
    
    var body: some View {
        GeometryReader { geo in
            // Use native display refresh rate for smooth 120Hz ProMotion scrolling
            TimelineView(.animation(paused: !needsScroll)) { timeline in
                let totalDistance = textWidth + 50
                let elapsed = timeline.date.timeIntervalSince(startTime)
                let rawOffset = elapsed * speed
                let offset = needsScroll ? -CGFloat(rawOffset.truncatingRemainder(dividingBy: Double(totalDistance))) : 0
                
                HStack(spacing: needsScroll ? 50 : 0) {
                    Text(text)
                        .fixedSize()
                        .background(
                            GeometryReader { textGeo in
                                Color.clear.onAppear {
                                    textWidth = textGeo.size.width
                                }
                                .onChange(of: text) { _, _ in
                                    textWidth = textGeo.size.width
                                    startTime = Date() // Reset scroll on text change
                                }
                            }
                        )
                    
                    if needsScroll {
                        Text(text)
                            .fixedSize()
                    }
                }
                .offset(x: offset)
                // Center text when it fits, left-align when scrolling
                .frame(maxWidth: .infinity, alignment: needsScroll ? .leading : .center)
            }
            .onAppear {
                containerWidth = geo.size.width
                startTime = Date()
            }
            .onChange(of: geo.size.width) { _, newWidth in
                containerWidth = newWidth
            }
        }
        .clipped()
    }
}

/// Progress slider that matches LiquidSlider aesthetics (non-interactive)
struct ProgressSlider: View {
    var progress: CGFloat
    var accentColor: Color
    
    private let height: CGFloat = 6
    
    /// Safe progress value - guards against NaN and infinity
    private var safeProgress: CGFloat {
        let p = progress
        if p.isNaN || p.isInfinite {
            return 0
        }
        return min(1, max(0, p))
    }
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let filledWidth = safeProgress * width
            
            ZStack(alignment: .leading) {
                // Track background - concave glass well (matches LiquidSlider)
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(Color.white.opacity(0.05))
                    )
                    // Concave lighting: shadow on top, highlight on bottom
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: .black.opacity(0.3), location: 0),
                                        .init(color: .clear, location: 0.3),
                                        .init(color: .white.opacity(0.2), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .frame(height: height)
                
                // Filled portion - gradient with glow (matches LiquidSlider)
                if width > 0 && safeProgress > 0 {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor,
                                    accentColor.opacity(0.6)
                                ],
                                startPoint: .trailing,
                                endPoint: .leading
                            )
                        )
                        .frame(width: max(height, filledWidth), height: height)
                        // Inner glow
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .white.opacity(0.6), location: 0),
                                            .init(color: .clear, location: 0.5)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.5
                                )
                        )
                        // Glow shadow
                        .shadow(
                            color: accentColor.opacity(0.3),
                            radius: 4,
                            x: 2,
                            y: 0
                        )
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: safeProgress)
                }
            }
            .frame(height: height)
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: height)
    }
}

// MARK: - Legacy HUD (kept for reference)

/// HUD overlay view that appears below the notch for volume/brightness control
/// Styled with Liquid Glass aesthetics to match Droppy's design system
struct HUDOverlayView: View {
    @Binding var isVisible: Bool
    @Binding var hudType: HUDContentType
    @Binding var value: CGFloat
    
    var onValueChange: ((CGFloat) -> Void)?
    
    @State private var animatedValue: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon with dynamic symbol
            Image(systemName: hudType.icon(for: value))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.interpolate)
                .symbolVariant(.fill)
                .frame(width: 24, height: 20)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            
            // Slider
            LiquidSlider(
                value: $value,
                accentColor: hudType == .brightness ? .yellow : .white,
                onChange: { newValue in
                    onValueChange?(newValue)
                },
                onDragChange: { newValue in
                    onValueChange?(newValue)
                }
            )
            .frame(width: 160)
            
            // Percentage
            Text("\(Int(value * 100))%")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.gray)
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(hudBackground)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.9)
        .offset(y: isVisible ? 0 : -10)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isVisible)
        .onChange(of: value) { _, newValue in
            withAnimation(.smooth(duration: 0.1)) {
                animatedValue = newValue
            }
        }
    }
    
    private var hudBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.6))
            )
            // Specular rim lighting
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.4), location: 0),
                                .init(color: .white.opacity(0.1), location: 0.3),
                                .init(color: .black.opacity(0.2), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 15, y: 8)
    }
}

// MARK: - HUD State Manager

/// Manages the HUD overlay state and auto-hide timing
@Observable
class HUDStateManager {
    static let shared = HUDStateManager()
    
    var isVisible: Bool = false
    var hudType: HUDContentType = .volume
    var value: CGFloat = 0
    
    private var hideTask: Task<Void, Never>?
    private let visibleDuration: TimeInterval = 1.5
    
    private init() {}
    
    /// Show the HUD with the given type and value
    func show(type: HUDContentType, value: CGFloat) {
        hideTask?.cancel()
        
        self.hudType = type
        self.value = value
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            self.isVisible = true
        }
        
        // Schedule auto-hide
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(visibleDuration))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.isVisible = false
            }
        }
    }
    
    /// Hide the HUD immediately
    func hide() {
        hideTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isVisible = false
        }
    }
    
    /// Update value while HUD is visible (resets auto-hide timer)
    func updateValue(_ newValue: CGFloat) {
        value = newValue
        // Reset auto-hide timer
        show(type: hudType, value: newValue)
    }
}

// MARK: - Preview

#Preview("Notch HUD") {
    ZStack {
        Color.gray.opacity(0.3)
        
        VStack {
            // Simulate notch background
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black)
                .frame(width: 280, height: 90)
                .overlay {
                    NotchHUDView(
                        hudType: .constant(.volume),
                        value: .constant(0.65),
                        notchWidth: 180,
                        notchHeight: 37,
                        hudWidth: 280
                    )
                }
            
            Spacer().frame(height: 40)
            
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black)
                .frame(width: 280, height: 90)
                .overlay {
                    NotchHUDView(
                        hudType: .constant(.brightness),
                        value: .constant(0.4),
                        notchWidth: 180,
                        notchHeight: 37,
                        hudWidth: 280
                    )
                }
        }
    }
    .frame(width: 400, height: 300)
}
