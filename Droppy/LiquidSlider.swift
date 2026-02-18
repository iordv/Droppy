//
//  LiquidSlider.swift
//  Droppy
//
//  Created by Droppy on 05/01/2026.
//  Liquid Glass styled draggable slider
//

import SwiftUI

/// A reusable draggable slider with Liquid Glass (macOS 26) aesthetics
/// Features: Material background, specular rim lighting, expand-on-drag animation
struct LiquidSlider: View {
    @Binding var value: CGFloat // 0.0 to 1.0
    var accentColor: Color = .primary
    var showPercentage: Bool = false
    var isActive: Bool = false // External active state (for keyboard-triggered thickening)
    var onChange: ((CGFloat) -> Void)?
    var onDragChange: ((CGFloat) -> Void)?
    
    @State private var isDragging = false
    
    private let height: CGFloat = 6
    private let expandedHeight: CGFloat = 10
    
    /// Whether the slider should be in expanded state (dragging OR externally active)
    private var isExpanded: Bool { isDragging || isActive }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let currentHeight = isExpanded ? expandedHeight : height
            let progress = max(0, min(1, value))
            let filledWidth = progress * width
            
            ZStack(alignment: .leading) {
                // Track background - concave glass well
                Capsule()
                    .droppyGlassFill()
                    .overlay(
                        Capsule()
                            .fill(AdaptiveColors.buttonBackgroundAuto)
                    )
                    // Concave lighting: shadow on top, highlight on bottom
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: .black.opacity(0.3), location: 0),
                                        .init(color: .clear, location: 0.3),
                                        .init(color: .white.opacity(0.2), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .frame(height: currentHeight)
                
                // Filled portion - gradient with glow
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor,
                                accentColor.opacity(0.6)
                            ],
                            startPoint: .trailing,
                            endPoint: .leading
                        )
                    )
                    .frame(width: max(currentHeight, filledWidth), height: currentHeight)
                    // Inner glow
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: .white.opacity(0.6), location: 0),
                                        .init(color: .clear, location: 0.5)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )
                    // Glow shadow
                    .shadow(
                        color: accentColor.opacity(isExpanded ? 0.5 : 0.3),
                        radius: isExpanded ? 8 : 4,
                        x: 2,
                        y: 0
                    )
                    .opacity(value > 0.001 ? 1 : 0)
            }
            .frame(height: currentHeight)
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        withAnimation(DroppyAnimation.hover) {
                            isDragging = true
                        }
                        let newValue = gesture.location.x / width
                        let clampedValue = max(0, min(1, newValue))
                        value = clampedValue
                        onDragChange?(clampedValue)
                    }
                    .onEnded { _ in
                        withAnimation(DroppyAnimation.state) {
                            isDragging = false
                        }
                        onChange?(value)
                    }
            )
        }
        .frame(height: expandedHeight)
    }
}

/// System HUD content type
enum HUDContentType: String, CaseIterable {
    case volume
    case brightness
    case backlight
    case mute
    
    var icon: String {
        switch self {
        case .volume: return "speaker.wave.2.fill"
        case .brightness: return "sun.max.fill"
        case .backlight: return "light.max"
        case .mute: return "speaker.slash.fill"
        }
    }
    
    var label: String {
        switch self {
        case .volume: return "Volume"
        case .brightness: return "Brightness"
        case .backlight: return "Backlight"
        case .mute: return "Muted"
        }
    }
    
    /// Dynamic icon based on value
    func icon(for value: CGFloat) -> String {
        switch self {
        case .volume:
            if value == 0 { return "speaker.slash.fill" }
            else if value < 0.33 { return "speaker.wave.1.fill" }
            else if value < 0.66 { return "speaker.wave.2.fill" }
            else { return "speaker.wave.3.fill" }
        case .brightness:
            return value < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .backlight:
            return value > 0.5 ? "light.max" : "light.min"
        case .mute:
            return value > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        // Volume slider
        HStack(spacing: 12) {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(.primary)
            LiquidSlider(value: .constant(0.7))
                .frame(width: 200)
            Text("70%")
                .foregroundStyle(.gray)
        }
        .padding()
        .background(.black)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl))
        
        // Brightness slider
        HStack(spacing: 12) {
            Image(systemName: "sun.max.fill")
                .foregroundStyle(.yellow)
            LiquidSlider(value: .constant(0.4), accentColor: .yellow)
                .frame(width: 200)
        }
        .padding()
        .background(.black)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl))
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
