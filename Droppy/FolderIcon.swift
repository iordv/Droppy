//
//  FolderIcon.swift
//  Droppy
//
//  Custom animated folder icon in the same style as NotchFace.
//  Pure SwiftUI shapes for true 120fps buttery smooth animation.
//

import SwiftUI

/// Custom folder icon with the same premium look as NotchFace
struct FolderIcon: View {
    var size: CGFloat = 30
    var isPinned: Bool = false
    var isHovering: Bool = false
    
    // Gradient for regular folder (blue tint like NotchFace)
    private var folderGradient: LinearGradient {
        LinearGradient(
            colors: isPinned 
                ? [Color(red: 1.0, green: 0.95, blue: 0.7), Color(red: 0.95, green: 0.82, blue: 0.4)]  // Yellow/gold for pinned
                : [.white, Color(red: 0.72, green: 0.86, blue: 1.0)],  // Same as NotchFace
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // Darker shade for folder tab
    private var tabGradient: LinearGradient {
        LinearGradient(
            colors: isPinned
                ? [Color(red: 0.95, green: 0.85, blue: 0.5), Color(red: 0.88, green: 0.72, blue: 0.3)]
                : [Color(red: 0.85, green: 0.92, blue: 1.0), Color(red: 0.6, green: 0.78, blue: 0.95)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var body: some View {
        ZStack {
            // Main folder body
            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                .fill(folderGradient)
                .frame(width: size * 0.85, height: size * 0.65)
                .offset(y: size * 0.08)
            
            // Folder tab (top left)
            FolderTab()
                .fill(tabGradient)
                .frame(width: size * 0.4, height: size * 0.18)
                .offset(x: -size * 0.2, y: -size * 0.22)
            
            // Pin icon for pinned folders
            if isPinned {
                PinShape()
                    .fill(Color(red: 0.85, green: 0.65, blue: 0.2))
                    .frame(width: size * 0.22, height: size * 0.28)
                    .offset(x: size * 0.22, y: -size * 0.02)
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.25), radius: size * 0.03, y: size * 0.03)
        .scaleEffect(isHovering ? 1.08 : 1.0, anchor: .center)
        // Animation handled by parent view to prevent recursion lag
    }
}

/// Folder tab shape (rounded on top)
private struct FolderTab: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius = rect.height * 0.4
        
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: cornerRadius, y: 0),
            control: CGPoint(x: 0, y: 0)
        )
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: cornerRadius),
            control: CGPoint(x: rect.maxX, y: 0)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        
        return path
    }
}

/// Pin shape for pinned folders
private struct PinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Pin head (circle)
        let headRadius = w * 0.35
        path.addEllipse(in: CGRect(
            x: (w - headRadius * 2) / 2,
            y: 0,
            width: headRadius * 2,
            height: headRadius * 2
        ))
        
        // Pin body (triangle pointing down)
        path.move(to: CGPoint(x: w * 0.3, y: headRadius * 1.5))
        path.addLine(to: CGPoint(x: w * 0.5, y: h))
        path.addLine(to: CGPoint(x: w * 0.7, y: headRadius * 1.5))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - ZIP File Icon

/// Custom ZIP file icon with zipper detail for a premium look
struct ZIPFileIcon: View {
    var size: CGFloat = 44
    var isHovering: Bool = false
    
    private var iconScale: CGFloat { size / 44 }
    
    // Clean gradient for file body
    private var fileGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.95, green: 0.95, blue: 0.97), Color(red: 0.82, green: 0.84, blue: 0.88)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Purple/blue gradient for zipper (matching app accent)
    private var zipperGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var body: some View {
        ZStack {
            // File body with folded corner
            ZStack {
                // Main body
                UnevenRoundedRectangle(
                    topLeadingRadius: size * 0.12,
                    bottomLeadingRadius: size * 0.12,
                    bottomTrailingRadius: size * 0.12,
                    topTrailingRadius: size * 0.02
                )
                .fill(fileGradient)
                .frame(width: size * 0.7, height: size * 0.85)
                
                // Folded corner
                Path { path in
                    let cornerSize = size * 0.15
                    let startX = size * 0.7 / 2 - cornerSize / 2 + size * 0.125
                    let startY = -size * 0.85 / 2
                    
                    path.move(to: CGPoint(x: startX, y: startY))
                    path.addLine(to: CGPoint(x: startX + cornerSize, y: startY + cornerSize))
                    path.addLine(to: CGPoint(x: startX, y: startY + cornerSize))
                    path.closeSubpath()
                }
                .fill(Color(red: 0.75, green: 0.77, blue: 0.82))
            }
            
            // Zipper - vertical stripe with teeth
            VStack(spacing: 2 * iconScale) {
                ForEach(0..<5, id: \.self) { index in
                    // Zipper tooth pair
                    HStack(spacing: 1 * iconScale) {
                        // Left tooth
                        RoundedRectangle(cornerRadius: 1 * iconScale)
                            .fill(zipperGradient)
                            .frame(width: 4 * iconScale, height: 3 * iconScale)
                        
                        // Center line
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 1 * iconScale, height: 3 * iconScale)
                        
                        // Right tooth
                        RoundedRectangle(cornerRadius: 1 * iconScale)
                            .fill(zipperGradient)
                            .frame(width: 4 * iconScale, height: 3 * iconScale)
                    }
                }
            }
            .offset(y: size * 0.05)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.2), radius: size * 0.04, y: size * 0.03)
        .scaleEffect(isHovering ? 1.08 : 1.0, anchor: .center)
        .scaleEffect(isHovering ? 1.08 : 1.0, anchor: .center)
        // Animation handled by parent view to prevent recursion lag
    }
}

#Preview {
    HStack(spacing: 20) {
        VStack {
            FolderIcon(size: 44, isPinned: false)
            Text("Regular").font(.caption)
        }
        VStack {
            FolderIcon(size: 44, isPinned: true)
            Text("Pinned").font(.caption)
        }
        VStack {
            FolderIcon(size: 44, isPinned: false, isHovering: true)
            Text("Hover").font(.caption)
        }
        VStack {
            ZIPFileIcon(size: 44)
            Text("ZIP").font(.caption)
        }
        VStack {
            ZIPFileIcon(size: 44, isHovering: true)
            Text("ZIP Hover").font(.caption)
        }
    }
    .padding()
    .background(Color.black)
}
