//
//  DropZoneIcon.swift
//  Droppy
//
//  Premium animated icons for drop zones - subtle and refined.
//

import SwiftUI

/// Premium drop zone icon with subtle hover animations
/// Clean, minimal, and professional look
struct DropZoneIcon: View {
    enum IconType {
        case shelf      // Main drop zone - tray icon
        case airDrop    // AirDrop zone - wireless icon
    }
    
    let type: IconType
    let size: CGFloat
    let isActive: Bool  // Whether files are currently hovering over
    var useAdaptiveForegrounds: Bool = false
    
    var body: some View {
        iconContent
            .frame(width: size, height: size)
            .scaleEffect(isActive ? 1.08 : 1.0)
            .opacity(isActive ? 1.0 : (useAdaptiveForegrounds ? 0.8 : 0.5))
            .animation(DroppyAnimation.expandOpen, value: isActive)
    }
    
    // MARK: - Icon Content
    
    @ViewBuilder
    private var iconContent: some View {
        switch type {
        case .shelf:
            // Clean tray icon for drop zone
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(shelfGradient)
                .symbolRenderingMode(.monochrome)
            
        case .airDrop:
            // Real AirDrop-style icon (matches settings tooltip)
            Image(systemName: "airplayaudio")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(airDropGradient)
                .symbolRenderingMode(.monochrome)
        }
    }
    
    // MARK: - Computed Properties
    
    private var iconSize: CGFloat {
        size * 0.5
    }
    
    private var shelfGradient: LinearGradient {
        LinearGradient(
            colors: isActive 
                ? activeShelfGradientColors
                : idleGradientColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var airDropGradient: LinearGradient {
        LinearGradient(
            colors: isActive
                ? activeAirDropGradientColors
                : idleGradientColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var activeShelfGradientColors: [Color] {
        if useAdaptiveForegrounds {
            return [
                Color.blue.opacity(0.95),
                AdaptiveColors.primaryTextAuto.opacity(0.9)
            ]
        }
        return [Color.white, Color(red: 0.85, green: 0.92, blue: 1.0)]
    }

    private var activeAirDropGradientColors: [Color] {
        if useAdaptiveForegrounds {
            return [
                Color.cyan.opacity(0.92),
                AdaptiveColors.primaryTextAuto.opacity(0.88)
            ]
        }
        return [Color.white, Color(red: 0.7, green: 0.88, blue: 1.0)]
    }

    private var idleGradientColors: [Color] {
        if useAdaptiveForegrounds {
            return [
                AdaptiveColors.primaryTextAuto.opacity(0.78),
                AdaptiveColors.secondaryTextAuto.opacity(0.46)
            ]
        }
        return [
            Color.white.opacity(0.78),
            Color.white.opacity(0.46)
        ]
    }
}

// MARK: - Preview

#Preview("Drop Zone Icons") {
    HStack(spacing: 40) {
        VStack {
            DropZoneIcon(type: .shelf, size: 50, isActive: false)
            Text("Drop (idle)")
                .font(.caption)
        }
        VStack {
            DropZoneIcon(type: .shelf, size: 50, isActive: true)
            Text("Drop (active)")
                .font(.caption)
        }
        VStack {
            DropZoneIcon(type: .airDrop, size: 50, isActive: false)
            Text("AirDrop (idle)")
                .font(.caption)
        }
        VStack {
            DropZoneIcon(type: .airDrop, size: 50, isActive: true)
            Text("AirDrop (active)")
                .font(.caption)
        }
    }
    .padding(DroppySpacing.huge)
    .background(Color.black)
}
