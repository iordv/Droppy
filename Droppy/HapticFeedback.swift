import AppKit

/// Centralized haptic feedback manager for tactile response to user interactions
/// Uses NSHapticFeedbackManager - only works on MacBooks with Force Touch trackpad
enum HapticFeedback {
    
    // MARK: - Feedback Types
    
    /// Light tap for subtle confirmations (toggle, hover feedback)
    case light
    
    /// Medium feedback for standard actions (file drop, copy, expand)
    case medium
    
    /// Strong feedback for significant actions (delete, error, limit reached)
    case strong
    
    // MARK: - Public API
    
    /// Perform haptic feedback of the specified type
    func perform() {
        let performer = NSHapticFeedbackManager.defaultPerformer
        
        switch self {
        case .light:
            performer.perform(.levelChange, performanceTime: .now)
        case .medium:
            performer.perform(.generic, performanceTime: .now)
        case .strong:
            performer.perform(.alignment, performanceTime: .now)
        }
    }
    
    // MARK: - Convenience Methods
    
    /// File successfully dropped onto shelf or basket
    static func drop() {
        HapticFeedback.medium.perform()
    }
    
    /// Item copied to clipboard
    static func copy() {
        HapticFeedback.light.perform()
    }
    
    /// Item deleted or removed
    static func delete() {
        HapticFeedback.medium.perform()
    }
    
    /// Item pinned or unpinned
    static func pin() {
        HapticFeedback.light.perform()
    }
    
    /// Notch expanded or collapsed
    static func expand() {
        HapticFeedback.light.perform()
    }
    
    /// Reached volume/brightness min or max limit
    static func limit() {
        HapticFeedback.strong.perform()
    }
    
    /// Selection changed
    static func select() {
        HapticFeedback.light.perform()
    }
    
    /// Error or failed action
    static func error() {
        HapticFeedback.strong.perform()
    }
    
    /// Toggle switched
    static func toggle() {
        HapticFeedback.light.perform()
    }
    
    /// Light pop for hover peek effects
    static func pop() {
        HapticFeedback.light.perform()
    }
}
