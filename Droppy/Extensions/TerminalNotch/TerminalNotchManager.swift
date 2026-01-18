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
    
    /// Pulse animation trigger (set briefly on command execution)
    @Published var showPulse: Bool = false
    
    // MARK: - Settings
    
    /// Default shell path
    @AppStorage("terminalNotch_shell") var shellPath: String = "/bin/zsh"
    
    /// Terminal font size
    @AppStorage("terminalNotch_fontSize") var fontSize: Double = 13
    
    /// Terminal height when expanded
    @AppStorage("terminalNotch_height") var terminalHeight: Double = 300
    
    /// Whether extension is installed
    @AppStorage("terminalNotch_installed") var isInstalled: Bool = false
    
    /// Saved keyboard shortcut
    @Published var shortcut: SavedShortcut? = nil
    
    // MARK: - Private
    
    private var cancellables = Set<AnyCancellable>()
    private var process: Process?
    private var outputPipe: Pipe?
    private var inputPipe: Pipe?
    private var globalMonitor: Any?
    
    private init() {
        loadHistory()
        loadShortcut()
        registerShortcut()
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
    
    /// Clear terminal output (start fresh)
    func clearOutput() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            lastOutput = ""
            commandText = ""
        }
    }
    
    /// Execute a quick command (non-interactive)
    func executeQuickCommand(_ command: String) {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Add to history
        addToHistory(command)
        
        isRunning = true
        lastOutput = ""
        
        // Trigger pulse animation
        withAnimation(.easeOut(duration: 0.3)) {
            showPulse = true
        }
        // Auto-reset pulse after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.showPulse = false
        }
        
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
    
    /// Open Terminal.app (no automation - just launches the app)
    func openInTerminalApp() {
        // Use NSWorkspace to simply open Terminal.app
        // This doesn't require any special permissions
        if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            NSWorkspace.shared.openApplication(at: terminalURL, configuration: NSWorkspace.OpenConfiguration())
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
        
        // Remove keyboard shortcut
        removeShortcut()
        
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
            // Use -l for login shell (sources profile with PATH including brew)
            // and -c to run the command
            process.arguments = ["-l", "-c", command]
            process.standardOutput = pipe
            process.standardError = pipe
            process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                // Return full output - the view will handle scrolling
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: trimmed)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Shortcut Management
    
    private func loadShortcut() {
        if let data = UserDefaults.standard.data(forKey: "terminalNotch_shortcut"),
           let saved = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
            shortcut = saved
        }
    }
    
    private func saveShortcut() {
        if let shortcut = shortcut,
           let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: "terminalNotch_shortcut")
        } else {
            UserDefaults.standard.removeObject(forKey: "terminalNotch_shortcut")
        }
    }
    
    /// Register global keyboard shortcut for terminal toggle
    func registerShortcut() {
        // Remove existing monitor
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        
        guard let shortcut = shortcut, isInstalled else { return }
        
        // Create new global monitor
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if Int(event.keyCode) == shortcut.keyCode && flags.rawValue == shortcut.modifiers {
                Task { @MainActor in
                    self.toggle()
                }
            }
        }
        
        // Also monitor local events (when app is focused)
        _ = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, let shortcut = self.shortcut, self.isInstalled else { return event }
            
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if Int(event.keyCode) == shortcut.keyCode && flags.rawValue == shortcut.modifiers {
                Task { @MainActor in
                    self.toggle()
                }
                return nil // Consume the event
            }
            return event
        }
        
        saveShortcut()
    }
    
    /// Remove shortcut
    func removeShortcut() {
        shortcut = nil
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        UserDefaults.standard.removeObject(forKey: "terminalNotch_shortcut")
    }
}
