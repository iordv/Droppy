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
        
        // Configure terminal appearance
        terminalView.nativeBackgroundColor = NSColor.black
        terminalView.nativeForegroundColor = NSColor.white
        terminalView.caretColor = NSColor.systemGreen
        
        // IMPORTANT: Set autoresizing
        terminalView.autoresizingMask = [.width, .height]
        
        // Set font
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        terminalView.font = font
        
        // Configure terminal options
        terminalView.optionAsMetaKey = true
        
        // Set delegate
        terminalView.processDelegate = context.coordinator
        
        // Store reference for coordinator
        context.coordinator.terminalView = terminalView
        
        // Start the shell process
        let shell = shellPath.isEmpty ? "/bin/zsh" : shellPath
        let shellName = (shell as NSString).lastPathComponent
        let shellIdiom = "-" + shellName
        
        // Change to home directory
        FileManager.default.changeCurrentDirectoryPath(
            FileManager.default.homeDirectoryForCurrentUser.path
        )
        
        print("[SwiftTermView] Starting shell: \(shell)")
        terminalView.startProcess(executable: shell, execName: shellIdiom)
        
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
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        var manager: TerminalNotchManager
        weak var terminalView: LocalProcessTerminalView?
        
        init(manager: TerminalNotchManager) {
            self.manager = manager
        }
        
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
            print("[SwiftTermView] Size: \(newCols)x\(newRows)")
        }
        
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            print("[SwiftTermView] Title: \(title)")
        }
        
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            print("[SwiftTermView] Dir: \(directory ?? "nil")")
        }
        
        func processTerminated(source: TerminalView, exitCode: Int32?) {
            print("[SwiftTermView] Terminated: \(exitCode ?? -1)")
        }
    }
}
