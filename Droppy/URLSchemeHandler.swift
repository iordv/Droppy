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
///
/// Parameters:
/// - target: "shelf" or "basket" - where to add the files
/// - path: URL-encoded file path (can repeat for multiple files)
struct URLSchemeHandler {
    
    /// Handles an incoming droppy:// URL
    /// - Parameter url: The URL to process
    static func handle(_ url: URL) {
        print("🔗 URLSchemeHandler: Received URL: \(url.absoluteString)")
        
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
        let paths = queryItems
            .filter { $0.name == "path" }
            .compactMap { $0.value }
            .map { URL(fileURLWithPath: $0) }
        
        guard !paths.isEmpty else {
            print("⚠️ URLSchemeHandler: No file paths provided")
            return
        }
        
        print("🔗 URLSchemeHandler: Adding \(paths.count) file(s) to \(target)")
        
        // Add files to the appropriate destination
        let state = DroppyState.shared
        
        switch target.lowercased() {
        case "basket":
            // Add to floating basket
            state.addBasketItems(from: paths)
            
            // Show the basket if it's not visible
            if !state.isBasketVisible {
                state.isBasketVisible = true
                state.isBasketExpanded = true
            }
            
            // Ensure the basket window is shown
            FloatingBasketWindowController.shared.showBasket()
            
            print("✅ URLSchemeHandler: Added \(paths.count) file(s) to basket")
            
        case "shelf":
            fallthrough
        default:
            // Add to notch shelf
            state.addItems(from: paths)
            
            // Show the shelf if it's not visible
            if !state.isExpanded {
                state.isExpanded = true
            }
            
            print("✅ URLSchemeHandler: Added \(paths.count) file(s) to shelf")
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
}
