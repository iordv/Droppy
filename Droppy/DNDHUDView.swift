//
//  DNDHUDView.swift
//  Droppy
//
//  Created by Droppy on 17/01/2026.
//  Focus/DND HUD matching CapsLockHUDView style exactly
//

import SwiftUI

/// Compact Focus/DND HUD that sits inside the notch
/// Matches CapsLockHUDView layout exactly: icon on left wing, ON/OFF on right wing
struct DNDHUDView: View {
    @ObservedObject var dndManager: DNDManager
    let notchWidth: CGFloat   // Physical notch width
    let notchHeight: CGFloat  // Physical notch height
    let hudWidth: CGFloat     // Total HUD width
    var targetScreen: NSScreen? = nil  // Target screen for multi-monitor support
    
    /// Width of each "wing" (area left/right of physical notch)
    private var wingWidth: CGFloat {
        (hudWidth - notchWidth) / 2
    }
    
    /// Accent color: purple when Focus ON, white when OFF
    /// In transparent DI mode, always use white for readability
    private var accentColor: Color {
        dndManager.isDNDActive ? Color(red: 0.55, green: 0.35, blue: 0.95) : .white
    }
    
    /// Focus icon - use filled variant when ON
    private var focusIcon: String {
        dndManager.isDNDActive ? "moon.fill" : "moon"
    }
    
    /// Whether we're in Dynamic Island mode (screen-aware for multi-monitor)
    private var isDynamicIslandMode: Bool {
        let screen = targetScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen = screen else { return true }
        let hasNotch = screen.safeAreaInsets.top > 0
        let forceTest = UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")
        
        // External displays never have physical notches, so always use compact HUD layout
        if !screen.isBuiltIn {
            return true
        }
        
        // For built-in display, use main Dynamic Island setting
        let useDynamicIsland = UserDefaults.standard.object(forKey: "useDynamicIslandStyle") as? Bool ?? true
        return (!hasNotch || forceTest) && useDynamicIsland
    }
    
    /// Whether transparent Dynamic Island mode is enabled
    private var isTransparentDI: Bool {
        isDynamicIslandMode && UserDefaults.standard.bool(forKey: "useDynamicIslandTransparent")
    }
    
    /// Color for Dynamic Island mode - white for transparent, accent color otherwise
    private var dynamicIslandColor: Color {
        isTransparentDI ? .white : accentColor
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if isDynamicIslandMode {
                // DYNAMIC ISLAND: Icon on left edge, On/Off on right edge
                // Using BoringNotch pattern: padding = (notchHeight - iconHeight) / 2 for symmetry
                let iconSize: CGFloat = 18
                let symmetricPadding = (notchHeight - iconSize) / 2
                
                HStack {
                    // Focus icon - .leading alignment within frame
                    Image(systemName: focusIcon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(dynamicIslandColor)
                        .symbolEffect(.bounce.up, value: dndManager.isDNDActive)
                        .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                        .frame(width: 20, height: iconSize, alignment: .leading)
                    
                    Spacer()
                    
                    // On/Off text
                    Text(dndManager.isDNDActive ? "On" : "Off")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(dynamicIslandColor)
                        .contentTransition(.interpolate)
                }
                .padding(.horizontal, symmetricPadding)  // Same as vertical for symmetry
                .frame(height: notchHeight)
            } else {
                // NOTCH MODE: Two wings separated by the notch space
                // Using BoringNotch pattern: 20px icons with symmetricPadding for outer-wing alignment
                let iconSize: CGFloat = 20
                let symmetricPadding = max((notchHeight - iconSize) / 2, 6)  // Min 6px for visibility
                
                HStack(spacing: 0) {
                    // Left wing: Focus icon near left edge
                    HStack {
                        Image(systemName: focusIcon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .symbolEffect(.bounce.up, value: dndManager.isDNDActive)
                            .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                            .frame(width: iconSize, height: iconSize, alignment: .leading)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, symmetricPadding)
                    .frame(width: wingWidth)
                    
                    // Camera notch area (spacer)
                    Spacer()
                        .frame(width: notchWidth)
                    
                    // Right wing: ON/OFF near right edge
                    HStack {
                        Spacer(minLength: 0)
                        Text(dndManager.isDNDActive ? "On" : "Off")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .contentTransition(.interpolate)
                            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: dndManager.isDNDActive)
                    }
                    .padding(.trailing, symmetricPadding)
                    .frame(width: wingWidth)
                }
                .frame(height: notchHeight)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black
        DNDHUDView(
            dndManager: DNDManager.shared,
            notchWidth: 180,
            notchHeight: 32,
            hudWidth: 300
        )
    }
    .frame(width: 350, height: 60)
}
