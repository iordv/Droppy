import SwiftUI

// MARK: - Element Capture Preview Components
// Extracted from ElementCaptureManager.swift for faster incremental builds

struct CapturePreviewView: View {
    let image: NSImage
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    
    private let cornerRadius: CGFloat = 28
    private let padding: CGFloat = 16  // Symmetrical padding on all sides
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with badge (matching basket header style)
            HStack {
                Text("Screenshot")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Success badge (styled like basket buttons)
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("Copied!")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AdaptiveColors.hoverBackgroundAuto, lineWidth: 1)
                )
            }
            
            // Screenshot preview
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AdaptiveColors.hoverBackgroundAuto, lineWidth: 1)
                )
        }
        .padding(padding)  // Symmetrical padding on all sides
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
        )
        // Note: Shadow handled by NSWindow.hasShadow for proper rounded appearance
    }
}

