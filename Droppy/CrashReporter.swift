//
//  CrashReporter.swift
//  Droppy
//
//  Crash detection and GitHub Issue auto-reporting
//

import AppKit
import Foundation

/// Manages crash detection and offers to send reports via GitHub Issues
final class CrashReporter {
    static let shared = CrashReporter()
    
    private let crashFlagKey = "lastSessionCrashed"
    private let crashLogPathKey = "lastCrashLogPath"
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    
    private init() {}
    
    // MARK: - Crash Detection
    
    /// Call at app launch to mark session as started (not cleanly terminated)
    func markSessionStarted() {
        UserDefaults.standard.set(true, forKey: crashFlagKey)
    }
    
    /// Call at clean app termination to clear crash flag
    func markCleanExit() {
        UserDefaults.standard.set(false, forKey: crashFlagKey)
    }
    
    /// Check if last session crashed and offer to report
    func checkForCrashAndPrompt() {
        let didCrash = UserDefaults.standard.bool(forKey: crashFlagKey)
        
        // Clear the flag immediately to avoid repeated prompts
        UserDefaults.standard.set(false, forKey: crashFlagKey)
        
        guard didCrash else { return }
        
        // Find the most recent crash log
        let crashLog = findLatestCrashLog()
        
        // Prompt user after a short delay to let the app fully launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.showCrashReportPrompt(crashLog: crashLog)
        }
    }
    
    // MARK: - Crash Log Discovery
    
    private func findLatestCrashLog() -> String? {
        let crashDirs = [
            NSHomeDirectory() + "/Library/Logs/DiagnosticReports",
            "/Library/Logs/DiagnosticReports"
        ]
        
        var latestCrash: (path: String, date: Date)? = nil
        let fileManager = FileManager.default
        
        for dir in crashDirs {
            guard let files = try? fileManager.contentsOfDirectory(atPath: dir) else { continue }
            
            for file in files where file.contains("Droppy") && (file.hasSuffix(".ips") || file.hasSuffix(".crash")) {
                let path = (dir as NSString).appendingPathComponent(file)
                if let attrs = try? fileManager.attributesOfItem(atPath: path),
                   let modDate = attrs[.modificationDate] as? Date {
                    // Only consider crashes from the last 24 hours
                    if modDate > Date().addingTimeInterval(-86400) {
                        if latestCrash == nil || modDate > latestCrash!.date {
                            latestCrash = (path, modDate)
                        }
                    }
                }
            }
        }
        
        if let crashPath = latestCrash?.path {
            return try? String(contentsOfFile: crashPath, encoding: .utf8)
        }
        return nil
    }
    
    // MARK: - User Prompt
    
    private func showCrashReportPrompt(crashLog: String?) {
        let alert = NSAlert()
        alert.messageText = "Droppy Crashed"
        alert.informativeText = "It looks like Droppy crashed during your last session. Would you like to send a crash report to help improve the app?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Send Report")
        alert.addButton(withTitle: "Not Now")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            openGitHubIssue(crashLog: crashLog)
        }
    }
    
    // MARK: - GitHub Issue Creation
    
    private func openGitHubIssue(crashLog: String?) {
        let systemInfo = gatherSystemInfo()
        
        // Build issue body
        var body = """
        ## Crash Report
        
        **Droppy Version:** \(appVersion) (\(buildNumber))
        **macOS Version:** \(systemInfo.macOSVersion)
        **Mac Model:** \(systemInfo.macModel)
        **Chip:** \(systemInfo.chipType)
        
        ## What were you doing when the crash occurred?
        
        [Please describe what you were doing when Droppy crashed]
        
        ## Steps to reproduce (if known)
        
        1. 
        2. 
        3. 
        
        """
        
        if let log = crashLog, !log.isEmpty {
            // Truncate crash log if too long for URL (max ~8000 chars for safety)
            let truncatedLog = log.count > 6000 ? String(log.prefix(6000)) + "\n\n[Log truncated - full log in ~/Library/Logs/DiagnosticReports/]" : log
            
            body += """
            
            <details>
            <summary>Crash Log (click to expand)</summary>
            
            ```
            \(truncatedLog)
            ```
            
            </details>
            """
        } else {
            body += """
            
            ---
            *No crash log found. Check ~/Library/Logs/DiagnosticReports/ for Droppy crash files.*
            """
        }
        
        // URL encode the components
        let title = "Crash Report: v\(appVersion)"
        let labels = "bug,crash"
        
        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            // Fallback: open issues page
            if let url = URL(string: "https://github.com/iordv/Droppy/issues") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        
        let urlString = "https://github.com/iordv/Droppy/issues/new?title=\(encodedTitle)&body=\(encodedBody)&labels=\(labels)"
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - System Info
    
    private func gatherSystemInfo() -> (macOSVersion: String, macModel: String, chipType: String) {
        // macOS Version
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let macOSVersion = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        
        // Mac Model
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let macModel = String(cString: model)
        
        // Chip Type (Apple Silicon vs Intel)
        var chipSize = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &chipSize, nil, 0)
        var chip = [CChar](repeating: 0, count: chipSize)
        sysctlbyname("machdep.cpu.brand_string", &chip, &chipSize, nil, 0)
        let chipType = String(cString: chip)
        
        return (macOSVersion, macModel, chipType.isEmpty ? "Apple Silicon" : chipType)
    }
}
