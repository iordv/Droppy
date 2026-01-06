//
//  UpdateChecker.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import Foundation
import AppKit
import Combine

/// Lightweight update checker that uses GitHub releases API
@MainActor
class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()
    
    /// GitHub repository info
    private let owner = "iordv"
    private let repo = "Droppy"
    
    /// Background update check interval: 24 hours (industry standard)
    private let checkInterval: TimeInterval = 86400
    
    /// Timer fires hourly to evaluate if a daily check is needed
    private var backgroundTimer: Timer?
    
    /// UserDefaults key for last auto-check timestamp
    private let lastCheckKey = "lastAutoUpdateCheck"
    
    /// Current app version
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    /// Published properties for UI binding
    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var downloadURL: URL?
    @Published var releaseNotes: String?
    @Published var isChecking = false
    
    private init() {}
    
    // MARK: - Background Update Scheduling
    
    /// Start the background update scheduler. Call once at app launch.
    func startBackgroundChecking() {
        print("UpdateChecker: Starting background update scheduler (interval: \(Int(checkInterval / 3600))h)")
        
        // Perform initial check if needed
        checkIfDailyCheckNeeded()
        
        // Schedule hourly timer to evaluate if 24h have passed
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            guard let checker = self else { return }
            Task { @MainActor in
                checker.checkIfDailyCheckNeeded()
            }
        }
    }
    
    /// Evaluate if 24 hours have passed since last check
    private func checkIfDailyCheckNeeded() {
        let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? .distantPast
        let hoursSinceLastCheck = Date().timeIntervalSince(lastCheck) / 3600
        
        if hoursSinceLastCheck >= 24 {
            print("UpdateChecker: Performing daily update check (last check: \(Int(hoursSinceLastCheck))h ago)")
            performBackgroundCheck()
        } else {
            print("UpdateChecker: Skipping check, last check was \(Int(hoursSinceLastCheck))h ago")
        }
    }
    
    /// Perform background check and show update window if available
    private func performBackgroundCheck() {
        Task {
            await checkForUpdates()
            
            // Record successful check
            UserDefaults.standard.set(Date(), forKey: lastCheckKey)
            
            if updateAvailable {
                showUpdateWindow()
            }
        }
    }
    
    /// Check for updates from GitHub releases
    func checkForUpdates() async {
        guard !isChecking else { return }
        
        isChecking = true
        defer { isChecking = false }
        
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("UpdateChecker: Failed to fetch releases")
                return
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                print("UpdateChecker: Invalid response format")
                return
            }
            
            // Parse version (remove 'v' prefix if present)
            let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            
            latestVersion = remoteVersion
            releaseNotes = json["body"] as? String
            
            // Find DMG download URL from assets
            if let assets = json["assets"] as? [[String: Any]] {
                for asset in assets {
                    if let name = asset["name"] as? String,
                       name.lowercased().hasSuffix(".dmg"),
                       let urlString = asset["browser_download_url"] as? String,
                       let assetURL = URL(string: urlString) {
                        downloadURL = assetURL
                        break
                    }
                }
            }
            
            updateAvailable = isNewerVersion(remoteVersion, than: currentVersion)
            print("UpdateChecker: Check complete. Update available: \(updateAvailable) (\(currentVersion) → \(remoteVersion))")
            
        } catch {
            print("UpdateChecker: Error checking for updates: \(error)")
        }
    }
    
    /// Compare version strings (supports semantic versioning)
    private func isNewerVersion(_ remote: String, than current: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(remoteParts.count, currentParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            
            if r > c { return true }
            if r < c { return false }
        }
        
        return false
    }
    
    /// Show update window to user
    func showUpdateWindow() {
        guard updateAvailable, latestVersion != nil else { return }
        UpdateWindowController.shared.showWindow()
    }
    
    // Removed old update methods as they are replaced by AutoUpdater
    
    /// Check for updates and always show feedback to user
    func checkAndNotify() {
        Task {
            await checkForUpdates()
            if updateAvailable {
                showingUpToDate = false
                showUpdateWindow()
            } else {
                showUpToDateWindow()
            }
        }
    }
    
    /// Published property to indicate we're showing "up to date" state
    @Published var showingUpToDate = false
    
    /// Show the "up to date" styled window instead of NSAlert
    func showUpToDateWindow() {
        showingUpToDate = true
        UpdateWindowController.shared.showWindow()
    }
}
