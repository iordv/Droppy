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
    
    // MARK: - Dynamic Island Dimensions (collapsed state)
    
    /// Dynamic Island collapsed width
    static let dynamicIslandWidth: CGFloat = 210
    
    /// Dynamic Island collapsed height
    static let dynamicIslandHeight: CGFloat = 37
    
    /// Dynamic Island top margin from screen edge (creates floating effect like iPhone)
    static let dynamicIslandTopMargin: CGFloat = 4
    
    // MARK: - Physical Notch Dimensions
    
    /// Physical notch width (Apple's standard design)
    static let physicalNotchWidth: CGFloat = 180
    
    // MARK: - Floating Button Spacing
    
    /// Gap between expanded content and floating buttons below
    /// Used for buttons like close, terminal toggle, settings etc.
    static let floatingButtonGap: CGFloat = 12
    
    /// Extra offset for island mode floating buttons to match notch mode visual spacing
    /// In notch mode, currentExpandedHeight includes top padding compensation which naturally
    /// pushes buttons lower. Island mode needs this extra offset to match.
    static let floatingButtonIslandCompensation: CGFloat = 6
    
    // MARK: - Notch Mode Calculations
    
    /// Get the physical notch height for a given screen
    /// Returns 0 if no notch (external display or Dynamic Island mode)
    static func notchHeight(for screen: NSScreen?) -> CGFloat {
        guard let screen = screen else { return 0 }
        return screen.safeAreaInsets.top
    }
    
    /// Whether a screen is in Dynamic Island mode (no physical notch)
    static func isDynamicIslandMode(for screen: NSScreen?) -> Bool {
        notchHeight(for: screen) == 0
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
        
        if notch > 0 {
            // NOTCH MODE: Top padding = notchHeight (content just below notch)
            // Left/Right/Bottom = contentPadding (perfectly equal)
            return EdgeInsets(
                top: notch,
                leading: contentPadding,
                bottom: contentPadding,
                trailing: contentPadding
            )
        } else {
            // ISLAND MODE: 100% symmetrical padding on all edges
            return EdgeInsets(
                top: contentPadding,
                leading: contentPadding,
                bottom: contentPadding,
                trailing: contentPadding
            )
        }
    }
    
    /// Convenience method when you only have notchHeight, not the full screen
    /// - Parameter notchHeight: The physical notch height (0 for island mode)
    /// - Returns: EdgeInsets for the content
    static func contentEdgeInsets(notchHeight: CGFloat) -> EdgeInsets {
        if notchHeight > 0 {
            // NOTCH MODE
            return EdgeInsets(
                top: notchHeight,
                leading: contentPadding,
                bottom: contentPadding,
                trailing: contentPadding
            )
        } else {
            // ISLAND MODE: 100% symmetrical
            return EdgeInsets(
                top: contentPadding,
                leading: contentPadding,
                bottom: contentPadding,
                trailing: contentPadding
            )
        }
    }
}
