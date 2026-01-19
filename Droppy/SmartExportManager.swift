//
//  SmartExportManager.swift
//  Droppy
//
//  Centralized manager for automatic file export/saving
//  Handles compression, conversion, and other processed files
//

import AppKit

// MARK: - File Operation Types

enum FileOperation: String, CaseIterable, Identifiable {
    case compression = "Compression"
    case conversion = "Conversion"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var icon: String {
        switch self {
        case .compression: return "arrow.down.right.and.arrow.up.left"
        case .conversion: return "arrow.triangle.2.circlepath"
        }
    }
    
    var description: String {
        switch self {
        case .compression: return "Compressed images, videos, and PDFs"
        case .conversion: return "Converted files (PNG → JPEG, etc.)"
        }
    }
}

// MARK: - Smart Export Manager

@MainActor
final class SmartExportManager {
    static let shared = SmartExportManager()
    
    private init() {
        // Register defaults so that @AppStorage defaults match UserDefaults.bool behavior
        registerDefaults()
        
        // Migrate legacy compression settings to Smart Export on first use
        migrateFromLegacySettings()
    }
    
    // MARK: - Defaults Registration
    
    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            AppPreferenceKey.smartExportEnabled: PreferenceDefault.smartExportEnabled,
            AppPreferenceKey.smartExportCompressionEnabled: PreferenceDefault.smartExportCompressionEnabled,
            AppPreferenceKey.smartExportCompressionReveal: PreferenceDefault.smartExportCompressionReveal,
            AppPreferenceKey.smartExportConversionEnabled: PreferenceDefault.smartExportConversionEnabled,
            AppPreferenceKey.smartExportConversionReveal: PreferenceDefault.smartExportConversionReveal
        ])
    }
    
    // MARK: - Migration
    
    private func migrateFromLegacySettings() {
        let defaults = UserDefaults.standard
        
        // Only migrate if Smart Export hasn't been configured yet AND legacy was enabled
        let hasConfiguredSmartExport = defaults.object(forKey: AppPreferenceKey.smartExportEnabled) != nil
        let legacyEnabled = defaults.bool(forKey: AppPreferenceKey.compressionAutoSaveToFolder)
        
        if !hasConfiguredSmartExport && legacyEnabled {
            // Migrate legacy compression settings to Smart Export
            defaults.set(true, forKey: AppPreferenceKey.smartExportEnabled)
            defaults.set(true, forKey: AppPreferenceKey.smartExportCompressionEnabled)
            
            if let legacyFolder = defaults.string(forKey: AppPreferenceKey.compressionAutoSaveFolder), !legacyFolder.isEmpty {
                defaults.set(legacyFolder, forKey: AppPreferenceKey.smartExportCompressionFolder)
            }
            
            defaults.set(defaults.bool(forKey: AppPreferenceKey.compressionRevealInFinder), 
                        forKey: AppPreferenceKey.smartExportCompressionReveal)
            
            print("📦 SmartExportManager: Migrated legacy compression settings to Smart Export")
        }
    }
    
    // MARK: - Public API
    
    /// Whether Smart Export is enabled globally
    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: AppPreferenceKey.smartExportEnabled)
    }
    
    /// Check if auto-save is enabled for a specific operation
    func isAutoSaveEnabled(for operation: FileOperation) -> Bool {
        guard isEnabled else { return false }
        
        switch operation {
        case .compression:
            return UserDefaults.standard.bool(forKey: AppPreferenceKey.smartExportCompressionEnabled)
        case .conversion:
            return UserDefaults.standard.bool(forKey: AppPreferenceKey.smartExportConversionEnabled)
        }
    }
    
    /// Get the destination folder for a specific operation
    func destinationFolder(for operation: FileOperation) -> URL {
        let folderPath: String
        
        switch operation {
        case .compression:
            folderPath = UserDefaults.standard.string(forKey: AppPreferenceKey.smartExportCompressionFolder) ?? ""
        case .conversion:
            folderPath = UserDefaults.standard.string(forKey: AppPreferenceKey.smartExportConversionFolder) ?? ""
        }
        
        if folderPath.isEmpty {
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        }
        return URL(fileURLWithPath: folderPath)
    }
    
    /// Check if Reveal in Finder is enabled for a specific operation
    func shouldRevealInFinder(for operation: FileOperation) -> Bool {
        switch operation {
        case .compression:
            return UserDefaults.standard.bool(forKey: AppPreferenceKey.smartExportCompressionReveal)
        case .conversion:
            return UserDefaults.standard.bool(forKey: AppPreferenceKey.smartExportConversionReveal)
        }
    }
    
    /// Set the destination folder for a specific operation
    func setDestinationFolder(_ url: URL, for operation: FileOperation) {
        switch operation {
        case .compression:
            UserDefaults.standard.set(url.path, forKey: AppPreferenceKey.smartExportCompressionFolder)
        case .conversion:
            UserDefaults.standard.set(url.path, forKey: AppPreferenceKey.smartExportConversionFolder)
        }
    }
    
    /// Get display name for the current destination folder
    func destinationFolderName(for operation: FileOperation) -> String {
        let folder = destinationFolder(for: operation)
        let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? ""
        
        if folder.path == downloadsPath {
            return "Downloads"
        }
        return folder.lastPathComponent
    }
    
    // MARK: - File Saving
    
    /// Save a processed file to the configured destination (if enabled)
    /// Returns the saved URL if successful, nil if auto-save is disabled or failed
    @discardableResult
    func saveFile(_ url: URL, for operation: FileOperation) -> URL? {
        guard isAutoSaveEnabled(for: operation) else { return nil }
        
        let targetFolder = destinationFolder(for: operation)
        
        // Generate unique filename if file already exists
        var targetURL = targetFolder.appendingPathComponent(url.lastPathComponent)
        var counter = 1
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        
        while FileManager.default.fileExists(atPath: targetURL.path) {
            let newName = "\(baseName)_\(counter).\(ext)"
            targetURL = targetFolder.appendingPathComponent(newName)
            counter += 1
        }
        
        do {
            try FileManager.default.copyItem(at: url, to: targetURL)
            print("📦 SmartExport: Saved \(operation.rawValue.lowercased()) file to: \(targetURL.path)")
            
            // Reveal in Finder if enabled
            if shouldRevealInFinder(for: operation) {
                print("📦 SmartExport: Revealing in Finder...")
                // Ensure we're on main thread for AppKit calls
                DispatchQueue.main.async {
                    NSWorkspace.shared.selectFile(targetURL.path, inFileViewerRootedAtPath: targetFolder.path)
                }
            }
            
            return targetURL
        } catch {
            print("❌ SmartExport: Failed to save file: \(error.localizedDescription)")
            return nil
        }
    }
}
