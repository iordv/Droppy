//
//  ElementCaptureCard.swift
//  Droppy
//
//  Element Capture extension card for Settings extensions grid
//

import SwiftUI

struct ElementCaptureCard: View {
    // Use local state to avoid @StateObject + @MainActor deadlock
    @State private var currentShortcut: SavedShortcut?
    @State private var showInfoSheet = false
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon, stats, and badge
            HStack(alignment: .top) {
                // Icon from remote URL (cached to prevent flashing)
                CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/element-capture.jpg")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 22, weight: .medium))
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
                    
                    // Category badge - shows "Installed" if configured
                    Text(currentShortcut != nil ? "Installed" : "Productivity")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(currentShortcut != nil ? .green : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(currentShortcut != nil ? Color.green.opacity(0.15) : Color.white.opacity(0.1))
                        )
                }
            }
            
            // Title & Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Element Capture")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Screenshot any UI element by clicking on it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 8)
            
            // Shortcut status
            HStack {
                if let shortcut = currentShortcut {
                    HStack {
                        Text("Shortcut")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(shortcut.description)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
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
        .extensionCardStyle(accentColor: .blue)
        .contentShape(Rectangle())
        .onTapGesture {
            showInfoSheet = true
        }
        .onAppear {
            // Load shortcut from UserDefaults (safe, no MainActor issues)
            loadShortcut()
        }
        .sheet(isPresented: $showInfoSheet) {
            ElementCaptureInfoView(currentShortcut: $currentShortcut, installCount: installCount, rating: rating)
        }
    }
    
    private func loadShortcut() {
        if let data = UserDefaults.standard.data(forKey: "elementCaptureShortcut"),
           let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
            currentShortcut = decoded
        }
    }
}
