//
//  UpdateHUDView.swift
//  Droppy
//
//  Created by Droppy on 27/01/2026.
//  Update Available HUD - shows icon + "Update" on left, "Droppy [version]" on right
//

import SwiftUI

/// Update HUD that sits inside the notch
/// Layout: Icon + "Update" on left wing, "Droppy [version]" on right wing
/// Display-only notification - user can update through Settings
struct UpdateHUDView: View {
    let hudWidth: CGFloat     // Total HUD width
    var targetScreen: NSScreen? = nil  // Target screen for multi-monitor support
    
    @State private var animationTrigger = false
    
    /// Centralized layout calculator - Single Source of Truth
    private var layout: HUDLayoutCalculator {
        HUDLayoutCalculator(screen: targetScreen ?? NSScreen.main ?? NSScreen.screens.first)
    }
    
    /// Get the latest version from UpdateChecker
    private var versionText: String {
        if let version = UpdateChecker.shared.latestVersion {
            return "Droppy \(version)"
        }
        return "Droppy"
    }
    
    var body: some View {
        hudContent
            .onAppear {
                withAnimation(DroppyAnimation.scalePop) {
                    animationTrigger = true
                }
            }
    }
    
    @ViewBuilder
    private var hudContent: some View {
        if layout.isDynamicIslandMode {
            // DYNAMIC ISLAND: Icon + "Update" on left, "Droppy [version]" on right
            let iconSize = layout.iconSize
            let symmetricPadding = layout.symmetricPadding(for: iconSize)
            
            HStack {
                // Left: Icon + "Update"
                HStack(spacing: 6) {
                    updateIcon(size: iconSize)
                    Text("Update")
                        .font(.system(size: layout.labelFontSize, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Right: "Droppy [version]"
                Text(versionText)
                    .font(.system(size: layout.labelFontSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(.horizontal, symmetricPadding)
            .frame(height: layout.notchHeight)
        } else {
            // NOTCH MODE: Two wings separated by the notch space
            let iconSize = layout.iconSize
            let symmetricPadding = layout.symmetricPadding(for: iconSize)
            let wingWidth = layout.wingWidth(for: hudWidth)
            
            HStack(spacing: 0) {
                // Left wing: Icon + "Update"
                HStack(spacing: 6) {
                    updateIcon(size: iconSize)
                    Text("Update")
                        .font(.system(size: layout.labelFontSize, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.leading, symmetricPadding)
                .frame(width: wingWidth)
                
                // Camera notch area (spacer)
                Spacer()
                    .frame(width: layout.notchWidth)
                
                // Right wing: "Droppy [version]"
                HStack {
                    Spacer(minLength: 0)
                    Text(versionText)
                        .font(.system(size: layout.labelFontSize, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                .padding(.trailing, symmetricPadding)
                .frame(width: wingWidth)
            }
            .frame(height: layout.notchHeight)
        }
    }
    
    /// Update icon with subtle entrance animation
    @ViewBuilder
    private func updateIcon(size: CGFloat) -> some View {
        Image(systemName: "arrow.down.circle.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Color(red: 0.41, green: 0.71, blue: 1.0))
            .symbolEffect(.bounce.up.byLayer, value: animationTrigger)
            .scaleEffect(animationTrigger ? 1.0 : 0.88)
    }
}

// MARK: - Update Manager

/// Manages Update HUD display
struct UpdateHUDManager {
    /// Show update HUD when a new version is detected
    static func showUpdateAvailable() {
        // Only show if enabled in settings
        let enabled = UserDefaults.standard.bool(forKey: AppPreferenceKey.enableUpdateHUD)
        guard enabled else { return }
        
        HUDManager.shared.show(.update)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black
        UpdateHUDView(hudWidth: 300)
    }
    .frame(width: 350, height: 60)
}
