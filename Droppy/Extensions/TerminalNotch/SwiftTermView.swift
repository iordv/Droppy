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
    
    func makeNSView(context: Context) -> NSView {
        // Create a container view to handle layout
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.cgColor
        
        // Create terminal view
        let terminalView = LocalProcessTerminalView(frame: containerView.bounds)
        terminalView.autoresizingMask = [.width, .height]
        
        // Configure terminal appearance
        terminalView.nativeBackgroundColor = NSColor.black
        terminalView.nativeForegroundColor = NSColor.white
        terminalView.caretColor = NSColor.systemGreen
        
        // Set font
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        terminalView.font = font
        
        // Configure terminal options
        terminalView.optionAsMetaKey = true
        
        // Set delegate
        terminalView.processDelegate = context.coordinator
        
        // Add to container
        containerView.addSubview(terminalView)
        
        // Store reference for coordinator
        context.coordinator.terminalView = terminalView
        
        // Start the shell process after a brief delay to allow layout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.startShell(in: terminalView)
        }
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let terminalView = context.coordinator.terminalView else { return }
        
        // Update terminal frame to match container
        terminalView.frame = nsView.bounds
        
        // Update font if changed
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if terminalView.font != font {
            terminalView.font = font
        }
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
        
        // Start process
        terminalView.startProcess(executable: shell, execName: shellIdiom)
        
        // Force layout update
        terminalView.needsLayout = true
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
