//
//  MenuBarItem.swift
//  Droppy
//
//  Model for menu bar items, modeled after Ice's implementation.
//  Provides access to window info, frame, and owner details.
//

import Cocoa

/// Represents a menu bar status item window
struct MenuBarItem: Identifiable, Equatable, Hashable {
    /// The window identifier for this item
    let windowID: CGWindowID
    
    /// The title of the window (if any)
    let title: String?
    
    /// The owning application's name
    let ownerName: String
    
    /// The owning application's PID
    let ownerPID: pid_t
    
    /// The frame of the item in screen coordinates
    let frame: CGRect
    
    /// Whether the item is currently on screen
    let isOnScreen: Bool
    
    // MARK: - Identifiable
    
    var id: CGWindowID { windowID }
    
    // MARK: - Computed Properties
    
    /// Display name for the item (owner name or title)
    var displayName: String {
        title ?? ownerName
    }
    
    /// The owning application
    var owningApplication: NSRunningApplication? {
        NSRunningApplication(processIdentifier: ownerPID)
    }
    
    // MARK: - Initialization
    
    /// Creates a MenuBarItem from a window info dictionary
    init?(windowInfo: [String: Any]) {
        guard
            let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
            let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
            let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
            let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
            let x = boundsDict["X"],
            let y = boundsDict["Y"],
            let width = boundsDict["Width"],
            let height = boundsDict["Height"]
        else {
            return nil
        }
        
        self.windowID = windowID
        self.title = windowInfo[kCGWindowName as String] as? String
        self.ownerName = ownerName
        self.ownerPID = ownerPID
        self.frame = CGRect(x: x, y: y, width: width, height: height)
        self.isOnScreen = (windowInfo[kCGWindowIsOnscreen as String] as? Bool) ?? false
    }
    
    /// Creates a MenuBarItem by looking up a window ID
    init?(windowID: CGWindowID) {
        guard let windowInfoList = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]],
              let windowInfo = windowInfoList.first else {
            return nil
        }
        self.init(windowInfo: windowInfo)
    }
    
    // MARK: - Static Methods
    
    /// Gets all menu bar items
    /// - Parameters:
    ///   - onScreenOnly: If true, only returns items currently visible
    ///   - activeSpaceOnly: If true, only returns items in the active space
    /// - Returns: Array of MenuBarItem sorted by X position (right to left)
    static func getMenuBarItems(onScreenOnly: Bool = true, activeSpaceOnly: Bool = true) -> [MenuBarItem] {
        var options: CGWindowListOption = []
        if onScreenOnly {
            options.insert(.optionOnScreenOnly)
        }
        
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        // kCGStatusWindowLevel is the proper level for menu bar items (like Ice uses)
        let statusWindowLevel = Int(CGWindowLevelForKey(.statusWindow))
        
        var items: [MenuBarItem] = []
        
        for windowInfo in windowInfoList {
            // Must have the status window layer (menu bar level)
            guard let layer = windowInfo[kCGWindowLayer as String] as? Int else {
                continue
            }
            
            // Menu bar items are at kCGStatusWindowLevel
            guard layer == statusWindowLevel else {
                continue
            }
            
            guard let item = MenuBarItem(windowInfo: windowInfo) else {
                continue
            }
            
            // Skip Window Server windows
            if item.ownerName == "Window Server" {
                continue
            }
            
            // Skip our own Droppy items
            if item.ownerName == "Droppy" {
                continue
            }
            
            items.append(item)
        }
        
        // Sort by X position (right to left in menu bar)
        return items.sorted { $0.frame.minX > $1.frame.minX }
    }
    
    /// Gets menu bar items for a specific section (hidden vs visible)
    /// - Parameter hidden: If true, returns hidden items; if false, returns visible items
    /// - Returns: Array of MenuBarItem
    static func getHiddenMenuBarItems() -> [MenuBarItem] {
        // Get all items including offscreen
        return getMenuBarItems(onScreenOnly: false, activeSpaceOnly: true)
            .filter { !$0.isOnScreen }
    }
    
    /// Gets the current frame of a menu bar item by window ID
    static func getCurrentFrame(for windowID: CGWindowID) -> CGRect? {
        guard let item = MenuBarItem(windowID: windowID) else {
            return nil
        }
        return item.frame
    }
}

// MARK: - MenuBarItemInfo

/// Lightweight identifier for a menu bar item (used as dictionary key)
struct MenuBarItemInfo: Hashable, Codable {
    let windowID: CGWindowID
    let ownerName: String
    let ownerPID: pid_t
    
    init(item: MenuBarItem) {
        self.windowID = item.windowID
        self.ownerName = item.ownerName
        self.ownerPID = item.ownerPID
    }
    
    init(windowID: CGWindowID, ownerName: String, ownerPID: pid_t) {
        self.windowID = windowID
        self.ownerName = ownerName
        self.ownerPID = ownerPID
    }
}

extension MenuBarItem {
    /// Creates an info struct for this item
    var info: MenuBarItemInfo {
        MenuBarItemInfo(item: self)
    }
}
