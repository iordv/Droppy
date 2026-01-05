//
//  HexagonDotsEffect.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI

// MARK: - Hexagon Dots Effect
struct HexagonDotsEffect: View {
    var isExpanded: Bool = false
    var mouseLocation: CGPoint
    var isHovering: Bool
    var coordinateSpaceName: String = "shelfContainer"
    
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                // Early exit if size is invalid
                guard size.width > 0 && size.height > 0 else { return }
                
                // Coordinate transformation:
                let myFrame = proxy.frame(in: .named(coordinateSpaceName))
                let localMouse = CGPoint(
                    x: mouseLocation.x - myFrame.minX,
                    y: mouseLocation.y - myFrame.minY
                )
                
                let spacing: CGFloat = 10
                let radius: CGFloat = 0.8
                let hexHeight = spacing * sqrt(3) / 2
                
                let cols = min(Int(size.width / spacing) + 2, 200)
                let rows = min(Int(size.height / hexHeight) + 2, 200)
                
                // Optimization: Batch all idle dots into one path
                var idlePath = Path()
                
                for row in 0..<rows {
                    for col in 0..<cols {
                        let xOffset = (row % 2 == 0) ? 0 : spacing / 2
                        let x = CGFloat(col) * spacing + xOffset
                        let y = CGFloat(row) * hexHeight
                        
                        let point = CGPoint(x: x, y: y)
                        
                        // Optimized distance check to avoid sqrt for every point if possible,
                        // but sqrt is fast enough here.
                        let distSq = pow(point.x - localMouse.x, 2) + pow(point.y - localMouse.y, 2)
                        let limit: CGFloat = 80
                        let limitSq = limit * limit
                        
                        if isHovering && distSq < limitSq {
                            // Active Dot (Draw individually)
                            let distance = sqrt(distSq)
                            let intensity = 1 - (distance / limit)
                            let scale = 1 + (intensity * 0.5)
                            let opacity = 0.02 + (intensity * 0.13)
                            
                            let r = radius * scale
                            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                            
                            // 1. Set opacity
                            context.opacity = opacity
                            // 2. Draw directly without creating a Shape View
                            context.fill(Path(ellipseIn: rect), with: .color(.white))
                            
                        } else {
                            // Idle Dot (Add to batch)
                            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                            idlePath.addEllipse(in: rect)
                        }
                    }
                }
                
                // Draw all idle dots at once
                if !idlePath.isEmpty {
                    context.opacity = 0.015
                    context.fill(idlePath, with: .color(.white))
                }
            }
        }
        .allowsHitTesting(false)
        .animation(nil, value: mouseLocation)
    }
}
