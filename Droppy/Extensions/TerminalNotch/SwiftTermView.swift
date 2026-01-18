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
        let terminalView = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        
        // Configure terminal appearance - set explicit colors
        terminalView.nativeBackgroundColor = NSColor.black
        terminalView.nativeForegroundColor = NSColor.white
        
        // Set caret (cursor) color to be visible
        terminalView.caretColor = NSColor.systemGreen
        
        // Set font
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        terminalView.font = font
        
        // Configure terminal options
        terminalView.optionAsMetaKey = true
        
        // Set delegate
        terminalView.processDelegate = context.coordinator
        
        // Store reference for coordinator
        context.coordinator.terminalView = terminalView
        
        // Start the shell process AFTER setup
        DispatchQueue.main.async {
            self.startShell(in: terminalView)
        }
        
        return terminalView
    }
    
    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Update font if changed
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if nsView.font != font {
            nsView.font = font
        }
        
        // Ensure colors are set
        nsView.nativeBackgroundColor = NSColor.black
        nsView.nativeForegroundColor = NSColor.white
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(manager: manager)
    }
    
    private func startShell(in terminalView: LocalProcessTerminalView) {
        // Get shell path (use user's configured shell or default to zsh)
        let shell = shellPath.isEmpty ? getDefaultShell() : shellPath
        
        // Extract shell name and create login shell idiom (e.g., "-zsh")
        let shellName = (shell as NSString).lastPathComponent
        let shellIdiom = "-" + shellName
        
        // Change to home directory before starting shell
        FileManager.default.changeCurrentDirectoryPath(
            FileManager.default.homeDirectoryForCurrentUser.path
        )
        
        print("[SwiftTermView] Starting shell: \(shell) with idiom: \(shellIdiom)")
        
        // Start process using the same pattern as SwiftTerm's sample app
        terminalView.startProcess(executable: shell, execName: shellIdiom)
        
        // Force a redraw after starting
        terminalView.needsDisplay = true
    }
    
    /// Get the user's default shell from the system
    private func getDefaultShell() -> String {
        let bufsize = sysconf(_SC_GETPW_R_SIZE_MAX)
        guard bufsize != -1 else { return "/bin/zsh" }
        
        let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufsize)
        defer { buffer.deallocate() }
        
        var pwd = passwd()
        var result: UnsafeMutablePointer<passwd>?
        
        if getpwuid_r(getuid(), &pwd, buffer, bufsize, &result) == 0 {
            return String(cString: pwd.pw_shell)
        }
        return "/bin/zsh"
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        var manager: TerminalNotchManager
        weak var terminalView: LocalProcessTerminalView?
        
        init(manager: TerminalNotchManager) {
            self.manager = manager
        }
        
        // MARK: - LocalProcessTerminalViewDelegate
        
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
            print("[SwiftTermView] Size changed: \(newCols)x\(newRows)")
        }
        
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            print("[SwiftTermView] Title: \(title)")
        }
        
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            print("[SwiftTermView] Directory: \(directory ?? "nil")")
        }
        
        func processTerminated(source: TerminalView, exitCode: Int32?) {
            print("[SwiftTermView] Process terminated with code: \(exitCode ?? -1)")
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
