//
//  TerminalNotchView.swift
//  Droppy
//
//  SwiftUI view for the terminal interface using SwiftTerm
//

import SwiftUI

/// Terminal view that appears in the notch/shelf area
/// Uses SwiftTerm for full VT100 terminal emulation
struct TerminalNotchView: View {
    @ObservedObject var manager: TerminalNotchManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            terminalToolbar
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Full SwiftTerm terminal
            SwiftTermView(
                manager: manager,
                shellPath: manager.shellPath,
                fontSize: manager.fontSize
            )
            .frame(height: manager.terminalHeight)
        }
    }
    
    // MARK: - Toolbar
    
    private var terminalToolbar: some View {
        HStack {
            Text("Terminal")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            
            Spacer()
            
            // Font size controls
            HStack(spacing: 4) {
                Button(action: { manager.decreaseFontSize() }) {
                    Image(systemName: "textformat.size.smaller")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Decrease font size")
                
                Button(action: { manager.increaseFontSize() }) {
                    Image(systemName: "textformat.size.larger")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Increase font size")
            }
            .padding(.horizontal, 4)
            
            // Open in Terminal.app
            Button(action: { manager.openInTerminalApp() }) {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Open in Terminal.app")
            
            // Close button
            Button(action: { manager.hide() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Close terminal")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
    }
}

// MARK: - Preview

#Preview {
    TerminalNotchView(manager: TerminalNotchManager.shared)
        .frame(width: 400)
        .padding()
        .background(Color.black)
}
