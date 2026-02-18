import SwiftUI

// MARK: - Element Capture Preview Components
// Extracted from ElementCaptureManager.swift for faster incremental builds

struct CapturePreviewView: View {
    let image: NSImage
    var onEditTapped: ((NSImage) -> Void)? = nil
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    
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
                
                // Edit button (Droppy grey with hover effect)
                if onEditTapped != nil {
                    EditButton {
                        onEditTapped?(image)
                    }
                }
                
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
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                        .stroke(AdaptiveColors.hoverBackgroundAuto, lineWidth: 1)
                )
            }
            
            // Screenshot preview
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                        .stroke(AdaptiveColors.hoverBackgroundAuto, lineWidth: 1)
                )
        }
        .padding(padding)  // Symmetrical padding on all sides
        .droppyTransparentBackground(useTransparentBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
        )
        // Note: Shadow handled by NSWindow.hasShadow for proper rounded appearance
    }
}

// MARK: - Edit Button with Hover Effect

private struct EditButton: View {
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "pencil")
                    .font(.system(size: 10, weight: .semibold))
                Text("Edit")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? AdaptiveColors.overlayAuto(0.15) : AdaptiveColors.overlayAuto(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                    .stroke(AdaptiveColors.hoverBackgroundAuto, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help("Edit Screenshot")
    }
}
