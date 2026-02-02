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
        // Check user preference (default: true)
        let enabled = UserDefaults.standard.object(forKey: AppPreferenceKey.enableHapticFeedback) as? Bool ?? true
        guard enabled else { return }
        
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
    
    // MARK: - Debounce Tracking (Bug #132 Fix)
    // Prevents duplicate haptics when multiple call sites fire in quick succession
    
    private static var lastDropTime: Date = .distantPast
    private static let debounceInterval: TimeInterval = 0.25
    
    // MARK: - Convenience Methods
    
    /// File successfully dropped onto shelf or basket
    static func drop() {
        // BUG #132 FIX: Debounce to prevent multiple haptics from redundant call sites
        let now = Date()
        guard now.timeIntervalSince(lastDropTime) > debounceInterval else { return }
        lastDropTime = now
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
    
    /// Very subtle feedback for hover enter on interactive elements
    static func hover() {
        HapticFeedback.light.perform()
    }
    
    /// Light tap for button presses
    static func tap() {
        HapticFeedback.light.perform()
    }
    
    /// Subtle tick for slider step changes - tactile feedback via Force Touch trackpad
    /// Uses the lightest possible feedback to not overwhelm during continuous dragging
    static func sliderTick() {
        HapticFeedback.light.perform()
    }
    
    /// Stronger tick for reaching slider endpoints (min/max)
    static func sliderEndpoint() {
        HapticFeedback.medium.perform()
    }
}
