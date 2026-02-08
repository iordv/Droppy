//
//  FinderFolderDetector.swift
//  Droppy
//
//  Detects the frontmost Finder window's folder for Quick Actions
//

import AppKit

enum FinderFolderDetector {
    
    /// Gets the current folder from the frontmost Finder window
    /// Returns nil if Finder is not open or no folder is selected
    static func getCurrentFinderFolder() -> URL? {
        let script = """
        tell application "System Events"
            if not (exists process "Finder") then return ""
        end tell
        tell application "Finder"
            try
                set frontWindow to front window
                set targetFolder to (target of frontWindow) as alias
                return POSIX path of targetFolder
            on error
                return ""
            end try
        end tell
        """
        
        let path: String? = AppleScriptRuntime.execute {
            guard let appleScript = NSAppleScript(source: script) else {
                return nil
            }

            var error: NSDictionary?
            let result = appleScript.executeAndReturnError(&error)

            if let errorInfo = error {
                print("[FinderFolderDetector] AppleScript error: \(errorInfo)")
                return nil
            }

            return result.stringValue
        }

        guard let path, !path.isEmpty else {
            return nil
        }
        
        let url = URL(fileURLWithPath: path)
        
        // Verify it's a valid directory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        
        return url
    }
    
    /// Moves files to the specified folder
    /// Returns the number of successfully moved files
    @discardableResult
    static func moveFiles(_ urls: [URL], to destinationFolder: URL) -> Int {
        let fileManager = FileManager.default
        var successCount = 0
        
        for sourceURL in urls {
            let destinationURL = destinationFolder.appendingPathComponent(sourceURL.lastPathComponent)
            
            do {
                // Handle existing file
                if fileManager.fileExists(atPath: destinationURL.path) {
                    // Generate unique name
                    let uniqueURL = generateUniqueURL(for: destinationURL)
                    try fileManager.moveItem(at: sourceURL, to: uniqueURL)
                } else {
                    try fileManager.moveItem(at: sourceURL, to: destinationURL)
                }
                successCount += 1
            } catch {
                print("[FinderFolderDetector] Failed to move \(sourceURL.lastPathComponent): \(error)")
            }
        }
        
        return successCount
    }
    
    /// Copies files to the specified folder
    /// Returns the number of successfully copied files
    @discardableResult
    static func copyFiles(_ urls: [URL], to destinationFolder: URL) -> Int {
        let fileManager = FileManager.default
        var successCount = 0
        
        for sourceURL in urls {
            let destinationURL = destinationFolder.appendingPathComponent(sourceURL.lastPathComponent)
            
            do {
                // Handle existing file
                if fileManager.fileExists(atPath: destinationURL.path) {
                    // Generate unique name
                    let uniqueURL = generateUniqueURL(for: destinationURL)
                    try fileManager.copyItem(at: sourceURL, to: uniqueURL)
                } else {
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                }
                successCount += 1
            } catch {
                print("[FinderFolderDetector] Failed to copy \(sourceURL.lastPathComponent): \(error)")
            }
        }
        
        return successCount
    }
    
    /// Generates a unique URL by appending a number if the file already exists
    private static func generateUniqueURL(for url: URL) -> URL {
        let fileManager = FileManager.default
        let folder = url.deletingLastPathComponent()
        let filename = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        
        var counter = 1
        var newURL = url
        
        while fileManager.fileExists(atPath: newURL.path) {
            let newFilename = ext.isEmpty ? "\(filename) \(counter)" : "\(filename) \(counter).\(ext)"
            newURL = folder.appendingPathComponent(newFilename)
            counter += 1
        }
        
        return newURL
    }
}
