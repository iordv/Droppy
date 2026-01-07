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
        let pid = ProcessInfo.processInfo.processIdentifier
        
        // Robust script with retries, admin fallback, and proper error handling
        let script = """
        #!/bin/bash
        
        # Colors
        BLUE='\\033[0;34m'
        PURPLE='\\033[0;35m'
        CYAN='\\033[0;36m'
        GREEN='\\033[0;32m'
        RED='\\033[0;31m'
        YELLOW='\\033[0;33m'
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
        
        APP_PATH="\(appPath)"
        DMG_PATH="\(dmgPath)"
        APP_NAME="\(appName)"
        OLD_PID=\(pid)
        
        # Function to check if app is still running
        is_running() {
            kill -0 $OLD_PID 2>/dev/null
            return $?
        }
        
        # 1. Kill the old app and wait for it to close
        echo -e "${CYAN}⏳ Closing Droppy...${NC}"
        
        # Force kill by PID (the app should already be terminating, but make sure)
        kill -9 $OLD_PID 2>/dev/null || true
        
        # Wait for the process to actually die (up to 10 seconds)
        for i in {1..20}; do
            if ! is_running; then
                break
            fi
            sleep 0.5
        done
        
        # Extra safety wait
        sleep 1
        
        # 2. Mount DMG
        echo -e "${CYAN}📦 Mounting update image...${NC}"
        hdiutil attach "$DMG_PATH" -nobrowse -mountpoint /Volumes/DroppyUpdate > /dev/null 2>&1
        
        if [ ! -d "/Volumes/DroppyUpdate/$APP_NAME" ]; then
            echo -e "${RED}❌ Error: Could not mount the update DMG${NC}"
            echo -e "${YELLOW}Please download the update manually from GitHub.${NC}"
            read -p "Press Enter to exit..."
            exit 1
        fi
        
        # 3. Remove old app (try without admin first)
        echo -e "${CYAN}🗑️  Removing old version...${NC}"
        
        # Try regular delete first
        rm -rf "$APP_PATH" 2>/dev/null
        
        # Check if delete succeeded
        if [ -d "$APP_PATH" ]; then
            echo -e "${YELLOW}⚠️  Need admin permission to replace the app${NC}"
            echo ""
            
            # Try with admin privileges using osascript
            osascript -e "do shell script \\"rm -rf '$APP_PATH'\\" with administrator privileges" 2>/dev/null
            
            # Check again
            if [ -d "$APP_PATH" ]; then
                echo -e "${RED}❌ Could not remove old version${NC}"
                echo ""
                echo -e "${YELLOW}Please manually delete Droppy.app from Applications,${NC}"
                echo -e "${YELLOW}then drag the new version from the mounted disk image.${NC}"
                echo ""
                echo -e "Opening Applications folder and update image..."
                open /Applications
                open /Volumes/DroppyUpdate
                hdiutil detach /Volumes/DroppyUpdate > /dev/null 2>&1 || true
                rm -f "$DMG_PATH" 2>/dev/null || true
                read -p "Press Enter to exit..."
                exit 1
            fi
        fi
        
        # 4. Copy new app
        echo -e "${CYAN}🚀 Installing new Droppy...${NC}"
        cp -R "/Volumes/DroppyUpdate/$APP_NAME" "$APP_PATH"
        
        if [ ! -d "$APP_PATH" ]; then
            echo -e "${RED}❌ Failed to copy new version${NC}"
            echo ""
            echo -e "${YELLOW}Please manually copy Droppy.app from the mounted disk image.${NC}"
            open /Volumes/DroppyUpdate
            read -p "Press Enter to exit..."
            exit 1
        fi
        
        # 5. Remove quarantine attribute (fixes "damaged app" for unsigned apps)
        echo -e "${CYAN}🔓 Removing security restrictions...${NC}"
        xattr -rd com.apple.quarantine "$APP_PATH" 2>/dev/null || true
        
        # 6. Cleanup
        echo -e "${CYAN}🧹 Cleaning up...${NC}"
        hdiutil detach /Volumes/DroppyUpdate > /dev/null 2>&1 || true
        rm -f "$DMG_PATH" 2>/dev/null || true
        
        # 7. Success!
        echo ""
        echo -e "${GREEN}${BOLD}✅ UPDATE COMPLETE!${NC}"
        echo -e "${PURPLE}Droppy has been updated successfully.${NC}"
        echo ""
        echo -e "${BLUE}Starting the new version...${NC}"
        
        # Small delay to show success message
        sleep 1
        
        # Launch new app
        open -n "$APP_PATH"
        
        # Self-destruct
        (sleep 1 && rm -f "$0") &
        exit 0
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
