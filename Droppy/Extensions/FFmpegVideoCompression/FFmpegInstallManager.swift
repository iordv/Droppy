//
//  FFmpegInstallManager.swift
//  Droppy
//
//  Manages FFmpeg installation for video target size compression
//

import Foundation
import Combine

/// Manages the installation of FFmpeg for video compression
@MainActor
final class FFmpegInstallManager: ObservableObject {
    static let shared = FFmpegInstallManager()
    
    @Published var isInstalled = false
    @Published var isInstalling = false
    @Published var installProgress: String = ""
    @Published var installError: String?
    
    private let installedCacheKey = "ffmpeg_installed_cache"
    
    private init() {
        // Check cached value first for instant UI
        isInstalled = UserDefaults.standard.bool(forKey: installedCacheKey)
        // Then verify actual installation
        checkInstallationStatus()
    }
    
    func checkInstallationStatus() {
        Task {
            let installed = findFFmpegPath() != nil
            isInstalled = installed
            UserDefaults.standard.set(installed, forKey: installedCacheKey)
        }
    }
    
    // MARK: - FFmpeg Detection
    
    /// Find FFmpeg binary path
    func findFFmpegPath() -> String? {
        // Common locations
        let paths = [
            "/opt/homebrew/bin/ffmpeg",  // Apple Silicon Homebrew
            "/usr/local/bin/ffmpeg",      // Intel Homebrew
            "/usr/bin/ffmpeg",            // System
            "/opt/local/bin/ffmpeg"       // MacPorts
        ]
        
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Try to find via which
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        } catch {
            // Ignore
        }
        
        return nil
    }
    
    // MARK: - Homebrew Detection
    
    /// Check if Homebrew is installed (public for UI)
    var isHomebrewInstalled: Bool {
        // Apple Silicon
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") {
            return true
        }
        // Intel
        if FileManager.default.fileExists(atPath: "/usr/local/bin/brew") {
            return true
        }
        return false
    }
    
    /// Get Homebrew path
    private func homebrewPath() -> String? {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") {
            return "/opt/homebrew/bin/brew"
        }
        if FileManager.default.fileExists(atPath: "/usr/local/bin/brew") {
            return "/usr/local/bin/brew"
        }
        return nil
    }
    
    // MARK: - Installation
    
    /// Install FFmpeg using Homebrew
    func installFFmpeg() async {
        isInstalling = true
        installProgress = "Checking prerequisites..."
        installError = nil
        
        defer {
            isInstalling = false
            checkInstallationStatus()
        }
        
        // Check if already installed
        if findFFmpegPath() != nil {
            installProgress = "FFmpeg is already installed!"
            isInstalled = true
            return
        }
        
        // Check for Homebrew
        guard let brewPath = homebrewPath() else {
            installError = "Homebrew is required. Visit brew.sh to install it first."
            installProgress = ""
            return
        }
        
        installProgress = "Installing FFmpeg via Homebrew..."
        
        // Run brew install ffmpeg
        let process = Process()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = ["install", "ffmpeg"]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            
            installProgress = "Downloading and installing FFmpeg..."
            
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                installProgress = "FFmpeg installed successfully!"
                isInstalled = true
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                installError = "Installation failed: \(errorOutput.prefix(200))"
                installProgress = ""
            }
        } catch {
            installError = "Failed to start installation: \(error.localizedDescription)"
            installProgress = ""
        }
    }
    
    // MARK: - Uninstall
    
    func uninstallFFmpeg() async {
        isInstalling = true
        installProgress = "Removing FFmpeg..."
        
        defer {
            isInstalling = false
            checkInstallationStatus()
        }
        
        guard let brewPath = homebrewPath() else {
            installError = "Homebrew not found"
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = ["uninstall", "ffmpeg"]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                installProgress = "FFmpeg removed successfully"
                isInstalled = false
            } else {
                installError = "Failed to uninstall FFmpeg"
            }
        } catch {
            installError = "Failed to uninstall: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Cleanup
    
    /// Clean up when extension is removed
    func cleanup() {
        // Just clear the cached state - we don't actually uninstall FFmpeg
        // as users may want to keep it for other purposes
        UserDefaults.standard.removeObject(forKey: installedCacheKey)
        isInstalled = false
        installProgress = ""
        installError = nil
        
        print("[FFmpegInstallManager] Cleanup complete")
    }
}
