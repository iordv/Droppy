//
//  AIInstallManager.swift
//  Droppy
//
//  Created by Droppy on 11/01/2026.
//  Manages installation of AI background removal dependencies
//

import Foundation
import Combine

/// Manages the installation of Python transparent-background package
@MainActor
final class AIInstallManager: ObservableObject {
    static let shared = AIInstallManager()
    
    @Published var isInstalled = false
    @Published var isInstalling = false
    @Published var installProgress: String = ""
    @Published var installError: String?
    
    private let installedCacheKey = "aiBackgroundRemovalInstalled"
    
    private init() {
        // Load cached status immediately for instant UI response
        isInstalled = UserDefaults.standard.bool(forKey: installedCacheKey)
        
        // Verify in background (only if cached as installed to avoid slow startup)
        if isInstalled {
            Task {
                let actuallyInstalled = await checkTransparentBackgroundInstalled()
                if actuallyInstalled != isInstalled {
                    isInstalled = actuallyInstalled
                    UserDefaults.standard.set(actuallyInstalled, forKey: installedCacheKey)
                }
            }
        }
    }
    
    // MARK: - Installation Check
    
    func checkInstallationStatus() {
        Task {
            let installed = await checkTransparentBackgroundInstalled()
            isInstalled = installed
            UserDefaults.standard.set(installed, forKey: installedCacheKey)
        }
    }
    
    private func checkTransparentBackgroundInstalled() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-c", "import transparent_background; print('OK')"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        do {
            try process.run()
            
            // Non-blocking wait using async continuation
            await withCheckedContinuation { continuation in
                process.terminationHandler = { _ in
                    continuation.resume()
                }
            }
            
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    // MARK: - Installation
    
    /// Find Python 3 path, checking multiple locations
    private func findPython3() -> String? {
        let pythonPaths = [
            "/usr/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3"
        ]
        
        for path in pythonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
    
    /// Check if Xcode Command Line Tools are installed
    private func isXcodeCliInstalled() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["-p"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        do {
            try process.run()
            await withCheckedContinuation { continuation in
                process.terminationHandler = { _ in
                    continuation.resume()
                }
            }
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    /// Trigger Xcode Command Line Tools installation (shows macOS dialog)
    private func triggerXcodeCliInstall() async -> Bool {
        installProgress = "Installing Python 3 (Xcode Command Line Tools)..."
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["--install"]
        
        do {
            try process.run()
            
            // This opens a macOS dialog - user needs to click Install
            // We wait a bit and then check if Python3 becomes available
            installProgress = "Waiting for Xcode Command Line Tools installation..."
            
            // Check every 5 seconds for up to 10 minutes
            for _ in 0..<120 {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                
                if findPython3() != nil {
                    installProgress = "Python 3 installed successfully!"
                    return true
                }
            }
            
            return false
        } catch {
            return false
        }
    }
    
    func installTransparentBackground() async {
        isInstalling = true
        installProgress = "Starting installation..."
        installError = nil
        
        defer {
            isInstalling = false
            checkInstallationStatus()
        }
        
        // Step 1: Check if Python3 is available
        var pythonPath = findPython3()
        
        if pythonPath == nil {
            // Try to install via Xcode Command Line Tools
            installProgress = "Python 3 not found. Installing..."
            
            let installed = await triggerXcodeCliInstall()
            if !installed {
                installError = "Python 3 installation cancelled or failed. Please install Python from python.org"
                return
            }
            
            pythonPath = findPython3()
        }
        
        guard let python = pythonPath else {
            installError = "Python 3 not found after installation attempt."
            return
        }
        
        installProgress = "Installing transparent-background package..."
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: python)
        process.arguments = ["-m", "pip", "install", "--user", "--upgrade", "transparent-background"]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Note: Real-time progress removed for Swift 6 concurrency compliance
        // Show generic progress instead
        installProgress = "Downloading and installing packages..."
        
        do {
            try process.run()
            
            // Wait for completion
            await withCheckedContinuation { continuation in
                process.terminationHandler = { _ in
                    continuation.resume()
                }
            }
            
            // Process completed
            
            if process.terminationStatus == 0 {
                installProgress = "✅ Installation complete!"
                isInstalled = true
                
                // Enable the feature
                UserDefaults.standard.set(true, forKey: "useLocalBackgroundRemoval")
                
                // Track extension activation
                AnalyticsService.shared.trackExtensionActivation(extensionId: "aiBackgroundRemoval")
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                installError = "Installation failed: \(errorOutput)"
            }
        } catch {
            installError = "Failed to start installation: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Uninstall
    
    func uninstallTransparentBackground() async {
        isInstalling = true
        installProgress = "Removing package..."
        
        defer {
            isInstalling = false
            checkInstallationStatus()
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-m", "pip", "uninstall", "-y", "transparent-background"]
        
        do {
            try process.run()
            
            // Non-blocking wait using async continuation
            await withCheckedContinuation { continuation in
                process.terminationHandler = { _ in
                    continuation.resume()
                }
            }
            
            if process.terminationStatus == 0 {
                isInstalled = false
                UserDefaults.standard.set(false, forKey: "useLocalBackgroundRemoval")
            }
        } catch {
            installError = "Failed to uninstall: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Extension Removal Cleanup
    
    /// Clean up all AI Background Removal resources when extension is removed
    func cleanup() {
        Task {
            // Uninstall the Python package
            await uninstallTransparentBackground()
            
            // Clear cached state
            UserDefaults.standard.removeObject(forKey: installedCacheKey)
            UserDefaults.standard.removeObject(forKey: "useLocalBackgroundRemoval")
            UserDefaults.standard.removeObject(forKey: "aiBackgroundRemovalTracked")
            
            // Reset state
            isInstalled = false
            installProgress = ""
            installError = nil
            
            print("[AIInstallManager] Cleanup complete")
        }
    }
}
