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
    private let lastCleanExitKey = "lastCleanExitTimestamp"
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    
    /// Timestamp when the current session started
    private var sessionStartTime: Date?
    
    private init() {}
    
    // MARK: - Crash Detection
    
    /// Call at app launch to mark session as started (not cleanly terminated)
    func markSessionStarted() {
        sessionStartTime = Date()
        UserDefaults.standard.set(true, forKey: crashFlagKey)
    }
    
    /// Call at clean app termination to clear crash flag
    func markCleanExit() {
        UserDefaults.standard.set(false, forKey: crashFlagKey)
        // Record the timestamp of clean exit so we can filter old crash logs
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCleanExitKey)
    }
    
    /// Check if last session crashed and offer to report
    func checkForCrashAndPrompt() {
        // Skip crash detection in debug builds - rebuilding/stopping debugger triggers false positives
        #if DEBUG
        UserDefaults.standard.set(false, forKey: crashFlagKey)
        print("🔧 CrashReporter: Skipping crash check (DEBUG build)")
        return
        #else
        let didCrash = UserDefaults.standard.bool(forKey: crashFlagKey)
        
        // Clear the flag immediately to avoid repeated prompts
        UserDefaults.standard.set(false, forKey: crashFlagKey)
        
        guard didCrash else { return }
        
        // Get the last clean exit time - only show crashes AFTER this time
        let lastCleanExit = UserDefaults.standard.double(forKey: lastCleanExitKey)
        let lastCleanExitDate = lastCleanExit > 0 ? Date(timeIntervalSince1970: lastCleanExit) : nil
        
        // Find the most recent crash log that occurred AFTER last clean exit
        let crashLog = findLatestCrashLog(after: lastCleanExitDate)
        
        // Only prompt if we found a relevant crash log
        guard crashLog != nil else {
            print("🔧 CrashReporter: No recent crash log found after last clean exit, skipping prompt")
            return
        }
        
        // Prompt user after a short delay to let the app fully launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.showCrashReportPrompt(crashLog: crashLog)
        }
        #endif
    }
    
    // MARK: - Crash Log Discovery
    
    private func findLatestCrashLog(after minDate: Date? = nil) -> String? {
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
                    guard modDate > Date().addingTimeInterval(-86400) else { continue }
                    
                    // If we have a minimum date (last clean exit), only consider crashes AFTER it
                    if let minDate = minDate {
                        guard modDate > minDate else { continue }
                    }
                    
                    if latestCrash == nil || modDate > latestCrash!.date {
                        latestCrash = (path, modDate)
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
        Task { @MainActor in
            let shouldSend = await DroppyAlertController.shared.showWarning(
                title: "Droppy Crashed",
                message: "It looks like Droppy crashed during your last session. Would you like to send a crash report to help improve the app?",
                actionButtonTitle: "Send Report",
                showCancel: true
            )
            
            if shouldSend {
                openGitHubIssue(crashLog: crashLog)
            }
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
