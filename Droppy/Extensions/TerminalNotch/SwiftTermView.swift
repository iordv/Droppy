//
//  SwiftTermView.swift
//  Droppy
//
//  SwiftUI wrapper for SwiftTerm's LocalProcessTerminalView
//

import SwiftUI
import AppKit
import SwiftTerm

/// SwiftUI wrapper for SwiftTerm's LocalProcessTerminalView
/// Provides full VT100 terminal emulation with PTY support
struct SwiftTermView: NSViewRepresentable {
    @ObservedObject var manager: TerminalNotchManager
    
    /// Shell to use (zsh, bash, etc.)
    var shellPath: String
    
    /// Font size for terminal text
    var fontSize: CGFloat
    
    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)
        
        // Configure terminal appearance
        terminalView.nativeBackgroundColor = .black
        terminalView.nativeForegroundColor = .white
        
        // Set font
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        terminalView.font = font
        
        // Configure terminal options
        terminalView.optionAsMetaKey = true
        
        // Start the shell process
        startShell(in: terminalView)
        
        // Store reference for coordinator
        context.coordinator.terminalView = terminalView
        
        return terminalView
    }
    
    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Update font if changed
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if nsView.font != font {
            nsView.font = font
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(manager: manager)
    }
    
    private func startShell(in terminalView: LocalProcessTerminalView) {
        // Get shell path
        let shell = shellPath.isEmpty ? "/bin/zsh" : shellPath
        
        // Extract shell name from path (e.g., "zsh" from "/bin/zsh")
        let shellName = (shell as NSString).lastPathComponent
        
        // For login shell, the execName should be prefixed with "-" (e.g., "-zsh")
        let loginShellName = "-" + shellName
        
        // Get environment variables
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["LANG"] = "en_US.UTF-8"
        env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        env["SHELL"] = shell
        
        // Convert environment to array format (KEY=VALUE)
        let envArray = env.map { "\($0.key)=\($0.value)" }
        
        // Home directory for starting location
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        
        // Start the process
        // args: [loginShellName] means the shell sees itself as a login shell
        // execName: is what goes in argv[0]
        terminalView.startProcess(
            executable: shell,
            args: [],  // Arguments AFTER the shell name
            environment: envArray,
            execName: loginShellName  // Makes it a login shell
        )
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject {
        var manager: TerminalNotchManager
        weak var terminalView: LocalProcessTerminalView?
        
        init(manager: TerminalNotchManager) {
            self.manager = manager
        }
        
        /// Send input to terminal
        func sendInput(_ text: String) {
            terminalView?.send(txt: text)
        }
        
        /// Send special key
        func sendKey(_ key: UInt8) {
            terminalView?.send([key])
        }
        
        /// Terminate the process
        func terminate() {
            // Send Ctrl+C to the shell
            terminalView?.send([0x03])
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SwiftTermView_Previews: PreviewProvider {
    static var previews: some View {
        SwiftTermView(
            manager: TerminalNotchManager.shared,
            shellPath: "/bin/zsh",
            fontSize: 13
        )
        .frame(width: 400, height: 300)
    }
}
#endif
