//
//  TerminalNotchManager.swift
//  Droppy
//
//  Manages terminal state, process, and keyboard shortcuts
//

import SwiftUI
import AppKit
import Combine

/// Manages the Terminal-Notch extension state and terminal process
@MainActor
class TerminalNotchManager: ObservableObject {
    static let shared = TerminalNotchManager()
    
    // MARK: - Published State
    
    /// Whether the terminal overlay is visible
    @Published var isVisible: Bool = false
    
    /// Whether we're in expanded mode (full terminal) vs quick command mode
    @Published var isExpanded: Bool = false
    
    /// Current command input text (for quick mode)
    @Published var commandText: String = ""
    
    /// Command history
    @Published var commandHistory: [String] = []
    
    /// Current history index for navigation
    @Published var historyIndex: Int = -1
    
    /// Last command output (for quick mode feedback)
    @Published var lastOutput: String = ""
    
    /// Is command currently running
    @Published var isRunning: Bool = false
    
    // MARK: - Settings
    
    /// Default shell path
    @AppStorage("terminalNotch_shell") var shellPath: String = "/bin/zsh"
    
    /// Terminal font size
    @AppStorage("terminalNotch_fontSize") var fontSize: Double = 13
    
    /// Terminal height when expanded
    @AppStorage("terminalNotch_height") var terminalHeight: Double = 300
    
    /// Whether extension is installed
    @AppStorage("terminalNotch_installed") var isInstalled: Bool = false
    
    // MARK: - Private
    
    private var cancellables = Set<AnyCancellable>()
    private var process: Process?
    private var outputPipe: Pipe?
    private var inputPipe: Pipe?
    
    private init() {
        loadHistory()
    }
    
    // MARK: - Public Methods
    
    /// Toggle terminal visibility
    func toggle() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible.toggle()
            if isVisible {
                // Focus the terminal when shown
                focusTerminal()
            }
        }
    }
    
    /// Show terminal
    func show() {
        guard !isVisible else { return }
        toggle()
    }
    
    /// Hide terminal
    func hide() {
        guard isVisible else { return }
        toggle()
    }
    
    /// Toggle between quick and expanded mode
    func toggleExpanded() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded.toggle()
        }
    }
    
    /// Execute a quick command (non-interactive)
    func executeQuickCommand(_ command: String) {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Add to history
        addToHistory(command)
        
        isRunning = true
        lastOutput = ""
        
        Task {
            do {
                let output = try await runCommand(command)
                await MainActor.run {
                    self.lastOutput = output
                    self.isRunning = false
                    self.commandText = ""
                }
            } catch {
                await MainActor.run {
                    self.lastOutput = "Error: \(error.localizedDescription)"
                    self.isRunning = false
                }
            }
        }
    }
    
    /// Open Terminal.app with current working directory
    func openInTerminalApp() {
        let script = """
        tell application "Terminal"
            activate
            do script ""
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
    
    /// Navigate command history up
    func historyUp() {
        guard !commandHistory.isEmpty else { return }
        if historyIndex < commandHistory.count - 1 {
            historyIndex += 1
            commandText = commandHistory[commandHistory.count - 1 - historyIndex]
        }
    }
    
    /// Navigate command history down
    func historyDown() {
        if historyIndex > 0 {
            historyIndex -= 1
            commandText = commandHistory[commandHistory.count - 1 - historyIndex]
        } else if historyIndex == 0 {
            historyIndex = -1
            commandText = ""
        }
    }
    
    /// Cleanup when extension is removed
    func cleanup() {
        isVisible = false
        isExpanded = false
        commandHistory = []
        isInstalled = false
        
        // Clear history from disk
        UserDefaults.standard.removeObject(forKey: "terminalNotch_history")
    }
    
    // MARK: - Private Methods
    
    private func focusTerminal() {
        // Will be handled by the view
        historyIndex = -1
    }
    
    private func addToHistory(_ command: String) {
        // Don't add duplicates of the last command
        if commandHistory.last != command {
            commandHistory.append(command)
            // Keep last 100 commands
            if commandHistory.count > 100 {
                commandHistory.removeFirst()
            }
            saveHistory()
        }
        historyIndex = -1
    }
    
    private func loadHistory() {
        if let history = UserDefaults.standard.stringArray(forKey: "terminalNotch_history") {
            commandHistory = history
        }
    }
    
    private func saveHistory() {
        UserDefaults.standard.set(commandHistory, forKey: "terminalNotch_history")
    }
    
    /// Run a shell command and return output
    private func runCommand(_ command: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: shellPath)
            process.arguments = ["-c", command]
            process.standardOutput = pipe
            process.standardError = pipe
            process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                // Trim and limit output for quick mode
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                let lines = trimmed.components(separatedBy: "\n")
                if lines.count > 10 {
                    let preview = lines.prefix(10).joined(separator: "\n")
                    continuation.resume(returning: preview + "\n... (\(lines.count - 10) more lines)")
                } else {
                    continuation.resume(returning: trimmed)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
