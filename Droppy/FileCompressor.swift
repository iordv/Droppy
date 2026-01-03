//
//  FileCompressor.swift
//  Droppy
//
//  Created by Jordy Spruit on 03/01/2026.
//

import Foundation
import AppKit
@preconcurrency import AVFoundation
import UniformTypeIdentifiers
import PDFKit
import Quartz

/// Quality levels for compression
enum CompressionQuality: Int, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    
    var displayName: String {
        switch self {
        case .low: return "Low (Smaller)"
        case .medium: return "Medium (Balanced)"
        case .high: return "High (Minimal Loss)"
        }
    }
    
    /// JPEG quality factor (0.0 - 1.0)
    var jpegQuality: CGFloat {
        switch self {
        case .low: return 0.3
        case .medium: return 0.6
        case .high: return 0.85
        }
    }
    
    /// Video export preset
    var videoPreset: String {
        switch self {
        case .low: return AVAssetExportPreset1280x720
        case .medium: return AVAssetExportPresetHEVC1920x1080
        case .high: return AVAssetExportPresetHighestQuality
        }
    }
}

/// Mode for compression operation
enum CompressionMode {
    case preset(CompressionQuality)
    case targetSize(bytes: Int64)
}

/// Service for compressing files (images, PDFs, videos)
class FileCompressor {
    static let shared = FileCompressor()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Check if a file can be compressed
    static func canCompress(url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image) || type.conforms(to: .pdf) || type.conforms(to: .movie) || type.conforms(to: .video)
    }
    
    /// Check if a file type can be compressed
    static func canCompress(fileType: UTType?) -> Bool {
        guard let type = fileType else { return false }
        return type.conforms(to: .image) || type.conforms(to: .pdf) || type.conforms(to: .movie) || type.conforms(to: .video)
    }
    
    /// Compress a file with the specified mode
    /// Returns the URL of the compressed file, or nil on failure
    func compress(url: URL, mode: CompressionMode) async -> URL? {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return nil }
        guard let originalSize = FileCompressor.fileSize(url: url) else { return nil }
        
        var resultURL: URL?
        
        if type.conforms(to: .image) {
            resultURL = await compressImage(url: url, mode: mode)
            
        } else if type.conforms(to: .pdf) {
            // TARGET SIZE RESTRICTION: Only allow target size for photos.
            // For PDF, fallback to Medium preset if targetSize is requested.
            let effectiveMode: CompressionMode
            if case .targetSize = mode {
                print("Target Size not supported for PDF. Falling back to Medium.")
                effectiveMode = .preset(.medium)
            } else {
                effectiveMode = mode
            }
            resultURL = await compressPDF(url: url, mode: effectiveMode)
            
        } else if type.conforms(to: .movie) || type.conforms(to: .video) {
            // TARGET SIZE RESTRICTION: Only allow target size for photos.
            // For Video, fallback to Medium preset if targetSize is requested.
            let effectiveMode: CompressionMode
            if case .targetSize = mode {
                print("Target Size not supported for Video. Falling back to Medium.")
                effectiveMode = .preset(.medium)
            } else {
                effectiveMode = mode
            }
            resultURL = await compressVideo(url: url, mode: effectiveMode)
        }
        
        // MARK: - Size Guard
        // If the compressed file is larger or equal (or basically the same), discard it.
        // This prevents the "Compression made it bigger" issue.
        if let compressed = resultURL, let newSize = FileCompressor.fileSize(url: compressed) {
            if newSize < originalSize {
                print("Compression success: \(originalSize) -> \(newSize) bytes")
                return compressed
            } else {
                print("Compression Guard: New size (\(newSize)) >= Original (\(originalSize)). Discarding result.")
                try? FileManager.default.removeItem(at: compressed)
                return nil
            }
        }
        
        return nil
    }
    
    /// Get the file size in bytes
    static func fileSize(url: URL) -> Int64? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return nil
        }
        return size
    }
    
    /// Format bytes as human-readable string
    static func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Image Compression
    
    private func compressImage(url: URL, mode: CompressionMode) async -> URL? {
        guard let image = NSImage(contentsOf: url),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        let fileName = url.deletingPathExtension().lastPathComponent
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileName)_compressed")
            .appendingPathExtension("jpg")
        
        switch mode {
        case .preset(let quality):
            guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality.jpegQuality]) else {
                return nil
            }
            try? data.write(to: outputURL)
            return outputURL
            
        case .targetSize(let bytes):
            return await compressImageToTargetSize(bitmap: bitmap, targetBytes: bytes, outputURL: outputURL)
        }
    }
    
    private func compressImageToTargetSize(bitmap: NSBitmapImageRep, targetBytes: Int64, outputURL: URL) async -> URL? {
        // Binary search for finding the right quality
        var low: CGFloat = 0.0
        var high: CGFloat = 1.0
        var bestData: Data?
        
        // Try reasonably up to 8 iterations
        var iterations = 0
        while iterations < 8 {
            let mid = (low + high) / 2
            guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: mid]) else {
                return nil
            }
            
            if Int64(data.count) < targetBytes {
                bestData = data
                // Size is okay, try higher quality
                low = mid
            } else {
                // Size too big, try lower quality
                high = mid
            }
            
            iterations += 1
        }
        
        // If we couldn't reach target, use the lowest quality
        if bestData == nil {
            bestData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.01])
        }
        
        guard let finalData = bestData else { return nil }
        
        do {
            try finalData.write(to: outputURL)
            return outputURL
        } catch {
            print("Error writing compressed image: \(error)")
            return nil
        }
    }
    
    // MARK: - PDF Compression
    
    private func compressPDF(url: URL, mode: CompressionMode) async -> URL? {
        let pdfDocument = PDFDocument(url: url)
        
        // 1. Capture original page rotations (to fix orientation after Quartz Filter potentially strips them)
        var pageRotations: [Int] = []
        if let doc = pdfDocument {
            for i in 0..<doc.pageCount {
                if let page = doc.page(at: i) {
                    pageRotations.append(page.rotation)
                } else {
                    pageRotations.append(0)
                }
            }
        }
        
        let fileName = url.deletingPathExtension().lastPathComponent
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileName)_temp_qfilter")
            .appendingPathExtension("pdf")
        
        // 2. Apply Quartz Filter (Reduce File Size)
        // This preserves vector content (text) unlike rendering to images
        if let filter = QuartzFilter(url: URL(fileURLWithPath: "/System/Library/Filters/Reduce File Size.qfilter")) {
             // Create a PDF context that applies the filter
             guard let consumer = CGDataConsumer(url: tempURL as CFURL) else { return nil }
             
             // We need a context to draw into.
             // If we pass nil for mediaBox, CoreGraphics handles it per page?
             // Actually, consumer context creation requires mediaBox in some versions, but can be nil.
             guard let context = CGContext(consumer: consumer, mediaBox: nil, nil) else { return nil }
             
             // Apply filter logic - THIS IS THE KEY for non-destructive compression steps
             // filter.apply(to: context) works on drawing contexts
             // Note: convert `context` to `CGContext?` implicitly
             filter.apply(to: context)
             
             if let doc = pdfDocument {
                 for i in 0..<doc.pageCount {
                     guard let page = doc.page(at: i) else { continue }
                     // Use existing media box
                     var pageBox = page.bounds(for: .mediaBox)
                     
                     let pageInfo = [kCGPDFContextMediaBox as String: NSData(bytes: &pageBox, length: MemoryLayout<CGRect>.size)] as CFDictionary
                     context.beginPDFPage(pageInfo)
                     
                     // Draw ORIGINAL page content
                     // This preserves text, vectors, etc.
                     page.draw(with: .mediaBox, to: context)
                     
                     context.endPDFPage()
                 }
             }
             context.closePDF()
        } else {
            // Filter not found? Just copy original? Or fail?
            return nil
        }
        
        // 3. Restore Rotations and Save Final
        // Quartz Filter often resets rotation or applies it physically. 
        // We load the temp PDF and re-apply original rotation metadata just in case.
        
        guard let compressedDoc = PDFDocument(url: tempURL) else { return nil }
        
        // Safety check page counts
        let count = min(compressedDoc.pageCount, pageRotations.count)
        
        for i in 0..<count {
            if let page = compressedDoc.page(at: i) {
                // Check if we need to restore rotation
                // Sometimes Quartz 'bakes' the rotation. If the page content is visually rotated, 
                // setting rotation again might double-rotate?
                // Visual check: page.bounds(for: .cropBox) vs original?
                // RELIABLE STRATEGY: 
                // If Quartz baked it, rotation is 0, but content is rotated.
                // If Quartz reset it, rotation is 0, content is upright (so looks wrong).
                // Usually Quartz Filter strips metadata (rotation=0) but leaves content coordinate system alone (so it looks sideways).
                // Setting rotation back to original fixes it.
                
                page.rotation = pageRotations[i]
            }
        }
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileName)_compressed")
            .appendingPathExtension("pdf")
            
        if compressedDoc.write(to: outputURL) {
            // Cleanup temp
            try? FileManager.default.removeItem(at: tempURL)
            return outputURL
        }
        
        return nil
    }
    
    // MARK: - Video Compression
    
    private func compressVideo(url: URL, mode: CompressionMode) async -> URL? {
        let asset = AVAsset(url: url)
        
        let fileName = url.deletingPathExtension().lastPathComponent
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileName)_compressed")
            .appendingPathExtension("mp4")
        
        // Remove existing file if present
        try? FileManager.default.removeItem(at: outputURL)
        
        // Always use Preset since targetSize is disallowed for Video now
        // But logic in compress() handles the fallback.
        // Here we handle the presets map.
        
        switch mode {
        case .preset(let quality):
            return await compressVideoWithPreset(asset: asset, preset: quality.videoPreset, outputURL: outputURL)
        // If somehow targetSize leaks here, handled gracefully or logic error?
        // It shouldn't if compress() works.
        case .targetSize:
             // Fallback just in case
            return await compressVideoWithPreset(asset: asset, preset: AVAssetExportPresetMediumQuality, outputURL: outputURL)
        }
    }
    
    private func compressVideoWithPreset(asset: AVAsset, preset: String, outputURL: URL) async -> URL? {
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
            return nil
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        if exportSession.status == .completed {
            return outputURL
        } else {
            print("Video export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")")
            return nil
        }
    }
}
