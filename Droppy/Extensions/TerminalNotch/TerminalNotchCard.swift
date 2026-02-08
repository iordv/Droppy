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

    private var titleColor: Color {
        AdaptiveColors.primaryTextAuto
    }

    private var subtitleColor: Color {
        AdaptiveColors.secondaryTextAuto
    }

    private var actionTextColor: Color {
        AdaptiveColors.primaryTextAuto
    }
    
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
                        .foregroundStyle(titleColor)
                    
                    // Subtitle
                    Text(extensionType.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(subtitleColor)
                    
                    Spacer()
                    
                    // Install status
                    HStack(spacing: 8) {
                        if manager.isInstalled {
                            Text("Installed")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.green)
                        } else {
                            Text("Set Up")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(actionTextColor)
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
            .padding(DroppySpacing.xl)
            .frame(height: 160)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
        }
        .buttonStyle(DroppyCardButtonStyle(cornerRadius: DroppyRadius.large))
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.green.opacity(0.16), AdaptiveColors.panelBackgroundAuto],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                    .strokeBorder(AdaptiveColors.overlayAuto(0.1), lineWidth: 1)
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
