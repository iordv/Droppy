//
//  BackgroundRemovalManager.swift
//  Droppy
//
//  Created by Jordy Spruit on 11/01/2026.
//

import Foundation
@preconcurrency import Vision
import CoreImage
import AppKit
import Combine

/// Manages AI-powered background removal using Apple Vision framework
/// Uses VNGenerateForegroundInstanceMaskRequest (macOS 14+) for subject isolation
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
        
        // Load image
        guard let ciImage = CIImage(contentsOf: url) else {
            throw BackgroundRemovalError.failedToLoadImage
        }
        
        progress = 0.2
        
        // Remove background
        let outputImage = try await removeBackground(from: ciImage)
        
        progress = 0.8
        
        // Save as PNG
        let outputURL = url.deletingPathExtension()
            .appendingPathExtension("_nobg")
            .appendingPathExtension("png")
        
        let finalURL = generateUniqueURL(for: outputURL)
        try saveAsPNG(image: outputImage, to: finalURL)
        
        progress = 1.0
        
        return finalURL
    }
    
    /// Remove background from a CIImage
    /// - Parameter image: Source CIImage
    /// - Returns: CIImage with transparent background
    nonisolated func removeBackground(from image: CIImage) async throws -> CIImage {
        // Create foreground mask request
        let request = VNGenerateForegroundInstanceMaskRequest()
        
        // Create request handler
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        
        // Perform request synchronously on background thread
        try await Task.detached {
            try handler.perform([request])
        }.value
        
        // Get the mask observation
        guard let observation = request.results?.first else {
            throw BackgroundRemovalError.noMaskGenerated
        }
        
        // Generate the mask as CIImage
        let maskPixelBuffer = try observation.generateScaledMaskForImage(
            forInstances: observation.allInstances,
            from: handler
        )
        
        let maskCIImage = CIImage(cvPixelBuffer: maskPixelBuffer)
        
        // Apply mask to original image using blend filter
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            throw BackgroundRemovalError.filterCreationFailed
        }
        
        // Create transparent background
        let transparentBackground = CIImage.empty()
        
        blendFilter.setValue(image, forKey: kCIInputImageKey)
        blendFilter.setValue(transparentBackground, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(maskCIImage, forKey: kCIInputMaskImageKey)
        
        guard let outputImage = blendFilter.outputImage else {
            throw BackgroundRemovalError.blendFailed
        }
        
        return outputImage
    }
    
    // MARK: - Private Helpers
    
    private func saveAsPNG(image: CIImage, to url: URL) throws {
        let context = CIContext()
        
        // Render to CGImage
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            throw BackgroundRemovalError.renderFailed
        }
        
        // Create PNG representation
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw BackgroundRemovalError.pngEncodingFailed
        }
        
        // Write to file
        try pngData.write(to: url)
    }
    
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
}

// MARK: - Errors

enum BackgroundRemovalError: LocalizedError {
    case failedToLoadImage
    case noMaskGenerated
    case filterCreationFailed
    case blendFailed
    case renderFailed
    case pngEncodingFailed
    
    var errorDescription: String? {
        switch self {
        case .failedToLoadImage:
            return "Failed to load image"
        case .noMaskGenerated:
            return "Could not detect foreground subject"
        case .filterCreationFailed:
            return "Failed to create blend filter"
        case .blendFailed:
            return "Failed to apply mask to image"
        case .renderFailed:
            return "Failed to render output image"
        case .pngEncodingFailed:
            return "Failed to encode as PNG"
        }
    }
}
