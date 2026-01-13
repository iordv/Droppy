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
        
        // Find Python3
        let pythonPaths = ["/usr/bin/python3", "/usr/local/bin/python3", "/opt/homebrew/bin/python3"]
        var pythonPath: String?
        for path in pythonPaths {
            if FileManager.default.fileExists(atPath: path) {
                pythonPath = path
                break
            }
        }
        
        guard let python = pythonPath else {
            throw BackgroundRemovalError.pythonNotInstalled
        }
        
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
                img = Image.open('\(imageURL.path)').convert('RGB')
                remover = Remover(mode='base')
                result = remover.process(img, type='rgba')
                result.save('\(outputURL.path)', 'PNG')
                
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
}

// MARK: - Errors

enum BackgroundRemovalError: LocalizedError {
    case failedToLoadImage
    case pythonNotInstalled
    case pythonScriptFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .failedToLoadImage:
            return "Failed to load image"
        case .pythonNotInstalled:
            return "Python or transparent-background not installed. Run: pip3 install transparent-background"
        case .pythonScriptFailed(let message):
            return "Background removal failed: \(message)"
        }
    }
}
