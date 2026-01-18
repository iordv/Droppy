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
    @State private var isCopyHovering = false
    @State private var isCloseHovering = false
    @State private var showCopiedFeedback = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Extracted Text")
                        .font(.headline)
                    Text("Text recognized from image")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(20)
            
            Divider()
                .padding(.horizontal, 20)
            
            // Content
            ScrollView {
                Text(text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 300)
            
            Divider()
                .padding(.horizontal, 20)
            
            // Action buttons
            HStack(spacing: 10) {
                Button {
                    onClose()
                } label: {
                    Text("Close")
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background((isCloseHovering ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isCloseHovering = h
                    }
                }
                
                Spacer()
                
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(text, forType: .string)
                    
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        showCopiedFeedback = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        onClose()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold))
                        Text(showCopiedFeedback ? "Copied!" : "Copy to Clipboard")
                    }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background((showCopiedFeedback ? Color.green : Color.blue).opacity(isCopyHovering ? 1.0 : 0.8))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isCopyHovering = h
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
    }
}
