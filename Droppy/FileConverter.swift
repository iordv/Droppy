//
//  FileConverter.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

/// Represents a file format that can be converted to
enum ConversionFormat: String, CaseIterable, Identifiable {
    case jpeg = "JPEG"
    case png = "PNG"
    case pdf = "PDF"
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .pdf: return "pdf"
        }
    }
    
    var bitmapType: NSBitmapImageRep.FileType? {
        switch self {
        case .jpeg: return .jpeg
        case .png: return .png
        case .pdf: return nil // PDF uses native apps or LibreOffice
        }
    }
    
    var displayName: String {
        switch self {
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        case .pdf: return "PDF"
        }
    }
    
    var icon: String {
        switch self {
        case .jpeg: return "photo"
        case .png: return "photo.fill"
        case .pdf: return "doc.richtext"
        }
    }
}

/// A conversion option presented in the context menu
struct ConversionOption: Identifiable {
    let id = UUID()
    let format: ConversionFormat
    
    var displayName: String { format.displayName }
    var icon: String { format.icon }
}

/// Utility class for converting files between formats using native macOS APIs
class FileConverter {
    
    // MARK: - Available Conversions
    
    /// Returns available conversion options for a given file type
    static func availableConversions(for fileType: UTType?) -> [ConversionOption] {
        guard let fileType = fileType else { return [] }
        
        var options: [ConversionOption] = []
        
        // Image conversions
        if fileType.conforms(to: .image) {
            // If it's a PNG, offer JPEG
            if fileType.conforms(to: .png) {
                options.append(ConversionOption(format: .jpeg))
            }
            // If it's a JPEG, offer PNG
            else if fileType.conforms(to: .jpeg) {
                options.append(ConversionOption(format: .png))
            }
            // For other image formats (HEIC, TIFF, BMP, GIF), offer both
            else if fileType.conforms(to: .heic) ||
                    fileType.conforms(to: .tiff) ||
                    fileType.conforms(to: .bmp) ||
                    fileType.conforms(to: .gif) {
                options.append(ConversionOption(format: .jpeg))
                options.append(ConversionOption(format: .png))
            }
        }
        
        // Document to PDF conversions (via Cloudmersive API)
        // Word documents
        if fileType.conforms(to: UTType("org.openxmlformats.wordprocessingml.document") ?? .data) ||
           fileType.conforms(to: UTType("com.microsoft.word.doc") ?? .data) ||
           fileType.identifier == "org.openxmlformats.wordprocessingml.document" ||
           fileType.identifier == "com.microsoft.word.doc" {
            options.append(ConversionOption(format: .pdf))
        }
        
        // Excel spreadsheets
        if fileType.conforms(to: UTType("org.openxmlformats.spreadsheetml.sheet") ?? .data) ||
           fileType.conforms(to: UTType("com.microsoft.excel.xls") ?? .data) ||
           fileType.identifier == "org.openxmlformats.spreadsheetml.sheet" ||
           fileType.identifier == "com.microsoft.excel.xls" {
            options.append(ConversionOption(format: .pdf))
        }
        
        // PowerPoint presentations
        if fileType.conforms(to: UTType("org.openxmlformats.presentationml.presentation") ?? .data) ||
           fileType.conforms(to: UTType("com.microsoft.powerpoint.ppt") ?? .data) ||
           fileType.identifier == "org.openxmlformats.presentationml.presentation" ||
           fileType.identifier == "com.microsoft.powerpoint.ppt" {
            options.append(ConversionOption(format: .pdf))
        }
        
        return options
    }
    
    // MARK: - Conversion Methods
    
    /// Converts a file to the specified format
    /// Returns the URL of the converted file (in temp directory), or nil if conversion failed
    static func convert(_ url: URL, to format: ConversionFormat) async -> URL? {
        // Generate output URL in temp directory
        let tempDirectory = FileManager.default.temporaryDirectory
        let filename = url.deletingPathExtension().lastPathComponent + "." + format.fileExtension
        let outputURL = tempDirectory.appendingPathComponent(filename)
        
        // Ensure unique filename in temp
        let finalURL = uniqueURL(for: outputURL)
        
        // Route to appropriate converter
        if format == .pdf {
            return await convertDocumentToPDF(from: url, to: finalURL)
        } else {
            return await convertImage(from: url, to: finalURL, format: format)
        }
    }
    
    /// Moves a converted file to the Downloads folder
    /// Returns the final URL in Downloads, or nil if move failed
    static func saveToDownloads(_ tempURL: URL) -> URL? {
        let fileManager = FileManager.default
        
        guard let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            print("FileConverter: Could not find Downloads folder")
            return nil
        }
        
        let destinationURL = uniqueURL(for: downloadsURL.appendingPathComponent(tempURL.lastPathComponent))
        
        do {
            try fileManager.moveItem(at: tempURL, to: destinationURL)
            print("FileConverter: Saved to Downloads: \(destinationURL.lastPathComponent)")
            return destinationURL
        } catch {
            print("FileConverter: Failed to move to Downloads: \(error)")
            return nil
        }
    }
    
    // MARK: - Image Conversion
    
    private static func convertImage(from sourceURL: URL, to destinationURL: URL, format: ConversionFormat) async -> URL? {
        guard let image = NSImage(contentsOf: sourceURL) else {
            print("FileConverter: Failed to load image from \(sourceURL)")
            return nil
        }
        
        // Get the best representation
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            print("FileConverter: Failed to create bitmap representation")
            return nil
        }
        
        guard let bitmapType = format.bitmapType else {
            print("FileConverter: Format \(format.displayName) does not support bitmap conversion")
            return nil
        }
        
        // Set compression quality for JPEG
        var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]
        if format == .jpeg {
            properties[.compressionFactor] = 0.9 // High quality JPEG
        }
        
        // Convert to target format
        guard let outputData = bitmapRep.representation(using: bitmapType, properties: properties) else {
            print("FileConverter: Failed to convert to \(format.displayName)")
            return nil
        }
        
        // Write to file
        do {
            try outputData.write(to: destinationURL)
            print("FileConverter: Successfully converted to \(destinationURL.lastPathComponent)")
            return destinationURL
        } catch {
            print("FileConverter: Failed to write file: \(error)")
            return nil
        }
    }
    
    /// Returns the specific app name required to convert this file type to PDF
    static func requiredAppForPDFConversion(fileType: UTType?) -> String? {
        guard let fileType = fileType else { return nil }
        
        // PowerPoint → Keynote
        if fileType.conforms(to: UTType("org.openxmlformats.presentationml.presentation") ?? .data) ||
           fileType.conforms(to: UTType("com.microsoft.powerpoint.ppt") ?? .data) ||
           fileType.identifier == "org.openxmlformats.presentationml.presentation" ||
           fileType.identifier == "com.microsoft.powerpoint.ppt" {
            return "Keynote"
        }
        
        // Word → Pages
        if fileType.conforms(to: UTType("org.openxmlformats.wordprocessingml.document") ?? .data) ||
           fileType.conforms(to: UTType("com.microsoft.word.doc") ?? .data) ||
           fileType.identifier == "org.openxmlformats.wordprocessingml.document" ||
           fileType.identifier == "com.microsoft.word.doc" {
            return "Pages"
        }
        
        // Excel → Numbers
        if fileType.conforms(to: UTType("org.openxmlformats.spreadsheetml.sheet") ?? .data) ||
           fileType.conforms(to: UTType("com.microsoft.excel.xls") ?? .data) ||
           fileType.identifier == "org.openxmlformats.spreadsheetml.sheet" ||
           fileType.identifier == "com.microsoft.excel.xls" {
            return "Numbers"
        }
        
        return nil
    }
    // MARK: - Document to PDF Conversion (via Native macOS iWork Apps)
    
    private static func convertDocumentToPDF(from sourceURL: URL, to destinationURL: URL) async -> URL? {
        let fileExtension = sourceURL.pathExtension.lowercased()
        
        // Route to appropriate native converter
        switch fileExtension {
        case "pptx", "ppt":
            return await convertViaNativeApp(from: sourceURL, to: destinationURL, app: .keynote)
        case "docx", "doc":
            return await convertViaNativeApp(from: sourceURL, to: destinationURL, app: .pages)
        case "xlsx", "xls":
            return await convertViaNativeApp(from: sourceURL, to: destinationURL, app: .numbers)
        default:
            // Fall back to LibreOffice for unsupported formats
            return await convertDocumentToPDFViaLibreOffice(from: sourceURL, to: destinationURL)
        }
    }
    
    /// Native iWork app types for conversion
    private enum IWorkApp: String {
        case keynote = "Keynote"
        case pages = "Pages"
        case numbers = "Numbers"
        
        /// Bundle identifier for the app
        var bundleIdentifier: String {
            switch self {
            case .keynote: return "com.apple.iWork.Keynote"
            case .pages: return "com.apple.iWork.Pages"
            case .numbers: return "com.apple.iWork.Numbers"
            }
        }
        
        /// Check if the app is installed
        var isInstalled: Bool {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
        }
    }
    
    /// Convert document using native iWork app via AppleScript
    /// Preserves original layout optimally since iWork apps have excellent Office format support
    private static func convertViaNativeApp(from sourceURL: URL, to destinationURL: URL, app: IWorkApp) async -> URL? {
        // Check if app is installed first to avoid crash/dialog
        guard app.isInstalled else {
            print("FileConverter: \(app.rawValue) is not installed, falling back to LibreOffice")
            return await convertDocumentToPDFViaLibreOffice(from: sourceURL, to: destinationURL)
        }
        
        // Escape paths for AppleScript
        let sourcePath = sourceURL.path.replacingOccurrences(of: "\"", with: "\\\"")
        let destPath = destinationURL.path.replacingOccurrences(of: "\"", with: "\\\"")
        
        let script: String
        switch app {
        case .keynote:
            script = """
            tell application "Keynote"
                activate
                open POSIX file "\(sourcePath)"
                delay 1
                set theDoc to front document
                export theDoc to POSIX file "\(destPath)" as PDF with properties {PDF image quality:Best}
                close theDoc saving no
            end tell
            """
        case .pages:
            script = """
            tell application "Pages"
                activate
                open POSIX file "\(sourcePath)"
                delay 1
                set theDoc to front document
                export theDoc to POSIX file "\(destPath)" as PDF with properties {image quality:Best}
                close theDoc saving no
            end tell
            """
        case .numbers:
            script = """
            tell application "Numbers"
                activate
                open POSIX file "\(sourcePath)"
                delay 1
                set theDoc to front document
                export theDoc to POSIX file "\(destPath)" as PDF with properties {image quality:Best}
                close theDoc saving no
            end tell
            """
        }
        
        // Execute AppleScript
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let errorDescription: String? = AppleScriptRuntime.execute {
                    var error: NSDictionary?
                    guard let appleScript = NSAppleScript(source: script) else {
                        return "Failed to create AppleScript for \(app.rawValue)"
                    }
                    appleScript.executeAndReturnError(&error)
                    return error.map { "\($0)" }
                }

                if let errorDescription {
                    print("FileConverter: AppleScript error for \(app.rawValue): \(errorDescription)")
                    Task {
                        let fallbackResult = await convertDocumentToPDFViaLibreOffice(from: sourceURL, to: destinationURL)
                        continuation.resume(returning: fallbackResult)
                    }
                    return
                }

                // Verify the file was created
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    print("FileConverter: Successfully converted to PDF via \(app.rawValue)")
                    continuation.resume(returning: destinationURL)
                } else {
                    print("FileConverter: \(app.rawValue) export completed but file not found")
                    Task {
                        let fallbackResult = await convertDocumentToPDFViaLibreOffice(from: sourceURL, to: destinationURL)
                        continuation.resume(returning: fallbackResult)
                    }
                }
            }
        }
    }
    
    // MARK: - Fallback: LibreOffice CLI
    
    /// Common LibreOffice installation paths on macOS
    private static let libreOfficePaths = [
        "/Applications/LibreOffice.app/Contents/MacOS/soffice",
        "/opt/homebrew/bin/soffice",
        "/usr/local/bin/soffice"
    ]
    
    /// Check if LibreOffice is installed and return the path
    private static var libreOfficePath: String? {
        for path in libreOfficePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
    
    /// Convert document using LibreOffice command-line (headless mode)
    private static func convertDocumentToPDFViaLibreOffice(from sourceURL: URL, to destinationURL: URL) async -> URL? {
        guard let sofficePath = libreOfficePath else {
            print("FileConverter: No PDF converter available. Install Keynote/Pages/Numbers (free from App Store) or LibreOffice.")
            return nil
        }
        
        // LibreOffice converts to a directory, not a specific file
        let outputDir = destinationURL.deletingLastPathComponent()
        
        // Run LibreOffice in headless mode
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sofficePath)
        process.arguments = [
            "--headless",
            "--convert-to", "pdf",
            "--outdir", outputDir.path,
            sourceURL.path
        ]
        
        // Suppress output
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            
            // Wait for completion
            await withCheckedContinuation { continuation in
                process.terminationHandler = { _ in
                    continuation.resume()
                }
            }
            
            if process.terminationStatus == 0 {
                // LibreOffice outputs with the same basename but .pdf extension
                let expectedPDF = outputDir.appendingPathComponent(
                    sourceURL.deletingPathExtension().lastPathComponent + ".pdf"
                )
                
                // Rename to our desired destination if different
                if expectedPDF.path != destinationURL.path {
                    try? FileManager.default.moveItem(at: expectedPDF, to: destinationURL)
                }
                
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    print("FileConverter: Successfully converted to PDF via LibreOffice")
                    return destinationURL
                }
            }
            
            print("FileConverter: LibreOffice conversion failed")
            return nil
            
        } catch {
            print("FileConverter: LibreOffice process error: \(error)")
            return nil
        }
    }
    
    // MARK: - ZIP Creation
    
    /// Creates a ZIP archive from multiple files
    /// Returns the URL of the created ZIP file (in temp directory), or nil if creation failed
    static func createZIP(from items: [DroppedItem], archiveName: String? = nil) async -> URL? {
        guard !items.isEmpty else { return nil }
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let zipName = archiveName ?? "Archive"
        let zipFilename = zipName + ".zip"
        let zipURL = uniqueURL(for: tempDirectory.appendingPathComponent(zipFilename))
        
        // Create a temporary work directory to hold file copies
        let workDir = tempDirectory.appendingPathComponent(UUID().uuidString)
        
        do {
            try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        } catch {
            print("FileConverter: Failed to create work directory: \(error)")
            return nil
        }
        
        // Copy files to work directory (handles files from different locations)
        var filenames: [String] = []
        for item in items {
            var destFilename = item.name
            var destURL = workDir.appendingPathComponent(destFilename)
            
            // Handle duplicate filenames within the archive
            var counter = 1
            while FileManager.default.fileExists(atPath: destURL.path) {
                let name = item.url.deletingPathExtension().lastPathComponent
                let ext = item.url.pathExtension
                destFilename = "\(name)_\(counter).\(ext)"
                destURL = workDir.appendingPathComponent(destFilename)
                counter += 1
            }
            
            do {
                try FileManager.default.copyItem(at: item.url, to: destURL)
                filenames.append(destFilename)
            } catch {
                print("FileConverter: Failed to copy file for ZIP: \(error)")
                // Continue with other files
            }
        }
        
        guard !filenames.isEmpty else {
            try? FileManager.default.removeItem(at: workDir)
            return nil
        }
        
        // Use macOS built-in zip command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = workDir
        process.arguments = ["-r", zipURL.path] + filenames
        
        // Suppress output
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            
            // Non-blocking wait using async continuation
            await withCheckedContinuation { continuation in
                process.terminationHandler = { _ in
                    continuation.resume()
                }
            }
            
            // Cleanup work directory
            try? FileManager.default.removeItem(at: workDir)
            
            if process.terminationStatus == 0 {
                print("FileConverter: Successfully created ZIP: \(zipURL.lastPathComponent)")
                return zipURL
            } else {
                print("FileConverter: zip command failed with status \(process.terminationStatus)")
            }
        } catch {
            print("FileConverter: Failed to run zip command: \(error)")
            try? FileManager.default.removeItem(at: workDir)
        }
        
        return nil
    }
    
    // MARK: - Helpers
    
    /// Generates a unique URL if the file already exists
    private static func uniqueURL(for url: URL) -> URL {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: url.path) {
            return url
        }
        
        let directory = url.deletingLastPathComponent()
        let filename = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        
        var counter = 1
        var newURL = url
        
        while fileManager.fileExists(atPath: newURL.path) {
            let newFilename = "\(filename)_\(counter).\(ext)"
            newURL = directory.appendingPathComponent(newFilename)
            counter += 1
        }
        
        return newURL
    }
}
