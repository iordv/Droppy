//
//  MediaPlayerView.swift
//  Droppy
//
//  Created by Droppy on 05/01/2026.
//  Native macOS-style media player for the expanded notch
//

import SwiftUI

/// Full media player view for the expanded notch
/// Native macOS design with album art, visualizer, and control buttons
struct MediaPlayerView: View {
    @ObservedObject var musicManager: MusicManager
    @State private var isDragging: Bool = false
    @State private var dragValue: Double = 0
    @State private var lastDragTime: Date = .distantPast
    @State private var isAlbumArtPressed: Bool = false
    @State private var isAlbumArtHovering: Bool = false
    
    /// Dominant color from album art for visualizer
    private var visualizerColor: Color {
        if musicManager.albumArt.size.width > 0 {
            return musicManager.albumArt.dominantColor()
        }
        return .white.opacity(0.7)
    }
    
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
                // MARK: - Top Row: Album Art + Song Info + Visualizer
                HStack(spacing: 14) {
                    // Album Art
                    albumArtView
                    
                    // Song info (title + artist)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(musicManager.songTitle.isEmpty ? "Not Playing" : musicManager.songTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        Text(musicManager.artistName.isEmpty ? "—" : musicManager.artistName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Audio Visualizer (right side, colored by album art)
                    AudioVisualizerBars(isPlaying: musicManager.isPlaying, color: visualizerColor)
                        .frame(width: 32, height: 20)
                }
                
                // MARK: - Middle Row: Time + Slider
                HStack(spacing: 12) {
                    // Current time
                    Text(elapsedTimeString(at: currentDate))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                    
                    // Progress Slider
                    progressSliderView(at: currentDate)
                    
                    // Total time
                    Text(remainingTimeString())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .monospacedDigit()
                        .frame(width: 40, alignment: .leading)
                }
                
                // MARK: - Bottom Row: Controls
                controlsRow
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
    }
    
    // MARK: - Album Art
    
    private var albumArtView: some View {
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
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            // Subtle border highlight
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .scaleEffect(isAlbumArtPressed ? 0.95 : (isAlbumArtHovering ? 1.02 : 1.0))
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isAlbumArtPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAlbumArtHovering)
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
    
    // MARK: - Progress Slider
    
    private func progressSliderView(at date: Date) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let currentProgress = progress(at: date)
            let progressWidth = max(0, min(width, width * currentProgress))
            // Expand track height when dragging
            let trackHeight: CGFloat = isDragging ? 6 : 4
            
            ZStack(alignment: .leading) {
                // Track background (dark gray)
                Capsule()
                    .fill(Color.white.opacity(isDragging ? 0.3 : 0.2))
                    .frame(height: trackHeight)
                
                // Filled portion (white with glow when dragging)
                if currentProgress > 0 {
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(trackHeight, progressWidth), height: trackHeight)
                        .shadow(color: isDragging ? .white.opacity(0.4) : .clear, radius: isDragging ? 4 : 0)
                }
            }
            .frame(height: trackHeight)
            .frame(maxHeight: .infinity, alignment: .center)
            .scaleEffect(y: isDragging ? 1.1 : 1.0, anchor: .center)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isDragging = true
                        }
                        let fraction = max(0, min(1, value.location.x / width))
                        dragValue = Double(fraction) * musicManager.songDuration
                    }
                    .onEnded { value in
                        let fraction = max(0, min(1, value.location.x / width))
                        let seekTime = Double(fraction) * musicManager.songDuration
                        musicManager.seek(to: seekTime)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            isDragging = false
                        }
                        lastDragTime = Date()
                    }
            )
        }
        .frame(height: 20)
    }
    
    // MARK: - Controls Row
    
    private var controlsRow: some View {
        HStack(spacing: 32) {
            // Previous
            MediaControlButton(icon: "backward.fill", size: 24) {
                musicManager.previousTrack()
            }
            
            // Play/Pause (larger)
            MediaControlButton(
                icon: musicManager.isPlaying ? "pause.fill" : "play.fill",
                size: 32
            ) {
                musicManager.togglePlay()
            }
            
            // Next
            MediaControlButton(icon: "forward.fill", size: 24) {
                musicManager.nextTrack()
            }
        }
        .allowsHitTesting(true)
    }
}

// MARK: - Audio Visualizer Bars

/// Animated audio visualizer bars (BoringNotch-style CAShapeLayer animation)
struct AudioVisualizerBars: View {
    let isPlaying: Bool
    var color: Color = .white
    
    var body: some View {
        AudioSpectrumView(isPlaying: isPlaying, barCount: 5, barWidth: 3, spacing: 2, height: 20, color: color)
            .frame(width: 5 * 3 + 4 * 2, height: 20) // 5 bars * 3px + 4 gaps * 2px
    }
}

// MARK: - Media Control Button (plain, no background)

/// Simple media control button without background (for rewind/play/forward)
struct MediaControlButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size + 16, height: size + 16)
                .scaleEffect(isHovering ? 1.05 : 1.0)
                .contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace)) // Smooth icon morph
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
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
            .frame(width: 350, height: 200)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
