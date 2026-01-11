//
//  AutoUpdater.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import Foundation
import AppKit

/// Handles downloading and installing app updates
class AutoUpdater {
    static let shared = AutoUpdater()
    
    private init() {}
    
    /// Downloads and installs the update from the given URL (ZIP file)
    func installUpdate(from url: URL) {
        Task {
            // 1. Download ZIP
            guard let extractedAppPath = await downloadAndExtractZIP(from: url) else {
                return
            }
            
            // 2. Install and Restart using helper app
            do {
                try launchUpdaterHelper(appPath: extractedAppPath)
            } catch {
                print("AutoUpdater: Installation failed: \(error)")
                await DroppyAlertController.shared.showError(
                    title: "Update Failed",
                    message: error.localizedDescription
                )
            }
        }
    }
    
    private func downloadAndExtractZIP(from url: URL) async -> String? {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("DroppyUpdate")
        let zipURL = tempDir.appendingPathComponent("update.zip")
        
        do {
            // Clean up any previous attempt
            if FileManager.default.fileExists(atPath: tempDir.path) {
                try FileManager.default.removeItem(at: tempDir)
            }
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // Download ZIP
            let (data, _) = try await URLSession.shared.data(from: url)
            try data.write(to: zipURL)
            
            // Extract ZIP using ditto (preserves permissions and attributes)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-xk", zipURL.path, tempDir.path]
            try process.run()
            process.waitUntilExit()
            
            // Find Droppy.app in .payload folder
            let payloadAppPath = tempDir.appendingPathComponent(".payload/Droppy.app").path
            if FileManager.default.fileExists(atPath: payloadAppPath) {
                return payloadAppPath
            }
            
            // Fallback: look for Droppy.app directly
            let directAppPath = tempDir.appendingPathComponent("Droppy.app").path
            if FileManager.default.fileExists(atPath: directAppPath) {
                return directAppPath
            }
            
            print("AutoUpdater: Could not find Droppy.app in extracted ZIP")
            await DroppyAlertController.shared.showError(
                title: "Update Failed",
                message: "Could not find Droppy.app in the update package."
            )
            return nil
            
        } catch {
            print("AutoUpdater: Download/extract failed: \(error)")
            await DroppyAlertController.shared.showError(
                title: "Update Failed",
                message: "Could not download the update. Please try again later."
            )
            return nil
        }
    }
    
    /// Launch the updater helper with the extracted app path
    private func launchUpdaterHelper(appPath newAppPath: String) throws {
        let currentAppPath = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier
        
        // For ZIP-based updates, we can use a simpler inline approach
        // since the app is already extracted
        try performZIPUpdate(newAppPath: newAppPath, currentAppPath: currentAppPath, pid: pid)
    }
    
    /// Perform update from extracted ZIP (no DMG mounting needed)
    private func performZIPUpdate(newAppPath: String, currentAppPath: String, pid: Int32) throws {
        let scriptPath = FileManager.default.temporaryDirectory.appendingPathComponent("update_droppy.command").path
        
        let script = """
        #!/bin/bash
        
        # Colors
        BLUE='\\033[0;34m'
        GREEN='\\033[0;32m'
        CYAN='\\033[0;36m'
        BOLD='\\033[1m'
        NC='\\033[0m'
        
        clear
        echo -e "${BLUE}${BOLD}"
        echo "    ____  ____  ____  ____  ______  __"
        echo "   / __ \\/ __ \\/ __ \\/ __ \\/ __ \\ \\/ /"
        echo "  / / / / /_/ / / / / /_/ / /_/ /\\  / "
        echo " / /_/ / _, _/ /_/ / ____/ ____/ / /  "
        echo "/_____/_/ |_|\\____/_/   /_/     /_/   "
        echo -e "${NC}"
        echo -e "${CYAN}${BOLD}    >>> UPDATING DROPPY <<<${NC}"
        echo ""
        
        NEW_APP="\(newAppPath)"
        CURRENT_APP="\(currentAppPath)"
        OLD_PID=\(pid)
        
        # Kill and wait
        echo -e "${CYAN}⏳ Closing Droppy...${NC}"
        kill -9 $OLD_PID 2>/dev/null || true
        sleep 2
        
        # Remove old
        echo -e "${CYAN}🗑️  Removing old version...${NC}"
        rm -rf "$CURRENT_APP" 2>/dev/null || osascript -e "do shell script \\"rm -rf '$CURRENT_APP'\\" with administrator privileges" 2>/dev/null
        
        # Install new
        echo -e "${CYAN}🚀 Installing new Droppy...${NC}"
        cp -R "$NEW_APP" "$CURRENT_APP"
        
        # Remove quarantine
        xattr -rd com.apple.quarantine "$CURRENT_APP" 2>/dev/null || true
        
        # Cleanup temp
        echo -e "${CYAN}🧹 Cleaning up...${NC}"
        rm -rf "$(dirname "$NEW_APP")" 2>/dev/null || true
        
        echo ""
        echo -e "${GREEN}${BOLD}✅ UPDATE COMPLETE!${NC}"
        sleep 1
        open -n "$CURRENT_APP"
        (sleep 1 && rm -f "$0") &
        exit 0
        """
        
        try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        
        var attributes = [FileAttributeKey : Any]()
        attributes[.posixPermissions] = 0o755
        try FileManager.default.setAttributes(attributes, ofItemAtPath: scriptPath)
        
        NSWorkspace.shared.open(URL(fileURLWithPath: scriptPath))
        NSApplication.shared.terminate(nil)
    }
}
