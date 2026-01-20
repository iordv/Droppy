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
struct HUDLayoutCalculator {
    let screen: NSScreen
    
    // MARK: - Computed Layout Properties
    
    /// Physical notch height from safe area insets
    var notchHeight: CGFloat {
        let height = screen.safeAreaInsets.top
        // Fallback for screens without notch - use Dynamic Island height
        return height > 0 ? height : 32
    }
    
    /// Physical notch width (hardcoded based on Apple's design)
    var notchWidth: CGFloat {
        // MacBook Pro notch is 180pt wide
        screen.safeAreaInsets.top > 0 ? 180 : 0
    }
    
    /// Whether to use Dynamic Island (compact) layout vs Notch (wing) layout
    var isDynamicIslandMode: Bool {
        let hasPhysicalNotch = screen.safeAreaInsets.top > 0
        let forceTest = UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")
        
        // External displays never have physical notches, always use compact layout
        if !screen.isBuiltIn {
            return true
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
    /// In Notch mode: ensures icons align with outer edges
    func symmetricPadding(for iconSize: CGFloat) -> CGFloat {
        let calculated = (notchHeight - iconSize) / 2
        return max(calculated, 6) // Minimum 6px for visibility
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
    static var current: HUDLayoutCalculator {
        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen.screens[0]
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
