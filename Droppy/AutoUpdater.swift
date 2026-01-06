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
    
    /// Downloads and installs the update from the given URL
    func installUpdate(from url: URL) {
        Task {
            // 1. Download DMG
            guard let dmgURL = await downloadDMG(from: url) else {
                return
            }
            
            // 2. Install and Restart
            do {
                try installAndRestart(dmgPath: dmgURL.path)
            } catch {
                print("AutoUpdater: Installation failed: \(error)")
                _ = await MainActor.run {
                    NSAlert(error: error).runModal()
                }
            }
        }
    }
    
    private func downloadDMG(from url: URL) async -> URL? {
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("DroppyUpdate.dmg")
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            try data.write(to: destinationURL)
            return destinationURL
        } catch {
            print("AutoUpdater: Download failed: \(error)")
            await MainActor.run {
                let alert = NSAlert()
                alert.messageText = "Update Failed"
                alert.informativeText = "Could not download the update. Please try again later."
                alert.runModal()
            }
            return nil
        }
    }
    
    private func installAndRestart(dmgPath: String) throws {
        // Create a temporary install script with .command extension (runs in Terminal)
        let scriptPath = FileManager.default.temporaryDirectory.appendingPathComponent("update_droppy.command").path
        let appPath = Bundle.main.bundlePath
        let appName = "Droppy.app"
        
        // Detailed script with logging and pauses
        let script = """
        #!/bin/bash
        
        # Colors
        BLUE='\\033[0;34m'
        PURPLE='\\033[0;35m'
        CYAN='\\033[0;36m'
        GREEN='\\033[0;32m'
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
        echo -e "${PURPLE}${BOLD}    >>> NEW UPDATE DETECTED <<<${NC}"
        echo ""
        
        # 1. Wait
        echo -e "${CYAN}⏳ Closing old version...${NC}"
        sleep 2
        
        # 2. Mount
        echo -e "${CYAN}📦 Mounting Update Image...${NC}"
        hdiutil attach "\(dmgPath)" -nobrowse -mountpoint /Volumes/DroppyUpdate > /dev/null
        
        # 3. Copy
        echo -e "${CYAN}🚀 Installing new Droppy...${NC}"
        # Remove old app
        rm -rf "\(appPath)"
        # Copy new app
        cp -R "/Volumes/DroppyUpdate/\(appName)" "\(appPath)"
        # Remove quarantine attribute (fixes "damaged app" for unsigned apps)
        xattr -rd com.apple.quarantine "\(appPath)" 2>/dev/null || true
        
        # 4. Cleanup
        echo -e "${CYAN}🧹 Cleaning up temporary files...${NC}"
        hdiutil detach /Volumes/DroppyUpdate > /dev/null
        rm -f "\(dmgPath)"
        
        # 5. Relaunch
        echo ""
        echo -e "${GREEN}${BOLD}✅ UPDATE COMPLETE!${NC}"
        echo -e "${PURPLE}Droppy is ready to go.${NC}"
        echo ""
        echo -e "${BLUE}Starting the new version now...${NC}"
        
        open -n "\(appPath)"
        
        # Self-destruct
        (sleep 1 && rm -f "$0") &
        exit
        """
        
        try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        
        // Make executable
        var attributes = [FileAttributeKey : Any]()
        attributes[.posixPermissions] = 0o755
        try FileManager.default.setAttributes(attributes, ofItemAtPath: scriptPath)
        
        // Open the script in Terminal (Visible execution)
        NSWorkspace.shared.open(URL(fileURLWithPath: scriptPath))
        
        // Terminate current app
        NSApplication.shared.terminate(nil)
    }
}
