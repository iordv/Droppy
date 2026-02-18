//
//  ShelfQuickActionsBar.swift
//  Droppy
//
//  Quick Actions bar for shelf - appears when files are dragged
//  Same functionality as basket quick actions
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Shelf Quick Actions Bar

struct ShelfQuickActionsBar: View {
    let items: [DroppedItem]
    /// Whether to use transparent styling (passed from parent based on actual shelf transparency)
    var useTransparent: Bool = false
    
    private let buttonSize: CGFloat = 32
    private let spacing: CGFloat = 12
    private var isQuickshareEnabled: Bool { !ExtensionType.quickshare.isRemoved }
    
    @State private var isBarAreaTargeted = false  // Track when drag is over the bar area (between buttons)
    
    /// Computed width of bar area: 4 buttons + 3 gaps
    private var barWidth: CGFloat {
        let actionCount = isQuickshareEnabled ? 4 : 3
        return (buttonSize * CGFloat(actionCount)) + (spacing * CGFloat(actionCount - 1)) + 16
    }
    
    var body: some View {
        ZStack {
            // Transparent hit area background - captures drags between buttons
            Capsule()
                .fill(AdaptiveColors.overlayAuto(0.001)) // Nearly invisible but captures events
                .frame(width: barWidth, height: buttonSize + 8)
                // Track when drag is over the bar area
                .onDrop(of: [UTType.fileURL, UTType.url, UTType.text, UTType.image, UTType.movie, UTType.data], isTargeted: $isBarAreaTargeted) { _ in
                    return false  // Don't handle drop here
                }
                // Keep shelf quick actions state alive while drag is over bar area
                .onChange(of: isBarAreaTargeted) { _, targeted in
                    if targeted {
                        // Drag entered bar area
                        DroppyState.shared.isShelfQuickActionsTargeted = true
                    }
                    // Don't clear on exit - buttons will handle that
                }
            
            HStack(spacing: spacing) {
                ShelfQuickActionButton(actionType: .airdrop, useTransparent: useTransparent, shareAction: shareViaAirDrop)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity).animation(DroppyAnimation.itemInsertion),
                        removal: .scale(scale: 0.5).combined(with: .opacity).animation(DroppyAnimation.hover)
                    ))
                ShelfQuickActionButton(actionType: .messages, useTransparent: useTransparent, shareAction: shareViaMessages)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity).animation(DroppyAnimation.itemInsertion.delay(0.03)),
                        removal: .scale(scale: 0.5).combined(with: .opacity).animation(DroppyAnimation.hover)
                    ))
                ShelfQuickActionButton(actionType: .mail, useTransparent: useTransparent, shareAction: shareViaMail)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity).animation(DroppyAnimation.itemInsertion.delay(0.06)),
                        removal: .scale(scale: 0.5).combined(with: .opacity).animation(DroppyAnimation.hover)
                    ))
                if isQuickshareEnabled {
                    ShelfQuickActionButton(actionType: .quickshare, useTransparent: useTransparent, shareAction: cloudShare)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity).animation(DroppyAnimation.itemInsertion.delay(0.09)),
                            removal: .scale(scale: 0.5).combined(with: .opacity).animation(DroppyAnimation.hover)
                        ))
                }
            }
        }
        .animation(DroppyAnimation.state, value: items.count)
    }
    
    // MARK: - Share Actions
    
    private func shareViaAirDrop(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSSharingService(named: .sendViaAirDrop)?.perform(withItems: urls)
    }
    
    private func shareViaMessages(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSSharingService(named: .composeMessage)?.perform(withItems: urls)
    }
    
    private func shareViaMail(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let didCompose = MailHelper.composeEmail(with: urls)
        if !didCompose {
            HapticFeedback.error()
        }
    }
    
    /// Uses the configured cloud action (Droppy Quickshare or iCloud Drive).
    private func cloudShare(_ urls: [URL]) {
        QuickActionsCloudShare.share(urls: urls) {
            // No need to hide shelf after share - user may want to continue working
        }
    }
}

// MARK: - Shelf Quick Action Button

struct ShelfQuickActionButton: View {
    let actionType: QuickActionType
    var useTransparent: Bool = false
    let shareAction: ([URL]) -> Void
    
    @State private var isHovering = false
    @State private var isTargeted = false
    
    private let size: CGFloat = 32
    
    // Border opacity matches basket style
    private var borderOpacity: Double {
        if isTargeted { return 0.3 }
        if isHovering { return 0.2 }
        return useTransparent ? 0.12 : 0.06
    }
    
    var body: some View {
        // Use AppKit-based drop target for reliable Photos.app file promise support
        FilePromiseDropTarget(
            isTargeted: $isTargeted,
            onFilesReceived: { urls in
                shareAction(urls)
            },
            onHoverChanged: { hovering in
                isHovering = hovering
                if hovering {
                    DroppyState.shared.hoveredShelfQuickAction = actionType
                } else if DroppyState.shared.hoveredShelfQuickAction == actionType {
                    DroppyState.shared.hoveredShelfQuickAction = nil
                }
            }
        ) {
            Circle()
                // Transparent mode: use material, Dark mode: pure black
                .droppyTransparentFill(useTransparent, fallback: Color.black)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(
                            useTransparent
                                ? AdaptiveColors.overlayAuto(borderOpacity)
                                : Color.white.opacity(borderOpacity),
                            lineWidth: 1
                        )
                )
                .overlay(
                    Image(systemName: actionType.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            useTransparent
                                ? AdaptiveColors.primaryTextAuto.opacity(0.88)
                                : .white.opacity(0.85)
                        )
                )
                .scaleEffect(isTargeted ? 1.18 : (isHovering ? 1.05 : 1.0))
                .animation(DroppyAnimation.hoverBouncy, value: isTargeted)
                .animation(DroppyAnimation.hoverBouncy, value: isHovering)
        }
        .frame(width: size, height: size)
        // Update shared state when this button is targeted
        .onChange(of: isTargeted) { _, targeted in
            if targeted {
                DroppyState.shared.isShelfQuickActionsTargeted = true
                DroppyState.shared.hoveredShelfQuickAction = actionType
            } else {
                // Clear hover state when drag leaves this button
                if DroppyState.shared.hoveredShelfQuickAction == actionType {
                    DroppyState.shared.hoveredShelfQuickAction = nil
                }
            }
        }
        // Clear hover state when button disappears
        .onDisappear {
            if DroppyState.shared.hoveredShelfQuickAction == actionType {
                DroppyState.shared.hoveredShelfQuickAction = nil
            }
        }
        .onTapGesture {
            let urls = DroppyState.shared.items.map(\.url)
            if !urls.isEmpty {
                HapticFeedback.select()
                shareAction(urls)
            }
        }
    }
}
