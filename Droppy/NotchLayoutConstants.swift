//
//  NotchLayoutConstants.swift
//  Droppy
//
//  Single Source of Truth (SSOT) for notch/island layout calculations.
//  ALL expanded content views (MediaPlayer, TerminalNotch, ShelfView, etc.)
//  MUST use these constants for consistent padding.
//

import SwiftUI

/// Centralized layout constants for notch and Dynamic Island modes.
/// Use these for ALL expanded content padding to ensure perfect consistency.
enum NotchLayoutConstants {
    
    // MARK: - Content Padding (for expanded views like MediaPlayer, TerminalNotch, ShelfItems)
    
    /// Standard content padding (left, right, bottom) - equal on all three edges
    static let contentPadding: CGFloat = 20
    
    /// Horizontal padding compensation for curved wing corners (topCornerRadius)
    /// Applied in: built-in notch mode, external notch style
    static let wingCornerCompensation: CGFloat = 10
    
    // MARK: - Dynamic Island Dimensions (collapsed state)
    
    /// Dynamic Island collapsed width
    static let dynamicIslandWidth: CGFloat = 210
    
    /// Dynamic Island collapsed height (adjustable via user preference)
    static var dynamicIslandHeight: CGFloat {
        let offset = UserDefaults.standard.double(forKey: AppPreferenceKey.dynamicIslandHeightOffset)
        return 37 + offset  // Base: 37pt, Range: 27pt to 47pt
    }
    
    /// Dynamic Island top margin from screen edge (creates floating effect like iPhone)
    static let dynamicIslandTopMargin: CGFloat = 4
    
    // MARK: - Physical Notch Dimensions
    
    /// Baseline fallback notch width used when geometry metadata is unavailable.
    static let physicalNotchWidth: CGFloat = 180
    
    /// Hard bounds for user notch-width calibration.
    static let minimumCalibratedNotchWidth: CGFloat = 140
    static let maximumCalibratedNotchWidth: CGFloat = 320
    
    /// User-controlled notch width offset (built-in physical-notch displays only).
    static var notchWidthOffset: CGFloat {
        CGFloat(UserDefaults.standard.double(forKey: AppPreferenceKey.notchWidthOffset))
    }
    
    // MARK: - Floating Button Spacing
    
    /// Gap between expanded content and floating buttons below
    /// Used for buttons like close, terminal toggle, settings etc.
    static let floatingButtonGap: CGFloat = 12
    
    /// Extra offset for island mode floating buttons to match notch mode visual spacing
    /// In notch mode, currentExpandedHeight includes top padding compensation which naturally
    /// pushes buttons lower. Island mode needs this extra offset to match.
    static let floatingButtonIslandCompensation: CGFloat = 6
    
    // MARK: - Notch Mode Calculations
    
    /// Standard MacBook Pro notch height (menu bar safe area height)
    /// This is consistent across all notch MacBooks at their default resolution
    static let physicalNotchHeight: CGFloat = 37
    
    /// Get the physical notch height for a given screen
    /// Returns physicalNotchHeight as fallback when screen is unavailable
    /// CRITICAL: Uses auxiliary areas for detection (stable on lock screen) and
    /// returns the stable safeAreaInsets value when available, with a fixed fallback
    static func notchHeight(for screen: NSScreen?) -> CGFloat {
        // CRITICAL: Return physical notch height when screen is unavailable for stable positioning
        guard let screen = screen else { return physicalNotchHeight }
        
        // Use auxiliary areas to detect physical notch (stable on lock screen)
        let hasPhysicalNotch = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
        guard hasPhysicalNotch else { return 0 }
        
        // Return actual safeAreaInsets if available, otherwise use fixed constant
        let topInset = screen.safeAreaInsets.top
        return topInset > 0 ? topInset : physicalNotchHeight
    }
    
    /// Get the physical notch width for a given screen.
    /// Uses auxiliary safe areas when available and applies user calibration on built-in displays.
    /// Falls back to baseline notch-style width when physical metadata is unavailable.
    static func notchWidth(for screen: NSScreen?) -> CGFloat {
        guard let screen = screen else {
            let fallback = physicalNotchWidth + notchWidthOffset
            return min(max(fallback, minimumCalibratedNotchWidth), maximumCalibratedNotchWidth)
        }
        
        let measuredWidth: CGFloat
        if let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            let gap = rightArea.minX - leftArea.maxX
            if gap.isFinite && gap > 0 {
                measuredWidth = max(gap, physicalNotchWidth)
            } else {
                measuredWidth = physicalNotchWidth
            }
        } else if screen.isBuiltIn {
            // Keep built-in geometry stable if auxiliary areas are briefly unavailable.
            measuredWidth = physicalNotchWidth
        } else {
            // External displays can still render notch visual style using fallback width.
            measuredWidth = physicalNotchWidth
        }
        
        let adjustedWidth = measuredWidth + (screen.isBuiltIn ? notchWidthOffset : 0)
        return min(max(adjustedWidth, minimumCalibratedNotchWidth), maximumCalibratedNotchWidth)
    }
    
    /// Whether a screen is in Dynamic Island mode (no physical notch)
    /// Uses auxiliary areas for stable detection on lock screen
    /// CRITICAL: Returns false (notch mode) when screen is unavailable to prevent layout jumps
    static func isDynamicIslandMode(for screen: NSScreen?) -> Bool {
        usesDynamicIslandStyle(for: screen)
    }

    /// Unified display-mode resolver used across shelf/HUD/window geometry.
    /// External displays honor `externalDisplayUseDynamicIsland`.
    /// Built-in displays honor `useDynamicIslandStyle`, but physical-notch Macs stay in notch mode
    /// unless force-test is enabled.
    static func usesDynamicIslandStyle(for screen: NSScreen?) -> Bool {
        guard let screen = screen else { return false }

        if !screen.isBuiltIn {
            return UserDefaults.standard.preference(
                AppPreferenceKey.externalDisplayUseDynamicIsland,
                default: PreferenceDefault.externalDisplayUseDynamicIsland
            )
        }

        let hasPhysicalNotch = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
        let forceTest = UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")
        let useDynamicIsland = UserDefaults.standard.preference(
            AppPreferenceKey.useDynamicIslandStyle,
            default: PreferenceDefault.useDynamicIslandStyle
        )
        return (!hasPhysicalNotch || forceTest) && useDynamicIsland
    }
    
    // MARK: - EdgeInsets Calculation
    
    /// Calculate content EdgeInsets for expanded views.
    /// - Notch mode: top = notchHeight (content starts JUST below the physical notch),
    ///               left/right/bottom = contentPadding (equal on all three)
    /// - Island mode: equal padding on ALL four edges
    ///
    /// - Parameter screen: The target screen (uses main if nil)
    /// - Returns: EdgeInsets for the content
    static func contentEdgeInsets(for screen: NSScreen?) -> EdgeInsets {
        let targetScreen = screen ?? NSScreen.main
        let notch = notchHeight(for: targetScreen)
        
        // Check if external display using notch visual style (has curved corners)
        let isExternalWithNotchStyle: Bool = {
            guard let s = targetScreen else { return false }
            if s.isBuiltIn { return false }
            let externalUseDI = UserDefaults.standard.preference(
                AppPreferenceKey.externalDisplayUseDynamicIsland,
                default: PreferenceDefault.externalDisplayUseDynamicIsland
            )
            return !externalUseDI
        }()
        
        // v21.72: Same values as contentEdgeInsets(notchHeight:isExternalWithNotchStyle:)
        let symmetricPadding = contentPadding + wingCornerCompensation  // 30pt
        
        if notch > 0 {
            // NOTCH MODE: Top = notchHeight (just below physical notch)
            // Left/Right = 30pt for curved corner clearance
            // Bottom = 20pt
            return EdgeInsets(
                top: notch,
                leading: symmetricPadding,
                bottom: contentPadding,
                trailing: symmetricPadding
            )
        } else if isExternalWithNotchStyle {
            // EXTERNAL WITH NOTCH STYLE (v21.72): Symmetric vertical, DI-style horizontal
            // Top/Bottom = 20pt, Left/Right = 30pt
            return EdgeInsets(
                top: contentPadding,
                leading: symmetricPadding,
                bottom: contentPadding,
                trailing: symmetricPadding
            )
        } else {
            // PURE ISLAND MODE: 20pt symmetrical on ALL 4 edges for compact look
            return EdgeInsets(
                top: contentPadding,
                leading: contentPadding,
                bottom: contentPadding,
                trailing: contentPadding
            )
        }
    }
    
    /// Convenience method when you only have notchHeight, not the full screen
    /// - Parameters:
    ///   - notchHeight: The physical notch height (0 for island mode)
    ///   - isExternalWithNotchStyle: Whether this is an external display with notch visual style
    /// - Returns: EdgeInsets for the content
    static func contentEdgeInsets(notchHeight: CGFloat, isExternalWithNotchStyle: Bool = false) -> EdgeInsets {
        // v21.68: All modes use 30pt (contentPadding + wingCornerCompensation) for horizontal edges
        // Island mode: 30pt on ALL 4 edges for 100% symmetry
        let symmetricPadding = contentPadding + wingCornerCompensation  // 30pt
        
        if notchHeight > 0 {
            // NOTCH MODE: Top = notchHeight, Left/Right = 30pt, Bottom = 20pt
            return EdgeInsets(
                top: notchHeight,
                leading: symmetricPadding,
                bottom: contentPadding,
                trailing: symmetricPadding
            )
        } else if isExternalWithNotchStyle {
            // EXTERNAL WITH NOTCH STYLE (v21.72): Symmetric vertical, DI-style horizontal
            // Top/Bottom = 20pt (symmetrical vertical), Left/Right = 30pt (matches DI)
            return EdgeInsets(
                top: contentPadding,  // 20pt
                leading: symmetricPadding,  // 30pt
                bottom: contentPadding,  // 20pt (matches top for visual balance)
                trailing: symmetricPadding  // 30pt
            )
        } else {
            // PURE ISLAND MODE: 20pt symmetrical on ALL 4 edges for compact look
            return EdgeInsets(
                top: contentPadding,
                leading: contentPadding,
                bottom: contentPadding,
                trailing: contentPadding
            )
        }
    }
}
