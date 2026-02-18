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
    
    /// Check if target size compression is available for videos (requires FFmpeg extension)
    static var isVideoTargetSizeAvailable: Bool {
        !ExtensionType.ffmpegVideoCompression.isRemoved && FFmpegInstallManager.shared.isInstalled
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
            // Video compression with target size is now supported
            resultURL = await compressVideo(url: url, mode: mode)
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
        let asset = AVURLAsset(url: url)
        
        let fileName = url.deletingPathExtension().lastPathComponent
        
        switch mode {
        case .preset(let quality):
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(fileName)_compressed")
                .appendingPathExtension("mp4")
            // Remove existing file if present
            try? FileManager.default.removeItem(at: outputURL)
            return await compressVideoWithPreset(asset: asset, preset: quality.videoPreset, outputURL: outputURL)
            
        case .targetSize(let targetBytes):
            let outputDirectory = preferredOutputDirectory(for: url)
            let outputURL = uniqueOutputURL(
                baseName: "\(fileName)_compressed",
                ext: "mp4",
                in: outputDirectory
            )
            return await compressVideoToTargetSize(asset: asset, targetBytes: targetBytes, outputURL: outputURL)
        }
    }

    /// Prefer exporting next to the source file, unless the source lives in temporary storage.
    /// In that case, export to Downloads so users can actually find the result.
    private func preferredOutputDirectory(for sourceURL: URL) -> URL {
        let sourceDirectory = sourceURL.deletingLastPathComponent().standardizedFileURL
        let tempDirectory = FileManager.default.temporaryDirectory.standardizedFileURL

        if sourceDirectory.path.hasPrefix(tempDirectory.path) {
            if let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                return downloads
            }
        }

        return sourceDirectory
    }

    private func uniqueOutputURL(baseName: String, ext: String, in directory: URL) -> URL {
        var candidate = directory.appendingPathComponent(baseName).appendingPathExtension(ext)
        var counter = 1

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory
                .appendingPathComponent("\(baseName)_\(counter)")
                .appendingPathExtension(ext)
            counter += 1
        }

        return candidate
    }
    
    private func compressVideoWithPreset(asset: AVAsset, preset: String, outputURL: URL) async -> URL? {
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
            return nil
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Use modern async throws API (macOS 15+) with fallback
        if #available(macOS 15.0, *) {
            do {
                try await exportSession.export(to: outputURL, as: .mp4)
                return outputURL
            } catch {
                print("Video export failed: \(error.localizedDescription)")
                return nil
            }
        } else {
            // Legacy API for older macOS
            await exportSession.export()
            if exportSession.status == .completed {
                return outputURL
            } else {
                print("Video export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")")
                return nil
            }
        }
    }
    
    /// Compress video to target file size using FFmpeg two-pass encoding
    /// This provides exact file size targeting like compressO
    private func compressVideoToTargetSize(asset: AVAsset, targetBytes: Int64, outputURL: URL) async -> URL? {
        // Get video duration
        guard let duration = try? await asset.load(.duration) else {
            print("Video compression: Failed to load duration")
            return nil
        }
        
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds > 0 else {
            print("Video compression: Invalid duration")
            return nil
        }
        
        // Get source URL from asset
        guard let urlAsset = asset as? AVURLAsset else {
            print("Video compression: Asset is not a URL asset")
            return nil
        }
        let inputURL = urlAsset.url
        
        // Calculate target bitrate (in kbps for FFmpeg)
        // Formula: videoBitrate = (targetBytes * 8 - audioBitrate * duration) / duration
        let audioBitrateKbps = 128 // 128 kbps for audio
        let targetBits = Double(targetBytes) * 8
        let audioBits = Double(audioBitrateKbps * 1000) * durationSeconds
        let videoBits = max(targetBits - audioBits, 50_000 * durationSeconds) // Min 50kbps
        let videoBitrateKbps = Int(videoBits / durationSeconds / 1000)
        
        print("Video compression (FFmpeg): Duration=\(durationSeconds)s, Target=\(targetBytes) bytes, VideoBitrate=\(videoBitrateKbps)k")
        
        // Find FFmpeg path from install manager
        guard let ffmpegPath = FFmpegInstallManager.shared.findFFmpegPath() else {
            print("Video compression: FFmpeg not found. Please install the Video Target Size extension.")
            return nil
        }
        
        // Create temp directory for two-pass log files
        let tempDir = FileManager.default.temporaryDirectory
        let passLogPrefix = tempDir.appendingPathComponent("ffmpeg2pass_\(UUID().uuidString)").path
        
        // Pass 1: Analyze video
        let pass1Args = [
            "-hide_banner",
            "-y", "-i", inputURL.path,
            "-map", "0:v:0",
            "-c:v", "libx264",
            "-b:v", "\(videoBitrateKbps)k",
            "-pass", "1",
            "-passlogfile", passLogPrefix,
            "-an", // No audio in pass 1
            "-sn", // Skip subtitles (often incompatible with MP4 output)
            "-dn", // Skip data streams/attachments
            "-f", "null", "-"
        ]
        
        print("Video compression: Running pass 1…")
        let pass1Success = await runFFmpeg(path: ffmpegPath, arguments: pass1Args)
        guard pass1Success else {
            print("Video compression: Pass 1 failed")
            cleanupPassLogs(prefix: passLogPrefix)
            return nil
        }
        
        // Pass 2: Encode with target bitrate
        let pass2Args = [
            "-hide_banner",
            "-y", "-i", inputURL.path,
            "-map", "0:v:0",
            "-map", "0:a?",
            "-c:v", "libx264",
            "-b:v", "\(videoBitrateKbps)k",
            "-pass", "2",
            "-passlogfile", passLogPrefix,
            "-c:a", "aac",
            "-b:a", "\(audioBitrateKbps)k",
            "-sn", // Skip subtitle streams (prevents MKV->MP4 failures)
            "-dn", // Skip data streams/attachments
            "-movflags", "+faststart",
            outputURL.path
        ]
        
        print("Video compression: Running pass 2…")
        let pass2Success = await runFFmpeg(path: ffmpegPath, arguments: pass2Args)
        
        // Cleanup pass log files
        cleanupPassLogs(prefix: passLogPrefix)
        
        if pass2Success {
            print("Video compression: FFmpeg success")
            return outputURL
        } else {
            print("Video compression: Pass 2 failed")
            return nil
        }
    }
    
    /// Run FFmpeg with arguments
    private func runFFmpeg(path: String, arguments: [String]) async -> Bool {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            
            // Route output to null to avoid pipe backpressure deadlocks with verbose ffmpeg logs.
            process.standardError = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            
            do {
                process.terminationHandler = { process in
                    let didSucceed = process.terminationStatus == 0
                    if !didSucceed {
                        print("FFmpeg process exited with status \(process.terminationStatus)")
                    }
                    continuation.resume(returning: didSucceed)
                }
                try process.run()
            } catch {
                print("FFmpeg process error: \(error)")
                continuation.resume(returning: false)
            }
        }
    }
    
    /// Cleanup two-pass log files
    private func cleanupPassLogs(prefix: String) {
        let fm = FileManager.default
        let logFile = prefix + "-0.log"
        let mbtreeFile = prefix + "-0.log.mbtree"
        try? fm.removeItem(atPath: logFile)
        try? fm.removeItem(atPath: mbtreeFile)
    }
}
