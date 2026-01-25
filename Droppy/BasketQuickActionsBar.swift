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
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @State private var isExpanded = false
    @State private var isHovering = false
    @State private var isBoltTargeted = false  // Track when files are dragged over collapsed bolt
    
    private let buttonSize: CGFloat = 48
    private let spacing: CGFloat = 12
    
    // Colors based on transparency mode
    private var buttonFill: Color {
        useTransparentBackground ? Color.white.opacity(0.12) : Color.black
    }
    @State private var isBarAreaTargeted = false  // Track when drag is over the bar area (between buttons)
    
    /// Computed width of expanded bar area: 4 buttons + 3 gaps
    private var expandedBarWidth: CGFloat {
        (buttonSize * 4) + (spacing * 3) + 16  // Extra padding for safety
    }
    
    var body: some View {
        ZStack {
            // Transparent hit area background - captures drags between buttons AND clears state when drag exits
            if isExpanded {
                Capsule()
                    .fill(Color.white.opacity(0.001)) // Nearly invisible but captures events
                    .frame(width: expandedBarWidth, height: buttonSize + 8)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    // Track when drag is over the bar area
                    .onDrop(of: [UTType.fileURL], isTargeted: $isBarAreaTargeted) { _ in
                        return false  // Don't handle drop here
                    }
                    // Clear global state when drag exits the bar area
                    .onChange(of: isBarAreaTargeted) { _, targeted in
                        if !targeted {
                            // Drag left the bar area - clear the global targeting state
                            DroppyState.shared.isQuickActionsTargeted = false
                        }
                    }
            }
            
            HStack(spacing: spacing) {
                if isExpanded {
                    // Expanded: Floating buttons only
                    QuickDropActionButton(actionType: .airdrop, useTransparent: useTransparentBackground, shareAction: shareViaAirDrop)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity).animation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.0)),
                            removal: .scale(scale: 0.5).combined(with: .opacity).animation(.easeOut(duration: 0.15))
                        ))
                    QuickDropActionButton(actionType: .messages, useTransparent: useTransparentBackground, shareAction: shareViaMessages)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity).animation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.03)),
                            removal: .scale(scale: 0.5).combined(with: .opacity).animation(.easeOut(duration: 0.15))
                        ))
                    QuickDropActionButton(actionType: .mail, useTransparent: useTransparentBackground, shareAction: shareViaMail)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity).animation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.06)),
                            removal: .scale(scale: 0.5).combined(with: .opacity).animation(.easeOut(duration: 0.15))
                        ))
                    QuickDropActionButton(actionType: .quickshare, useTransparent: useTransparentBackground, shareAction: quickShareTo0x0)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity).animation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.09)),
                            removal: .scale(scale: 0.5).combined(with: .opacity).animation(.easeOut(duration: 0.15))
                        ))
                } else {
                    // Collapsed: Zap button - matches basket border style
                    // CRITICAL: Also accepts drops to auto-expand when files are dragged over it
                    Circle()
                        .fill(buttonFill)
                        .frame(width: buttonSize, height: buttonSize)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(isBoltTargeted ? 0.4 : 0.08), lineWidth: isBoltTargeted ? 2 : 1)
                        )
                        .overlay(
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white.opacity(isBoltTargeted ? 1.0 : 0.75))
                        )
                        .scaleEffect(isBoltTargeted ? 1.15 : 1.0)
                        .contentShape(Circle().scale(1.3))
                        // DRAG-TO-EXPAND: Detect when files are dragged over the collapsed bolt
                        .onDrop(of: [UTType.fileURL], isTargeted: $isBoltTargeted) { _ in
                            // Don't handle the drop here - just expand so user can drop on specific action
                            return false
                        }
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isBoltTargeted)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isExpanded)
        .onHover { hovering in
            isHovering = hovering
        }
        .onChange(of: isHovering) { _, hovering in
            // EXPANDED VIA HOVER: normal expand/collapse on hover
            // But don't collapse if still dragging over quick action buttons
            if !hovering && (DroppyState.shared.isQuickActionsTargeted || isBoltTargeted) {
                return  // Keep expanded while dragging over bar
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                isExpanded = hovering
            }
            // Clear hovered action when collapsing
            if !hovering {
                DroppyState.shared.hoveredQuickAction = nil
            }
            if hovering && !isExpanded {
                HapticFeedback.expand()
            }
        }
        // DRAG-TO-EXPAND: Auto-expand when files are dragged over the collapsed bolt
        .onChange(of: isBoltTargeted) { _, targeted in
            if targeted && !isExpanded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isExpanded = true
                }
                HapticFeedback.expand()
            }
        }
        // COLLAPSE when quick action targeting ends (drag left the buttons)
        .onChange(of: DroppyState.shared.isQuickActionsTargeted) { _, targeted in
            if !targeted && !isHovering && isExpanded {
                DroppyState.shared.hoveredQuickAction = nil
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isExpanded = false
                }
            }
        }
        // COLLAPSE when basket becomes targeted (drag moved to basket area)
        .onChange(of: DroppyState.shared.isBasketTargeted) { _, targeted in
            if targeted && isExpanded {
                // Drag moved to basket - collapse back to bolt and clear quick actions state
                DroppyState.shared.isQuickActionsTargeted = false
                DroppyState.shared.hoveredQuickAction = nil
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isExpanded = false
                }
            }
        }
    }
    
    // MARK: - Share Actions
    
    private func shareViaAirDrop(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSSharingService(named: .sendViaAirDrop)?.perform(withItems: urls)
        FloatingBasketWindowController.shared.hideBasket()
    }
    
    private func shareViaMessages(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSSharingService(named: .composeMessage)?.perform(withItems: urls)
        FloatingBasketWindowController.shared.hideBasket()
    }
    
    private func shareViaMail(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSSharingService(named: .composeEmail)?.perform(withItems: urls)
        FloatingBasketWindowController.shared.hideBasket()
    }
    
    /// Droppy Quickshare - uploads files to 0x0.st and copies shareable link to clipboard
    /// Multiple files are automatically zipped into a single archive
    private func quickShareTo0x0(_ urls: [URL]) {
        DroppyQuickshare.share(urls: urls) {
            FloatingBasketWindowController.shared.hideBasket()
        }
    }
}

// MARK: - Quick Drop Action Button

struct QuickDropActionButton: View {
    let actionType: QuickActionType
    var useTransparent: Bool = false
    let shareAction: ([URL]) -> Void
    
    @State private var isHovering = false
    @State private var isTargeted = false
    
    private let size: CGFloat = 48
    
    private var buttonFill: Color {
        useTransparent ? Color.white.opacity(0.12) : Color.black
    }
    
    var body: some View {
        Circle()
            .fill(buttonFill)
            .frame(width: size, height: size)
            .overlay(
                // Simple clean border - matches basket style
                Circle()
                    .stroke(Color.white.opacity(isTargeted ? 0.3 : (isHovering ? 0.15 : 0.08)), lineWidth: 1)
            )
            .overlay(
                Image(systemName: actionType.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            )
            // Grow when file dragged over
            .scaleEffect(isTargeted ? 1.18 : (isHovering ? 1.05 : 1.0))
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isTargeted)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
                // Update shared state for basket explanation overlay
                if hovering {
                    DroppyState.shared.hoveredQuickAction = actionType
                } else if DroppyState.shared.hoveredQuickAction == actionType {
                    DroppyState.shared.hoveredQuickAction = nil
                }
            }
            .contentShape(Circle().scale(1.3))
            .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }
            // CRITICAL: Update shared state when this button is targeted
            // Only SET the state - clearing is handled by capsule exit or basket targeting
            .onChange(of: isTargeted) { _, targeted in
                if targeted {
                    DroppyState.shared.isQuickActionsTargeted = true
                    DroppyState.shared.hoveredQuickAction = actionType
                }
                // Don't clear here - let capsule/basket handle it
            }
            .onTapGesture {
                let urls = DroppyState.shared.basketItems.map(\.url)
                if !urls.isEmpty {
                    HapticFeedback.select()
                    shareAction(urls)
                }
            }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    } else if let url = item as? URL {
                        urls.append(url)
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                HapticFeedback.drop()
                shareAction(urls)
                // Don't auto-hide here - let the share action decide
                // iCloud sharing needs the window to stay open for the popover
            }
        }
    }
}

