//
//  OCRResultView.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI

struct OCRResultView: View {
    let text: String
    let onClose: () -> Void
    
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    @State private var hoverLocation: CGPoint = .zero
    @State private var isBgHovering: Bool = false
    @State private var isCopyHovering = false
    @State private var isCloseHovering = false
    @State private var showCopiedFeedback = false
    
    private let cornerRadius: CGFloat = 24
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(useTransparentBackground ? Color.clear : Color.black)
                .background {
                    if useTransparentBackground {
                        Color.clear
                            .liquidGlass(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                }
                .overlay {
                    HexagonDotsEffect(
                        mouseLocation: hoverLocation,
                        isHovering: isBgHovering,
                        coordinateSpaceName: "ocrContainer"
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Extracted Text")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                    
                    // Copy Button
                    Button {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(text, forType: .string)
                        
                        // Show feedback and close
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            showCopiedFeedback = true
                        }
                        
                        // Close window after brief feedback
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            onClose()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11, weight: .bold))
                            Text(showCopiedFeedback ? "Copied!" : "Copy")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(showCopiedFeedback ? Color.green.opacity(0.9) : Color.blue.opacity(isCopyHovering ? 1.0 : 0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isCopyHovering)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isCopyHovering)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: showCopiedFeedback)
                    }
                    .buttonStyle(.plain)
                    .onHover { mirroring in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isCopyHovering = mirroring
                        }
                    }
                    
                    // Close Button
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(isCloseHovering ? 1.0 : 0.6))
                            .padding(8)
                            .background(Color.white.opacity(isCloseHovering ? 0.25 : 0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .scaleEffect(isCloseHovering ? 1.1 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isCloseHovering)
                    }
                    .buttonStyle(.plain)
                    .onHover { mirroring in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isCloseHovering = mirroring
                        }
                    }
                }
                .padding(16)
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // Content
                ScrollView {
                    Text(text)
                        .font(.body) // Cleaner look than monospaced
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(width: 400, height: 500)
        .coordinateSpace(name: "ocrContainer")
        .onContinuousHover(coordinateSpace: .named("ocrContainer")) { phase in
            switch phase {
            case .active(let location):
                hoverLocation = location
                isBgHovering = true
            case .ended:
                isBgHovering = false
            }
        }
        .padding(40)
    }
}
