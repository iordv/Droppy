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
    case curvedArrow = "arrow.uturn.up"
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
        case .curvedArrow: return "Curved Arrow"
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
        case .curvedArrow: return "c"
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
    // Canvas min-dimension when annotation was created, used to preserve visual scale across render sizes.
    var referenceCanvasMinDimension: CGFloat = 0
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
    @State private var didApplyInitialZoom = false
    @State private var pinchStartZoomScale: CGFloat?
    @State private var didApplyInitialEditorColor = false
    
    // Font selection
    @State private var selectedFont: String = "SF Pro"
    private let availableFonts = ["SF Pro", "SF Mono", "Helvetica Neue", "Arial", "Georgia", "Menlo"]
    
    // Annotation moving
    @State private var selectedAnnotationIndex: Int? = nil
    @State private var isDraggingAnnotation = false
    @State private var draggedAnnotationInitialPoints: [CGPoint] = []
    
    private let colors: [Color] = [.red, .orange, .yellow, .green, .cyan, .purple, .black, .white]
    private let strokeWidths: [(CGFloat, String)] = [(2, "S"), (4, "M"), (6, "L")]
    
    // Transparent mode preference
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.elementCaptureEditorDefaultColor) private var defaultEditorColorToken = PreferenceDefault.elementCaptureEditorDefaultColor
    @AppStorage(AppPreferenceKey.elementCaptureEditorPrefer100Zoom) private var prefer100Zoom = PreferenceDefault.elementCaptureEditorPrefer100Zoom
    @AppStorage(AppPreferenceKey.elementCaptureEditorPinchZoomEnabled) private var pinchZoomEnabled = PreferenceDefault.elementCaptureEditorPinchZoomEnabled
    
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
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            guard pinchZoomEnabled else { return }
                            if pinchStartZoomScale == nil {
                                pinchStartZoomScale = zoomScale
                            }
                            guard let base = pinchStartZoomScale else { return }
                            zoomScale = clampedZoomScale(base * value)
                        }
                        .onEnded { _ in
                            pinchStartZoomScale = nil
                        }
                )
                .onAppear {
                    applyInitialZoomIfNeeded(fittedSize: fittedSize)
                    canvasSize = CGSize(
                        width: fittedSize.width * zoomScale,
                        height: fittedSize.height * zoomScale
                    )
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
            didApplyInitialEditorColor = false
            applyInitialEditorColorIfNeeded()
            updateCursor()
            didApplyInitialZoom = false
            pinchStartZoomScale = nil
        }
        .onDisappear {
            removeKeyboardMonitor()
            NSCursor.arrow.set()  // Reset cursor on close
        }
        .onChange(of: selectedTool) { _, _ in
            updateCursor()
            applyHighlighterDefaultColorIfNeeded()
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
                    case .curvedArrow: selectedTool = .curvedArrow; return nil
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
        case .arrow, .curvedArrow, .line, .rectangle, .ellipse, .freehand, .highlighter, .blur:
            NSCursor.crosshair.set()
        case .text:
            NSCursor.iBeam.set()
        }
    }

    private func clampedZoomScale(_ value: CGFloat) -> CGFloat {
        min(4.0, max(0.25, value))
    }

    private func applyInitialEditorColorIfNeeded() {
        guard !didApplyInitialEditorColor else { return }
        didApplyInitialEditorColor = true
        selectedColor = colorForToken(defaultEditorColorToken)
        applyHighlighterDefaultColorIfNeeded()
    }

    private func applyHighlighterDefaultColorIfNeeded() {
        if selectedTool == .highlighter {
            selectedColor = .yellow
        }
    }

    private func colorForToken(_ token: String) -> Color {
        switch token.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "cyan": return .cyan
        case "purple": return .purple
        case "black": return .black
        case "white": return .white
        default: return .red
        }
    }

    private func applyInitialZoomIfNeeded(fittedSize: CGSize) {
        guard !didApplyInitialZoom else { return }
        defer { didApplyInitialZoom = true }

        guard prefer100Zoom else {
            zoomScale = 1.0
            return
        }

        let safeImageWidth = max(originalImage.size.width, 1)
        let safeImageHeight = max(originalImage.size.height, 1)
        let safeFittedWidth = max(fittedSize.width, 1)
        let safeFittedHeight = max(fittedSize.height, 1)

        let nativeScaleWidth = safeImageWidth / safeFittedWidth
        let nativeScaleHeight = safeImageHeight / safeFittedHeight
        var targetScale = min(nativeScaleWidth, nativeScaleHeight)

        // Large captures are easier to edit when opened slightly below full native scale.
        if targetScale > 1.2 {
            targetScale *= 0.8
        }

        zoomScale = clampedZoomScale(targetScale)
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
                                .stroke(AdaptiveColors.overlayAuto(0.24), lineWidth: 0.8)
                        )
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
        
        // Check if we're dragging an existing annotation
        if isDraggingAnnotation, let index = selectedAnnotationIndex, index < annotations.count {
            // Move annotation by drag delta while keeping normalized points in bounds.
            let proposedDelta = CGPoint(
                x: normalizedPoint.x - normalizedStart.x,
                y: normalizedPoint.y - normalizedStart.y
            )
            annotations[index].points = translatePoints(
                draggedAnnotationInitialPoints,
                by: proposedDelta
            )
            return
        }
        
        // Check if clicking on existing annotation (to select for moving)
        if abs(value.translation.width) <= 1 && abs(value.translation.height) <= 1 {
            // This is the start of a drag - check for annotation under cursor
            let normalizedClickPoint = CGPoint(
                x: value.startLocation.x / containerSize.width,
                y: value.startLocation.y / containerSize.height
            )
            if let annotationIndex = findAnnotationAt(point: normalizedClickPoint, in: containerSize) {
                selectedAnnotationIndex = annotationIndex
                draggedAnnotationInitialPoints = annotations[annotationIndex].points
                isDraggingAnnotation = true
                return
            }
        }
        
        if selectedTool == .text {
            // Text tool just needs click position
            return
        }
        
        let isShiftHeld = NSEvent.modifierFlags.contains(.shift)

        if currentAnnotation == nil {
            // Start new annotation
            var annotation = Annotation(
                tool: selectedTool,
                color: selectedColor,
                strokeWidth: strokeWidth
            )
            annotation.referenceCanvasMinDimension = max(1, min(containerSize.width, containerSize.height))
            // Capture blur strength for blur tool
            if selectedTool == .blur {
                annotation.blurStrength = blurStrength
            }
            if isShiftHeld {
                let constrainedPoint = applyShiftConstraint(
                    from: normalizedStart,
                    to: normalizedPoint,
                    tool: selectedTool
                )
                annotation.points = [normalizedStart, constrainedPoint]
            } else {
                annotation.points = [normalizedStart, normalizedPoint]
            }
            currentAnnotation = annotation
        } else {
            // Update current annotation
            if (selectedTool == .freehand || selectedTool == .highlighter) && !isShiftHeld {
                currentAnnotation?.points.append(normalizedPoint)
            } else {
                // Shift-constrain applies across drawing tools.
                var constrainedPoint = normalizedPoint
                
                if isShiftHeld {
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
    
    /// Applies Shift-key constraints across drawing tools.
    /// - Line-like tools snap to 45° increments.
    /// - Shape tools constrain to equal width/height.
    private func applyShiftConstraint(from start: CGPoint, to end: CGPoint, tool: AnnotationTool) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        
        switch tool {
        case .arrow, .curvedArrow, .line, .freehand, .highlighter:
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
        // Reset drag state for annotation moving
        if isDraggingAnnotation {
            isDraggingAnnotation = false
            selectedAnnotationIndex = nil
            draggedAnnotationInitialPoints = []
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
            
            let shiftHeldAtEnd = NSEvent.modifierFlags.contains(.shift)
            let shouldFinalizeAsSegment =
                (selectedTool != .freehand && selectedTool != .highlighter) || shiftHeldAtEnd

            // Finalize line-like end points (including Shift-constrained freehand/highlighter).
            if shouldFinalizeAsSegment {
                var finalEnd = normalizedEnd
                if shiftHeldAtEnd {
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
        annotation.referenceCanvasMinDimension = max(1, min(canvasSize.width, canvasSize.height))
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
    
    /// Find any annotation at the given point, returning its index if found
    private func findAnnotationAt(point: CGPoint, in containerSize: CGSize) -> Int? {
        // Check in reverse order so top-most annotations are picked first.
        for (index, annotation) in annotations.enumerated().reversed() {
            if annotationContains(point: point, annotation: annotation, in: containerSize) {
                return index
            }
        }
        return nil
    }
    
    private func annotationContains(point: CGPoint, annotation: Annotation, in containerSize: CGSize) -> Bool {
        guard !annotation.points.isEmpty else { return false }
        
        let hitPoint = scaleNormalizedPoint(point, to: containerSize)
        let displayStrokeWidth = effectiveStrokeWidth(for: annotation, in: containerSize)
        let baseTolerance = max(10, displayStrokeWidth * 3)
        
        switch annotation.tool {
        case .arrow, .line:
            guard let endPoint = annotation.points.last else { return false }
            let start = scaleNormalizedPoint(annotation.points[0], to: containerSize)
            let end = scaleNormalizedPoint(endPoint, to: containerSize)
            return pointToSegmentDistance(hitPoint, start: start, end: end) <= baseTolerance
            
        case .curvedArrow:
            guard let endPoint = annotation.points.last else { return false }
            let start = scaleNormalizedPoint(annotation.points[0], to: containerSize)
            let end = scaleNormalizedPoint(endPoint, to: containerSize)
            return pointToCurvedArrowDistance(hitPoint, start: start, end: end) <= baseTolerance
            
        case .rectangle, .blur:
            guard let endPoint = annotation.points.last else { return false }
            let rect = rectFromNormalizedPoints(annotation.points[0], endPoint, in: containerSize)
            return rect.insetBy(dx: -baseTolerance, dy: -baseTolerance).contains(hitPoint)
            
        case .ellipse:
            guard let endPoint = annotation.points.last else { return false }
            let rect = rectFromNormalizedPoints(annotation.points[0], endPoint, in: containerSize)
            guard rect.width > 1, rect.height > 1 else { return false }
            let expandedRect = rect.insetBy(dx: -baseTolerance, dy: -baseTolerance)
            guard expandedRect.contains(hitPoint) else { return false }
            
            // Treat ellipse hit testing as inside-or-near-shape for easy grabbing.
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let rx = rect.width / 2
            let ry = rect.height / 2
            let nx = (hitPoint.x - center.x) / rx
            let ny = (hitPoint.y - center.y) / ry
            let normalizedDistance = (nx * nx) + (ny * ny)
            let toleranceScale = max(baseTolerance / max(min(rx, ry), 1), 0.2)
            return normalizedDistance <= (1.0 + toleranceScale)
            
        case .freehand, .highlighter:
            let points = annotation.points.map { scaleNormalizedPoint($0, to: containerSize) }
            guard points.count >= 2 else {
                guard let first = points.first else { return false }
                return hypot(hitPoint.x - first.x, hitPoint.y - first.y) <= baseTolerance
            }
            let lineTolerance = annotation.tool == .highlighter
                ? max(baseTolerance, displayStrokeWidth * 5)
                : baseTolerance
            for index in 1..<points.count {
                let start = points[index - 1]
                let end = points[index]
                if pointToSegmentDistance(hitPoint, start: start, end: end) <= lineTolerance {
                    return true
                }
            }
            return false
            
        case .text:
            let textRect = textBounds(for: annotation, in: containerSize)
            return textRect.insetBy(dx: -8, dy: -6).contains(hitPoint)
        }
    }
    
    private func translatePoints(_ points: [CGPoint], by proposedDelta: CGPoint) -> [CGPoint] {
        guard !points.isEmpty else { return points }
        
        var minX = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var minY = CGFloat.infinity
        var maxY = -CGFloat.infinity
        
        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        
        let clampedDeltaX = min(max(proposedDelta.x, -minX), 1 - maxX)
        let clampedDeltaY = min(max(proposedDelta.y, -minY), 1 - maxY)
        
        return points.map { point in
            CGPoint(
                x: point.x + clampedDeltaX,
                y: point.y + clampedDeltaY
            )
        }
    }
    
    private func scaleNormalizedPoint(_ point: CGPoint, to containerSize: CGSize) -> CGPoint {
        CGPoint(
            x: point.x * containerSize.width,
            y: point.y * containerSize.height
        )
    }
    
    private func rectFromNormalizedPoints(_ p1: CGPoint, _ p2: CGPoint, in containerSize: CGSize) -> CGRect {
        let s1 = scaleNormalizedPoint(p1, to: containerSize)
        let s2 = scaleNormalizedPoint(p2, to: containerSize)
        return CGRect(
            x: min(s1.x, s2.x),
            y: min(s1.y, s2.y),
            width: abs(s2.x - s1.x),
            height: abs(s2.y - s1.y)
        )
    }
    
    private func textBounds(for annotation: Annotation, in containerSize: CGSize) -> CGRect {
        guard let textOrigin = annotation.points.first else { return .zero }
        let scaledOrigin = scaleNormalizedPoint(textOrigin, to: containerSize)
        let displayStrokeWidth = effectiveStrokeWidth(for: annotation, in: containerSize)
        
        // Approximate dimensions to keep hit testing lightweight.
        let textWidth = max(60, CGFloat(annotation.text.count) * displayStrokeWidth * 5)
        let textHeight = max(16, displayStrokeWidth * 12)
        
        return CGRect(
            x: scaledOrigin.x,
            y: scaledOrigin.y,
            width: textWidth,
            height: textHeight
        )
    }
    
    private func pointToSegmentDistance(_ point: CGPoint, start: CGPoint, end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        
        guard dx != 0 || dy != 0 else {
            return hypot(point.x - start.x, point.y - start.y)
        }
        
        let t = ((point.x - start.x) * dx + (point.y - start.y) * dy) / (dx * dx + dy * dy)
        let clampedT = min(max(t, 0), 1)
        
        let projection = CGPoint(
            x: start.x + clampedT * dx,
            y: start.y + clampedT * dy
        )
        return hypot(point.x - projection.x, point.y - projection.y)
    }
    
    private func pointToCurvedArrowDistance(_ point: CGPoint, start: CGPoint, end: CGPoint) -> CGFloat {
        let sampledPoints = sampledCurvedArrowPoints(from: start, to: end)
        guard sampledPoints.count >= 2 else { return .greatestFiniteMagnitude }
        
        var minDistance = CGFloat.greatestFiniteMagnitude
        for idx in 1..<sampledPoints.count {
            let segmentDistance = pointToSegmentDistance(
                point,
                start: sampledPoints[idx - 1],
                end: sampledPoints[idx]
            )
            minDistance = min(minDistance, segmentDistance)
        }
        
        return minDistance
    }
    
    private func sampledCurvedArrowPoints(from start: CGPoint, to end: CGPoint, segments: Int = 20) -> [CGPoint] {
        let control = curvedArrowControlPoint(from: start, to: end)
        let clampedSegments = max(2, segments)

        var points: [CGPoint] = []
        points.reserveCapacity(clampedSegments + 1)

        for index in 0...clampedSegments {
            let t = CGFloat(index) / CGFloat(clampedSegments)
            let oneMinusT = 1 - t
            let startWeight = oneMinusT * oneMinusT
            let controlWeight = 2 * oneMinusT * t
            let endWeight = t * t

            let x = (startWeight * start.x) + (controlWeight * control.x) + (endWeight * end.x)
            let y = (startWeight * start.y) + (controlWeight * control.y) + (endWeight * end.y)
            points.append(CGPoint(x: x, y: y))
        }

        return points
    }

    private func effectiveStrokeWidth(for annotation: Annotation, in containerSize: CGSize) -> CGFloat {
        let referenceMinDimension = annotation.referenceCanvasMinDimension
        guard referenceMinDimension > 1 else { return annotation.strokeWidth }

        let targetMinDimension = max(1, min(containerSize.width, containerSize.height))
        return annotation.strokeWidth * (targetMinDimension / referenceMinDimension)
    }
    
    private func curvedArrowControlPoint(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        guard distance > 0.001 else {
            return CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        }
        
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let normal = CGPoint(x: -dy / distance, y: dx / distance)
        let curveAmount = min(max(distance * 0.28, 20), 120)
        
        return CGPoint(
            x: mid.x + normal.x * curveAmount,
            y: mid.y + normal.y * curveAmount
        )
    }
    
    private func saveAnnotatedImage() {
        let annotatedImage = renderAnnotatedImage()
        onSave(annotatedImage)
    }
    
    // MARK: - Rendering
    
    private func renderAnnotatedImage() -> NSImage {
        let renderSize = editorRenderSize(fallback: .zero)
        
        if let renderedImage = renderRenderedViewImage(renderSize: renderSize) {
            return renderedImage
        }
        
        guard let bitmap = renderAnnotatedBitmap() else {
            return originalImage
        }
        
        let image = NSImage(size: bitmap.size)
        image.addRepresentation(bitmap)
        return image
    }
    
    private func renderAnnotatedPNGData() -> Data? {
        let renderSize = editorRenderSize(fallback: .zero)
        
        if let renderedImage = renderRenderedViewImage(renderSize: renderSize),
           let tiffData = renderedImage.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData) {
            return bitmapRep.representation(using: .png, properties: [:])
        }
        
        guard let bitmap = renderAnnotatedBitmap() else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
    
    private func renderRenderedViewImage(renderSize: NSSize) -> NSImage? {
        guard renderSize.width > 0, renderSize.height > 0 else { return nil }
        
        let exportView = ZStack {
            Image(nsImage: originalImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: renderSize.width, height: renderSize.height)
            
            AnnotationCanvas(
                annotations: annotations,
                currentAnnotation: currentAnnotation,
                originalImage: originalImage,
                imageSize: renderSize,
                containerSize: renderSize
            )
            .frame(width: renderSize.width, height: renderSize.height)
        }
        .frame(width: renderSize.width, height: renderSize.height)

        // Primary path: offscreen AppKit snapshot for WYSIWYG parity with on-screen SwiftUI rendering.
        let hosting = NSHostingView(rootView: exportView)
        hosting.frame = NSRect(origin: .zero, size: renderSize)
        hosting.layoutSubtreeIfNeeded()
        
        if let bitmapRep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
            bitmapRep.size = renderSize
            hosting.cacheDisplay(in: hosting.bounds, to: bitmapRep)
            let image = NSImage(size: renderSize)
            image.addRepresentation(bitmapRep)
            return image
        }

        // Fallback: ImageRenderer.
        let renderer = ImageRenderer(content: exportView)
        renderer.proposedSize = ProposedViewSize(width: renderSize.width, height: renderSize.height)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return renderer.nsImage
    }
    
    private func renderAnnotatedBitmap() -> NSBitmapImageRep? {
        let source = resolvedSourceImage()
        let renderSize = editorRenderSize(fallback: source.size)
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
        
        // Keep point-size metadata aligned with the actual rendered pixel buffer.
        bitmap.size = renderSize
        
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        
        let renderRect = NSRect(origin: .zero, size: renderSize)
        
        // Draw exactly the same NSImage source used by the editor preview.
        originalImage.draw(in: renderRect, from: .zero, operation: .copy, fraction: 1.0)
        
        // Freeze the exact rendered base image for blur sampling so annotation sampling
        // always uses the same coordinate space as the export bitmap.
        let sourceImageForSampling: NSImage? = {
            guard let snapshotRep = bitmap.copy() as? NSBitmapImageRep else { return nil }
            let snapshot = NSImage(size: renderSize)
            snapshot.addRepresentation(snapshotRep)
            return snapshot
        }()
        
        // Draw annotations on top in the same pixel coordinate space.
        for annotation in annotations {
            drawAnnotation(annotation, in: renderSize, sourceImage: sourceImageForSampling)
        }
        
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }
    
    private func editorRenderSize(fallback: NSSize) -> NSSize {
        // Keep export geometry on the same coordinate basis used by the on-screen editor.
        if originalImage.size.width > 0, originalImage.size.height > 0 {
            return originalImage.size
        }
        if fallback.width > 0, fallback.height > 0 {
            return fallback
        }
        return NSSize(width: 1, height: 1)
    }
    
    private func resolvedSourceImage() -> (cgImage: CGImage?, size: NSSize) {
        // Prefer AppKit's currently resolved CGImage first. This is usually the exact
        // visible representation and avoids selecting stale/cropped cached reps.
        if let cgImage = originalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return (cgImage, NSSize(width: cgImage.width, height: cgImage.height))
        }
        
        let expectedAspect: CGFloat? = {
            guard originalImage.size.width > 0, originalImage.size.height > 0 else { return nil }
            return originalImage.size.width / originalImage.size.height
        }()
        
        typealias Candidate = (cgImage: CGImage?, width: Int, height: Int, aspectDelta: CGFloat)
        var candidates: [Candidate] = []
        
        for representation in originalImage.representations {
            let width: Int
            let height: Int
            let cgImage: CGImage?
            
            if let bitmapRep = representation as? NSBitmapImageRep {
                width = max(bitmapRep.pixelsWide, Int(bitmapRep.size.width.rounded(.up)))
                height = max(bitmapRep.pixelsHigh, Int(bitmapRep.size.height.rounded(.up)))
                cgImage = bitmapRep.cgImage
            } else if let ciRep = representation as? NSCIImageRep {
                width = max(representation.pixelsWide, Int(representation.size.width.rounded(.up)))
                height = max(representation.pixelsHigh, Int(representation.size.height.rounded(.up)))
                cgImage = CIContext().createCGImage(ciRep.ciImage, from: ciRep.ciImage.extent)
            } else {
                width = max(representation.pixelsWide, Int(representation.size.width.rounded(.up)))
                height = max(representation.pixelsHigh, Int(representation.size.height.rounded(.up)))
                cgImage = nil
            }
            
            guard width > 0, height > 0 else { continue }
            
            let aspect = CGFloat(width) / CGFloat(height)
            let aspectDelta: CGFloat = {
                guard let expectedAspect, expectedAspect > 0 else { return 0 }
                return abs(aspect - expectedAspect) / expectedAspect
            }()
            
            candidates.append((cgImage: cgImage, width: width, height: height, aspectDelta: aspectDelta))
        }
        
        let isLessPreferred: (Candidate, Candidate) -> Bool = { lhs, rhs in
            // Prefer closest aspect first to prevent wrong cropped reps.
            let aspectSlack: CGFloat = 0.001
            if abs(lhs.aspectDelta - rhs.aspectDelta) > aspectSlack {
                return lhs.aspectDelta > rhs.aspectDelta
            }
            
            // Prefer candidates that have a concrete CGImage backing.
            if (lhs.cgImage != nil) != (rhs.cgImage != nil) {
                return lhs.cgImage == nil
            }
            
            // Then pick the highest resolution.
            let lhsArea = Int64(lhs.width) * Int64(lhs.height)
            let rhsArea = Int64(rhs.width) * Int64(rhs.height)
            return lhsArea < rhsArea
        }
        
        let bestAspectMatch = candidates
            .filter { $0.aspectDelta <= 0.03 }
            .max(by: isLessPreferred)
        let bestClosest = candidates.max(by: isLessPreferred)
        
        if let candidate = bestAspectMatch ?? bestClosest {
            return (candidate.cgImage, NSSize(width: candidate.width, height: candidate.height))
        }
        
        if let bitmapRep = originalImage.representations
            .compactMap({ $0 as? NSBitmapImageRep })
            .max(by: { ($0.pixelsWide * $0.pixelsHigh) < ($1.pixelsWide * $1.pixelsHigh) }) {
            return (nil, NSSize(width: bitmapRep.pixelsWide, height: bitmapRep.pixelsHigh))
        }
        
        let fallbackSize = NSSize(
            width: max(1, originalImage.size.width.rounded(.up)),
            height: max(1, originalImage.size.height.rounded(.up))
        )
        return (nil, fallbackSize)
    }
    
    private func drawAnnotation(_ annotation: Annotation, in size: NSSize, sourceImage: NSImage?) {
        guard !annotation.points.isEmpty else { return }
        
        let nsColor = NSColor(annotation.color)
        nsColor.setStroke()
        nsColor.setFill()
        let effectiveStrokeWidth = effectiveStrokeWidth(
            for: annotation,
            in: CGSize(width: size.width, height: size.height)
        )
        
        switch annotation.tool {
        case .arrow:
            drawArrow(from: annotation.points[0], to: annotation.points.last ?? annotation.points[0], strokeWidth: effectiveStrokeWidth, in: size)
            
        case .curvedArrow:
            drawCurvedArrow(from: annotation.points[0], to: annotation.points.last ?? annotation.points[0], strokeWidth: effectiveStrokeWidth, in: size)
            
        case .line:
            // Simple straight line (no arrowhead)
            let path = NSBezierPath()
            path.lineWidth = effectiveStrokeWidth
            path.lineCapStyle = .round
            path.move(to: scalePoint(annotation.points[0], to: size))
            path.line(to: scalePoint(annotation.points.last ?? annotation.points[0], to: size))
            path.stroke()
            
        case .rectangle:
            let rect = rectFromPoints(annotation.points[0], annotation.points.last ?? annotation.points[0], in: size)
            let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
            path.lineWidth = effectiveStrokeWidth
            path.stroke()
            
        case .ellipse:
            let rect = rectFromPoints(annotation.points[0], annotation.points.last ?? annotation.points[0], in: size)
            let path = NSBezierPath(ovalIn: rect)
            path.lineWidth = effectiveStrokeWidth
            path.stroke()
            
        case .freehand:
            let path = NSBezierPath()
            path.lineWidth = effectiveStrokeWidth
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
            path.lineWidth = effectiveStrokeWidth * 4 // Wider for highlighter effect
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
            let blurSourceImage = sourceImage ?? originalImage
            
            // Scale blur block size with render scale to match editor preview proportions.
            let blurScale = effectiveStrokeWidth / max(annotation.strokeWidth, 0.001)
            let pixelSize = max(1, Int((annotation.blurStrength * blurScale).rounded()))
            let tinySize = NSSize(width: pixelSize, height: pixelSize)
            let tinyImage = NSImage(size: tinySize)
            tinyImage.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .none
            blurSourceImage.draw(
                in: NSRect(origin: .zero, size: tinySize),
                from: rect,  // rect is already in image coordinates
                operation: .copy,
                fraction: 1.0
            )
            tinyImage.unlockFocus()
            
            // Draw the tiny image scaled back up (creates pixelation)
            NSGraphicsContext.current?.imageInterpolation = .none
            tinyImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
            
        case .text:
            let scaledPoint = scalePoint(annotation.points[0], to: size)
            // Get the correct font
            let fontName = annotation.font == "SF Pro" ? ".AppleSystemUIFont" : annotation.font
            let font = NSFont(name: fontName, size: effectiveStrokeWidth * 8) ?? NSFont.systemFont(ofSize: effectiveStrokeWidth * 8, weight: .semibold)
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
    
    private func drawCurvedArrow(from start: CGPoint, to end: CGPoint, strokeWidth: CGFloat, in size: NSSize) {
        let scaledStart = scalePoint(start, to: size)
        let scaledEnd = scalePoint(end, to: size)
        let control = curvedArrowControlPoint(from: scaledStart, to: scaledEnd)
        
        let cubicControl1 = CGPoint(
            x: scaledStart.x + (2.0 / 3.0) * (control.x - scaledStart.x),
            y: scaledStart.y + (2.0 / 3.0) * (control.y - scaledStart.y)
        )
        let cubicControl2 = CGPoint(
            x: scaledEnd.x + (2.0 / 3.0) * (control.x - scaledEnd.x),
            y: scaledEnd.y + (2.0 / 3.0) * (control.y - scaledEnd.y)
        )
        
        let path = NSBezierPath()
        path.lineWidth = strokeWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: scaledStart)
        path.curve(to: scaledEnd, controlPoint1: cubicControl1, controlPoint2: cubicControl2)
        path.stroke()
        
        let tangent = CGPoint(
            x: scaledEnd.x - control.x,
            y: scaledEnd.y - control.y
        )
        let fallback = CGPoint(
            x: scaledEnd.x - scaledStart.x,
            y: scaledEnd.y - scaledStart.y
        )
        let headVector = hypot(tangent.x, tangent.y) > 0.001 ? tangent : fallback
        let angle = atan2(headVector.y, headVector.x)
        
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
        let effectiveStrokeWidth = effectiveStrokeWidth(for: annotation, in: size)
        let strokeStyle = StrokeStyle(lineWidth: effectiveStrokeWidth, lineCap: .round, lineJoin: .round)
        
        switch annotation.tool {
        case .arrow:
            let start = scalePoint(annotation.points[0], to: size)
            let end = scalePoint(annotation.points.last ?? annotation.points[0], to: size)
            drawArrow(from: start, to: end, color: color, strokeStyle: strokeStyle, in: context)
            
        case .curvedArrow:
            let start = scalePoint(annotation.points[0], to: size)
            let end = scalePoint(annotation.points.last ?? annotation.points[0], to: size)
            drawCurvedArrow(from: start, to: end, color: color, strokeStyle: strokeStyle, in: context)
            
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
            let highlightStyle = StrokeStyle(lineWidth: effectiveStrokeWidth * 4, lineCap: .round, lineJoin: .round)
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
            
            // Scale blur block size with render scale to match editor preview proportions.
            let blurScale = effectiveStrokeWidth / max(annotation.strokeWidth, 0.001)
            let pixelSize = max(1, Int((annotation.blurStrength * blurScale).rounded()))
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
            let fontName = annotation.font == "SF Pro"
                ? Font.system(size: effectiveStrokeWidth * 8, weight: .semibold)
                : Font.custom(annotation.font, size: effectiveStrokeWidth * 8)
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
    
    private func drawCurvedArrow(from start: CGPoint, to end: CGPoint, color: Color, strokeStyle: StrokeStyle, in context: GraphicsContext) {
        let control = curvedArrowControlPoint(from: start, to: end)
        
        var curvePath = Path()
        curvePath.move(to: start)
        curvePath.addQuadCurve(to: end, control: control)
        context.stroke(curvePath, with: .color(color), style: strokeStyle)
        
        let tangent = CGPoint(
            x: end.x - control.x,
            y: end.y - control.y
        )
        let fallback = CGPoint(
            x: end.x - start.x,
            y: end.y - start.y
        )
        let headVector = hypot(tangent.x, tangent.y) > 0.001 ? tangent : fallback
        let angle = atan2(headVector.y, headVector.x)
        
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

    private func effectiveStrokeWidth(for annotation: Annotation, in size: CGSize) -> CGFloat {
        let referenceMinDimension = annotation.referenceCanvasMinDimension
        guard referenceMinDimension > 1 else { return annotation.strokeWidth }

        let targetMinDimension = max(1, min(size.width, size.height))
        return annotation.strokeWidth * (targetMinDimension / referenceMinDimension)
    }
    
    private func curvedArrowControlPoint(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        guard distance > 0.001 else {
            return CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        }
        
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let normal = CGPoint(x: -dy / distance, y: dx / distance)
        let curveAmount = min(max(distance * 0.28, 20), 120)
        
        return CGPoint(
            x: mid.x + normal.x * curveAmount,
            y: mid.y + normal.y * curveAmount
        )
    }
}
