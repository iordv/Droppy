//
//  SpotifyCard.swift
//  Droppy
//
//  Spotify extension card for Settings extensions grid
//

import SwiftUI

struct SpotifyExtensionCard: View {
    @State private var showInfoSheet = false
    // Uses tracking key set when Spotify is first used (not OAuth which is optional)
    private var isInstalled: Bool { UserDefaults.standard.bool(forKey: "spotifyTracked") }
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon, stats, and badge
            HStack(alignment: .top) {
                // Official Spotify icon from remote URL (cached to prevent flashing)
                CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/icons/spotify.png")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 24))
                        .foregroundStyle(.blue)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                Spacer()
                
                // Stats row: installs + rating + badge
                HStack(spacing: 8) {
                    // Installs (always visible)
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                        Text("\(installCount ?? 0)")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                    
                    // Rating (always visible)
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
                    
                    // Category badge - shows "Installed" if authenticated
                    Text(isInstalled ? "Installed" : "Media")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isInstalled ? .green : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isInstalled ? Color.green.opacity(0.15) : AdaptiveColors.subtleBorderAuto)
                        )
                }
            }
            
            // Title & Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Spotify Integration")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Extra shuffle, repeat & replay controls in the media player.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 8)
            
            // Status row - Running indicator
            HStack {
                Circle()
                    .fill(SpotifyController.shared.isSpotifyRunning ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 6, height: 6)
                Text(SpotifyController.shared.isSpotifyRunning ? "Running" : "Not running")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(SpotifyController.shared.isSpotifyRunning ? .primary : .secondary)
                Spacer()
            }
        }
        .frame(minHeight: 160)
        .extensionCardStyle(accentColor: Color(red: 0.12, green: 0.84, blue: 0.38))
        .contentShape(Rectangle())
        .onTapGesture {
            showInfoSheet = true
        }
        .sheet(isPresented: $showInfoSheet) {
            ExtensionInfoView(extensionType: .spotify, installCount: installCount, rating: rating)
        }
    }
}
