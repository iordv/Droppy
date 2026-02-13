//
//  BackgroundRemovalManager.swift
//  Droppy
//
//  Created by Jordy Spruit on 11/01/2026.
//

import Foundation
import AppKit
import Combine

/// Manages AI-powered background removal using transparent-background Python library
@MainActor
final class BackgroundRemovalManager: ObservableObject {
    static let shared = BackgroundRemovalManager()
    
    @Published var isProcessing = false
    @Published var progress: Double = 0
    
    private init() {}
    
    // MARK: - Public API
    
    /// Remove background from an image file and save as PNG
    /// - Parameter url: URL of the source image
    /// - Returns: URL of the output image with transparent background (*_nobg.png)
    func removeBackground(from url: URL) async throws -> URL {
        // Don't process if extension is disabled
        guard !ExtensionType.aiBackgroundRemoval.isRemoved else {
            throw BackgroundRemovalError.extensionDisabled
        }
        
        isProcessing = true
        progress = 0
        defer { 
            isProcessing = false 
            progress = 1.0
        }
        
        // Verify image exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw BackgroundRemovalError.failedToLoadImage
        }
        
        progress = 0.1
        
        // Use Python transparent-background
        print("[BG Removal] Using transparent-background Python")
        let outputData = try await removeBackgroundWithPython(imageURL: url)
        progress = 0.8
        
        // Generate output path
        let baseName = url.deletingPathExtension().lastPathComponent
        let directory = url.deletingLastPathComponent()
        let outputURL = directory.appendingPathComponent("\(baseName)_nobg.png")
        let finalURL = generateUniqueURL(for: outputURL)
        
        // Write to file
        try outputData.write(to: finalURL)
        
        progress = 1.0
        
        return finalURL
    }
    
    // MARK: - Private Helpers
    
    private func generateUniqueURL(for url: URL) -> URL {
        var finalURL = url
        var counter = 1
        
        let directory = url.deletingLastPathComponent()
        let baseName = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_nobg", with: "")
        let ext = url.pathExtension
        
        while FileManager.default.fileExists(atPath: finalURL.path) {
            let newName = "\(baseName)_nobg\(counter > 1 ? "_\(counter)" : "").\(ext)"
            finalURL = directory.appendingPathComponent(newName)
            counter += 1
        }
        
        return finalURL
    }
    
    /// Remove background using Python transparent-background library
    nonisolated func removeBackgroundWithPython(imageURL: URL) async throws -> Data {
        // Create temporary output file
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent(UUID().uuidString + "_nobg.png")
        
        // Use the same Python environment that has transparent-background installed.
        guard let python = Self.findPythonWithTransparentBackground() else {
            throw BackgroundRemovalError.pythonNotInstalled
        }
        
        let escapedInputPath = Self.escapePythonPath(imageURL.path)
        let escapedOutputPath = Self.escapePythonPath(outputURL.path)
        
        // Run transparent-background command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: python)
        process.arguments = [
            "-c",
            """
            from transparent_background import Remover
            from PIL import Image
            import sys
            import gc
            
            try:
                img = Image.open('\(escapedInputPath)').convert('RGB')
                remover = Remover(mode='base')
                result = remover.process(img, type='rgba')
                result.save('\(escapedOutputPath)', 'PNG')
                
                # Explicit memory cleanup - critical for large models
                del remover
                del img
                del result
                gc.collect()
                
                print('OK')
            except Exception as e:
                print(f'ERROR: {e}', file=sys.stderr)
                sys.exit(1)
            """
        ]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: BackgroundRemovalError.pythonScriptFailed(errorMessage))
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: BackgroundRemovalError.pythonNotInstalled)
            }
        }
        
        // Read output file
        let outputData = try Data(contentsOf: outputURL)
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: outputURL)
        
        return outputData
    }
    
    nonisolated private static func escapePythonPath(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }
    
    nonisolated private static func findPythonWithTransparentBackground() -> String? {
        let pythonPaths = candidatePythonPaths()
        for path in pythonPaths {
            if isTransparentBackgroundInstalled(at: path) {
                return path
            }
        }
        return nil
    }
    
    nonisolated private static func candidatePythonPaths() -> [String] {
        var paths: [String] = [AIInstallManager.managedVenvPythonPath]
        
        if let cachedPath = UserDefaults.standard.string(forKey: "aiBackgroundRemovalPythonPath") {
            paths.append(cachedPath)
        }
        
        paths.append(contentsOf: [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
            "/usr/bin/python3"
        ])
        
        var seen: Set<String> = []
        var unique: [String] = []
        for path in paths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            if seen.insert(path).inserted {
                unique.append(path)
            }
        }
        
        return unique
    }
    
    nonisolated private static func isTransparentBackgroundInstalled(at pythonPath: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["-c", "import importlib.util, sys; sys.exit(0 if importlib.util.find_spec('transparent_background') else 1)"]
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

// MARK: - Errors

enum BackgroundRemovalError: LocalizedError {
    case failedToLoadImage
    case pythonNotInstalled
    case pythonScriptFailed(String)
    case extensionDisabled
    
    var errorDescription: String? {
        switch self {
        case .failedToLoadImage:
            return "Failed to load image"
        case .pythonNotInstalled:
            return "AI package missing. Open Extensions > AI Background Removal and run Install."
        case .pythonScriptFailed(let message):
            return "Background removal failed: \(message)"
        case .extensionDisabled:
            return "AI Background Removal is disabled"
        }
    }
}
