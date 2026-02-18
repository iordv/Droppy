//
//  DroppedItemView.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI

// MARK: - Sharing Services Cache


/// Individual item card displayed on the shelf with liquid glass styling
struct DroppedItemView: View {
    let item: DroppedItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void
    
    @State private var thumbnail: NSImage?
    @State private var isHovering = false
    @State private var isPressed = false
    @State private var showRemoveButton = false
    @State private var cachedSharingServices: [NSSharingService] = []
    
    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail/Icon with glass container
            ZStack(alignment: .topTrailing) {
                // Glass card background
                RoundedRectangle(cornerRadius: DroppyRadius.lx, style: .continuous)
                    .droppyGlassFill()
                    .frame(width: 64, height: 64)
                    .overlay {
                        RoundedRectangle(cornerRadius: DroppyRadius.lx, style: .continuous)
                            .strokeBorder(Color(NSColor.labelColor).opacity(0.2), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                
                // Thumbnail or icon
                Group {
                    if let thumbnail = thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(nsImage: item.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
                .frame(width: 64, height: 64)
                
                // Remove button with animation
                if showRemoveButton {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .buttonStyle(DroppyCircleButtonStyle(size: 20))
                    .offset(x: 6, y: -6)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Filename - subtly scrolls for long names
            SubtleScrollingText(
                text: item.name,
                font: .system(size: 10, weight: .medium),
                foregroundStyle: AnyShapeStyle(Color(NSColor.labelColor).opacity(0.9)),
                maxWidth: 72,
                lineLimit: 2,
                alignment: .center
            )
        }
        .padding(DroppySpacing.sm)
        .background {
            // Selection/hover background - exactly matches shelf outer edge (bottomRadius: 40)
            RoundedRectangle(cornerRadius: DroppyRadius.giant, style: .continuous)
                .fill(backgroundColor)
                .overlay {
                    RoundedRectangle(cornerRadius: DroppyRadius.giant, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: isSelected ? 2 : 1)
                }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .shadow(color: .black.opacity(isHovering ? 0.15 : 0), radius: 8, y: 4)
        .onHover { hovering in
            // Direct state update - animation handled by view-level .animation() modifiers
            isHovering = hovering
            showRemoveButton = hovering
        }
        .animation(DroppyAnimation.hoverBouncy, value: isHovering)
        .animation(DroppyAnimation.hoverBouncy, value: showRemoveButton)
        .onTapGesture {
            withAnimation(DroppyAnimation.state) {
                onSelect()
            }
        }
        .pressAction {
            withAnimation(DroppyAnimation.press) {
                isPressed = true
            }
        } onRelease: {
            withAnimation(DroppyAnimation.release) {
                isPressed = false
            }
        }
        .contextMenu {
            Button {
                item.copyToClipboard()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            
            Button {
                item.openFile()
            } label: {
                Label("Open", systemImage: "arrow.up.forward.square")
            }
            
            Button {
                item.revealInFinder()
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            
            // Remove Background - only show for image files
            if item.isImage {
                if AIInstallManager.shared.isInstalled {
                    Button {
                        Task {
                            do {
                                let outputURL = try await item.removeBackground()
                                NSWorkspace.shared.selectFile(outputURL.path, inFileViewerRootedAtPath: outputURL.deletingLastPathComponent().path)
                            } catch {
                                print("Background removal failed: \(error.localizedDescription)")
                            }
                        }
                    } label: {
                        Label("Remove Background", systemImage: "person.and.background.dotted")
                    }
                } else {
                    Button {
                        // No action - just informational
                    } label: {
                        Label("Remove Background (Settings > Extensions)", systemImage: "person.and.background.dotted")
                    }
                    .disabled(true)
                }
            }
            
            Divider()
            
            // Share submenu - positions correctly relative to context menu
            Menu {
                ForEach(cachedSharingServices, id: \.title) { service in
                    Button {
                        service.perform(withItems: [item.url])
                    } label: {
                        Label {
                            Text(service.title)
                        } icon: {
                            Image(nsImage: service.image)
                        }
                    }
                }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            Button(role: .destructive) {
                withAnimation(DroppyAnimation.state) {
                    onRemove()
                }
            } label: {
                Label("Remove from Shelf", systemImage: "xmark")
            }
        }
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
        .task {
            // Load thumbnail from cache (no delay - cache handles throttling)
            thumbnail = await ThumbnailCache.shared.loadThumbnailAsync(for: item, size: CGSize(width: 128, height: 128))
        }
        .onAppear {
            refreshContextMenuCache()
        }
        .onChange(of: item.url) { _, _ in
            refreshContextMenuCache()
        }
        .animation(DroppyAnimation.bouncy, value: isSelected)
    }
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        } else if isHovering {
            return Color(NSColor.labelColor).opacity(0.05)
        }
        return .clear
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.6)
        } else if isHovering {
            return Color(NSColor.labelColor).opacity(0.1)
        }
        return .clear
    }

    private func refreshContextMenuCache() {
        cachedSharingServices = sharingServicesForItems([item.url])
    }
}

// MARK: - Keyboard Shortcut Support

extension DroppedItemView {
    func onCopyShortcut() {
        item.copyToClipboard()
    }
}
// MARK: - Press Action Support

extension View {
    /// Detects press and release gestures for interactive scaling or state changes
    func pressAction(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressActions(onPress: onPress, onRelease: onRelease))
    }
}

struct PressActions: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void
    
    @State private var isPressing = false
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressing {
                            isPressing = true
                            onPress()
                        }
                    }
                    .onEnded { _ in
                        isPressing = false
                        onRelease()
                    }
            )
    }
}
