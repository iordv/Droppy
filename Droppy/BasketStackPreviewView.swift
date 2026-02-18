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

// MARK: - Shared Stacked Peek

private struct StackedFilePeekStyle {
    let containerSize: CGSize
    let cardSize: CGFloat
    let iconSize: CGFloat
    let folderSymbolSize: CGFloat
    let cornerRadius: CGFloat
    let thumbnailSize: CGSize
    let stackYOffset: CGFloat
    let hoverLift: CGFloat
    let hoverSpreadMultiplier: CGFloat
    let horizontalOffsetMultiplier: CGFloat
    let rotationMultiplier: Double
    let maxDownwardOffset: CGFloat
    let enableHoverHaptic: Bool

    static let basket = StackedFilePeekStyle(
        containerSize: CGSize(width: 194, height: 144),
        cardSize: 116,
        iconSize: 52,
        folderSymbolSize: 40,
        cornerRadius: DroppyRadius.medium,
        thumbnailSize: CGSize(width: 220, height: 220),
        stackYOffset: 0,
        hoverLift: -4,
        hoverSpreadMultiplier: 1.4,
        horizontalOffsetMultiplier: 0.58,
        rotationMultiplier: 0.7,
        maxDownwardOffset: 0,
        enableHoverHaptic: true
    )

    static let shelf = StackedFilePeekStyle(
        containerSize: CGSize(width: 112, height: 84),
        cardSize: 68,
        iconSize: 30,
        folderSymbolSize: 25,
        cornerRadius: DroppyRadius.small,
        thumbnailSize: CGSize(width: 150, height: 150),
        stackYOffset: 16,
        hoverLift: -1,
        hoverSpreadMultiplier: 1.15,
        horizontalOffsetMultiplier: 1.0,
        rotationMultiplier: 1.0,
        maxDownwardOffset: 8,
        enableHoverHaptic: false
    )
}

private enum PeekItemKind: Hashable {
    case image
    case video
    case audio
    case pdf
    case zip
    case folder
    case file
}

private func peekItemKind(for item: DroppedItem) -> PeekItemKind {
    if item.isDirectory { return .folder }

    let ext = item.url.pathExtension.lowercased()
    let zipExtensions: Set<String> = ["zip", "7z", "rar", "tar", "gz", "tgz", "bz2", "xz"]
    if zipExtensions.contains(ext) {
        return .zip
    }

    guard let fileType = item.fileType else { return .file }

    if fileType.conforms(to: .image) { return .image }
    if fileType.conforms(to: .movie) || fileType.conforms(to: .video) { return .video }
    if fileType.conforms(to: .audio) { return .audio }
    if fileType.conforms(to: .pdf) { return .pdf }
    if fileType.conforms(to: .archive) { return .zip }

    return .file
}

private func peekCountText(for items: [DroppedItem]) -> String {
    let count = items.count
    guard count > 0 else { return "0 Files" }

    let firstKind = peekItemKind(for: items[0])
    let allSameKind = items.dropFirst().allSatisfy { peekItemKind(for: $0) == firstKind }
    guard allSameKind else { return "\(count) \(count == 1 ? "File" : "Files")" }

    switch firstKind {
    case .image:
        return "\(count) \(count == 1 ? "Photo" : "Photos")"
    case .video:
        return "\(count) \(count == 1 ? "Video" : "Videos")"
    case .audio:
        return "\(count) \(count == 1 ? "Audio File" : "Audio Files")"
    case .pdf:
        return "\(count) \(count == 1 ? "PDF" : "PDFs")"
    case .zip:
        return "\(count) \(count == 1 ? "ZIP" : "ZIPs")"
    case .folder:
        return "\(count) \(count == 1 ? "Folder" : "Folders")"
    case .file:
        return "\(count) \(count == 1 ? "File" : "Files")"
    }
}

/// Stacked thumbnail preview for collapsed basket mode.
struct BasketStackPreviewView: View {
    let items: [DroppedItem]

    var body: some View {
        StackedFilePeekView(items: items, style: .basket)
    }
}

/// Compact stacked thumbnail preview for collapsed shelf mode.
struct ShelfStackPeekView: View {
    let items: [DroppedItem]

    var body: some View {
        StackedFilePeekView(items: items, style: .shelf)
    }
}

private struct StackedFilePeekView: View {
    let items: [DroppedItem]
    let style: StackedFilePeekStyle

    private var displayItems: [DroppedItem] {
        Array(items.suffix(3))
    }

    @State private var thumbnails: [UUID: NSImage] = [:]
    @State private var loadingThumbnailIDs: Set<UUID> = []
    @State private var thumbnailTasks: [UUID: Task<Void, Never>] = [:]
    @State private var hasAppeared = false
    @State private var isHovering = false

    var body: some View {
        ZStack {
            ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                DropoverCard(
                    item: item,
                    thumbnail: thumbnails[item.id],
                    index: index,
                    totalCount: displayItems.count,
                    hasAppeared: hasAppeared,
                    isHovering: isHovering,
                    style: style
                )
                .offset(y: style.stackYOffset)
                .zIndex(Double(index))
            }
        }
        .frame(width: style.containerSize.width, height: style.containerSize.height)
        .clipped()
        .animation(DroppyAnimation.hoverQuick, value: isHovering)
        .onHover { hovering in
            guard hovering != isHovering else { return }
            isHovering = hovering
            if hovering && style.enableHoverHaptic {
                HapticFeedback.hover()
            }
        }
        .onAppear {
            loadThumbnails()
            withAnimation(DroppyAnimation.transition.delay(0.1)) {
                hasAppeared = true
            }
        }
        .onChange(of: items.map(\.id)) { _, _ in
            loadThumbnails()
        }
        .onDisappear {
            cancelAndClearThumbnailState()
        }
    }

    private func loadThumbnails() {
        let visibleIDs = Set(displayItems.map(\.id))
        pruneThumbnailState(keeping: visibleIDs)

        for item in displayItems where thumbnails[item.id] == nil && !loadingThumbnailIDs.contains(item.id) {
            loadingThumbnailIDs.insert(item.id)
            let task = Task {
                defer {
                    Task { @MainActor in
                        loadingThumbnailIDs.remove(item.id)
                        thumbnailTasks.removeValue(forKey: item.id)
                    }
                }

                if let thumbnail = await generateThumbnailWithRetry(for: item, size: style.thumbnailSize) {
                    await MainActor.run {
                        guard displayItems.contains(where: { $0.id == item.id }) else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            thumbnails[item.id] = thumbnail
                        }
                    }
                }
            }
            thumbnailTasks[item.id] = task
        }
    }

    private func pruneThumbnailState(keeping visibleIDs: Set<UUID>) {
        thumbnails = thumbnails.filter { visibleIDs.contains($0.key) }
        loadingThumbnailIDs = loadingThumbnailIDs.intersection(visibleIDs)

        let staleTaskIDs = thumbnailTasks.keys.filter { !visibleIDs.contains($0) }
        for id in staleTaskIDs {
            thumbnailTasks[id]?.cancel()
            thumbnailTasks.removeValue(forKey: id)
        }
    }

    private func cancelAndClearThumbnailState() {
        for task in thumbnailTasks.values {
            task.cancel()
        }
        thumbnailTasks.removeAll()
        loadingThumbnailIDs.removeAll()
        thumbnails.removeAll()
    }

    private func generateThumbnailWithRetry(for item: DroppedItem, size: CGSize) async -> NSImage? {
        if let thumbnail = await generateThumbnail(for: item.url, size: size) {
            return thumbnail
        }

        // Some files briefly fail QuickLook on first paint (for example after fresh drops).
        // Retry a few times so collapsed mode resolves to the exact preview once available.
        let retryDelays: [UInt64] = [250_000_000, 800_000_000]
        for delay in retryDelays {
            try? await Task.sleep(nanoseconds: delay)
            if let thumbnail = await generateThumbnail(for: item.url, size: size) {
                return thumbnail
            }
        }

        return nil
    }

    /// Uses QuickLook thumbnails with video-frame fallback for movie files.
    private func generateThumbnail(for url: URL, size: CGSize) async -> NSImage? {
        let fileType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType

        if let fileType, (fileType.conforms(to: .movie) || fileType.conforms(to: .video)) {
            if let videoThumbnail = await generateVideoThumbnail(for: url, size: size) {
                return videoThumbnail
            }
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: NSScreen.main?.backingScaleFactor ?? 2.0,
            representationTypes: .all
        )

        do {
            let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            return thumbnail.nsImage
        } catch {
            if let fileType, fileType.conforms(to: .image), let image = NSImage(contentsOf: url) {
                return image
            }
            return nil
        }
    }

    private func generateVideoThumbnail(for url: URL, size: CGSize) async -> NSImage? {
        return await withCheckedContinuation { continuation in
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: size.width * 2, height: size.height * 2)

            let time = CMTime(seconds: 1.0, preferredTimescale: 600)

            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, result, _ in
                if result == .succeeded, let cgImage {
                    continuation.resume(returning: NSImage(cgImage: cgImage, size: size))
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
    let style: StackedFilePeekStyle
    
    // Dropover-style rotation angles (subtle, organic feel)
    private var rotation: Double {
        guard hasAppeared else { return 0 }
        let scaleFactor = style.cardSize / 80
        let rotationScale = scaleFactor * style.rotationMultiplier
        switch (totalCount, index) {
        case (1, _):
            return 0
        case (2, 0):
            return -6 * rotationScale
        case (2, 1):
            return 3 * rotationScale
        case (3, 0):
            return -10 * rotationScale
        case (3, 1):
            return -3 * rotationScale
        case (3, 2):
            return 5 * rotationScale
        default:
            return Double(index - totalCount / 2) * 4 * rotationScale
        }
    }
    
    // Dropover-style offset for stacked effect
    // When hovering, cards spread apart subtly for "peek" effect
    private var offset: CGSize {
        guard hasAppeared else { return .zero }

        let sizeFactor = (style.cardSize / 80) * style.horizontalOffsetMultiplier
        let spreadX: CGFloat = isHovering ? style.hoverSpreadMultiplier : 1.0
        let liftY: CGFloat = isHovering ? style.hoverLift : 0

        let rawOffset: CGSize
        switch (totalCount, index) {
        case (1, _):
            rawOffset = .zero
        case (2, 0):
            rawOffset = CGSize(width: -5 * spreadX * sizeFactor, height: (4 * sizeFactor) + liftY * 0.5)
        case (2, 1):
            rawOffset = CGSize(width: 5 * spreadX * sizeFactor, height: (-2 * sizeFactor) + liftY)
        case (3, 0):
            rawOffset = CGSize(width: -8 * spreadX * sizeFactor, height: (6 * sizeFactor) + liftY * 0.3)
        case (3, 1):
            rawOffset = CGSize(width: 0, height: (2 * sizeFactor) + liftY * 0.6)
        case (3, 2):
            rawOffset = CGSize(width: 8 * spreadX * sizeFactor, height: (-4 * sizeFactor) + liftY)
        default:
            let centerOffset = CGFloat(index) - CGFloat(totalCount - 1) / 2.0
            rawOffset = CGSize(
                width: centerOffset * 10 * spreadX * sizeFactor,
                height: liftY * CGFloat(index) / CGFloat(totalCount)
            )
        }

        return CGSize(
            width: rawOffset.width,
            height: min(rawOffset.height, style.maxDownwardOffset)
        )
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
                    .frame(width: style.cardSize, height: style.cardSize)
                    .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
            } else if item.isDirectory {
                // Folder icon fallback
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .fill(AdaptiveColors.overlayAuto(0.1))
                    .frame(width: style.cardSize, height: style.cardSize)
                    .overlay(
                        Image(systemName: "folder.fill")
                            .font(.system(size: style.folderSymbolSize))
                            .foregroundStyle(AdaptiveColors.secondaryTextAuto.opacity(0.9))
                    )
            } else {
                // Generic file icon fallback
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .fill(AdaptiveColors.overlayAuto(0.1))
                    .frame(width: style.cardSize, height: style.cardSize)
                    .overlay(
                        Image(nsImage: ThumbnailCache.shared.cachedIcon(forPath: item.url.path))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: style.iconSize, height: style.iconSize)
                    )
            }
        }
        .shadow(
            color: .black.opacity(shadowOpacity),
            radius: max(2, style.cardSize * 0.08),
            x: 0,
            y: max(1, style.cardSize * 0.04)
        )
        .rotationEffect(.degrees(rotation))
        .offset(offset)
        .scaleEffect(scale)
        .animation(DroppyAnimation.transition, value: hasAppeared)
    }
}

// MARK: - Header Count Label

/// Compact count label used above collapsed stack previews.
struct PeekFileCountHeader: View {
    enum HeaderStyle: Equatable {
        case plain
        case pill
    }

    let items: [DroppedItem]
    var compact: Bool = false
    var style: HeaderStyle = .plain

    private var labelText: String {
        peekCountText(for: items)
    }

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: compact ? 9 : 11, weight: .semibold))
            Text(labelText)
                .font(.system(size: compact ? 11 : 13, weight: .semibold))
        }
        .foregroundStyle(AdaptiveColors.secondaryTextAuto.opacity(style == .plain ? 0.95 : 0.9))
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 4 : 6)
        .background(backgroundView)
    }

    @ViewBuilder
    private var backgroundView: some View {
        if style == .pill {
            Capsule()
                .fill(AdaptiveColors.overlayAuto(compact ? 0.08 : 0.1))
                .overlay(
                    Capsule()
                        .strokeBorder(AdaptiveColors.overlayAuto(0.14), lineWidth: 1)
                )
        } else {
            Color.clear
        }
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
        peekCountText(for: items)
    }
    
    var body: some View {
        Button(action: action) {
            Text(countText)
        }
        .buttonStyle(DroppyPillButtonStyle(size: .small, showChevron: true))
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
            Image(systemName: "chevron.backward")
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
