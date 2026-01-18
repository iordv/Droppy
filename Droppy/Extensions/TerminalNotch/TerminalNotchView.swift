//
//  TerminalNotchView.swift
//  Droppy
//
//  SwiftUI view for the terminal interface
//

import SwiftUI

/// Quick command terminal view that appears in the notch area
struct TerminalNotchView: View {
    @ObservedObject var manager: TerminalNotchManager
    @FocusState private var isInputFocused: Bool
    
    /// Whether we're in Dynamic Island mode (no physical notch to clear)
    private var isDynamicIslandMode: Bool {
        guard let screen = NSScreen.main else { return true }
        let hasNotch = screen.safeAreaInsets.top > 0
        let useDynamicIsland = UserDefaults.standard.object(forKey: "useDynamicIslandStyle") as? Bool ?? true
        // External displays or DI mode = no physical notch
        return !screen.isBuiltIn || (!hasNotch && useDynamicIsland)
    }
    
    /// Standard padding for content
    private let uniformPadding: CGFloat = 14
    
    /// Extra top padding needed to clear the physical notch
    private var topPadding: CGFloat {
        isDynamicIslandMode ? uniformPadding : 36
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if manager.isExpanded {
                expandedTerminalView
            } else {
                quickCommandView
            }
        }
        // No external styling - terminal lives inside shelf's content area
        // which already has its own black background
        .onAppear {
            isInputFocused = true
        }
    }
    
    // MARK: - Quick Command View
    
    private var quickCommandView: some View {
        VStack(spacing: 8) {
            // Top spacer: 36pt for notch mode (clears physical notch), 14pt uniform for DI mode
            Spacer()
                .frame(height: topPadding)
            
            // Command input row
            HStack(spacing: 10) {
                // Shell prompt
                Text("$")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                
                // Command input
                TextField("Enter command...", text: $manager.commandText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white)
                    .focused($isInputFocused)
                    .onSubmit {
                        manager.executeQuickCommand(manager.commandText)
                    }
                    .onKeyPress(.upArrow) {
                        manager.historyUp()
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        manager.historyDown()
                        return .handled
                    }
                
                // Running indicator
                if manager.isRunning {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            // Output preview (if any)
            if !manager.lastOutput.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                ScrollView {
                    Text(manager.lastOutput)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .frame(maxHeight: 200)
            }
        }
    }
    
    // MARK: - Expanded Terminal View
    
    private var expandedTerminalView: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Terminal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                
                Spacer()
                
                // Collapse button
                Button(action: { manager.toggleExpanded() }) {
                    Image(systemName: "rectangle.compress.vertical")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Collapse to quick mode")
                
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
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Terminal content area
            // This will be replaced with SwiftTerm's LocalProcessTerminalView
            // For now, show a placeholder with the quick command interface
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        // Show command history with outputs
                        ForEach(manager.commandHistory.suffix(20), id: \.self) { cmd in
                            HStack(spacing: 6) {
                                Text("$")
                                    .foregroundStyle(.green)
                                Text(cmd)
                                    .foregroundStyle(.white)
                            }
                            .font(.system(size: manager.fontSize, design: .monospaced))
                        }
                        
                        if !manager.lastOutput.isEmpty {
                            Text(manager.lastOutput)
                                .font(.system(size: manager.fontSize, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                
                // Input line
                HStack(spacing: 8) {
                    Text("$")
                        .font(.system(size: manager.fontSize, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                    
                    TextField("", text: $manager.commandText)
                        .textFieldStyle(.plain)
                        .font(.system(size: manager.fontSize, design: .monospaced))
                        .foregroundStyle(.white)
                        .focused($isInputFocused)
                        .onSubmit {
                            manager.executeQuickCommand(manager.commandText)
                        }
                        .onKeyPress(.upArrow) {
                            manager.historyUp()
                            return .handled
                        }
                        .onKeyPress(.downArrow) {
                            manager.historyDown()
                            return .handled
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.03))
            }
            .frame(height: manager.terminalHeight)
        }
    }
    
    // MARK: - Background
    
    private var terminalBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview {
    TerminalNotchView(manager: TerminalNotchManager.shared)
        .frame(width: 400)
        .padding()
        .background(Color.black)
}
