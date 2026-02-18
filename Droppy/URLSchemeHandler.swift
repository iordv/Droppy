//
//  URLSchemeHandler.swift
//  Droppy
//
//  Created by Jordy Spruit on 08/01/2026.
//

import SwiftUI

/// Handles incoming droppy:// URL scheme requests from Alfred and other apps
///
/// URL Format:
/// - droppy://add?target=shelf&path=/path/to/file1&path=/path/to/file2
/// - droppy://add?target=basket&path=/path/to/file
/// - droppy://add?target=shelf&url=https%3A%2F%2Fexample.com
/// - droppy://extension/{id} - Opens extension info sheet
///
/// Parameters:
/// - target: "shelf" or "basket" - where to add the files
/// - path: URL-encoded file path (can repeat for multiple files)
/// - url: URL-encoded web link (can repeat for multiple links)
struct URLSchemeHandler {
    
    /// Handles an incoming droppy:// URL
    /// - Parameter url: The URL to process
    static func handle(_ url: URL) {
        print("🔗 URLSchemeHandler: Received URL: \(url.absoluteString)")

        let licenseManager = LicenseManager.shared
        if licenseManager.requiresLicenseEnforcement && !licenseManager.hasAccess {
            print("🔒 URLSchemeHandler: Blocked while license is not active")
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                LicenseWindowController.shared.show()
            }
            return
        }
        
        // Parse the action from the host component (e.g., "add")
        guard let host = url.host else {
            print("⚠️ URLSchemeHandler: No action specified in URL")
            return
        }
        
        switch host.lowercased() {
        case "add":
            handleAddAction(url: url)
        case "spotify-callback":
            // Handle Spotify OAuth callback
            handleSpotifyCallback(url: url)
        case "extension":
            // Open extension info sheet from website
            handleExtensionAction(url: url)
        default:
            print("⚠️ URLSchemeHandler: Unknown action '\(host)'")
        }
    }
    
    /// Handles the "add" action - adds files to shelf or basket
    private static func handleAddAction(url: URL) {
        // Parse query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            print("⚠️ URLSchemeHandler: Failed to parse URL components")
            return
        }
        
        let queryItems = components.queryItems ?? []
        
        // Get target (shelf or basket, default to shelf)
        let target = queryItems.first(where: { $0.name == "target" })?.value ?? "shelf"
        
        // Get all file paths
        let fileURLs = queryItems
            .filter { $0.name == "path" }
            .compactMap { $0.value }
            .map { URL(fileURLWithPath: $0) }

        // Get all remote links and convert them to .webloc files
        let remoteURLs = queryItems
            .filter { $0.name == "url" }
            .compactMap { $0.value }
            .compactMap { DroppyLinkSupport.parseWebURL(from: $0) }

        var itemsToAdd = fileURLs
        if !remoteURLs.isEmpty {
            let tempLinksFolder = FileManager.default.temporaryDirectory
                .appendingPathComponent("DroppyURLScheme-\(UUID().uuidString)", isDirectory: true)
            let linkFiles = DroppyLinkSupport.createWeblocFiles(for: remoteURLs, in: tempLinksFolder)
            itemsToAdd.append(contentsOf: linkFiles)
        }
        
        guard !itemsToAdd.isEmpty else {
            print("⚠️ URLSchemeHandler: No valid paths or links provided")
            return
        }
        
        print("🔗 URLSchemeHandler: Adding \(itemsToAdd.count) item(s) to \(target)")
        
        // Add files to the appropriate destination
        let state = DroppyState.shared
        
        switch target.lowercased() {
        case "basket":
            FloatingBasketWindowController.addItemsFromExternalSource(itemsToAdd)
            
            print("✅ URLSchemeHandler: Added \(itemsToAdd.count) item(s) to basket")
            
        case "shelf":
            fallthrough
        default:
            // Add to notch shelf
            state.addItems(from: itemsToAdd)
            
            // Show the shelf if it's not visible (use main display for URL scheme triggers)
            if !state.isExpanded {
                if let mainDisplayID = NSScreen.main?.displayID {
                    state.expandShelf(for: mainDisplayID)
                }
            }
            
            print("✅ URLSchemeHandler: Added \(itemsToAdd.count) item(s) to shelf")
        }
    }
    
    /// Handles Spotify OAuth callback
    /// URL Format: droppy://spotify-callback?code=xxx
    private static func handleSpotifyCallback(url: URL) {
        print("🎵 URLSchemeHandler: Received Spotify OAuth callback")
        
        if SpotifyAuthManager.shared.handleCallback(url: url) {
            print("✅ URLSchemeHandler: Spotify authentication successful")
        } else {
            print("⚠️ URLSchemeHandler: Spotify authentication failed")
        }
    }
    
    /// Handles extension deep links from the website
    /// URL Format: droppy://extension/{id}
    /// Supported IDs include: ai-bg, alfred, finder, element-capture, spotify, apple-music, window-snap, voice-transcribe, video-target-size, termi-notch, notchface, snap-camera, quickshare, notification-hud, caffeine, menu-bar-manager, todo
    private static func handleExtensionAction(url: URL) {
        // Extract extension ID from path (e.g., "/ai-bg" -> "ai-bg")
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let extensionId = pathComponents.first else {
            print("⚠️ URLSchemeHandler: No extension ID in URL path")
            return
        }
        
        print("🧩 URLSchemeHandler: Opening extension '\(extensionId)'")
        
        // Map URL ID to ExtensionType
        let extensionType: ExtensionType?
        switch extensionId.lowercased() {
        case "ai-bg", "ai", "background-removal":
            extensionType = .aiBackgroundRemoval
        case "alfred", "alfred-workflow":
            extensionType = .alfred
        case "finder", "finder-services":
            extensionType = .finderServices
        case "element-capture", "element", "capture":
            extensionType = .elementCapture
        case "spotify", "spotify-integration":
            extensionType = .spotify
        case "apple-music", "applemusic", "music":
            extensionType = .appleMusic
        case "window-snap", "windowsnap", "snap":
            extensionType = .windowSnap
        case "voice-transcribe", "voicetranscribe", "transcribe":
            extensionType = .voiceTranscribe
        case "video-target-size", "ffmpeg", "video-compression":
            extensionType = .ffmpegVideoCompression
        case "termi-notch", "terminotch", "terminal", "terminal-notch":
            extensionType = .terminalNotch
        case "notchface", "snap-camera", "camera", "snapcam":
            extensionType = .camera
        case "quickshare", "quick-share":
            extensionType = .quickshare
        case "notification-hud", "notify-me", "notificationhud":
            extensionType = .notificationHUD
        case "caffeine", "high-alert", "highalert":
            extensionType = .caffeine
        case "menu-bar-manager", "menubarmanager":
            extensionType = .menuBarManager
        case "todo", "to-do", "tasks":
            extensionType = .todo
        default:
            print("⚠️ URLSchemeHandler: Unknown extension ID '\(extensionId)'")
            extensionType = nil
        }
        
        // Open Settings window and show the extension sheet
        DispatchQueue.main.async {
            // Bring app to front
            NSApp.activate(ignoringOtherApps: true)
            
            // Open Settings to Extensions tab with the specific extension sheet
            if let type = extensionType {
                SettingsWindowController.shared.showSettings(openingExtension: type)
                print("✅ URLSchemeHandler: Opened extension info sheet for '\(extensionId)'")
            } else {
                // Just open Settings to Extensions tab
                SettingsWindowController.shared.showSettings()
            }
        }
    }
}
