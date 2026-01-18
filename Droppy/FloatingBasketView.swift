import UniformTypeIdentifiers
//
//  FloatingBasketView.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI

//
//  FloatingBasketView.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI

// MARK: - Floating Basket View

/// A floating basket view that appears during file drags as an alternative drop zone
struct FloatingBasketView: View {
    @Bindable var state: DroppyState
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    @AppStorage("showClipboardButton") private var showClipboardButton = false
    @AppStorage("enableNotchShelf") private var enableNotchShelf = true
    @AppStorage("enableAutoClean") private var enableAutoClean = false
    @AppStorage("enableAirDropZone") private var enableAirDropZone = true
    
    @State private var dashPhase: CGFloat = 0
    
    /// Dash phase freezes when any zone is targeted (animation pause effect)
    private var effectiveDashPhase: CGFloat {
        (state.isBasketTargeted || state.isAirDropZoneTargeted) ? 0 : dashPhase
    }
    
    // Drag-to-select state
    @State private var isDragSelecting = false
    @State private var dragSelectionStart: CGPoint = .zero
    @State private var dragSelectionCurrent: CGPoint = .zero
    
    // Global rename state
    @State private var renamingItemId: UUID?
    
    private let cornerRadius: CGFloat = 28
    
    // Each item is 76pt wide + 8pt spacing between = 84pt per item
    // For 4 items: 4 * 76 + 3 * 8 = 304 + 24 = 328, plus 24pt padding each side = 376
    private let itemWidth: CGFloat = 76
    private let itemSpacing: CGFloat = 8
    private let horizontalPadding: CGFloat = 24
    private let columnsPerRow: Int = 4
    
    // AirDrop zone width (30% of total when enabled)
    private let airDropZoneWidth: CGFloat = 90
    
    private var currentHeight: CGFloat {
        if state.basketItems.isEmpty {
            return 130
        } else {
            let rowCount = ceil(Double(state.basketItems.count) / Double(columnsPerRow))
            // 96pt per item height + 8pt spacing + header area
            return max(1, rowCount) * (96 + itemSpacing) + 72
        }
    }
    
    /// Base width without AirDrop zone
    private var baseWidth: CGFloat {
        if state.basketItems.isEmpty {
            return 200
        } else {
            // Width for exactly 4 items: 4 * itemWidth + 3 * spacing + padding
            return CGFloat(columnsPerRow) * itemWidth + CGFloat(columnsPerRow - 1) * itemSpacing + horizontalPadding * 2
        }
    }
    
    /// Total width including AirDrop zone when enabled AND basket is empty
    private var currentWidth: CGFloat {
        // AirDrop zone only shows when basket is empty
        let showAirDropZone = enableAirDropZone && state.basketItems.isEmpty
        return baseWidth + (showAirDropZone ? airDropZoneWidth : 0)
    }
    
    // Compute selection rectangle from start/current points
    private var selectionRect: CGRect {
        let minX = min(dragSelectionStart.x, dragSelectionCurrent.x)
        let minY = min(dragSelectionStart.y, dragSelectionCurrent.y)
        let maxX = max(dragSelectionStart.x, dragSelectionCurrent.x)
        let maxY = max(dragSelectionStart.y, dragSelectionCurrent.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    // Item frames for drag selection
    @State private var itemFrames: [UUID: CGRect] = [:]
    
    // Hover States for buttons
    @State private var isShelfButtonHovering = false
    @State private var isClipboardButtonHovering = false
    @State private var isCloseButtonHovering = false
    @State private var headerFrame: CGRect = .zero
    
    
    var body: some View {
        ZStack {
            Color.clear
            
            VStack(spacing: 12) {
            // Main Basket Content
            ZStack {
                    // Background (extracted to reduce type-checker complexity)
                    basketBackground
                    .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)

                    
                    // Content
                    if state.basketItems.isEmpty {
                        emptyContent
                    } else {
                        itemsContent
                    }
                    
                    // Selection rectangle overlay
                    if isDragSelecting {
                        Rectangle()
                            .fill(Color.blue.opacity(0.2))
                            .overlay(
                                Rectangle()
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                            .frame(width: selectionRect.width, height: selectionRect.height)
                            .position(x: selectionRect.midX, y: selectionRect.midY)
                    }
                }
                .frame(width: currentWidth, height: currentHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .scaleEffect((state.isBasketTargeted || state.isAirDropZoneTargeted) ? 1.03 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.isBasketTargeted)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.isAirDropZoneTargeted)
                // Use same spring animation as shelf for row expansion
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: state.basketItems.count)
                .coordinateSpace(name: "basketContainer")
                .onPreferenceChange(ItemFramePreferenceKey.self) { frames in
                    self.itemFrames = frames
                }
                .gesture(
                    DragGesture(minimumDistance: 5, coordinateSpace: .local)
                        .onChanged { value in
                            if !isDragSelecting {
                                // Ignore drags starting in the header (window drag area)
                                if headerFrame.contains(value.startLocation) {
                                    return
                                }
                                
                                // Check if drag started on an item using robust geometry data
                                for frame in itemFrames.values {
                                    if frame.contains(value.startLocation) {
                                        return
                                    }
                                }
                                
                                // Start selection
                                isDragSelecting = true
                                dragSelectionStart = value.startLocation
                                state.deselectAllBasket()
                            }
                            dragSelectionCurrent = value.location
                            
                            // Update selection based on items intersecting the rectangle
                            updateSelectionFromRect()
                        }
                        .onEnded { _ in
                            isDragSelecting = false
                        }
                )
                // Removed .onTapGesture from here to prevent swallowing touches on children
                .onAppear {
                    withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                        dashPhase -= 280 // Multiple of 14 (6+8) for smooth loop
                    }
                }
                .onChange(of: state.basketItems.count) { oldCount, newCount in
                    if newCount == 0 {
                        FloatingBasketWindowController.shared.hideBasket()
                    }
                }
            } // Close VStack
        } // Close ZStack
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        // MARK: - Auto-Hide Hover Tracking
        .onHover { isHovering in
            if isHovering {
                FloatingBasketWindowController.shared.onBasketHoverEnter()
            } else {
                FloatingBasketWindowController.shared.onBasketHoverExit()
            }
        }
        // MARK: - Keyboard Shortcuts
        .background {
            // Hidden button for Cmd+A select all
            Button("") {
            }
            .keyboardShortcut("a", modifiers: .command)
            .opacity(0)
        }
    }
    
    private func updateSelectionFromRect() {
        state.deselectAllBasket()
        
        // Use captured frames, which accounts for scrolling and layout accurately
        for (id, frame) in itemFrames {
            if selectionRect.intersects(frame) {
                state.selectedBasketItems.insert(id)
            }
        }
    }
    
    /// Basket background with glass effect and dashed border (extracted for type-checker)
    @ViewBuilder
    private var basketBackground: some View {
        // AirDrop zone only shows when basket is empty
        let showAirDropZone = enableAirDropZone && state.basketItems.isEmpty
        
        if showAirDropZone {
            // Wider basket with AirDrop zone on right (only when empty)
            ZStack(alignment: .leading) {
                // Single background for the whole basket
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(useTransparentBackground ? Color.clear : Color.black)
                    .frame(width: currentWidth, height: currentHeight)
                    .background {
                        if useTransparentBackground {
                            Color.clear
                                .liquidGlass(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                
                // Left zone outline (main basket - blue when targeted)
                RoundedRectangle(cornerRadius: cornerRadius - 8, style: .continuous)
                    .stroke(
                        state.isBasketTargeted ? Color.blue : Color.white.opacity(0.2),
                        style: StrokeStyle(
                            lineWidth: state.isBasketTargeted ? 2 : 1.5,
                            lineCap: .round,
                            dash: [6, 8],
                            dashPhase: effectiveDashPhase
                        )
                    )
                    .frame(width: baseWidth - 20, height: currentHeight - 20)
                    .offset(x: 10)
                
                // Right zone outline (AirDrop - red when targeted)
                RoundedRectangle(cornerRadius: cornerRadius - 8, style: .continuous)
                    .stroke(
                        state.isAirDropZoneTargeted ? Color.red : Color.white.opacity(0.2),
                        style: StrokeStyle(
                            lineWidth: state.isAirDropZoneTargeted ? 2 : 1.5,
                            lineCap: .round,
                            dash: [6, 8],
                            dashPhase: effectiveDashPhase
                        )
                    )
                    .frame(width: airDropZoneWidth - 15, height: currentHeight - 20)
                    .offset(x: baseWidth + 5)
                
                // AirDrop icon and label in the right zone (identical style to basket zone but red)
                VStack(spacing: 6) {
                    Image(systemName: state.isAirDropZoneTargeted ? "wifi" : "wifi")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(state.isAirDropZoneTargeted ? .red : .secondary)
                        .symbolEffect(.bounce, value: state.isAirDropZoneTargeted)
                    
                    Text(state.isAirDropZoneTargeted ? "Drop!" : "AirDrop")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(state.isAirDropZoneTargeted ? .primary : .secondary)
                }
                .frame(width: airDropZoneWidth, height: currentHeight)
                .offset(x: baseWidth)
            }
        } else {
            // Normal basket layout (AirDrop disabled OR basket has items)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(useTransparentBackground ? Color.clear : Color.black)
                .frame(width: currentWidth, height: currentHeight)
                .background {
                    if useTransparentBackground {
                        Color.clear
                            .liquidGlass(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius - 8, style: .continuous)
                        .stroke(
                            state.isBasketTargeted ? Color.blue : Color.white.opacity(0.2),
                            style: StrokeStyle(
                                lineWidth: state.isBasketTargeted ? 2 : 1.5,
                                lineCap: .round,
                                dash: [6, 8],
                                dashPhase: effectiveDashPhase
                            )
                        )
                        .padding(12)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
    
    @ViewBuilder
    private var emptyContent: some View {
        if enableAirDropZone {
            // Split layout when AirDrop zone is enabled
            HStack(spacing: 0) {
                // Main basket zone content - face reacts to hover
                NotchFace(size: 50, isExcited: state.isBasketTargeted)
                    .frame(width: baseWidth)
                
                // Empty space - the icon is already in airDropZoneBackground
                Color.clear
                    .frame(width: airDropZoneWidth)
            }
            .allowsHitTesting(false)
        } else {
            // Original layout when AirDrop zone is disabled
            NotchFace(size: 50, isExcited: state.isBasketTargeted)
                .allowsHitTesting(false)
        }
    }
    
    private var itemsContent: some View {
        return VStack(spacing: 8) {
            // Header
            HStack {
                Text("\(state.basketItems.count) item\(state.basketItems.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Move to shelf button (only when shelf is enabled)
                if enableNotchShelf {
                    Button {
                        moveToShelf()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.to.line")
                                .font(.system(size: 10, weight: .bold))
                            Text("To Shelf")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(isShelfButtonHovering ? 1.0 : 0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovering in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isShelfButtonHovering = isHovering
                        }
                    }
                }
                
                // Clipboard button (optional)
                if showClipboardButton {
                    Button {
                        ClipboardWindowController.shared.toggle()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isClipboardButtonHovering ? .primary : .secondary)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(isClipboardButtonHovering ? 0.2 : 0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovering in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isClipboardButtonHovering = isHovering
                        }
                    }
                }
                
                // Close button
                Button {
                    closeBasket()
                } label: {
                    Image(systemName: "eraser.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isCloseButtonHovering ? .primary : .secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(isCloseButtonHovering ? 0.2 : 0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { isHovering in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isCloseButtonHovering = isHovering
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 22)

            .background(WindowDragHandle()) // Allow dragging by header
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            headerFrame = proxy.frame(in: .named("basketContainer"))
                        }
                        .onChange(of: proxy.frame(in: .named("basketContainer"))) { _, newFrame in
                            headerFrame = newFrame
                        }
                }
            )
            
            // Items grid - wrapped in ZStack with background tap handler for deselection
            ZStack {
                // Background tap handler - catches clicks on empty areas
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        state.deselectAllBasket()
                        // If rename was active, end the file operation lock
                        if renamingItemId != nil {
                            state.isRenaming = false
                            state.endFileOperation()
                        }
                        renamingItemId = nil
                    }
                
                // Items grid using LazyVGrid for efficient rendering
                let columns = Array(repeating: GridItem(.fixed(itemWidth), spacing: itemSpacing), count: columnsPerRow)
                
                LazyVGrid(columns: columns, spacing: itemSpacing) {
                    ForEach(state.basketItems) { item in
                        BasketItemView(item: item, state: state, renamingItemId: $renamingItemId) {
                            state.removeBasketItem(item)
                        }
                        // Smooth in-place morph matching shelf behavior
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state.basketItems.count)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, 16)
        }
    }
    
    private func moveToShelf() {
        // Move selected items if any are selected, otherwise move all
        let itemsToMove: [DroppedItem]
        if state.selectedBasketItems.isEmpty {
            itemsToMove = state.basketItems
        } else {
            itemsToMove = state.basketItems.filter { state.selectedBasketItems.contains($0.id) }
        }
        
        // Remove moved items from basket and add to shelf
        // Use transfer-safe removal to preserve files on disk
        for item in itemsToMove {
            state.addItem(item)
            state.removeBasketItemForTransfer(item)
        }
        state.deselectAllBasket()
        
        // Hide basket if empty after move
        if state.basketItems.isEmpty {
            FloatingBasketWindowController.shared.hideBasket()
        }
    }
    
    private func closeBasket() {
        state.clearBasket()
        FloatingBasketWindowController.shared.hideBasket()
    }
}




// MARK: - Rename Text Field with Auto-Select and Animated Dotted Border
private struct RenameTextField: View {
    @Binding var text: String
    @Binding var isRenaming: Bool
    let onRename: () -> Void
    
    @State private var dashPhase: CGFloat = 0
    
    var body: some View {
        AutoSelectTextField(
            text: $text,
            onSubmit: onRename,
            onCancel: { isRenaming = false }
        )
        .font(.system(size: 11, weight: .medium))
        .frame(width: 72)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.3))
        )
        // Animated dotted blue outline
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    Color.accentColor.opacity(0.8),
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        lineCap: .round,
                        dash: [3, 3],
                        dashPhase: dashPhase
                    )
                )
        )
        .onAppear {
            // Animate the marching ants
            withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                dashPhase = 6
            }
        }
    }
}

// MARK: - Auto-Select Text Field (NSViewRepresentable)
private struct AutoSelectTextField: NSViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.backgroundColor = .clear
        textField.textColor = .white
        textField.font = .systemFont(ofSize: 11, weight: .medium)
        textField.alignment = .center
        textField.focusRingType = .none
        textField.stringValue = text
        
        // Make it the first responder and select all text after a brief delay
        // For non-activating panels, we need special handling to make them accept keyboard input
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let window = textField.window as? NSPanel else { return }
            
            // Temporarily allow the panel to become key window
            window.becomesKeyOnlyIfNeeded = false
            
            // CRITICAL: Activate the app itself - this is what makes the selection blue vs grey
            NSApp.activate(ignoringOtherApps: true)
            
            // Make the window key and order it front to accept keyboard input
            window.makeKeyAndOrderFront(nil)
            
            // Now make the text field first responder
            window.makeFirstResponder(textField)
            
            // Select all text
            textField.selectText(nil)
            if let editor = textField.currentEditor() {
                editor.selectedRange = NSRange(location: 0, length: textField.stringValue.count)
            }
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Only update if text changed externally
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: AutoSelectTextField
        
        init(_ parent: AutoSelectTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ notification: Notification) {
            if let textField = notification.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Enter pressed - submit
                parent.onSubmit()
                return true
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                // Escape pressed - cancel
                parent.onCancel()
                return true
            }
            return false
        }
    }
}
