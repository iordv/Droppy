//
//  MailHelper.swift
//  Droppy
//
//  Provides AppleScript-based email export functionality for Mail.app
//

import Foundation
import AppKit

enum QuickActionsMailApp: String, CaseIterable, Identifiable {
    case systemDefault
    case appleMail
    case outlook

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemDefault: return "Default"
        case .appleMail: return "Mail"
        case .outlook: return "Outlook"
        }
    }

    var icon: String {
        switch self {
        case .systemDefault: return "gearshape"
        case .appleMail: return "apple.logo"
        case .outlook: return "envelope.badge"
        }
    }

    var bundleIdentifier: String? {
        switch self {
        case .systemDefault: return nil
        case .appleMail: return "com.apple.mail"
        case .outlook: return "com.microsoft.Outlook"
        }
    }
}

/// Helper for exporting emails from Mail.app using AppleScript
class MailHelper {
    static let shared = MailHelper()
    
    private init() {}

    // MARK: - Quick Actions Compose

    @discardableResult
    static func composeEmail(with urls: [URL]) -> Bool {
        guard !urls.isEmpty else { return false }
        let rawValue = UserDefaults.standard.preference(
            AppPreferenceKey.quickActionsMailApp,
            default: PreferenceDefault.quickActionsMailApp
        )
        let selectedApp = QuickActionsMailApp(rawValue: rawValue) ?? .systemDefault
        return composeEmail(with: urls, app: selectedApp)
    }

    @discardableResult
    static func composeEmail(with urls: [URL], app: QuickActionsMailApp) -> Bool {
        guard !urls.isEmpty else { return false }

        switch app {
        case .systemDefault:
            guard let service = NSSharingService(named: .composeEmail) else { return false }
            service.perform(withItems: urls)
            return true

        case .appleMail:
            if openURLs(urls, withBundleIdentifier: "com.apple.mail") {
                return true
            }
            guard let service = NSSharingService(named: .composeEmail) else { return false }
            service.perform(withItems: urls)
            return true

        case .outlook:
            if composeWithOutlookAppleScript(urls: urls) {
                return true
            }
            // Opening file URLs directly in Outlook does not reliably create attachments.
            // Fall back to the system compose service instead.
            guard let service = NSSharingService(named: .composeEmail) else { return false }
            service.perform(withItems: urls)
            return true
        }
    }

    static func isMailClientInstalled(_ app: QuickActionsMailApp) -> Bool {
        guard let bundleIdentifier = app.bundleIdentifier else { return true }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    @discardableResult
    private static func openURLs(_ urls: [URL], withBundleIdentifier bundleIdentifier: String) -> Bool {
        guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return false
        }
        NSWorkspace.shared.open(urls, withApplicationAt: applicationURL, configuration: NSWorkspace.OpenConfiguration())
        return true
    }

    @discardableResult
    private static func composeWithOutlookAppleScript(urls: [URL]) -> Bool {
        guard isMailClientInstalled(.outlook) else { return false }

        let fileList = urls
            .map { "\"\(escapeAppleScriptString($0.path))\"" }
            .joined(separator: ", ")
        let script = """
        tell application id "com.microsoft.Outlook"
            activate
            set newMessage to make new outgoing message with properties {subject:""}
            repeat with filePath in {\(fileList)}
                set attachmentFile to POSIX file (filePath as text)
                make new attachment with properties {file:attachmentFile} at newMessage
            end repeat
            open newMessage
            return (count of attachments of newMessage)
        end tell
        """

        let attachmentCount: Int = AppleScriptRuntime.execute {
            var error: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else { return 0 }
            let result = appleScript.executeAndReturnError(&error)
            if let error {
                print("📧 MailHelper: Outlook AppleScript error: \(error)")
                return 0
            }
            return Int(result.int32Value)
        }
        guard attachmentCount > 0 else {
            print("📧 MailHelper: Outlook AppleScript created draft without attachments")
            return false
        }
        return true
    }

    private static func escapeAppleScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
    
    /// Exports the currently selected email(s) from Mail.app to .eml files
    /// - Parameter destinationDirectory: Where to save the .eml files
    /// - Returns: Array of URLs to the saved .eml files
    func exportSelectedEmails(to destinationDirectory: URL) async -> [URL] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let savedFiles = self.exportEmailsSync(to: destinationDirectory)
                continuation.resume(returning: savedFiles)
            }
        }
    }
    
    private func exportEmailsSync(to destinationDirectory: URL) -> [URL] {
        // Ensure destination exists
        try? FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        
        let destPath = destinationDirectory.path
        
        // AppleScript to save selected messages as .eml files
        // Mail.app's "source" property returns the raw RFC 822 message source
        let script = """
        tell application "Mail"
            set selectedMessages to selection
            if (count of selectedMessages) = 0 then
                return ""
            end if
            
            set savedFiles to {}
            repeat with msg in selectedMessages
                try
                    set msgSubject to subject of msg
                    set msgSource to source of msg
                    
                    -- Sanitize filename
                    set sanitizedName to my sanitizeFilename(msgSubject)
                    set filePath to "\(destPath)/" & sanitizedName & ".eml"
                    
                    -- Write the source to file
                    set fileRef to open for access POSIX file filePath with write permission
                    write msgSource to fileRef as «class utf8»
                    close access fileRef
                    
                    set end of savedFiles to filePath
                on error errMsg
                    -- Continue with next email
                end try
            end repeat
            
            return savedFiles as text
        end tell
        
        on sanitizeFilename(theText)
            set illegalChars to {"/", ":", "\\\\", "*", "?", "\\"", "<", ">", "|"}
            set sanitized to theText
            repeat with c in illegalChars
                set AppleScript's text item delimiters to c
                set textItems to text items of sanitized
                set AppleScript's text item delimiters to "-"
                set sanitized to textItems as text
            end repeat
            set AppleScript's text item delimiters to ""
            
            -- Truncate to reasonable length
            if length of sanitized > 100 then
                set sanitized to text 1 thru 100 of sanitized
            end if
            
            return sanitized
        end sanitizeFilename
        """
        
        let resultString: String? = AppleScriptRuntime.execute {
            var error: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else {
                print("📧 MailHelper: Failed to create AppleScript")
                return nil
            }

            let result = appleScript.executeAndReturnError(&error)
            if let error {
                print("📧 MailHelper: AppleScript error: \(error)")
                return nil
            }

            return result.stringValue
        }

        guard let resultString else {
            return []
        }
        
        // Parse the result - it's a comma-separated list of file paths
        guard !resultString.isEmpty else {
            print("📧 MailHelper: No messages exported")
            return []
        }
        
        let filePaths = resultString.components(separatedBy: ", ")
        let fileURLs = filePaths.compactMap { path -> URL? in
            let trimmed = path.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            return URL(fileURLWithPath: trimmed)
        }
        
        print("📧 MailHelper: Exported \(fileURLs.count) email(s)")
        return fileURLs
    }
}
