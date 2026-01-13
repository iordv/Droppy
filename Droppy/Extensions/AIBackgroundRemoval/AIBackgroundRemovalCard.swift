//
//  AIBackgroundRemovalCard.swift
//  Droppy
//
//  AI Background Removal extension card for Settings extensions grid
//

import SwiftUI

struct AIBackgroundRemovalCard: View {
    @State private var showInfoSheet = false
    private var isInstalled: Bool { AIInstallManager.shared.isInstalled }
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon, stats, and badge
            HStack(alignment: .top) {
                // AI extension icon from remote URL
                AsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/ai-bg.jpg")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 24))
                            .foregroundStyle(.blue)
                    default:
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(white: 0.2))
                    }
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
                    
                    // Category badge - shows "Installed" if model is installed
                    Text(isInstalled ? "Installed" : "AI")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isInstalled ? .green : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isInstalled ? Color.green.opacity(0.15) : Color.white.opacity(0.1))
                        )
                }
            }
            
            // Title & Description
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Background Removal")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Remove image backgrounds instantly with local AI.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 8)
            
            // Status row based on install state
            HStack {
                let manager = AIInstallManager.shared
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
                    Text("Installing...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("One-click install")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
        }
        .frame(minHeight: 160)
        .extensionCardStyle(accentColor: .pink)
        .contentShape(Rectangle())
        .onTapGesture {
            showInfoSheet = true
        }
        .sheet(isPresented: $showInfoSheet) {
            AIInstallView(installCount: installCount, rating: rating)
        }
    }
}
