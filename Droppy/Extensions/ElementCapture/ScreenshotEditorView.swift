//
//  ScreenshotEditorView.swift
//  Droppy
//
//  Screenshot annotation editor with arrows, rectangles, ellipses, freehand, and text tools
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Annotation Model

enum AnnotationTool: String, CaseIterable, Identifiable {
    case arrow = "arrow.up.right"
    case line = "line.diagonal"
    case rectangle = "rectangle"
    case ellipse = "oval"
    case freehand = "scribble"
    case highlighter = "highlighter"
    case blur = "eye.slash"
    case text = "textformat"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .arrow: return "Arrow"
        case .line: return "Line"
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .freehand: return "Freehand"
        case .highlighter: return "Highlighter"
        case .blur: return "Blur"
        case .text: return "Text"
        }
    }
    
    /// Default keyboard shortcut key (single character, no modifiers)
    var defaultShortcut: Character {
        switch self {
        case .arrow: return "a"
        case .line: return "l"
        case .rectangle: return "r"
        case .ellipse: return "o"  // O for oval/ellipse
        case .freehand: return "f"
        case .highlighter: return "h"
        case .blur: return "b"
        case .text: return "t"
        }
    }
    
    /// Tooltip with shortcut hint
    var tooltipWithShortcut: String {
        "\(displayName) (\(defaultShortcut.uppercased()))"
    }
}

struct Annotation: Identifiable {
    let id = UUID()
    var tool: AnnotationTool
    var points: [CGPoint] = []
    var color: Color
    var strokeWidth: CGFloat
    var text: String = ""
    var font: String = "SF Pro"
    var blurStrength: CGFloat = 10  // For blur tool: lower = stronger pixelation (5-30)
}

// MARK: - Window Drag View (NSViewRepresentable for reliable window dragging)

struct WindowDragView: NSViewRepresentable {
    func makeNSView(context: Context) -> DraggableView {
        DraggableView()
    }
    
    func updateNSView(_ nsView: DraggableView, context: Context) {}
    
    class DraggableView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

// Zoom is now handled via +/- buttons in the toolbar

// MARK: - Screenshot Editor View

struct ScreenshotEditorView: View {
    let originalImage: NSImage
    let onSave: (NSImage) -> Void
    let onCancel: () -> Void
    
    @State private var annotations: [Annotation] = []
    @State private var currentAnnotation: Annotation?
    @State private var selectedTool: AnnotationTool = .arrow
    @State private var selectedColor: Color = .red
    @State private var strokeWidth: CGFloat = 4
    @State private var undoStack: [[Annotation]] = []
    @State private var textInput: String = ""
    @State private var showingTextInput = false
    @State private var textPosition: CGPoint = .zero
    @State private var canvasSize: CGSize = .zero
    @State private var showingOutputMenu = false
    
    // Zoom
    @State private var zoomScale: CGFloat = 1.0
    
    // Font selection
    @State private var selectedFont: String = "SF Pro"
    private let availableFonts = ["SF Pro", "SF Mono", "Helvetica Neue", "Arial", "Georgia", "Menlo"]
    
    // Annotation moving
    @State private var selectedAnnotationIndex: Int? = nil
    @State private var isDraggingAnnotation = false
    
    private let colors: [Color] = [.red, .orange, .yellow, .green, .cyan, .purple, .white]
    private let strokeWidths: [(CGFloat, String)] = [(2, "S"), (4, "M"), (6, "L")]
    
    // Transparent mode preference
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    
    // Blur strength preference (5-30, lower = stronger pixelation)
    @AppStorage(AppPreferenceKey.editorBlurStrength) private var blurStrength = PreferenceDefault.editorBlurStrength
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar (draggable area)
            titleBar
            
            // Tools bar (scrollable)
            toolsBarContainer
            
            // Canvas with zoom support
            GeometryReader { containerGeometry in
                let availableSize = containerGeometry.size
                let imageAspect = originalImage.size.width / originalImage.size.height
                let containerAspect = availableSize.width / availableSize.height
                
                // Calculate size to fit image in container at 100%
                let fittedSize: CGSize = {
                    if imageAspect > containerAspect {
                        // Image is wider than container
                        let width = availableSize.width
                        let height = width / imageAspect
                        return CGSize(width: width, height: height)
                    } else {
                        // Image is taller than container
                        let height = availableSize.height
                        let width = height * imageAspect
                        return CGSize(width: width, height: height)
                    }
                }()
                
                let scaledSize = CGSize(
                    width: fittedSize.width * zoomScale,
                    height: fittedSize.height * zoomScale
                )
                
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack {
                        // Background image
                        Image(nsImage: originalImage)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: scaledSize.width, height: scaledSize.height)
                        
                        // Annotations canvas overlay
                        AnnotationCanvas(
                            annotations: annotations,
                            currentAnnotation: currentAnnotation,
                            originalImage: originalImage,
                            imageSize: originalImage.size,
                            containerSize: scaledSize
                        )
                        .frame(width: scaledSize.width, height: scaledSize.height)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    handleDrag(value, in: scaledSize)
                                }
                                .onEnded { value in
                                    handleDragEnd(value, in: scaledSize)
                                }
                        )
                        .onContinuousHover { phase in
                            switch phase {
                            case .active:
                                updateCursor()
                            case .ended:
                                NSCursor.arrow.set()
                            }
                        }
                    }
                    .frame(width: scaledSize.width, height: scaledSize.height)
                }
                .frame(width: availableSize.width, height: availableSize.height)
                .onAppear {
                    canvasSize = scaledSize
                }
            }
            .background(useTransparentBackground ? Color.clear : AdaptiveColors.panelBackgroundAuto)
        }
        .frame(minWidth: 600, idealWidth: 800, maxWidth: .infinity)
        .frame(minHeight: 400, idealHeight: 600, maxHeight: .infinity)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .sheet(isPresented: $showingTextInput) {
            textInputSheet
        }
        .onAppear {
            setupKeyboardMonitor()
            updateCursor()
        }
        .onDisappear {
            removeKeyboardMonitor()
            NSCursor.arrow.set()  // Reset cursor on close
        }
        .onChange(of: selectedTool) { _, _ in
            updateCursor()
        }
    }
    
    // MARK: - Keyboard Shortcuts
    
    @State private var keyboardMonitor: Any?
    
    private func setupKeyboardMonitor() {
        // Load shortcuts from manager
        let shortcuts = ElementCaptureManager.shared.editorShortcuts
        
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            // Don't capture if text input sheet is showing
            guard !showingTextInput else { return event }
            
            // Check for modifier keys
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let keyCode = Int(event.keyCode)
            
            // Check against each editor shortcut
            for (action, shortcut) in shortcuts {
                if keyCode == shortcut.keyCode && flags.rawValue == shortcut.modifiers {
                    switch action {
                    // Tools
                    case .arrow: selectedTool = .arrow; return nil
                    case .line: selectedTool = .line; return nil
                    case .rectangle: selectedTool = .rectangle; return nil
                    case .ellipse: selectedTool = .ellipse; return nil
                    case .freehand: selectedTool = .freehand; return nil
                    case .highlighter: selectedTool = .highlighter; return nil
                    case .blur: selectedTool = .blur; return nil
                    case .text: selectedTool = .text; return nil
                    // Strokes
                    case .strokeSmall: strokeWidth = 2; return nil
                    case .strokeMedium: strokeWidth = 4; return nil
                    case .strokeLarge: strokeWidth = 6; return nil
                    // Zoom
                    case .zoomIn: zoomScale = min(4.0, zoomScale + 0.25); return nil
                    case .zoomOut: zoomScale = max(0.25, zoomScale - 0.25); return nil
                    case .zoomReset: zoomScale = 1.0; return nil
                    // Actions  
                    case .undo: undo(); return nil
                    case .redo: redo(); return nil
                    case .cancel: onCancel(); return nil
                    case .done: saveAnnotatedImage(); return nil
                    }
                }
            }
            
            // Check for ⌘C to copy and close  
            if keyCode == 8 && flags == .command {  // 8 = C key
                saveAnnotatedImage()
                return nil
            }
            
            return event
        }
    }
    
    private func removeKeyboardMonitor() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
    }
    
    // MARK: - Cursor Feedback
    
    private func updateCursor() {
        // Use crosshair cursor for drawing tools
        switch selectedTool {
        case .arrow, .line, .rectangle, .ellipse, .freehand, .highlighter, .blur:
            NSCursor.crosshair.set()
        case .text:
            NSCursor.iBeam.set()
        }
    }
    
    // MARK: - Title Bar (Draggable)
    
    private var titleBar: some View {
        HStack {
            // Close button
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 28))
            
            Spacer()
            
            // Title (drag handle area)
            Text("Edit Screenshot")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Output menu + Done
            HStack(spacing: 10) {
                // Output options menu
                Menu {
                    Button {
                        saveToFile()
                    } label: {
                        Label("Save to File...", systemImage: "square.and.arrow.down")
                    }
                    
                    if !ExtensionType.quickshare.isRemoved {
                        Button {
                            shareViaQuickshare()
                        } label: {
                            Label("Quickshare", systemImage: "drop.fill")
                        }
                    }
                    
                    Button {
                        addToShelf()
                    } label: {
                        Label("Add to Shelf", systemImage: "tray.and.arrow.down")
                    }
                    
                    Button {
                        addToBasket()
                    } label: {
                        Label("Add to Basket", systemImage: "basket")
                    }
                    
                    Divider()
                    
                    Button {
                        saveAnnotatedImage()
                    } label: {
                        Label("Copy to Clipboard", systemImage: "doc.on.clipboard")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AdaptiveColors.primaryTextAuto.opacity(0.85))
                        .frame(width: 28, height: 28)
                        .background(AdaptiveColors.overlayAuto(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                
                // Done button
                Button(action: saveAnnotatedImage) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("Done")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .green, size: .small))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ZStack {
                if useTransparentBackground {
                    AdaptiveColors.overlayAuto(0.06)
                } else {
                    AdaptiveColors.buttonBackgroundAuto
                }
                WindowDragView()
            }
        )
    }
    
    // MARK: - Tools Bar
    
    private var toolsBar: some View {
        HStack(spacing: 8) {
            // Undo/Redo
            Button(action: undo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 28))
            .disabled(annotations.isEmpty)
            .opacity(annotations.isEmpty ? 0.4 : 1)
            
            Button(action: redo) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 28))
            .disabled(undoStack.isEmpty)
            .opacity(undoStack.isEmpty ? 0.4 : 1)
            
            toolbarDivider
            
            // Zoom controls
            Button(action: { zoomScale = max(0.25, zoomScale - 0.25) }) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 28))
            .disabled(zoomScale <= 0.25)
            .opacity(zoomScale <= 0.25 ? 0.4 : 1)
            
            Text("\(Int(zoomScale * 100))%")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(AdaptiveColors.secondaryTextAuto)
                .frame(width: 40)
            
            Button(action: { zoomScale = min(4.0, zoomScale + 0.25) }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 28))
            .disabled(zoomScale >= 4.0)
            .opacity(zoomScale >= 4.0 ? 0.4 : 1)
            
            Button(action: { zoomScale = 1.0 }) {
                Text("Fit")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 28))
            .opacity(zoomScale == 1.0 ? 0.4 : 1)
            
            toolbarDivider
            
            // Tools
            ForEach(AnnotationTool.allCases) { tool in
                Button {
                    selectedTool = tool
                } label: {
                    Image(systemName: tool.rawValue)
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(DroppyToggleButtonStyle(
                    isOn: selectedTool == tool,
                    size: 28,
                    cornerRadius: 14,
                    accentColor: .yellow
                ))
                .help(tool.tooltipWithShortcut)
            }
            
            toolbarDivider
            
            // Colors
            HStack(spacing: 4) {
                ForEach(colors, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(selectedColor == color ? AdaptiveColors.primaryTextAuto : Color.clear, lineWidth: 2)
                        )
                        .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                        .animation(.easeOut(duration: 0.1), value: selectedColor)
                        .onTapGesture {
                            selectedColor = color
                        }
                }
            }
            
            toolbarDivider
            
            HStack(spacing: 6) {
                ForEach(strokeWidths, id: \.0) { width, name in
                    Button {
                        strokeWidth = width
                    } label: {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(strokeWidth == width ? Color.yellow : AdaptiveColors.overlayAuto(0.5))
                            .frame(width: 22, height: width + 4)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 28, height: 28) // Larger hit target
                    .contentShape(Rectangle())
                    .help(name)
                }
            }
            
            toolbarDivider
            
            // Font picker (only relevant for text tool)
            Menu {
                ForEach(availableFonts, id: \.self) { font in
                    Button {
                        selectedFont = font
                    } label: {
                        HStack {
                            Text(font)
                                .font(.custom(font == "SF Pro" ? ".AppleSystemUIFont" : font, size: 12))
                            if selectedFont == font {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "textformat")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(selectedTool == .text ? .yellow : AdaptiveColors.primaryTextAuto.opacity(0.75))
                    .frame(width: 28, height: 28)
                    .background(AdaptiveColors.overlayAuto(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Font: \(selectedFont)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var toolsBarContainer: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            toolsBar
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .background(useTransparentBackground ? AdaptiveColors.overlayAuto(0.04) : AdaptiveColors.buttonBackgroundAuto)
    }
    
    private var toolbarDivider: some View {
        Rectangle()
            .fill(AdaptiveColors.overlayAuto(0.1))
            .frame(width: 1, height: 22)
    }
    
    // MARK: - Output Functions
    
    private func saveToFile() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "Screenshot.png"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            if let pngData = renderAnnotatedPNGData() {
                try? pngData.write(to: url)
            }
        }
    }
    
    private func shareViaQuickshare() {
        guard !ExtensionType.quickshare.isRemoved else { return }
        // Use Droppy's quickshare
        if let pngData = renderAnnotatedPNGData() {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("screenshot_\(UUID().uuidString).png")
            try? pngData.write(to: tempURL)
            // Use DroppyQuickshare to upload
            DroppyQuickshare.share(urls: [tempURL])
        }
        onCancel() // Close editor
    }
    
    private func addToShelf() {
        // Save to temp file and add to shelf
        if let pngData = renderAnnotatedPNGData() {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("screenshot_\(UUID().uuidString).png")
            try? pngData.write(to: tempURL)
            // Directly add to shelf
            DroppyState.shared.addItems(from: [tempURL])
        }
        onCancel() // Close editor
    }
    
    private func addToBasket() {
        // Save to temp file and add to basket
        if let pngData = renderAnnotatedPNGData() {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("screenshot_\(UUID().uuidString).png")
            try? pngData.write(to: tempURL)
            FloatingBasketWindowController.addItemsFromExternalSource([tempURL])
        }
        onCancel() // Close editor
    }
    
    // MARK: - Text Input Sheet
    
    private var textInputSheet: some View {
        VStack(spacing: 0) {
            // Header
            Text("Add Text")
                .font(.headline.bold())
                .foregroundStyle(.primary)
                .padding(.top, 24)
                .padding(.bottom, 16)
            
            Divider()
                .padding(.horizontal, 20)
            
            // Text field with dotted outline
            VStack(spacing: 12) {
                TextField("Enter text...", text: $textInput)
                    .textFieldStyle(.plain)
                    .font(.custom(selectedFont == "SF Pro" ? ".AppleSystemUIFont" : selectedFont, size: 14))
                    .droppyTextInputChrome(
                        cornerRadius: DroppyRadius.medium,
                        horizontalPadding: 12,
                        verticalPadding: 12
                    )
                
                // Font picker
                HStack {
                    Text("Font:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Menu {
                        ForEach(availableFonts, id: \.self) { font in
                            Button {
                                selectedFont = font
                            } label: {
                                HStack {
                                    Text(font)
                                        .font(.custom(font == "SF Pro" ? ".AppleSystemUIFont" : font, size: 12))
                                    if selectedFont == font {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedFont)
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AdaptiveColors.overlayAuto(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
                .padding(.horizontal, 20)
            
            // Action buttons (Droppy standard layout)
            HStack(spacing: 10) {
                Button {
                    showingTextInput = false
                    textInput = ""
                } label: {
                    Text("Cancel")
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
                
                Spacer()
                
                Button {
                    addTextAnnotation()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add")
                    }
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
                .disabled(textInput.isEmpty)
                .opacity(textInput.isEmpty ? 0.5 : 1.0)
            }
            .padding(DroppySpacing.lg)
        }
        .frame(width: 320)
        .background(AdaptiveColors.panelBackgroundAuto)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
    }
    
    // MARK: - Gesture Handling
    
    private func handleDrag(_ value: DragGesture.Value, in containerSize: CGSize) {
        // Normalize point to 0-1 range for zoom-independent storage
        let normalizedPoint = CGPoint(
            x: value.location.x / containerSize.width,
            y: value.location.y / containerSize.height
        )
        let normalizedStart = CGPoint(
            x: value.startLocation.x / containerSize.width,
            y: value.startLocation.y / containerSize.height
        )
        
        // Check if we're dragging an existing text annotation
        if isDraggingAnnotation, let index = selectedAnnotationIndex, index < annotations.count {
            // Move the text annotation
            annotations[index].points = [normalizedPoint]
            return
        }
        
        // Check if clicking on existing text annotation (to select for moving)
        if value.translation.width == 0 && value.translation.height == 0 {
            // This is the start of a drag - check for text annotation under cursor
            let normalizedClickPoint = CGPoint(
                x: value.startLocation.x / containerSize.width,
                y: value.startLocation.y / containerSize.height
            )
            if let textIndex = findTextAnnotationAt(point: normalizedClickPoint, in: containerSize) {
                selectedAnnotationIndex = textIndex
                isDraggingAnnotation = true
                return
            }
        }
        
        if selectedTool == .text {
            // Text tool just needs click position
            return
        }
        
        if currentAnnotation == nil {
            // Start new annotation
            var annotation = Annotation(
                tool: selectedTool,
                color: selectedColor,
                strokeWidth: strokeWidth
            )
            // Capture blur strength for blur tool
            if selectedTool == .blur {
                annotation.blurStrength = blurStrength
            }
            annotation.points = [normalizedStart, normalizedPoint]
            currentAnnotation = annotation
        } else {
            // Update current annotation
            if selectedTool == .freehand || selectedTool == .highlighter {
                currentAnnotation?.points.append(normalizedPoint)
            } else {
                // For arrow, line, rect, ellipse - track start and end with Shift-constrain
                var constrainedPoint = normalizedPoint
                
                // Check if Shift is held for constrain mode
                if NSEvent.modifierFlags.contains(.shift) {
                    constrainedPoint = applyShiftConstraint(
                        from: normalizedStart,
                        to: normalizedPoint,
                        tool: selectedTool
                    )
                }
                
                currentAnnotation?.points = [normalizedStart, constrainedPoint]
            }
        }
    }
    
    /// Applies Shift-key constraints: 45° angles for lines/arrows, square/circle for rect/ellipse
    private func applyShiftConstraint(from start: CGPoint, to end: CGPoint, tool: AnnotationTool) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        
        switch tool {
        case .arrow, .line:
            // Snap to nearest 45° angle (0°, 45°, 90°, 135°, 180°, 225°, 270°, 315°)
            let angle = atan2(dy, dx)
            let snappedAngle = round(angle / (.pi / 4)) * (.pi / 4)
            let distance = hypot(dx, dy)
            return CGPoint(
                x: start.x + cos(snappedAngle) * distance,
                y: start.y + sin(snappedAngle) * distance
            )
            
        case .rectangle, .ellipse, .blur:
            // Constrain to square/circle (equal width and height)
            let size = max(abs(dx), abs(dy))
            return CGPoint(
                x: start.x + (dx >= 0 ? size : -size),
                y: start.y + (dy >= 0 ? size : -size)
            )
            
        default:
            return end
        }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value, in containerSize: CGSize) {
        // Reset drag state for text moving
        if isDraggingAnnotation {
            isDraggingAnnotation = false
            selectedAnnotationIndex = nil
            return
        }
        
        if selectedTool == .text {
            // Store normalized position for text
            textPosition = CGPoint(
                x: value.location.x / containerSize.width,
                y: value.location.y / containerSize.height
            )
            canvasSize = containerSize // Store for text annotation
            showingTextInput = true
            return
        }
        
        if var annotation = currentAnnotation {
            // Finalize annotation with normalized coordinates
            let normalizedStart = CGPoint(
                x: value.startLocation.x / containerSize.width,
                y: value.startLocation.y / containerSize.height
            )
            let normalizedEnd = CGPoint(
                x: value.location.x / containerSize.width,
                y: value.location.y / containerSize.height
            )
            
            if selectedTool != .freehand && selectedTool != .highlighter {
                // Apply Shift-constraint to final points if Shift is held
                var finalEnd = normalizedEnd
                if NSEvent.modifierFlags.contains(.shift) {
                    finalEnd = applyShiftConstraint(
                        from: normalizedStart,
                        to: normalizedEnd,
                        tool: selectedTool
                    )
                }
                annotation.points = [normalizedStart, finalEnd]
            }
            
            // Only add if there's actual content
            let distance = hypot(
                value.location.x - value.startLocation.x,
                value.location.y - value.startLocation.y
            )
            if distance > 5 {
                annotations.append(annotation)
                undoStack.removeAll() // Clear redo stack on new action
            }
        }
        currentAnnotation = nil
    }
    
    // MARK: - Actions
    
    private func addTextAnnotation() {
        var annotation = Annotation(
            tool: .text,
            color: selectedColor,
            strokeWidth: strokeWidth
        )
        annotation.points = [textPosition]
        annotation.text = textInput
        annotation.font = selectedFont
        annotations.append(annotation)
        undoStack.removeAll()
        
        showingTextInput = false
        textInput = ""
    }
    
    private func undo() {
        guard !annotations.isEmpty else { return }
        undoStack.append(annotations)
        annotations.removeLast()
    }
    
    private func redo() {
        guard let lastState = undoStack.popLast() else { return }
        annotations = lastState
    }
    
    /// Find a text annotation at the given point, returning its index if found
    private func findTextAnnotationAt(point: CGPoint, in containerSize: CGSize) -> Int? {
        // Check text annotations in reverse order (top-most first)
        for (index, annotation) in annotations.enumerated().reversed() {
            guard annotation.tool == .text, !annotation.points.isEmpty else { continue }
            
            let textPoint = annotation.points[0]
            // Estimate text bounds - approximately 150x40 for typical text
            let textWidth: CGFloat = CGFloat(annotation.text.count) * annotation.strokeWidth * 5
            let textHeight: CGFloat = annotation.strokeWidth * 12
            let textRect = CGRect(
                x: textPoint.x,
                y: textPoint.y,
                width: max(60, textWidth),
                height: textHeight
            )
            
            if textRect.contains(point) {
                return index
            }
        }
        return nil
    }
    
    private func saveAnnotatedImage() {
        let annotatedImage = renderAnnotatedImage()
        onSave(annotatedImage)
    }
    
    // MARK: - Rendering
    
    private func renderAnnotatedImage() -> NSImage {
        guard let bitmap = renderAnnotatedBitmap() else {
            return originalImage
        }
        
        let image = NSImage(size: bitmap.size)
        image.addRepresentation(bitmap)
        return image
    }
    
    private func renderAnnotatedPNGData() -> Data? {
        guard let bitmap = renderAnnotatedBitmap() else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
    
    private func renderAnnotatedBitmap() -> NSBitmapImageRep? {
        let renderSize = sourcePixelSize()
        let renderWidth = max(1, Int(renderSize.width.rounded(.toNearestOrAwayFromZero)))
        let renderHeight = max(1, Int(renderSize.height.rounded(.toNearestOrAwayFromZero)))
        
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: renderWidth,
            pixelsHigh: renderHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        
        bitmap.size = originalImage.size
        
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        
        let renderRect = NSRect(origin: .zero, size: renderSize)
        
        // Draw original image at full pixel resolution.
        originalImage.draw(in: renderRect, from: .zero, operation: .copy, fraction: 1.0)
        
        // Draw annotations on top in the same pixel coordinate space.
        for annotation in annotations {
            drawAnnotation(annotation, in: renderSize)
        }
        
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }
    
    private func sourcePixelSize() -> NSSize {
        if let bitmapRep = originalImage.representations
            .compactMap({ $0 as? NSBitmapImageRep })
            .max(by: { ($0.pixelsWide * $0.pixelsHigh) < ($1.pixelsWide * $1.pixelsHigh) }) {
            return NSSize(width: bitmapRep.pixelsWide, height: bitmapRep.pixelsHigh)
        }
        
        if let cgImage = originalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return NSSize(width: cgImage.width, height: cgImage.height)
        }
        
        return originalImage.size
    }
    
    private func drawAnnotation(_ annotation: Annotation, in size: NSSize) {
        guard !annotation.points.isEmpty else { return }
        
        let nsColor = NSColor(annotation.color)
        nsColor.setStroke()
        nsColor.setFill()
        
        switch annotation.tool {
        case .arrow:
            drawArrow(from: annotation.points[0], to: annotation.points.last ?? annotation.points[0], strokeWidth: annotation.strokeWidth, in: size)
            
        case .line:
            // Simple straight line (no arrowhead)
            let path = NSBezierPath()
            path.lineWidth = annotation.strokeWidth
            path.lineCapStyle = .round
            path.move(to: scalePoint(annotation.points[0], to: size))
            path.line(to: scalePoint(annotation.points.last ?? annotation.points[0], to: size))
            path.stroke()
            
        case .rectangle:
            let rect = rectFromPoints(annotation.points[0], annotation.points.last ?? annotation.points[0], in: size)
            let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
            path.lineWidth = annotation.strokeWidth
            path.stroke()
            
        case .ellipse:
            let rect = rectFromPoints(annotation.points[0], annotation.points.last ?? annotation.points[0], in: size)
            let path = NSBezierPath(ovalIn: rect)
            path.lineWidth = annotation.strokeWidth
            path.stroke()
            
        case .freehand:
            let path = NSBezierPath()
            path.lineWidth = annotation.strokeWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            
            for (index, point) in annotation.points.enumerated() {
                let scaledPoint = scalePoint(point, to: size)
                if index == 0 {
                    path.move(to: scaledPoint)
                } else {
                    path.line(to: scaledPoint)
                }
            }
            path.stroke()
            
        case .highlighter:
            // Semi-transparent marker effect
            let path = NSBezierPath()
            path.lineWidth = annotation.strokeWidth * 4 // Wider for highlighter effect
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            
            for (index, point) in annotation.points.enumerated() {
                let scaledPoint = scalePoint(point, to: size)
                if index == 0 {
                    path.move(to: scaledPoint)
                } else {
                    path.line(to: scaledPoint)
                }
            }
            // Use semi-transparent color
            nsColor.withAlphaComponent(0.4).setStroke()
            path.stroke()
            
        case .blur:
            // Simple pixelation using NSImage lockFocus
            // rect is already in image coordinates (rectFromPoints scales normalized to size)
            let rect = rectFromPoints(annotation.points[0], annotation.points.last ?? annotation.points[0], in: size)
            guard rect.width > 4 && rect.height > 4 else { return }
            
            // Use annotation's blur strength (lower = stronger pixelation)
            let pixelSize = Int(annotation.blurStrength)
            let tinySize = NSSize(width: pixelSize, height: pixelSize)
            let tinyImage = NSImage(size: tinySize)
            tinyImage.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .none
            originalImage.draw(in: NSRect(origin: .zero, size: tinySize),
                              from: rect,  // rect is already in image coordinates
                              operation: .copy,
                              fraction: 1.0)
            tinyImage.unlockFocus()
            
            // Draw the tiny image scaled back up (creates pixelation)
            NSGraphicsContext.current?.imageInterpolation = .none
            tinyImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
            
        case .text:
            let scaledPoint = scalePoint(annotation.points[0], to: size)
            // Get the correct font
            let fontName = annotation.font == "SF Pro" ? ".AppleSystemUIFont" : annotation.font
            let font = NSFont(name: fontName, size: annotation.strokeWidth * 8) ?? NSFont.systemFont(ofSize: annotation.strokeWidth * 8, weight: .semibold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: nsColor
            ]
            annotation.text.draw(at: scaledPoint, withAttributes: attributes)
        }
    }
    
    private func drawArrow(from start: CGPoint, to end: CGPoint, strokeWidth: CGFloat, in size: NSSize) {
        let scaledStart = scalePoint(start, to: size)
        let scaledEnd = scalePoint(end, to: size)
        
        let path = NSBezierPath()
        path.lineWidth = strokeWidth
        path.lineCapStyle = .round
        
        // Main line
        path.move(to: scaledStart)
        path.line(to: scaledEnd)
        path.stroke()
        
        // Arrowhead
        let angle = atan2(scaledEnd.y - scaledStart.y, scaledEnd.x - scaledStart.x)
        let arrowLength: CGFloat = 15 + strokeWidth * 2
        let arrowAngle: CGFloat = .pi / 6
        
        let arrowPath = NSBezierPath()
        arrowPath.lineWidth = strokeWidth
        arrowPath.lineCapStyle = .round
        arrowPath.lineJoinStyle = .round
        
        let point1 = CGPoint(
            x: scaledEnd.x - arrowLength * cos(angle - arrowAngle),
            y: scaledEnd.y - arrowLength * sin(angle - arrowAngle)
        )
        let point2 = CGPoint(
            x: scaledEnd.x - arrowLength * cos(angle + arrowAngle),
            y: scaledEnd.y - arrowLength * sin(angle + arrowAngle)
        )
        
        arrowPath.move(to: point1)
        arrowPath.line(to: scaledEnd)
        arrowPath.line(to: point2)
        arrowPath.stroke()
    }
    
    private func rectFromPoints(_ p1: CGPoint, _ p2: CGPoint, in size: NSSize) -> NSRect {
        let s1 = scalePoint(p1, to: size)
        let s2 = scalePoint(p2, to: size)
        return NSRect(
            x: min(s1.x, s2.x),
            y: min(s1.y, s2.y),
            width: abs(s2.x - s1.x),
            height: abs(s2.y - s1.y)
        )
    }
    
    private func scalePoint(_ point: CGPoint, to size: NSSize) -> CGPoint {
        // Points are normalized 0-1, scale to image size
        // Note: NSImage coordinate system has origin at bottom-left, so flip Y
        return CGPoint(
            x: point.x * size.width,
            y: (1.0 - point.y) * size.height  // Flip Y for NSImage (0-1 normalized, 0=top, 1=bottom in SwiftUI)
        )
    }
}

// MARK: - Annotation Canvas

struct AnnotationCanvas: View {
    let annotations: [Annotation]
    let currentAnnotation: Annotation?
    let originalImage: NSImage
    let imageSize: CGSize
    let containerSize: CGSize
    
    var body: some View {
        Canvas { context, size in
            // Draw completed annotations
            for annotation in annotations {
                drawAnnotation(annotation, in: context, size: size)
            }
            
            // Draw current annotation being created
            if let current = currentAnnotation {
                drawAnnotation(current, in: context, size: size)
            }
        }
    }
    
    private func drawAnnotation(_ annotation: Annotation, in context: GraphicsContext, size: CGSize) {
        guard !annotation.points.isEmpty else { return }
        
        let color = annotation.color
        let strokeStyle = StrokeStyle(lineWidth: annotation.strokeWidth, lineCap: .round, lineJoin: .round)
        
        switch annotation.tool {
        case .arrow:
            let start = scalePoint(annotation.points[0], to: size)
            let end = scalePoint(annotation.points.last ?? annotation.points[0], to: size)
            drawArrow(from: start, to: end, color: color, strokeStyle: strokeStyle, in: context)
            
        case .line:
            let start = scalePoint(annotation.points[0], to: size)
            let end = scalePoint(annotation.points.last ?? annotation.points[0], to: size)
            var linePath = Path()
            linePath.move(to: start)
            linePath.addLine(to: end)
            context.stroke(linePath, with: .color(color), style: strokeStyle)
            
        case .rectangle:
            let rect = rectFromPoints(annotation.points[0], annotation.points.last ?? annotation.points[0], size: size)
            let path = RoundedRectangle(cornerRadius: 4).path(in: rect)
            context.stroke(path, with: .color(color), style: strokeStyle)
            
        case .ellipse:
            let rect = rectFromPoints(annotation.points[0], annotation.points.last ?? annotation.points[0], size: size)
            let path = Ellipse().path(in: rect)
            context.stroke(path, with: .color(color), style: strokeStyle)
            
        case .freehand:
            var path = Path()
            for (index, point) in annotation.points.enumerated() {
                let scaled = scalePoint(point, to: size)
                if index == 0 {
                    path.move(to: scaled)
                } else {
                    path.addLine(to: scaled)
                }
            }
            context.stroke(path, with: .color(color), style: strokeStyle)
            
        case .highlighter:
            var path = Path()
            for (index, point) in annotation.points.enumerated() {
                let scaled = scalePoint(point, to: size)
                if index == 0 {
                    path.move(to: scaled)
                } else {
                    path.addLine(to: scaled)
                }
            }
            let highlightStyle = StrokeStyle(lineWidth: annotation.strokeWidth * 4, lineCap: .round, lineJoin: .round)
            context.stroke(path, with: .color(color.opacity(0.4)), style: highlightStyle)
            
        case .blur:
            let rect = rectFromPoints(annotation.points[0], annotation.points.last ?? annotation.points[0], size: size)
            guard rect.width > 4 && rect.height > 4 else { return }
            
            // Sample from original image - need to flip Y because NSImage has bottom-left origin
            let scaleX = originalImage.size.width / size.width
            let scaleY = originalImage.size.height / size.height
            
            // Flip Y for NSImage coordinate system
            let flippedY = size.height - rect.maxY  // Convert from top-left to bottom-left origin
            let sourceRect = NSRect(
                x: rect.origin.x * scaleX,
                y: flippedY * scaleY,
                width: rect.width * scaleX,
                height: rect.height * scaleY
            )
            
            // Use annotation's blur strength (lower = stronger pixelation)
            let pixelSize = Int(annotation.blurStrength)
            let tinySize = NSSize(width: pixelSize, height: pixelSize)
            let tinyImage = NSImage(size: tinySize)
            tinyImage.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .none
            originalImage.draw(in: NSRect(origin: .zero, size: tinySize),
                              from: sourceRect,
                              operation: .copy,
                              fraction: 1.0)
            tinyImage.unlockFocus()
            
            // Draw pixelated region using resolved image
            if let cgImage = tinyImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let nsImage = NSImage(cgImage: cgImage, size: rect.size)
                context.draw(Image(nsImage: nsImage), in: rect)
            }
            
        case .text:
            let scaledPoint = scalePoint(annotation.points[0], to: size)
            let fontName = annotation.font == "SF Pro" ? Font.system(size: annotation.strokeWidth * 8, weight: .semibold) : Font.custom(annotation.font, size: annotation.strokeWidth * 8)
            context.draw(Text(annotation.text).font(fontName).foregroundColor(color), at: scaledPoint, anchor: .topLeading)
        }
    }
    
    private func drawArrow(from start: CGPoint, to end: CGPoint, color: Color, strokeStyle: StrokeStyle, in context: GraphicsContext) {
        // Main line
        var linePath = Path()
        linePath.move(to: start)
        linePath.addLine(to: end)
        context.stroke(linePath, with: .color(color), style: strokeStyle)
        
        // Arrowhead
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 15 + strokeStyle.lineWidth * 2
        let arrowAngle: CGFloat = .pi / 6
        
        let point1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let point2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        var arrowPath = Path()
        arrowPath.move(to: point1)
        arrowPath.addLine(to: end)
        arrowPath.addLine(to: point2)
        context.stroke(arrowPath, with: .color(color), style: strokeStyle)
    }
    
    private func rectFromPoints(_ p1: CGPoint, _ p2: CGPoint, size: CGSize) -> CGRect {
        let s1 = scalePoint(p1, to: size)
        let s2 = scalePoint(p2, to: size)
        return CGRect(
            x: min(s1.x, s2.x),
            y: min(s1.y, s2.y),
            width: abs(s2.x - s1.x),
            height: abs(s2.y - s1.y)
        )
    }
    
    // Scale normalized 0-1 point to display coordinates
    private func scalePoint(_ point: CGPoint, to size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
}
