//
//  WindowSnapCard.swift
//  Droppy
//
//  Window Snap extension card for Settings extensions grid
//

import SwiftUI

struct WindowSnapCard: View {
    @State private var hasShortcuts = false
    @State private var showInfoSheet = false
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon, stats, and badge
            HStack(alignment: .top) {
                // Icon from remote URL (cached to prevent flashing)
                CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/icons/window-snap.jpg")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "rectangle.split.2x2")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.cyan)
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
                    
                    // Category badge - shows "Installed" if configured
                    Text(hasShortcuts ? "Installed" : "Productivity")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(hasShortcuts ? .green : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(hasShortcuts ? Color.green.opacity(0.15) : AdaptiveColors.subtleBorderAuto)
                        )
                }
            }
            
            // Title & Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Window Snap")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Snap windows to halves, quarters, and thirds with keyboard shortcuts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 8)
            
            // Status row
            HStack {
                if hasShortcuts {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Configured")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("Not configured")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
        }
        .frame(minHeight: 160)
        .extensionCardStyle(accentColor: .cyan)
        .contentShape(Rectangle())
        .onTapGesture {
            showInfoSheet = true
        }
        .onAppear {
            loadShortcuts()
        }
        .sheet(isPresented: $showInfoSheet) {
            WindowSnapInfoView(installCount: installCount, rating: rating)
        }
    }
    
    private func loadShortcuts() {
        // Check if any shortcuts are configured
        if let data = UserDefaults.standard.data(forKey: "windowSnapShortcuts"),
           let decoded = try? JSONDecoder().decode([String: SavedShortcut].self, from: data),
           !decoded.isEmpty {
            hasShortcuts = true
        }
    }
}
