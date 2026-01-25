//
//  DroppyQuickshare.swift
//  Droppy
//
//  Shared Quickshare logic for uploading files and getting shareable links
//  Can be called from context menus, quick action buttons, etc.
//

import Foundation
import AppKit

/// Droppy Quickshare - uploads files to 0x0.st and gets shareable links
enum DroppyQuickshare {
    
    /// Share files via Droppy Quickshare
    /// Multiple files are automatically zipped into a single archive
    static func share(urls: [URL]) {
        guard !urls.isEmpty else { return }
        guard !DroppyState.shared.isSharingInProgress else { return }
        
        DroppyState.shared.isSharingInProgress = true
        DroppyState.shared.quickShareStatus = .uploading
        
        DispatchQueue.global(qos: .userInitiated).async {
            var uploadURL = urls.first!
            var isTemporaryZip = false
            
            // If multiple files, create a ZIP first
            if urls.count > 1 {
                guard let zipURL = createZIP(from: urls) else {
                    DispatchQueue.main.async {
                        DroppyState.shared.isSharingInProgress = false
                        DroppyState.shared.quickShareStatus = .failed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            DroppyState.shared.quickShareStatus = .idle
                        }
                    }
                    return
                }
                uploadURL = zipURL
                isTemporaryZip = true
            }
            
            // Upload the file
            let shareURL = uploadTo0x0(fileURL: uploadURL)
            
            // Clean up temporary zip if we created one
            if isTemporaryZip {
                try? FileManager.default.removeItem(at: uploadURL)
            }
            
            DispatchQueue.main.async {
                DroppyState.shared.isSharingInProgress = false
                
                if let shareURL = shareURL {
                    // Success! Copy URL to clipboard
                    let clipboard = NSPasteboard.general
                    clipboard.clearContents()
                    clipboard.setString(shareURL, forType: .string)
                    
                    // Show success feedback
                    DroppyState.shared.quickShareStatus = .success(urls: [shareURL])
                    HapticFeedback.copy()
                    
                    // Show success popup
                    QuickShareSuccessWindowController.show(shareURL: shareURL)
                    
                    // Reset status after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        DroppyState.shared.quickShareStatus = .idle
                    }
                } else {
                    // Upload failed
                    DroppyState.shared.quickShareStatus = .failed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        DroppyState.shared.quickShareStatus = .idle
                    }
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    /// Creates a ZIP archive from multiple files
    private static func createZIP(from urls: [URL]) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let zipName = "Droppy Share (\(urls.count) items).zip"
        let zipURL = tempDir.appendingPathComponent(zipName)
        
        // Remove existing zip if any
        try? FileManager.default.removeItem(at: zipURL)
        
        // Create zip using Archive utility
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = tempDir
        
        // Copy files to temp dir first for clean paths
        let stagingDir = tempDir.appendingPathComponent("droppy_staging_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        
        var stagedFiles: [String] = []
        for url in urls {
            let destURL = stagingDir.appendingPathComponent(url.lastPathComponent)
            do {
                try FileManager.default.copyItem(at: url, to: destURL)
                stagedFiles.append(url.lastPathComponent)
            } catch {
                print("Failed to stage file for ZIP: \(error)")
            }
        }
        
        guard !stagedFiles.isEmpty else {
            try? FileManager.default.removeItem(at: stagingDir)
            return nil
        }
        
        process.currentDirectoryURL = stagingDir
        process.arguments = ["-r", zipURL.path] + stagedFiles
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Cleanup staging
            try? FileManager.default.removeItem(at: stagingDir)
            
            if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: zipURL.path) {
                return zipURL
            }
        } catch {
            print("ZIP creation failed: \(error)")
        }
        
        try? FileManager.default.removeItem(at: stagingDir)
        return nil
    }
    
    /// Uploads a file to 0x0.st and returns the shareable URL
    private static func uploadTo0x0(fileURL: URL) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        var resultURL: String? = nil
        
        // Create multipart form data request
        let url = URL(string: "https://0x0.st")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build request body
        var body = Data()
        let filename = fileURL.lastPathComponent
        
        // File data part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        
        guard let fileData = try? Data(contentsOf: fileURL) else {
            return nil
        }
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("Upload error: \(error)")
                return
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                let trimmed = responseString.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("http") {
                    resultURL = trimmed
                }
            }
        }
        
        task.resume()
        semaphore.wait()
        
        return resultURL
    }
}
