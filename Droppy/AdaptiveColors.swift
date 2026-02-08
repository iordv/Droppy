import SwiftUI

/// Semantic color palette that adapts to the active macOS appearance.
enum AdaptiveColors {
    /// Base contrast tint used for overlays (white in dark mode, black in light mode).
    static let contrastTintAuto = Color(nsColor: .labelColor)
    
    /// Default button/background overlay.
    static let buttonBackgroundAuto = contrastTintAuto.opacity(0.10)
    
    /// Hover/active overlay.
    static let hoverBackgroundAuto = contrastTintAuto.opacity(0.16)
    
    /// Overlay helper for one-off opacities.
    static func overlayAuto(_ opacity: Double) -> Color {
        contrastTintAuto.opacity(opacity)
    }
    
    /// Subtle border for cards and containers.
    static let subtleBorderAuto = Color(nsColor: .separatorColor).opacity(0.75)
    
    /// Opaque panel/window background when material blur is disabled.
    static let panelBackgroundAuto = Color(nsColor: .windowBackgroundColor).opacity(0.97)
    
    /// Shared shape style for opaque panels.
    static let panelBackgroundOpaqueStyle = AnyShapeStyle(panelBackgroundAuto)
    
    /// Primary text color.
    static let primaryTextAuto = Color(nsColor: .labelColor)
    
    /// Secondary text color.
    static let secondaryTextAuto = Color(nsColor: .secondaryLabelColor)
}
