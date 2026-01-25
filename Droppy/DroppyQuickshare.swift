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
            var displayFilename = uploadURL.lastPathComponent
            
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
                displayFilename = "Droppy Share (\(urls.count) items).zip"
            }
            
            // Upload the file
            let result = uploadTo0x0(fileURL: uploadURL)
            
            // Clean up temporary zip if we created one
            if isTemporaryZip {
                try? FileManager.default.removeItem(at: uploadURL)
            }
            
            DispatchQueue.main.async {
                DroppyState.shared.isSharingInProgress = false
                
                if let result = result {
                    // Success! Copy URL to clipboard
                    let clipboard = NSPasteboard.general
                    clipboard.clearContents()
                    clipboard.setString(result.shareURL, forType: .string)
                    
                    // Store in Quickshare Manager for history
                    let quickshareItem = QuickshareItem(
                        filename: displayFilename,
                        shareURL: result.shareURL,
                        token: result.token,
                        fileSize: result.fileSize
                    )
                    print("🚀 [DroppyQuickshare] Created item, calling addItem...")
                    QuickshareManager.shared.addItem(quickshareItem)
                    print("🚀 [DroppyQuickshare] addItem called, manager items: \(QuickshareManager.shared.items.count)")
                    
                    // Show success feedback
                    DroppyState.shared.quickShareStatus = .success(urls: [result.shareURL])
                    HapticFeedback.copy()
                    
                    // Show success popup
                    QuickShareSuccessWindowController.show(shareURL: result.shareURL)
                    
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
    
    /// Upload result containing URL and management token
    struct UploadResult {
        let shareURL: String
        let token: String
        let fileSize: Int64
    }
    
    /// Uploads a file to 0x0.st and returns the shareable URL and management token
    private static func uploadTo0x0(fileURL: URL) -> UploadResult? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: UploadResult? = nil
        
        // Get file size for expiration calculation
        let fileSize: Int64 = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
        
        // Create multipart form data request
        let url = URL(string: "https://0x0.st")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Droppy/1.0", forHTTPHeaderField: "User-Agent")
        
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
            
            // Extract X-Token from response headers
            var token = ""
            if let httpResponse = response as? HTTPURLResponse {
                token = httpResponse.value(forHTTPHeaderField: "X-Token") ?? ""
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                let trimmed = responseString.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("http") {
                    result = UploadResult(shareURL: trimmed, token: token, fileSize: fileSize)
                }
            }
        }
        
        task.resume()
        semaphore.wait()
        
        return result
    }
}

