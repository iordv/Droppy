//
//  MenuBarItem.swift
//  Droppy
//
//  Model for menu bar items using Ice's approach.
//  Menu bar items are windows at kCGStatusWindowLevel (layer 25).
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
    
    /// The owning application's bundle identifier
    let bundleIdentifier: String?
    
    // MARK: - Unique Key (Ice's approach: bundleIdentifier:title)
    
    /// Unique key for this item - combines bundleIdentifier and title like Ice
    /// This is stable across app restarts and uniquely identifies each item
    var uniqueKey: String {
        let namespace = bundleIdentifier ?? "<null>"
        let itemTitle = title ?? ""
        return "\(namespace):\(itemTitle)"
    }
    
    // MARK: - Identifiable
    
    var id: String { uniqueKey }  // Use uniqueKey as the stable ID
    
    // MARK: - Computed Properties
    
    /// Display name for the item - resolves bundle IDs to actual app names
    var displayName: String {
        // Handle Control Center special titles like Ice does
        if bundleIdentifier == "com.apple.controlcenter" {
            switch title {
            case "AccessibilityShortcuts": return "Accessibility Shortcuts"
            case "BentoBox", "BentoBox-0": return "Control Centre"
            case "FocusModes": return "Focus"
            case "KeyboardBrightness": return "Keyboard Brightness"
            case "MusicRecognition": return "Music Recognition"
            case "NowPlaying", "Now Playing": return "Now Playing"
            case "ScreenMirroring": return "Screen Mirroring"
            case "StageManager": return "Stage Manager"
            case "UserSwitcher": return "Fast User Switching"
            case "WiFi", "Wi-Fi": return "Wi-Fi"
            case "Battery": return "Battery"
            case "Clock": return "Clock"
            case "Siri": return "Siri"
            case "AudioVideoModule": return "Sound"
            default:
                // Title might be a bundle identifier - try to resolve it
                if let title = title, title.contains(".") && !title.contains(" ") {
                    return resolveAppName(from: title) ?? title
                }
                return title ?? "Control Centre"
            }
        }
        
        // Handle SystemUIServer special titles
        if bundleIdentifier == "com.apple.systemuiserver" {
            switch title {
            case "TimeMachine.TMMenuExtraHost", "TimeMachineMenuExtra.TMMenuExtraHost":
                return "Time Machine"
            default:
                break
            }
        }
        
        // If title looks like a bundle identifier, resolve it to app name
        if let title = title, !title.isEmpty {
            if title.contains(".") && !title.contains(" ") {
                // Looks like a bundle ID - try to resolve it
                return resolveAppName(from: title) ?? title
            }
            // Title without dots - use as-is
            return title
        }
        
        // Fallback to owner name
        return ownerName.isEmpty ? "Unknown" : ownerName
    }
    
    /// Resolves a bundle identifier to the app's display name
    private func resolveAppName(from bundleID: String) -> String? {
        // Try to get app URL from bundle ID
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        // Get the app name from the file name (without .app extension)
        let appName = appURL.deletingPathExtension().lastPathComponent
        return appName.isEmpty ? nil : appName
    }
    
    /// The owning application
    var owningApplication: NSRunningApplication? {
        NSRunningApplication(processIdentifier: ownerPID)
    }
    
    // MARK: - Static Methods
    
    /// Gets all menu bar items by finding windows at kCGStatusWindowLevel
    /// This is the key insight from Ice: menu bar items are at layer 25
    static func getMenuBarItems(onScreenOnly: Bool = true, activeSpaceOnly: Bool = true) -> [MenuBarItem] {
        // kCGStatusWindowLevel is 25 - this is where menu bar items live
        let statusWindowLevel = Int(CGWindowLevelForKey(.statusWindow))
        
        print("[MenuBarItem] Looking for windows at layer \(statusWindowLevel) (kCGStatusWindowLevel)")
        
        // Get all windows
        var options: CGWindowListOption = [.optionAll]
        if onScreenOnly {
            options = [.optionOnScreenOnly]
        }
        
        guard let allWindowInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            print("[MenuBarItem] CGWindowListCopyWindowInfo failed")
            return []
        }
        
        print("[MenuBarItem] Scanning \(allWindowInfo.count) windows")
        
        var items: [MenuBarItem] = []
        
        for info in allWindowInfo {
            // Get layer - CRITICAL filter
            guard let layer = info[kCGWindowLayer as String] as? Int else {
                continue
            }
            
            // Only include windows at status window level (layer 25)
            guard layer == statusWindowLevel else {
                continue
            }
            
            guard let windowID = info[kCGWindowNumber as String] as? CGWindowID else {
                continue
            }
            
            // Get accurate frame from private API (more reliable than bounds dict)
            let frame: CGRect
            if let privateFrame = WindowServer.getWindowFrame(windowID: windowID) {
                frame = privateFrame
            } else if let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                      let x = boundsDict["X"],
                      let y = boundsDict["Y"],
                      let width = boundsDict["Width"],
                      let height = boundsDict["Height"] {
                frame = CGRect(x: x, y: y, width: width, height: height)
            } else {
                continue
            }
            
            // Skip tiny/invalid windows
            if frame.width < 5 || frame.height < 5 {
                continue
            }
            
            let ownerName = info[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t ?? 0
            let title = info[kCGWindowName as String] as? String
            
            // Skip our own items and Window Server
            if ownerName == "Droppy" || ownerName == "Window Server" {
                continue
            }
            
            // Get bundle identifier from running application
            let bundleID = NSRunningApplication(processIdentifier: ownerPID)?.bundleIdentifier
            
            let item = MenuBarItem(
                windowID: windowID,
                title: title,
                ownerName: ownerName,
                ownerPID: ownerPID,
                frame: frame,
                bundleIdentifier: bundleID
            )
            
            print("[MenuBarItem] Found: '\(item.displayName)' owner=\(ownerName) at x=\(Int(frame.minX)) w=\(Int(frame.width)) layer=\(layer)")
            items.append(item)
        }
        
        print("[MenuBarItem] Returning \(items.count) menu bar items")
        
        // Sort by X position (right to left in menu bar)
        return items.sorted { $0.frame.minX > $1.frame.minX }
    }
    
    /// Gets the current frame of a menu bar item by window ID
    static func getCurrentFrame(for windowID: CGWindowID) -> CGRect? {
        WindowServer.getWindowFrame(windowID: windowID)
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
