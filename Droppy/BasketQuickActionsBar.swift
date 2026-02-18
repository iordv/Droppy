//
//  BasketQuickActionsBar.swift
//  Droppy
//
//  Quick Actions bar - simple, snappy animation
//  Supports transparency mode
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Quick Actions Bar

struct BasketQuickActionsBar: View {
    let items: [DroppedItem]
    var basketState: BasketState = FloatingBasketWindowController.shared.basketState
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @State private var isExpanded = false
    @State private var isHovering = false
    @State private var isBoltTargeted = false  // Track when files are dragged over collapsed bolt
    @State private var collapseWorkItem: DispatchWorkItem?
    @ObservedObject private var dragMonitor = DragMonitor.shared
    
    private let buttonSize: CGFloat = 48
    private let spacing: CGFloat = 12
    private var isQuickshareEnabled: Bool { !ExtensionType.quickshare.isRemoved }
    
    // Colors based on transparency mode
    private var buttonFill: Color {
        useTransparentBackground ? AdaptiveColors.overlayAuto(0.12) : Color.black
    }
    @State private var isBarAreaTargeted = false  // Track when drag is over the bar area (between buttons)
    
    /// Computed width of expanded bar area: 4 buttons + 3 gaps
    private var expandedBarWidth: CGFloat {
        let actionCount = isQuickshareEnabled ? 4 : 3
        return (buttonSize * CGFloat(actionCount)) + (spacing * CGFloat(actionCount - 1)) + 16
    }

    private var stableHitFrameWidth: CGFloat {
        expandedBarWidth + 40
    }

    private var stableHitFrameHeight: CGFloat {
        buttonSize + 28
    }
    
    var body: some View {
        ZStack {
            // ALWAYS render transparent hit area - sized dynamically
            // This eliminates the race condition where the capsule appears after expansion
            // When collapsed: small area around bolt. When expanded: full bar area.
            Capsule()
                .fill(AdaptiveColors.overlayAuto(0.001)) // Nearly invisible but captures events
                .frame(
                    width: isExpanded ? expandedBarWidth + 36 : buttonSize + 22,
                    height: buttonSize + 24
                )
                // Track when drag is over the bar area
                // Include file promise types for Photos.app compatibility
                .onDrop(of: [UTType.fileURL, UTType.url, UTType.text, UTType.image, UTType.movie, UTType.data], isTargeted: $isBarAreaTargeted) { _ in
                    return false  // Don't handle drop here
                }
                // Keep expanded when drag is over bar area
                .onChange(of: isBarAreaTargeted) { _, targeted in
                    if targeted && !isExpanded {
                        cancelScheduledCollapse()
                        basketState.isQuickActionsTargeted = true
                        // Drag entered bar area while collapsed - expand
                        withAnimation(DroppyAnimation.state) {
                            isExpanded = true
                        }
                        HapticFeedback.expand()
                    } else if !targeted && !isHovering && !isBoltTargeted && !dragMonitor.isDragging {
                        scheduleCollapse()
                    }
                }
            
            ZStack {
                // Keep quick-action buttons mounted to avoid NSViewRepresentable transition ghosting.
                HStack(spacing: spacing) {
                    QuickDropActionButton(actionType: .airdrop, basketState: basketState, useTransparent: useTransparentBackground, shareAction: shareViaAirDrop)
                    QuickDropActionButton(actionType: .messages, basketState: basketState, useTransparent: useTransparentBackground, shareAction: shareViaMessages)
                    QuickDropActionButton(actionType: .mail, basketState: basketState, useTransparent: useTransparentBackground, shareAction: shareViaMail)
                    if isQuickshareEnabled {
                        QuickDropActionButton(actionType: .quickshare, basketState: basketState, useTransparent: useTransparentBackground, shareAction: cloudShare)
                    }
                }
                .opacity(isExpanded ? 1 : 0)
                .scaleEffect(isExpanded ? 1 : 0.92)
                .allowsHitTesting(isExpanded)
                
                // Collapsed: Zap button
                Circle()
                    .droppyTransparentFill(useTransparentBackground)
                    .frame(width: buttonSize, height: buttonSize)
                    .overlay(
                        Circle()
                            .stroke(AdaptiveColors.overlayAuto(isBoltTargeted ? 0.3 : (useTransparentBackground ? 0.12 : 0.06)), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.primaryTextAuto.opacity(isBoltTargeted ? 1.0 : 0.85))
                    )
                    .opacity(isExpanded ? 0 : 1)
                    .scaleEffect(isExpanded ? 0.92 : (isBoltTargeted ? 1.15 : 1.0))
                    .allowsHitTesting(!isExpanded)
                    .contentShape(Circle().scale(1.3))
                    // DRAG-TO-EXPAND: Detect when files are dragged over the collapsed bolt
                    // Include file promise types for Photos.app compatibility
                    .onDrop(of: [UTType.fileURL, UTType.url, UTType.text, UTType.image, UTType.movie, UTType.data], isTargeted: $isBoltTargeted) { _ in
                        // Don't handle the drop here - just expand so user can drop on specific action
                        return false
                    }
                    .animation(DroppyAnimation.hoverBouncy, value: isBoltTargeted)
            }
            .frame(width: isExpanded ? expandedBarWidth + 20 : buttonSize + 8, height: buttonSize + 24)
        }
        .frame(width: stableHitFrameWidth, height: stableHitFrameHeight)
        .contentShape(Rectangle())
        .animation(DroppyAnimation.state, value: isExpanded)
        .onHover { hovering in
            isHovering = hovering
        }
        .onChange(of: isHovering) { _, hovering in
            // EXPANDED VIA HOVER: normal expand/collapse on hover
            // But don't collapse if still dragging over bar area
            if !hovering && (isBarAreaTargeted || dragMonitor.isDragging || isBoltTargeted) {
                return  // Keep expanded while dragging anywhere over bar
            }
            if hovering {
                cancelScheduledCollapse()
                basketState.isQuickActionsTargeted = true
                if !isExpanded {
                    HapticFeedback.expand()
                }
                withAnimation(DroppyAnimation.state) {
                    isExpanded = true
                }
            } else {
                collapseIfPossible()
            }
        }
        // DRAG-TO-EXPAND: Auto-expand when files are dragged over the collapsed bolt
        .onChange(of: isBoltTargeted) { _, targeted in
            if targeted && !isExpanded {
                cancelScheduledCollapse()
                basketState.isQuickActionsTargeted = true
                withAnimation(DroppyAnimation.state) {
                    isExpanded = true
                }
                HapticFeedback.expand()
            } else if !targeted && !isBarAreaTargeted && !dragMonitor.isDragging {
                scheduleCollapse()
            }
        }
        .onChange(of: dragMonitor.isDragging) { _, dragging in
            if dragging {
                cancelScheduledCollapse()
                return
            }
            // Defensive reset: NSDragging callbacks can lag for some sources (e.g. file promises),
            // which can leave action explanation overlays visible longer than intended.
            resetQuickActionHoverState()
            if !isHovering && !isBarAreaTargeted && !isBoltTargeted && !basketState.isQuickActionsTargeted {
                scheduleCollapse()
            }
        }
        // Note: Main collapse logic is handled by onChange(of: isBarAreaTargeted) above
        // This handler is just for when buttons lose targeting but bar area keeps it
        // COLLAPSE when basket becomes targeted (drag moved to basket area)
        .onChange(of: basketState.isTargeted) { _, targeted in
            // While an active drag is in progress, keep quick actions stable and let
            // button/bar targeting decide collapse. This avoids focus flicker where
            // basket targeting briefly wins over center action buttons.
            if targeted && isExpanded && !dragMonitor.isDragging && !isBarAreaTargeted && !basketState.isQuickActionsTargeted {
                scheduleCollapse()
            }
        }
        .onDisappear {
            cancelScheduledCollapse()
            resetQuickActionHoverState()
        }
    }

    private func cancelScheduledCollapse() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
    }

    private func scheduleCollapse() {
        cancelScheduledCollapse()
        let workItem = DispatchWorkItem {
            collapseIfPossible()
        }
        collapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14, execute: workItem)
    }

    private func collapseIfPossible() {
        guard !isHovering, !isBarAreaTargeted, !isBoltTargeted, !dragMonitor.isDragging else {
            return
        }
        resetQuickActionHoverState()
        withAnimation(DroppyAnimation.state) {
            isExpanded = false
        }
    }

    private func resetQuickActionHoverState() {
        basketState.isQuickActionsTargeted = false
        basketState.hoveredQuickAction = nil
    }
    
    // MARK: - Share Actions
    
    private func shareViaAirDrop(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSSharingService(named: .sendViaAirDrop)?.perform(withItems: urls)
        basketState.ownerController?.hideBasketPreservingState()
            ?? FloatingBasketWindowController.shared.hideBasket(preserveState: true)
    }
    
    private func shareViaMessages(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSSharingService(named: .composeMessage)?.perform(withItems: urls)
        basketState.ownerController?.hideBasketPreservingState()
            ?? FloatingBasketWindowController.shared.hideBasket(preserveState: true)
    }
    
    private func shareViaMail(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let didCompose = MailHelper.composeEmail(with: urls)
        guard didCompose else {
            HapticFeedback.error()
            return
        }
        basketState.ownerController?.hideBasketPreservingState()
            ?? FloatingBasketWindowController.shared.hideBasket(preserveState: true)
    }
    
    /// Uses the configured cloud action (Droppy Quickshare or iCloud Drive).
    private func cloudShare(_ urls: [URL]) {
        QuickActionsCloudShare.share(urls: urls) {
            basketState.ownerController?.hideBasketPreservingState()
                ?? FloatingBasketWindowController.shared.hideBasket(preserveState: true)
        }
    }
}

// MARK: - Quick Drop Action Button

struct QuickDropActionButton: View {
    let actionType: QuickActionType
    var basketState: BasketState
    var useTransparent: Bool = false
    let shareAction: ([URL]) -> Void
    
    @State private var isHovering = false
    @State private var isTargeted = false
    
    private let size: CGFloat = 48
    
    // Border opacity matches basket: 0.12 when transparent, 0.06 when solid
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
                    basketState.isQuickActionsTargeted = true
                    basketState.hoveredQuickAction = actionType
                }
            }
        ) {
            Circle()
                .droppyTransparentFill(useTransparent)
                .frame(width: size, height: size)
                .overlay(
                    // Border matches basket style exactly
                    Circle()
                        .stroke(AdaptiveColors.overlayAuto(borderOpacity), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: actionType.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(AdaptiveColors.primaryTextAuto.opacity(0.88))
                )
                // Grow when file dragged over
                .scaleEffect(isTargeted ? 1.18 : (isHovering ? 1.05 : 1.0))
                .animation(DroppyAnimation.hoverBouncy, value: isTargeted)
                .animation(DroppyAnimation.hoverBouncy, value: isHovering)
        }
        .contentShape(Circle())
        .frame(width: size, height: size)
        // CRITICAL: Update basket state when this button is targeted
        // Only SET the state - clearing is handled by capsule exit or basket targeting
        .onChange(of: isTargeted) { _, targeted in
            if targeted {
                basketState.isQuickActionsTargeted = true
                basketState.hoveredQuickAction = actionType
            }
            // Don't clear on false here - let bar-level hover/drag exit handle it.
        }
        .onTapGesture {
            let urls = basketState.items.map(\.url)
            if !urls.isEmpty {
                HapticFeedback.select()
                shareAction(urls)
            }
        }
    }
}
