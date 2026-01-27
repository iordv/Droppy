//
//  HUDLayoutCalculator.swift
//  Droppy
//
//  Single Source of Truth for HUD layout calculations
//  All HUD views use this instead of duplicating logic
//

import SwiftUI
import AppKit

/// Centralized HUD layout calculator - Single Source of Truth
/// All HUD views should use this instead of duplicating isDynamicIslandMode, wingWidth, etc.
/// CRITICAL: Handles nil screen gracefully with safe fallback values for lock screen stability
struct HUDLayoutCalculator {
    let screen: NSScreen?
    
    // MARK: - Computed Layout Properties
    
    /// Physical notch height - uses auxiliary areas for stable lock screen detection
    /// Returns physicalNotchHeight when screen is unavailable to prevent layout jumps
    var notchHeight: CGFloat {
        // CRITICAL: Return physical notch height when screen is unavailable for stable positioning
        guard let screen = screen else { return NotchLayoutConstants.physicalNotchHeight }
        
        // Use auxiliary areas to detect physical notch (stable on lock screen)
        let hasPhysicalNotch = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
        
        if hasPhysicalNotch {
            let height = screen.safeAreaInsets.top
            // Return actual height when available, otherwise use fixed constant
            return height > 0 ? height : NotchLayoutConstants.physicalNotchHeight
        }
        
        // For external displays using Notch style, use the physical notch height
        if !screen.isBuiltIn && !isDynamicIslandMode {
            return NotchLayoutConstants.physicalNotchHeight
        }
        
        // Fallback for screens without notch - use Dynamic Island height
        return NotchLayoutConstants.dynamicIslandHeight
    }
    
    /// Physical notch width (hardcoded based on Apple's design)
    /// Returns physicalNotchWidth when screen is unavailable
    var notchWidth: CGFloat {
        // CRITICAL: Return physical notch width when screen is unavailable
        guard let screen = screen else { return NotchLayoutConstants.physicalNotchWidth }
        
        // Use auxiliary areas to detect physical notch (stable on lock screen)
        let hasPhysicalNotch = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
        
        if hasPhysicalNotch {
            return NotchLayoutConstants.physicalNotchWidth
        }
        
        // For external displays using Notch style, use the physical notch width
        if !screen.isBuiltIn && !isDynamicIslandMode {
            return NotchLayoutConstants.physicalNotchWidth
        }
        
        // No notch for Dynamic Island mode
        return 0
    }
    
    /// Whether to use Dynamic Island (compact) layout vs Notch (wing) layout
    /// Returns false (notch mode) when screen is unavailable to prevent layout jumps
    var isDynamicIslandMode: Bool {
        // CRITICAL: Return false (notch mode) when screen is unavailable to prevent layout jumps
        guard let screen = screen else { return false }
        
        // CRITICAL: Use auxiliary areas to detect physical notch, NOT safeAreaInsets
        // safeAreaInsets.top can be 0 on lock screen (no menu bar), but auxiliary areas
        // are hardware-based and always present for notch MacBooks
        let hasPhysicalNotch = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
        let forceTest = UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")
        
        // External displays never have physical notches, use user preference
        if !screen.isBuiltIn {
            // Respect the externalDisplayUseDynamicIsland setting
            return (UserDefaults.standard.object(forKey: AppPreferenceKey.externalDisplayUseDynamicIsland) as? Bool) ?? true
        }
        
        // For built-in display, use user preference
        let useDynamicIsland = (UserDefaults.standard.object(forKey: "useDynamicIslandStyle") as? Bool) ?? true
        return (!hasPhysicalNotch || forceTest) && useDynamicIsland
    }
    
    /// Whether transparent Dynamic Island mode is enabled
    /// Uses the MAIN "Transparent Background" setting - one toggle controls all transparency
    var isTransparentDynamicIsland: Bool {
        isDynamicIslandMode && UserDefaults.standard.bool(forKey: "useTransparentBackground")
    }
    
    /// Width of each "wing" (area left/right of physical notch) - only used in notch mode
    func wingWidth(for hudWidth: CGFloat) -> CGFloat {
        (hudWidth - notchWidth) / 2
    }
    
    /// Symmetric padding for icon alignment
    /// In Dynamic Island: matches vertical padding for visual balance
    /// In Notch mode: ensures icons align with outer edges, +10pt for curved wing corners
    func symmetricPadding(for iconSize: CGFloat) -> CGFloat {
        let calculated = (notchHeight - iconSize) / 2
        let basePadding = max(calculated, 6) // Minimum 6px for visibility
        // +10pt compensation for curved wing corners (topCornerRadius) in notch mode only
        return isDynamicIslandMode ? basePadding : basePadding + 10
    }
    
    // MARK: - Standard Sizes
    
    /// Standard icon size for Dynamic Island mode
    static let dynamicIslandIconSize: CGFloat = 18
    
    /// Standard icon size for Notch mode
    static let notchIconSize: CGFloat = 20
    
    /// Current icon size based on mode
    var iconSize: CGFloat {
        isDynamicIslandMode ? Self.dynamicIslandIconSize : Self.notchIconSize
    }
    
    /// Current font size for percentage/label text
    var labelFontSize: CGFloat {
        isDynamicIslandMode ? 13 : 15
    }
    
    // MARK: - Color Helpers
    
    /// Accent color adjusted for transparent Dynamic Island mode
    func adjustedColor(_ baseColor: Color) -> Color {
        isTransparentDynamicIsland ? .white : baseColor
    }
    
    // MARK: - Convenience Initializer
    
    /// Create calculator for current main screen or fallback
    /// NOTE: If no screens available, returns calculator with nil screen (uses safe fallbacks)
    static var current: HUDLayoutCalculator {
        let screen = NSScreen.main ?? NSScreen.screens.first
        return HUDLayoutCalculator(screen: screen)
    }
    
    /// Create calculator for a specific display ID
    static func forDisplay(_ displayID: CGDirectDisplayID) -> HUDLayoutCalculator? {
        guard let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) else {
            return nil
        }
        return HUDLayoutCalculator(screen: screen)
    }
}

// MARK: - Preview Helper

#Preview {
    VStack(spacing: 20) {
        let calc = HUDLayoutCalculator.current
        
        Text("HUD Layout Calculator")
            .font(.headline)
        
        VStack(alignment: .leading, spacing: 8) {
            Text("notchHeight: \(calc.notchHeight, specifier: "%.1f")")
            Text("notchWidth: \(calc.notchWidth, specifier: "%.1f")")
            Text("isDynamicIslandMode: \(calc.isDynamicIslandMode ? "Yes" : "No")")
            Text("iconSize: \(calc.iconSize, specifier: "%.1f")")
            Text("symmetricPadding: \(calc.symmetricPadding(for: calc.iconSize), specifier: "%.1f")")
        }
        .font(.system(.body, design: .monospaced))
    }
    .padding()
    .frame(width: 300)
}
