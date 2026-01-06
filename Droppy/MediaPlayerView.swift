//
//  MediaPlayerView.swift
//  Droppy
//
//  Created by Droppy on 05/01/2026.
//  Liquid Glass styled media player for the expanded notch
//

import SwiftUI

/// Full media player view for the expanded notch
/// Features album art with blur background, playback controls, and progress slider
struct MediaPlayerView: View {
    @ObservedObject var musicManager: MusicManager
    @State private var isDragging: Bool = false
    @State private var dragValue: Double = 0
    @State private var lastDragTime: Date = .distantPast
    @State private var isAlbumArtPressed: Bool = false
    @State private var isAlbumArtHovering: Bool = false
    
    /// Compute estimated position at given date
    private func estimatedPosition(at date: Date) -> Double {
        musicManager.estimatedPlaybackPosition(at: date)
    }
    
    /// Progress as fraction (0.0 - 1.0)
    private func progress(at date: Date) -> CGFloat {
        guard musicManager.songDuration > 0 else { return 0 }
        let pos = isDragging ? dragValue : estimatedPosition(at: date)
        return CGFloat(min(1, max(0, pos / musicManager.songDuration)))
    }
    
    /// Formatted elapsed time (mm:ss)
    private func elapsedTimeString(at date: Date) -> String {
        let seconds = isDragging ? dragValue : estimatedPosition(at: date)
        return timeString(from: seconds)
    }
    
    /// Formatted remaining/total time
    private func remainingTimeString() -> String {
        return timeString(from: musicManager.songDuration)
    }
    
    private func timeString(from seconds: Double) -> String {
        let totalSeconds = Int(max(0, seconds))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !musicManager.isPlaying && !isDragging)) { context in
            let currentDate = context.date
            
            VStack(spacing: 16) {
                // Top: Song Info + Album Art
                HStack(spacing: 16) {
                    // Album Art with lighting effect
                    albumArtView
                    
                    // Song info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(musicManager.songTitle.isEmpty ? "Not Playing" : musicManager.songTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        Text(musicManager.artistName.isEmpty ? "—" : musicManager.artistName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.6))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Progress Row: [Current Time] [Slider] [Total Time]
                HStack(spacing: 12) {
                    // Current time
                    Text(elapsedTimeString(at: currentDate))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .frame(width: 50, alignment: .leading)
                    
                    // Slider
                    progressSliderView(at: currentDate)
                    
                    // Total time
                    Text(remainingTimeString())
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                }
            }
            .padding(24) // Equal padding all around
            .padding(.top, 4) // Extra top for header icons
        }
    }
    
    // MARK: - Album Art
    
    private var albumArtView: some View {
        ZStack {
            // Blur background glow
            if musicManager.albumArt.size.width > 0 {
                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .scaleEffect(1.5)
                    .blur(radius: 30)
                    .opacity(musicManager.isPlaying ? 0.5 : 0.2)
                    .animation(.easeInOut(duration: 0.3), value: musicManager.isPlaying)
            }
            
            // Main album art
            Button {
                musicManager.openMusicApp()
            } label: {
                Group {
                    if musicManager.albumArt.size.width > 0 {
                        Image(nsImage: musicManager.albumArt)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white.opacity(0.4))
                            )
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                // Liquid Glass border
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(isAlbumArtHovering ? 0.8 : 0.5), location: 0),
                                    .init(color: .clear, location: 0.4),
                                    .init(color: .black.opacity(0.2), location: 1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isAlbumArtHovering ? 1.5 : 1
                        )
                )
                .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
                // Glow on hover
                .shadow(color: Color(nsColor: musicManager.avgColor).opacity(isAlbumArtHovering ? 0.6 : 0), radius: 15, y: 0)
            }
            .buttonStyle(.plain)
            .scaleEffect(isAlbumArtPressed ? 0.92 : (isAlbumArtHovering ? 1.03 : (musicManager.isPlaying ? 1 : 0.95)))
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isAlbumArtPressed)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isAlbumArtHovering)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: musicManager.isPlaying)
            .onHover { hovering in
                isAlbumArtHovering = hovering
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        isAlbumArtPressed = true
                    }
                    .onEnded { _ in
                        isAlbumArtPressed = false
                    }
            )
        }
        .frame(width: 80, height: 80)
    }
    
    // MARK: - Progress Slider
    
    private func progressSliderView(at date: Date) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let currentProgress = progress(at: date)
            let progressWidth = max(0, min(width, width * currentProgress))
            let height: CGFloat = isDragging ? 10 : 6
            let accentColor = Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.6)
            
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
                if currentProgress > 0 {
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
                        .frame(width: max(height, progressWidth), height: height)
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
                            color: accentColor.opacity(isDragging ? 0.5 : 0.3),
                            radius: isDragging ? 8 : 4,
                            x: 2,
                            y: 0
                        )
                }
                
                // Knob (only during drag)
                if isDragging {
                    Circle()
                        .fill(.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .offset(x: progressWidth - 7)
                }
            }
            .frame(height: height)
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let fraction = max(0, min(1, value.location.x / width))
                        dragValue = Double(fraction) * musicManager.songDuration
                    }
                    .onEnded { value in
                        let fraction = max(0, min(1, value.location.x / width))
                        let seekTime = Double(fraction) * musicManager.songDuration
                        musicManager.seek(to: seekTime)
                        isDragging = false
                        lastDragTime = Date()
                    }
            )
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDragging)
        }
        .frame(height: 14)
    }
    
    // MARK: - Controls Row
    
    private var controlsRow: some View {
        HStack(spacing: 24) {
            Spacer()
            
            // Previous
            SquarcleMediaButton(icon: "backward.fill", size: 32) {
                musicManager.previousTrack()
            }
            
            // Play/Pause (larger)
            SquarcleMediaButton(
                icon: musicManager.isPlaying ? "pause.fill" : "play.fill",
                size: 44,
                isPrimary: true
            ) {
                musicManager.togglePlay()
            }
            
            // Next
            SquarcleMediaButton(icon: "forward.fill", size: 32) {
                musicManager.nextTrack()
            }
            
            Spacer()
        }
    }
}

// MARK: - Squarcle Media Button

/// Media control button with squarcle (rounded square) Liquid Glass design
struct SquarcleMediaButton: View {
    let icon: String
    let size: CGFloat
    var isPrimary: Bool = false
    var action: () -> Void
    
    @State private var isHovering = false
    @State private var isPressed = false
    
    private var iconSize: CGFloat {
        isPrimary ? size * 0.4 : size * 0.45
    }
    
    private var cornerRadius: CGFloat {
        size * 0.28  // Squarcle proportion
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(isPrimary ? 1 : (isHovering ? 1 : 0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(isHovering ? 0.6 : 0.3), location: 0),
                                    .init(color: .white.opacity(0.1), location: 0.4),
                                    .init(color: .black.opacity(0.1), location: 1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: .black.opacity(isPrimary ? 0.3 : 0.2),
                    radius: isPrimary ? 8 : 4,
                    y: isPrimary ? 4 : 2
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.interactiveSpring(response: 0.15)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Color Extension

extension Color {
    /// Ensure minimum brightness for legibility on dark backgrounds
    func ensureMinimumBrightness(factor: CGFloat) -> Color {
        guard let nsColor = NSColor(self).usingColorSpace(.deviceRGB) else {
            return self
        }
        
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        nsColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
        let newBrightness = max(b, factor)
        return Color(hue: h, saturation: s, brightness: newBrightness, opacity: a)
    }
}

// MARK: - Compact Media Player (for closed notch hints)

struct CompactMediaPlayerView: View {
    @ObservedObject var musicManager = MusicManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            // Mini album art
            Image(nsImage: musicManager.albumArt)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // Playing indicator bars
            if musicManager.isPlaying {
                MusicVisualizerBars()
                    .frame(width: 16, height: 16)
            }
        }
    }
}

/// Animated music bars for playing indicator
struct MusicVisualizerBars: View {
    @State private var heights: [CGFloat] = [0.3, 0.6, 0.4]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white)
                    .frame(width: 3, height: 16 * heights[index])
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
            heights = [0.6, 1.0, 0.5]
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) {
                heights[1] = 0.4
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                heights[2] = 0.9
            }
        }
    }
}

// MARK: - Preview

#Preview("Media Player") {
    VStack {
        MediaPlayerView(musicManager: MusicManager.shared)
            .frame(width: 350, height: 180)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
