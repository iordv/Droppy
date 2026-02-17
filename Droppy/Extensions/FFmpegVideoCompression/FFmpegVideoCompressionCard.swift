//
//  FFmpegVideoCompressionCard.swift
//  Droppy
//
//  FFmpeg Video Compression extension card for Settings extensions grid
//

import SwiftUI

struct FFmpegVideoCompressionCard: View {
    @State private var showInfoSheet = false
    @ObservedObject private var manager = FFmpegInstallManager.shared
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon, stats, and badge
            HStack(alignment: .top) {
                // Extension icon from remote URL (cached)
                CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/icons/targeted-video-size.jpg")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "film")
                        .font(.system(size: 24))
                        .foregroundStyle(.green)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ms, style: .continuous))
                
                Spacer()
                
                // Stats row: installs + rating + badge
                HStack(spacing: 8) {
                    // Installs
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                        Text(AnalyticsService.shared.isDisabled ? "–" : "\(installCount ?? 0)")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                    
                    // Rating
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                        if let r = rating, r.ratingCount > 0 {
                            Text(String(format: "%.1f", r.averageRating))
                                .font(.caption2.weight(.medium))
                        } else {
                            Text("–")
                                .font(.caption2.weight(.medium))
                        }
                    }
                    .foregroundStyle(.secondary)
                    
                    // Category badge
                    Text(manager.isInstalled ? "Installed" : "Media")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(manager.isInstalled ? .green : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(manager.isInstalled ? Color.green.opacity(0.15) : AdaptiveColors.subtleBorderAuto)
                        )
                }
            }
            
            // Title & Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Video Target Size")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Compress videos to exact file sizes using FFmpeg.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 8)
            
            // Status row based on install state
            HStack {
                if manager.isInstalled {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Installed")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.green)
                    }
                } else if manager.isInstalling {
                    Text("Installing…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Requires Homebrew")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
        }
        .frame(minHeight: 160)
        .extensionCardStyle(accentColor: Color(red: 0.0, green: 0.5, blue: 0.25))
        .contentShape(Rectangle())
        .onTapGesture {
            showInfoSheet = true
        }
        .sheet(isPresented: $showInfoSheet) {
            FFmpegInstallView(installCount: installCount, rating: rating)
        }
    }
}
