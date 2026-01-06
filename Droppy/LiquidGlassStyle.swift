//
//  LiquidGlassStyle.swift
//  Droppy
//
//  Created by Jordy Spruit on 03/01/2026.
//

import SwiftUI

/// The foundational modifier for macOS 26 UI elements
struct LiquidGlassStyle: ViewModifier {
    var radius: CGFloat
    var depth: Double // 0.0 (Thin Pane) -> 1.0 (Thick Droplet)
    var isConcave: Bool // True for inputs (pressed in), False for buttons (popped out)
    var shape: AnyShape // Allows different shapes (RoundedRect, Capsule, Custom)

    init(radius: CGFloat = 16, depth: Double = 1.0, isConcave: Bool = false) {
        self.radius = radius
        self.depth = depth
        self.isConcave = isConcave
        self.shape = AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
    
    init<S: Shape>(shape: S, depth: Double = 1.0, isConcave: Bool = false) {
        self.radius = 0 // Not used when custom shape is provided
        self.depth = depth
        self.isConcave = isConcave
        self.shape = AnyShape(shape)
    }

    func body(content: Content) -> some View {
        content
            // 1. The Base Material (Refraction)
            .background(.ultraThinMaterial, in: shape)
            
            // 2. The "Tint" (Volume)
            .background(
                shape
                    .fill(Color.white.opacity(isConcave ? 0.05 : 0.12))
            )
            
            // 3. The Specular Rim (Lighting)
            .overlay(
                shape
                    .stroke(
                        LinearGradient(
                            stops: [
                                // Top Edge: Sharp Highlight
                                .init(color: .white.opacity(isConcave ? 0.1 : 0.7 * depth), location: 0),
                                // Middle: Clear
                                .init(color: .white.opacity(0.1), location: 0.4),
                                // Bottom Edge: Shadow/Occlusion
                                .init(color: isConcave ? .white.opacity(0.5) : .black.opacity(0.2), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            // 4. The Shadow (Elevation)
            .shadow(
                color: Color.black.opacity(isConcave ? 0.0 : 0.15 * depth),
                radius: 10 * depth,
                x: 0,
                y: 8 * depth
            )
    }
}

extension View {
    func liquidGlass(radius: CGFloat = 16, depth: Double = 1.0, isConcave: Bool = false) -> some View {
        self.modifier(LiquidGlassStyle(radius: radius, depth: depth, isConcave: isConcave))
    }
    
    func liquidGlass<S: Shape>(shape: S, depth: Double = 1.0, isConcave: Bool = false) -> some View {
        self.modifier(LiquidGlassStyle(shape: shape, depth: depth, isConcave: isConcave))
    }
}

// MARK: - Components

struct LiquidButton: View {
    var title: String
    var icon: String
    var action: () -> Void
    
    @State private var isHovering = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    // Icons have a slight drop shadow to float inside the glass
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            // Apply the Liquid Glass Engine
            .liquidGlass(
                radius: 99, // Capsule shape
                depth: isHovering ? 1.2 : 1.0, // Swells on hover
                isConcave: false
            )
            // Physical reaction to pressure
            .scaleEffect(isPressed ? 0.96 : 1.0)
            // Inner Glow (Subsurface scattering) - lightweight version
            .overlay(
                RoundedRectangle(cornerRadius: 99, style: .continuous)
                    .stroke(.white.opacity(isHovering ? 0.3 : 0.0), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hover in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                isHovering = hover
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.interactiveSpring(response: 0.2)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressed = false }
                }
        )
    }
}

struct LiquidTextField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 18))
            
            TextField("Search Files...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($isFocused)
        }
        .padding(16)
        // Note: isConcave is set to true
        .liquidGlass(radius: 20, depth: 0.8, isConcave: true)
        .overlay(
            // The "Focus Ring" is now a soft glow, not a sharp line
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.accentColor.opacity(isFocused ? 0.5 : 0), lineWidth: 1.5)
                .shadow(color: Color.accentColor.opacity(isFocused ? 0.4 : 0), radius: 8)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .frame(width: 300)
    }
}
