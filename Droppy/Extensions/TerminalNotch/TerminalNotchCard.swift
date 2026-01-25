//
//  TerminalNotchCard.swift
//  Droppy
//
//  Featured card for Terminal Notch in the extension store
//

import SwiftUI

/// Featured card displayed in the Extension Store
struct TerminalNotchCard: View {
    @ObservedObject var manager = TerminalNotchManager.shared
    var onTap: () -> Void = {}
    
    private let extensionType = ExtensionType.terminalNotch
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    // Category badge
                    Text(extensionType.category.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                    
                    // Title
                    Text(extensionType.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    // Subtitle
                    Text(extensionType.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Spacer()
                    
                    // Install status
                    HStack(spacing: 8) {
                        if manager.isInstalled {
                            Text("Installed")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.green)
                        } else {
                            Text("Get")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.green)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer()
                
                // Icon
                extensionType.iconView
            }
            .padding(20)
            .frame(height: 160)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(DroppyCardButtonStyle(cornerRadius: 16))
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.green.opacity(0.3),
                        Color.black.opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview {
    TerminalNotchCard()
        .frame(width: 300)
        .padding()
        .background(Color.black)
}
