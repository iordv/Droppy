//
//  DroppedItemView.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI

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
    
    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail/Icon with glass container
            ZStack(alignment: .topTrailing) {
                // Glass card background
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 64, height: 64)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
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
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(width: 64, height: 64)
                
                // Remove button with animation
                if showRemoveButton {
                    Button(action: onRemove) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .frame(width: 20, height: 20)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .offset(x: 6, y: -6)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Filename
            Text(item.name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 72)
                .foregroundStyle(.primary.opacity(0.9))
        }
        .padding(8)
        .background {
            // Selection/hover background
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(backgroundColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: isSelected ? 2 : 1)
                }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .shadow(color: .black.opacity(isHovering ? 0.15 : 0), radius: 8, y: 4)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isHovering = hovering
                showRemoveButton = hovering
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                onSelect()
            }
        }
        .pressAction {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                isPressed = true
            }
        } onRelease: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
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
            
            Divider()
            
            // Share submenu with system sharing services
            Menu {
                ForEach(NSSharingService.sharingServices(forItems: [item.url]), id: \.title) { service in
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    onRemove()
                }
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
        .draggable(item)
        .task {
            // Load thumbnail with slight delay for staggered effect
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            thumbnail = await item.generateThumbnail(size: CGSize(width: 128, height: 128))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        } else if isHovering {
            return Color.primary.opacity(0.05)
        }
        return .clear
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.6)
        } else if isHovering {
            return Color.primary.opacity(0.1)
        }
        return .clear
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

