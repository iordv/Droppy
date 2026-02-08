//
//  LockScreenMediaPanelView.swift
//  Droppy
//
//  Created by Droppy on 26/01/2026.
//  SwiftUI view for the lock screen media widget
//  Displays album art, track info, progress bar, visualizer and playback controls
//

import SwiftUI

/// Lock screen media panel - iPhone-inspired design
/// Displays on the macOS lock screen via SkyLight.framework
struct LockScreenMediaPanelView: View {
    @EnvironmentObject var musicManager: MusicManager
    @ObservedObject var animator: LockScreenMediaPanelAnimator
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    
    // MARK: - Layout Constants (pixel-perfect, synced with Manager)
    private let panelWidth: CGFloat = 380
    private let panelHeight: CGFloat = 160
    private let cornerRadius: CGFloat = 24
    private let edgePadding: CGFloat = 16
    private let albumArtSize: CGFloat = 56
    private let albumArtRadius: CGFloat = 10
    
    // MARK: - Body
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: musicManager.isPlaying ? 0.5 : 60)) { context in
            let estimatedTime = musicManager.estimatedPlaybackPosition(at: context.date)
            let progress: Double = musicManager.songDuration > 0 
                ? min(1, max(0, estimatedTime / musicManager.songDuration)) 
                : 0
            
            VStack(spacing: 14) {
                // Row 1: Album Art + Track Info + Visualizer
                HStack(alignment: .center, spacing: 0) {
                    // Album art
                    albumArtView
                        .padding(.trailing, 12)
                    
                    // Track info (title + artist)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(musicManager.songTitle.isEmpty ? "Not Playing" : musicManager.songTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(musicManager.artistName.isEmpty ? "Unknown Artist" : musicManager.artistName)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Visualizer (5 bars) - at exact right edge
                    AudioSpectrumView(
                        isPlaying: musicManager.isPlaying,
                        barCount: 5,
                        barWidth: 3,
                        spacing: 2,
                        height: 20,
                        color: musicManager.visualizerColor
                    )
                    .frame(width: 23, height: 20) // Explicit frame for visualizer (5*3 + 4*2 = 23)
                }
                // CRITICAL: Explicitly set frame width to ensure Spacer() works
                // width = panelWidth (380) - padding (16*2=32) = 348
                .frame(width: panelWidth - (edgePadding * 2), height: albumArtSize)
                
                // Row 2: Progress bar with timestamps
                HStack(spacing: 8) {
                    Text(formatTime(estimatedTime))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 32, alignment: .leading)
                    
                    // Progress track
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Background track
                            Capsule()
                                .fill(AdaptiveColors.overlayAuto(0.2))
                            
                            // Progress fill
                            Capsule()
                                .fill(AdaptiveColors.overlayAuto(0.9))
                                .frame(width: max(0, geo.size.width * progress))
                        }
                    }
                    .frame(height: 4)
                    
                    Text(formatTime(musicManager.songDuration))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 32, alignment: .trailing)
                }
                
                // Row 3: Media controls (centered)
                HStack(spacing: 40) {
                    // Previous
                    Button {
                        musicManager.previousTrack()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    // Play/Pause
                    Button {
                        musicManager.togglePlay()
                    } label: {
                        Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    // Next
                    Button {
                        musicManager.nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(edgePadding)
            .frame(width: panelWidth, height: panelHeight)
            .background(panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(useTransparentBackground ? 0.2 : 0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 30, x: 0, y: 15)
            // Entry/exit animations - FAST
            .scaleEffect(animator.isPresented ? 1 : 0.9, anchor: .center)
            .opacity(animator.isPresented ? 1 : 0)
            .animation(DroppyAnimation.hoverQuick, value: animator.isPresented)
        }
    }
    
    // MARK: - Panel Background
    
    @ViewBuilder
    private var panelBackground: some View {
        if useTransparentBackground {
            // Glass effect
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                AdaptiveColors.overlayAuto(0.03)
            }
        } else {
            // Dark solid
            Color.black.opacity(0.85)
        }
    }
    
    // MARK: - Album Art
    
    @ViewBuilder
    private var albumArtView: some View {
        if musicManager.albumArt.size.width > 0 {
            Image(nsImage: musicManager.albumArt)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: albumArtSize, height: albumArtSize)
                .clipShape(RoundedRectangle(cornerRadius: albumArtRadius, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: albumArtRadius, style: .continuous)
                .fill(AdaptiveColors.overlayAuto(0.1))
                .frame(width: albumArtSize, height: albumArtSize)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                )
        }
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Visual Effect View

private struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.blue.opacity(0.6)
        LockScreenMediaPanelView(animator: LockScreenMediaPanelAnimator())
            .environmentObject(MusicManager.shared)
    }
    .frame(width: 500, height: 300)
}
