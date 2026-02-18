//
//  TerminalNotchButton.swift
//  Droppy
//
//  Floating button to toggle terminal visibility
//

import SwiftUI

/// Floating terminal button that appears below the shelf
struct TerminalNotchButton: View {
    @ObservedObject var manager: TerminalNotchManager
    var isDynamicIslandMode: Bool = false
    
    var body: some View {
        Button(action: { manager.toggle() }) {
            Image(systemName: "terminal")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .padding(DroppySpacing.smd)
                .background(buttonBackground)
        }
        .buttonStyle(DroppyCardButtonStyle(cornerRadius: DroppyRadius.lx))
        .help("Toggle Terminal (Ctrl + `)")
    }
    
    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: DroppyRadius.lx, style: .continuous)
            .droppyGlassFill()
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.lx, style: .continuous)
                    .fill(Color.black.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.lx, style: .continuous)
                    .strokeBorder(AdaptiveColors.overlayAuto(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black
        TerminalNotchButton(manager: TerminalNotchManager.shared)
    }
    .frame(width: 100, height: 100)
}
