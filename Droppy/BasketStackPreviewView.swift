//
//  BasketStackPreviewView.swift
//  Droppy
//
//  Dropover-style stacked thumbnail preview for the collapsed basket view
//

import SwiftUI
import UniformTypeIdentifiers
import AVKit
import QuickLookThumbnailing

// MARK: - Basket Stack Preview View

/// Stacked thumbnail preview matching Dropover's exact styling
/// Shows up to 3 stacked cards with rotation/offset and rounded corners
struct BasketStackPreviewView: View {
    let items: [DroppedItem]
    
    // The most recent items to display (max 3 for visual stack)
    private var displayItems: [DroppedItem] {
        Array(items.suffix(3))
    }
    
    // Thumbnail cache for efficient rendering
    @State private var thumbnails: [UUID: NSImage] = [:]
    
    // Animation state for stacking effect
    @State private var hasAppeared = false
    
    // Hover state for peek/separate effect
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            // Render cards from bottom to top (oldest to newest)
            ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                DropoverCard(
                    item: item,
                    thumbnail: thumbnails[item.id],
                    index: index,
                    totalCount: displayItems.count,
                    hasAppeared: hasAppeared,
                    isHovering: isHovering
                )
                .zIndex(Double(index))
            }
        }
        .frame(width: 130, height: 110)
        .clipped() // Prevent hover animation from affecting surrounding layout
        .animation(DroppyAnimation.hover, value: isHovering)
        .onHover { hovering in
            if hovering != isHovering {
                isHovering = hovering
                if hovering {
                    HapticFeedback.hover()
                }
            }
        }
        .onAppear {
            loadThumbnails()
            // Stagger the appearance animation
            withAnimation(DroppyAnimation.transition.delay(0.1)) {
                hasAppeared = true
            }
        }
        .onChange(of: items.map(\.id)) { _, _ in
            loadThumbnails()
        }
    }
    
    private func loadThumbnails() {
        for item in displayItems {
            if thumbnails[item.id] == nil {
                Task {
                    // Use async thumbnail generation
                    let size = CGSize(width: 140, height: 140)
                    if let thumbnail = await generateThumbnail(for: item.url, size: size) {
                        await MainActor.run {
                            withAnimation(.easeOut(duration: 0.2)) {
                                thumbnails[item.id] = thumbnail
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Generate thumbnail for a URL - uses QuickLook for rich previews of all file types
    private func generateThumbnail(for url: URL, size: CGSize) async -> NSImage? {
        // Determine file type
        let fileType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
        
        // VIDEOS: Use AVAssetImageGenerator for actual frame thumbnails
        // QuickLook often returns generic icons instead of video frames
        if let fileType = fileType, (fileType.conforms(to: .movie) || fileType.conforms(to: .video)) {
            if let videoThumbnail = await generateVideoThumbnail(for: url, size: size) {
                return videoThumbnail
            }
        }
        
        // ALL OTHER FILES: Use QuickLook for rich previews (PDFs, Excel, images, documents, etc.)
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: NSScreen.main?.backingScaleFactor ?? 2.0,
            representationTypes: .all  // Include thumbnails AND icon fallbacks
        )
        
        do {
            let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            return thumbnail.nsImage
        } catch {
            // Fallback: Direct image load for images
            if let fileType = fileType, fileType.conforms(to: .image) {
                if let image = NSImage(contentsOf: url) {
                    return image
                }
            }
            // Ultimate fallback: cached icon
            return ThumbnailCache.shared.cachedIcon(forPath: url.path)
        }
    }
    
    /// Generate video thumbnail using AVAssetImageGenerator
    private func generateVideoThumbnail(for url: URL, size: CGSize) async -> NSImage? {
        return await withCheckedContinuation { continuation in
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: size.width * 2, height: size.height * 2) // Retina
            
            // Extract frame at 1 second (or start if video is shorter)
            let time = CMTime(seconds: 1.0, preferredTimescale: 600)
            
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, result, error in
                if result == .succeeded, let cgImage = cgImage {
                    let nsImage = NSImage(cgImage: cgImage, size: size)
                    continuation.resume(returning: nsImage)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

// MARK: - Dropover-Style Card

/// Individual card matching Dropover's stacked thumbnail style
/// - Rounded corners directly on thumbnail (NO white polaroid border)
/// - Subtle shadow for depth
/// - Rotation and offset based on position in stack
private struct DropoverCard: View {
    let item: DroppedItem
    let thumbnail: NSImage?
    let index: Int
    let totalCount: Int
    let hasAppeared: Bool
    let isHovering: Bool  // Parent hover state for enhanced effects
    
    // Dropover-style rotation angles (subtle, organic feel)
    private var rotation: Double {
        guard hasAppeared else { return 0 }
        switch (totalCount, index) {
        case (1, _):
            return 0
        case (2, 0):
            return -6
        case (2, 1):
            return 3
        case (3, 0):
            return -10
        case (3, 1):
            return -3
        case (3, 2):
            return 5
        default:
            return Double(index - totalCount / 2) * 4
        }
    }
    
    // Dropover-style offset for stacked effect
    // When hovering, cards spread apart subtly for "peek" effect
    private var offset: CGSize {
        guard hasAppeared else { return .zero }
        
        // Subtle spread on hover - less wide, more vertical lift
        let spreadX: CGFloat = isHovering ? 1.4 : 1.0
        let liftY: CGFloat = isHovering ? -4 : 0  // Cards lift up slightly
        
        switch (totalCount, index) {
        case (1, _):
            return .zero
        case (2, 0):
            return CGSize(width: -5 * spreadX, height: 4 + liftY * 0.5)
        case (2, 1):
            return CGSize(width: 5 * spreadX, height: -2 + liftY)
        case (3, 0):
            return CGSize(width: -8 * spreadX, height: 6 + liftY * 0.3)
        case (3, 1):
            return CGSize(width: 0, height: 2 + liftY * 0.6)
        case (3, 2):
            return CGSize(width: 8 * spreadX, height: -4 + liftY)
        default:
            let centerOffset = CGFloat(index) - CGFloat(totalCount - 1) / 2.0
            return CGSize(width: centerOffset * 10 * spreadX, height: liftY * CGFloat(index) / CGFloat(totalCount))
        }
    }
    
    // Scale - top card is largest
    private var scale: CGFloat {
        guard hasAppeared else { return 0.8 }
        let baseScale: CGFloat = 0.88
        let topScale: CGFloat = 1.0
        let progress = Double(index) / max(1, Double(totalCount - 1))
        return baseScale + (topScale - baseScale) * progress
    }
    
    // Shadow opacity - deeper for bottom cards
    private var shadowOpacity: Double {
        0.25 - Double(index) * 0.05
    }
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                // Direct thumbnail with rounded corners (Dropover style)
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
            } else if item.isDirectory {
                // Folder icon fallback
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .fill(AdaptiveColors.overlayAuto(0.1))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "folder.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(AdaptiveColors.secondaryTextAuto.opacity(0.9))
                    )
            } else {
                // Generic file icon fallback
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .fill(AdaptiveColors.overlayAuto(0.1))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(nsImage: ThumbnailCache.shared.cachedIcon(forPath: item.url.path))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                    )
            }
        }
        .shadow(color: .black.opacity(shadowOpacity), radius: 6, x: 0, y: 3)
        .rotationEffect(.degrees(rotation))
        .offset(offset)
        .scaleEffect(scale)
        .animation(DroppyAnimation.transition, value: hasAppeared)
    }
}

// MARK: - File Count Label (Dropover Style)

/// Bottom label showing file count with chevron indicator
/// Uses DroppyPillButtonStyle for consistent styling
struct BasketFileCountLabel: View {
    let items: [DroppedItem]
    let isHovering: Bool  // Kept for API compatibility but no longer used
    let action: () -> Void
    
    private var countText: String {
        let count = items.count
        
        // Determine the type label based on file types
        let allImages = items.allSatisfy { $0.fileType?.conforms(to: .image) == true }
        let allDocuments = items.allSatisfy { 
            $0.fileType?.conforms(to: .pdf) == true || 
            $0.fileType?.conforms(to: .text) == true ||
            $0.fileType?.conforms(to: .presentation) == true ||
            $0.fileType?.conforms(to: .spreadsheet) == true
        }
        
        let typeLabel: String
        if allImages {
            typeLabel = count == 1 ? "Image" : "Images"
        } else if allDocuments {
            typeLabel = count == 1 ? "Document" : "Documents"
        } else {
            typeLabel = count == 1 ? "File" : "Files"
        }
        
        return "\(count) \(typeLabel)"
    }
    
    var body: some View {
        Button(action: action) {
            Text(countText)
        }
        .buttonStyle(DroppyPillButtonStyle(size: .medium, showChevron: true))
    }
}

// MARK: - Basket Header Buttons (Dropover Style)

/// Close button (X) for top-left of basket - uses DroppyCircleButtonStyle
struct BasketCloseButton: View {
    /// Icon to display: "xmark" for delete, "eye.slash" for hide
    var iconName: String = "xmark"
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
        }
        .buttonStyle(DroppyCircleButtonStyle(size: 32))
    }
}

/// Menu button (chevron down) for top-right of basket - uses DroppyCircleButtonStyle
struct BasketMenuButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.down")
        }
        .buttonStyle(DroppyCircleButtonStyle(size: 32))
    }
}

// MARK: - Back Button for Expanded View

/// Back button (<) for expanded grid view header - uses DroppyCircleButtonStyle
struct BasketBackButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
        }
        .buttonStyle(DroppyCircleButtonStyle(size: 32))
    }
}

// MARK: - Drag Handle for Basket

/// Sleek capsule drag handle at top of basket for moving the window
/// Uses large invisible hit area for easy grabbing
/// Accent color matches basket's visual theme for multi-basket distinction
struct BasketDragHandle: View {
    let controller: FloatingBasketWindowController?
    var accentColor: BasketAccentColor = .teal
    var showAccentColor: Bool = true

    init(
        controller: FloatingBasketWindowController? = nil,
        accentColor: BasketAccentColor = .teal,
        showAccentColor: Bool = true
    ) {
        self.controller = controller
        self.accentColor = accentColor
        self.showAccentColor = showAccentColor
    }
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var initialMouseOffset: CGPoint = .zero // Offset from window origin to mouse
    
    /// Capsule fill color - accent is only used when multiple baskets are visible.
    private var capsuleFill: Color {
        if !showAccentColor {
            if isDragging {
                return AdaptiveColors.overlayAuto(0.52)
            } else if isHovering {
                return AdaptiveColors.overlayAuto(0.40)
            } else {
                return AdaptiveColors.overlayAuto(0.28)
            }
        }
        if isDragging {
            return accentColor.color.opacity(0.75)
        } else if isHovering {
            return accentColor.color.opacity(0.55)
        } else {
            // Always visible accent color (subtle when idle)
            return accentColor.color.opacity(0.35)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(capsuleFill)
                .frame(width: 44, height: 5)
        }
        .frame(width: 140, height: 28) // Large hit area
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovering = hovering
            }
            if hovering {
                NSCursor.openHand.push()
            } else if !isDragging {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    guard let window = controller?.basketWindow else { return }
                    
                    let mouseLocation = NSEvent.mouseLocation
                    
                    if !isDragging {
                        // First drag event - capture offset from window origin to mouse
                        isDragging = true
                        initialMouseOffset = CGPoint(
                            x: mouseLocation.x - window.frame.origin.x,
                            y: mouseLocation.y - window.frame.origin.y
                        )
                        NSCursor.closedHand.push()
                        HapticFeedback.select()
                    }
                    
                    // Move window maintaining the initial offset (no jump!)
                    let newX = mouseLocation.x - initialMouseOffset.x
                    let newY = mouseLocation.y - initialMouseOffset.y
                    window.setFrameOrigin(NSPoint(x: newX, y: newY))
                }
                .onEnded { _ in
                    isDragging = false
                    NSCursor.pop()
                }
        )
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.easeOut(duration: 0.15), value: isDragging)
    }
}

#Preview("Collapsed Basket") {
    ZStack {
        Color(red: 0.2, green: 0.25, blue: 0.6)
        VStack(spacing: 20) {
            // Header buttons
            HStack {
                BasketCloseButton(action: { })
                Spacer()
                BasketMenuButton { }
            }
            .padding(.horizontal, 16)
            
            Spacer()
            
            // Stacked preview placeholder
            RoundedRectangle(cornerRadius: DroppyRadius.medium)
                .fill(AdaptiveColors.overlayAuto(0.1))
                .frame(width: 100, height: 100)
            
            Spacer()
            
            // File count label
            BasketFileCountLabel(items: [], isHovering: false) { }
        }
        .padding(DroppySpacing.lg)
        .frame(width: 220, height: 260)
        .background(
            RoundedRectangle(cornerRadius: DroppyRadius.jumbo, style: .continuous)
                .fill(Color(red: 0.15, green: 0.18, blue: 0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.jumbo, style: .continuous)
                        .strokeBorder(AdaptiveColors.overlayAuto(0.1), lineWidth: 1)
                )
        )
    }
    .frame(width: 300, height: 350)
}
