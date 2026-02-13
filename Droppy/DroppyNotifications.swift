//
//  DroppyNotifications.swift
//  Droppy
//
//  Single Source of Truth for all custom notification names
//  Consolidates scattered Notification.Name extensions
//

import Foundation

// MARK: - Droppy Notification Names (Single Source of Truth)

extension Notification.Name {
    // MARK: - Clipboard
    
    /// Posted when the clipboard window is shown
    static let clipboardWindowDidShow = Notification.Name("ClipboardWindowDidShow")
    
    // MARK: - Drag & Drop
    
    /// Posted when a file is dragged out from the shelf
    static let droppyShelfDragOutCompleted = Notification.Name("droppyShelfDragOutCompleted")
    
    /// Posted when a file is dragged out from the basket
    static let droppyBasketDragOutCompleted = Notification.Name("droppyBasketDragOutCompleted")
    
    /// Posted when any drag-out operation completes
    static let droppyDragOutCompleted = Notification.Name("droppyDragOutCompleted")
    
    // MARK: - HUD

    /// Posted when HUD state changes (show/hide) - used to update window mouse event handling
    static let hudStateDidChange = Notification.Name("hudStateDidChange")

    // MARK: - Extensions

    /// Posted when an extension is installed/uninstalled
    static let extensionStateChanged = Notification.Name("extensionStateChanged")
    
    /// Posted when a deep link opens an extension page
    static let openExtensionFromDeepLink = Notification.Name("openExtensionFromDeepLink")
    
    /// Posted when navigating to Smart Export settings from an extension
    static let openSmartExportSettings = Notification.Name("openSmartExportSettings")
    
    // MARK: - Shortcuts
    
    /// Posted when Element Capture shortcut is changed
    static let elementCaptureShortcutChanged = Notification.Name("elementCaptureShortcutChanged")
    
    /// Posted when Window Snap shortcuts are changed
    static let windowSnapShortcutChanged = Notification.Name("windowSnapShortcutChanged")

    /// Posted when the Reminders quick-open shortcut is changed
    static let todoQuickOpenShortcutChanged = Notification.Name("todoQuickOpenShortcutChanged")

    /// Posted when the Reminders quick-open shortcut is triggered
    static let todoQuickOpenRequested = Notification.Name("todoQuickOpenRequested")

    // MARK: - Licensing

    /// Posted when Gumroad license activation state changes
    static let licenseStateDidChange = Notification.Name("licenseStateDidChange")
    
    // MARK: - Shelf
    
    /// Posted when a file should be added to the shelf (e.g., from screenshot editor)
    static let addFileToShelf = Notification.Name("addFileToShelf")
    
    // MARK: - System (Darwin notifications - keep as-is)
    
    /// System notification for screen lock (Darwin)
    static let screenIsLocked = Notification.Name("com.apple.screenIsLocked")
    
    /// System notification for screen unlock (Darwin)
    static let screenIsUnlocked = Notification.Name("com.apple.screenIsUnlocked")
}
