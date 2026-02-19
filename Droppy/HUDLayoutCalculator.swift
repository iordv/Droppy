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
        let hasNotch = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
        
        if hasNotch {
            let height = screen.safeAreaInsets.top
            // Return actual height when available, otherwise use fixed constant
            return height > 0 ? height : NotchLayoutConstants.physicalNotchHeight
        }
        
        // Fallback for screens without notch - use Dynamic Island height
        return NotchLayoutConstants.dynamicIslandHeight
    }
    
    /// Physical notch width derived from screen geometry with calibration fallback.
    /// Returns fallback notch width when screen is unavailable.
    var notchWidth: CGFloat {
        // CRITICAL: Return physical notch width when screen is unavailable
        guard let screen = screen else { return NotchLayoutConstants.notchWidth(for: nil) }
        
        // Use auxiliary areas to detect notch (stable on lock screen)
        let hasNotch = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
        guard hasNotch || screen.isBuiltIn else { return 0 }
        return NotchLayoutConstants.notchWidth(for: screen)
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
        
        // External displays use compact content layout regardless of visual style.
        if !screen.isBuiltIn {
            return true
        }
        
        // For built-in display, use user preference
        let useDynamicIsland = UserDefaults.standard.preference(
            AppPreferenceKey.useDynamicIslandStyle,
            default: PreferenceDefault.useDynamicIslandStyle
        )
        return (!hasPhysicalNotch || forceTest) && useDynamicIsland
    }
    
    /// Whether this is an external display using notch visual style (curved corners)
    /// External displays can choose DI style or Notch style - Notch style has curved corners that need padding
    var isExternalWithNotchStyle: Bool {
        guard let screen = screen else { return false }
        if screen.isBuiltIn { return false }
        // External display with notch style = user chose NOT to use DI style
        let externalUseDI = UserDefaults.standard.preference(
            AppPreferenceKey.externalDisplayUseDynamicIsland,
            default: PreferenceDefault.externalDisplayUseDynamicIsland
        )
        return !externalUseDI
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
    /// In Notch mode or External with notch style: +10pt for curved corners
    func symmetricPadding(for iconSize: CGFloat) -> CGFloat {
        let calculated = (notchHeight - iconSize) / 2
        let basePadding = max(calculated, 6) // Minimum 6px for visibility
        // +wingCornerCompensation for curved corners in:
        // 1. Built-in notch mode (physical notch with curved wing corners)
        // 2. External with notch visual style (curved topCornerRadius)
        let needsCurvedCornerPadding = !isDynamicIslandMode || isExternalWithNotchStyle
        return needsCurvedCornerPadding ? basePadding + NotchLayoutConstants.wingCornerCompensation : basePadding
    }
    
    // MARK: - Standard Sizes
    
    /// Standard icon size for Dynamic Island mode
    static let dynamicIslandIconSize: CGFloat = 16
    
    /// Standard icon size for Notch mode
    static let notchIconSize: CGFloat = 18
    
    /// Current icon size based on mode
    var iconSize: CGFloat {
        isDynamicIslandMode ? Self.dynamicIslandIconSize : Self.notchIconSize
    }
    
    /// Current font size for percentage/label text
    var labelFontSize: CGFloat {
        isDynamicIslandMode ? 12 : 14
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
