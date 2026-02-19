//
//  ScreenshotEditorView.swift
//  Droppy
//
//  Screenshot annotation editor with arrows, shapes, blur, magnifier, text, and sticker tools
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Annotation Model

enum AnnotationTool: String, CaseIterable, Identifiable {
    case arrow
    case curvedArrow
    case line
    case rectangle
    case ellipse
    case freehand
    case highlighter
    case blur
    case magnifier
    case imageOverlay
    case text
    case cursorSticker
    case pointerSticker
    case cursorStickerCircled
    case pointerStickerCircled
    case typingIndicatorSticker
    case numberSticker
    
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
        case .magnifier: return "Magnifier"
        case .imageOverlay: return "Photo-in-Photo"
        case .text: return "Text"
        case .cursorSticker: return "Cursor Sticker"
        case .pointerSticker: return "Pointer Sticker"
        case .cursorStickerCircled: return "Cursor Sticker (Circle)"
        case .pointerStickerCircled: return "Pointer Sticker (Circle)"
        case .typingIndicatorSticker: return "Typing Indicator"
        case .numberSticker: return "Number Sticker"
        }
    }

    var symbolName: String {
        switch self {
        case .arrow: return "arrow.up.forward"
        case .curvedArrow: return "arrow.uturn.up"
        case .line: return "line.diagonal"
        case .rectangle: return "rectangle"
        case .ellipse: return "oval"
        case .freehand: return "scribble"
        case .highlighter: return "highlighter"
        case .blur: return "eye.slash"
        case .magnifier: return "magnifyingglass.circle"
        case .imageOverlay: return "plus.rectangle.on.rectangle"
        case .text: return "textformat"
        case .cursorSticker, .cursorStickerCircled: return "cursorarrow"
        case .pointerSticker, .pointerStickerCircled: return "hand.point.up.left.fill"
        case .typingIndicatorSticker: return "ibeam"
        case .numberSticker: return "number.circle.fill"
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
        case .magnifier: return "m"
        case .imageOverlay: return "g"
        case .text: return "t"
        case .cursorSticker: return "u"
        case .pointerSticker: return "p"
        case .cursorStickerCircled: return "i"
        case .pointerStickerCircled: return "k"
        case .typingIndicatorSticker: return "y"
        case .numberSticker: return "n"
        }
    }
    
    /// Tooltip with shortcut hint
    var tooltipWithShortcut: String {
        "\(displayName) (\(defaultShortcut.uppercased()))"
    }

    var isSticker: Bool {
        switch self {
        case .cursorSticker, .pointerSticker, .cursorStickerCircled, .pointerStickerCircled, .typingIndicatorSticker, .numberSticker:
            return true
        default:
            return false
        }
    }

    var showsStickerCircle: Bool {
        switch self {
        case .cursorStickerCircled, .pointerStickerCircled:
            return true
        default:
            return false
        }
    }

    var isNativeCursorSticker: Bool {
        switch self {
        case .cursorSticker, .pointerSticker, .cursorStickerCircled, .pointerStickerCircled:
            return true
        default:
            return false
        }
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
    // Magnifier radius stored at reference canvas scale; converted at render time.
    var magnifierRadius: CGFloat = 0
    // Signed perpendicular curve offset for arrow tools, stored at reference canvas scale.
    var curveOffset: CGFloat = 0
    // 2D control-point offset from arrow midpoint, stored at reference canvas scale.
    var curveControlOffset: CGSize = .zero
    var hasCustomCurveControl: Bool = false
    // Image overlay source and corner style.
    var imagePath: String = ""
    var imageCornerRadius: CGFloat = 0
    // Canvas min-dimension when annotation was created, used to preserve visual scale across render sizes.
    var referenceCanvasMinDimension: CGFloat = 0
}

private enum MagnifierConfiguration {
    static let baseMagnification: CGFloat = 2.0
    static let maxMagnification: CGFloat = 6.0
    static let zoomBoostRadiusScale: CGFloat = 2.8
}

private func defaultMagnifierRadius(forStrokeWidth strokeWidth: CGFloat) -> CGFloat {
    max(34, strokeWidth * 10.5)
}

private func magnifierDisplayRadius(
    for annotation: Annotation,
    displayStrokeWidth: CGFloat,
    containerMinDimension: CGFloat
) -> CGFloat {
    let fallback = defaultMagnifierRadius(forStrokeWidth: displayStrokeWidth)
    guard annotation.magnifierRadius > 0 else { return fallback }
    guard annotation.referenceCanvasMinDimension > 1, containerMinDimension > 1 else { return fallback }
    return annotation.magnifierRadius * (containerMinDimension / annotation.referenceCanvasMinDimension)
}

private func magnifierStoredRadius(
    fromDisplayRadius displayRadius: CGFloat,
    annotation: Annotation,
    containerMinDimension: CGFloat
) -> CGFloat {
    guard annotation.referenceCanvasMinDimension > 1, containerMinDimension > 1 else { return displayRadius }
    return displayRadius * (annotation.referenceCanvasMinDimension / containerMinDimension)
}

private func magnifierMagnification(for lensRadius: CGFloat, defaultRadius: CGFloat) -> CGFloat {
    guard defaultRadius > 0 else { return MagnifierConfiguration.baseMagnification }
    let normalized = max(0.4, lensRadius / defaultRadius)
    let progress = min(max((normalized - 1.0) / (MagnifierConfiguration.zoomBoostRadiusScale - 1.0), 0), 1)
    return MagnifierConfiguration.baseMagnification
        + progress * (MagnifierConfiguration.maxMagnification - MagnifierConfiguration.baseMagnification)
}

private enum ScreenshotBackgroundPreset: String, CaseIterable, Identifiable {
    case midnight
    case twilight
    case ocean
    case ember
    case mint
    case graphite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .midnight: return "Midnight"
        case .twilight: return "Twilight"
        case .ocean: return "Ocean"
        case .ember: return "Ember"
        case .mint: return "Mint"
        case .graphite: return "Graphite"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .midnight:
            return LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.09, blue: 0.16),
                    Color(red: 0.09, green: 0.16, blue: 0.25),
                    Color(red: 0.18, green: 0.10, blue: 0.24)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .twilight:
            return LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.08, blue: 0.26),
                    Color(red: 0.32, green: 0.16, blue: 0.44),
                    Color(red: 0.74, green: 0.30, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .ocean:
            return LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.20, blue: 0.30),
                    Color(red: 0.08, green: 0.36, blue: 0.55),
                    Color(red: 0.17, green: 0.54, blue: 0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .ember:
            return LinearGradient(
                colors: [
                    Color(red: 0.25, green: 0.06, blue: 0.08),
                    Color(red: 0.49, green: 0.13, blue: 0.10),
                    Color(red: 0.84, green: 0.38, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .mint:
            return LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.23, blue: 0.20),
                    Color(red: 0.10, green: 0.38, blue: 0.33),
                    Color(red: 0.36, green: 0.70, blue: 0.52)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .graphite:
            return LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.09, blue: 0.10),
                    Color(red: 0.15, green: 0.15, blue: 0.18),
                    Color(red: 0.23, green: 0.23, blue: 0.26)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private enum ScreenshotBackgroundSource: String, CaseIterable, Identifiable {
    case gradient
    case currentWallpaper
    case customWallpaper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gradient: return "Gradient"
        case .currentWallpaper: return "Wallpaper"
        case .customWallpaper: return "Custom"
        }
    }
}

private struct StickerLayout {
    let symbolRect: CGRect
    let circleRect: CGRect?
    
    var bounds: CGRect {
        if let circleRect {
            return symbolRect.union(circleRect)
        }
        return symbolRect
    }
}

private enum StickerToolRenderer {
    private static let preparedImageCache = NSCache<NSString, NSImage>()

    static func symbolCandidates(for tool: AnnotationTool) -> [String] {
        switch tool {
        case .cursorSticker, .cursorStickerCircled:
            return ["cursorarrow", "arrow.up.left", "arrowtriangle.up.fill"]
        case .pointerSticker, .pointerStickerCircled:
            return ["hand.point.up.left.fill", "hand.point.up.left", "hand.tap"]
        case .typingIndicatorSticker:
            return ["ibeam", "text.cursor", "textformat"]
        case .numberSticker:
            return ["number.circle.fill", "number.circle"]
        default:
            return []
        }
    }

    static func nativeCursorImage(for tool: AnnotationTool) -> NSImage? {
        switch tool {
        case .cursorSticker, .cursorStickerCircled:
            return NSCursor.arrow.image
        case .pointerSticker, .pointerStickerCircled:
            return NSCursor.pointingHand.image
        default:
            return nil
        }
    }
    
    static func layout(for tool: AnnotationTool, anchor: CGPoint, displayStrokeWidth: CGFloat) -> StickerLayout? {
        guard tool.isSticker else { return nil }
        
        let base = max(18, displayStrokeWidth * 7)
        let symbolRect: CGRect
        switch tool {
        case .typingIndicatorSticker:
            let width = base * 0.38
            let height = base * 1.08
            symbolRect = CGRect(
                x: anchor.x - width / 2,
                y: anchor.y - height / 2,
                width: width,
                height: height
            )
        case .numberSticker:
            let diameter = base * 1.45
            symbolRect = CGRect(
                x: anchor.x - diameter / 2,
                y: anchor.y - diameter / 2,
                width: diameter,
                height: diameter
            )
        default:
            symbolRect = CGRect(
                x: anchor.x - base / 2,
                y: anchor.y - base / 2,
                width: base,
                height: base
            )
        }
        
        let circleRect: CGRect? = {
            guard tool.showsStickerCircle else { return nil }
            let diameter = base * 1.65
            return CGRect(
                x: anchor.x - diameter / 2,
                y: anchor.y - diameter / 2,
                width: diameter,
                height: diameter
            )
        }()
        
        return StickerLayout(symbolRect: symbolRect, circleRect: circleRect)
    }

    static func resolvedSymbolName(for tool: AnnotationTool) -> String? {
        for candidate in symbolCandidates(for: tool) {
            if NSImage(systemSymbolName: candidate, accessibilityDescription: nil) != nil {
                return candidate
            }
        }
        return nil
    }

    static func stickerImage(
        for tool: AnnotationTool,
        pointSize: CGFloat,
        tintColor: NSColor? = nil,
        outlineColor: NSColor? = nil
    ) -> NSImage? {
        if tool == .typingIndicatorSticker {
            let resolvedColor = tintColor ?? .black
            let cacheKey = "typing:\(Int(pointSize.rounded())):\(cacheColorKey(resolvedColor))" as NSString
            if let cachedImage = preparedImageCache.object(forKey: cacheKey) {
                return cachedImage
            }

            let image = typingIndicatorImage(pointSize: pointSize, color: resolvedColor)
            preparedImageCache.setObject(image, forKey: cacheKey)
            return image
        }

        if let nativeImage = nativeCursorImage(for: tool) {
            let cacheKey = "native:\(tool.rawValue):\(cacheColorKey(tintColor)):\(cacheColorKey(outlineColor))" as NSString
            if let cachedImage = preparedImageCache.object(forKey: cacheKey) {
                return cachedImage
            }

            let trimmedImage = alphaTrimmedImage(from: nativeImage) ?? nativeImage
            let output: NSImage
            if let tintColor {
                let resolvedOutline = outlineColor ?? contrastingOutlineColor(for: tintColor)
                output = outlinedMonochromeImage(
                    from: trimmedImage,
                    fillColor: tintColor,
                    outlineColor: resolvedOutline
                )
            } else {
                output = trimmedImage
            }
            preparedImageCache.setObject(output, forKey: cacheKey)
            return output
        }

        return symbolImage(for: tool, pointSize: pointSize, tintColor: tintColor)
    }

    static func fittedRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else {
            return bounds
        }

        let imageAspect = imageSize.width / imageSize.height
        let boundsAspect = bounds.width / bounds.height

        if imageAspect > boundsAspect {
            let height = bounds.width / imageAspect
            return CGRect(
                x: bounds.minX,
                y: bounds.midY - height / 2,
                width: bounds.width,
                height: height
            )
        } else {
            let width = bounds.height * imageAspect
            return CGRect(
                x: bounds.midX - width / 2,
                y: bounds.minY,
                width: width,
                height: bounds.height
            )
        }
    }

    private static func symbolImage(for tool: AnnotationTool, pointSize: CGFloat, tintColor: NSColor?) -> NSImage? {
        guard let symbolName = resolvedSymbolName(for: tool) else { return nil }
        let configuration = NSImage.SymbolConfiguration(pointSize: max(10, pointSize), weight: .bold)
        guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        else {
            return nil
        }

        if let tintColor {
            return monochromeImage(from: image, color: tintColor)
        }
        return image
    }

    private static func cacheColorKey(_ color: NSColor?) -> String {
        guard let color else { return "none" }
        let calibrated = color.usingColorSpace(.sRGB) ?? color
        return String(
            format: "%.3f-%.3f-%.3f-%.3f",
            calibrated.redComponent,
            calibrated.greenComponent,
            calibrated.blueComponent,
            calibrated.alphaComponent
        )
    }

    private static func contrastingOutlineColor(for fillColor: NSColor) -> NSColor {
        let color = fillColor.usingColorSpace(.sRGB) ?? fillColor
        let luminance = (0.2126 * color.redComponent) + (0.7152 * color.greenComponent) + (0.0722 * color.blueComponent)
        return luminance >= 0.58 ? .black : .white
    }

    private static func typingIndicatorImage(pointSize: CGFloat, color: NSColor) -> NSImage {
        let height = max(12, pointSize * 1.06)
        let width = max(4, pointSize * 0.42)
        let imageSize = NSSize(width: width, height: height)
        let image = NSImage(size: imageSize)
        image.lockFocus()

        color.setStroke()
        let path = NSBezierPath()
        path.lineWidth = max(1.6, width * 0.25)
        path.lineCapStyle = .round

        let inset = path.lineWidth / 2
        let minX = inset
        let maxX = imageSize.width - inset
        let midX = imageSize.width / 2
        let minY = inset
        let maxY = imageSize.height - inset

        path.move(to: CGPoint(x: midX, y: minY))
        path.line(to: CGPoint(x: midX, y: maxY))
        path.move(to: CGPoint(x: minX, y: minY))
        path.line(to: CGPoint(x: maxX, y: minY))
        path.move(to: CGPoint(x: minX, y: maxY))
        path.line(to: CGPoint(x: maxX, y: maxY))
        path.stroke()

        image.unlockFocus()
        return image
    }

    private static func outlinedMonochromeImage(
        from image: NSImage,
        fillColor: NSColor,
        outlineColor: NSColor
    ) -> NSImage {
        let outlineWidth = max(1.0, min(image.size.width, image.size.height) * 0.08)
        let inset = ceil(outlineWidth) + 1
        let outputSize = NSSize(
            width: image.size.width + (inset * 2),
            height: image.size.height + (inset * 2)
        )

        let output = NSImage(size: outputSize)
        let outlinedSourceRect = NSRect(x: inset, y: inset, width: image.size.width, height: image.size.height)
        let fillImage = monochromeImage(from: image, color: fillColor)
        let outlineImage = monochromeImage(from: image, color: outlineColor)

        output.lockFocus()
        for xStep in -Int(inset)...Int(inset) {
            for yStep in -Int(inset)...Int(inset) {
                let distance = hypot(CGFloat(xStep), CGFloat(yStep))
                if distance > outlineWidth { continue }
                outlineImage.draw(
                    in: outlinedSourceRect.offsetBy(dx: CGFloat(xStep), dy: CGFloat(yStep)),
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1.0
                )
            }
        }

        fillImage.draw(
            in: outlinedSourceRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )
        output.unlockFocus()
        return output
    }

    private static func alphaTrimmedImage(from image: NSImage) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let pixelBytes = CFDataGetBytePtr(data)
        else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = max(1, cgImage.bitsPerPixel / 8)

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            let row = pixelBytes + (y * bytesPerRow)
            for x in 0..<width {
                let alphaIndex = x * bytesPerPixel + min(3, bytesPerPixel - 1)
                let alpha = Int(row[alphaIndex])
                if alpha > 8 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }

        let cropRect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )
        guard let croppedImage = cgImage.cropping(to: cropRect) else { return nil }
        return NSImage(cgImage: croppedImage, size: NSSize(width: cropRect.width, height: cropRect.height))
    }

    private static func monochromeImage(from image: NSImage, color: NSColor) -> NSImage {
        let output = NSImage(size: image.size)
        output.lockFocus()
        let bounds = NSRect(origin: .zero, size: image.size)
        color.setFill()
        bounds.fill()
        image.draw(in: bounds, from: .zero, operation: .destinationIn, fraction: 1.0)
        output.unlockFocus()
        return output
    }
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
    @State private var showingCanvasStylePopover = false
    @State private var showingStickerPickerPopover = false
    @State private var isHoveringStickerPicker = false
    @State private var isHoveringStickerPopover = false
    @State private var showingColorPickerPopover = false
    @State private var isHoveringColorPicker = false
    @State private var isHoveringColorPopover = false
    @State private var showingStrokePickerPopover = false
    @State private var isHoveringStrokePicker = false
    @State private var isHoveringStrokePopover = false
    @State private var showingImageOverlayOptionsPopover = false
    @State private var editorViewportSize: CGSize = .zero
    @State private var editorFittedImageSize: CGSize = .zero
    @State private var wallpaperBackgroundImage: NSImage?
    @State private var customBackgroundImage: NSImage?
    @State private var imageOverlaySelectedPath: String = ""
    @State private var imageOverlayUseRoundedCorners = true
    @State private var imageOverlayPreviewCache: [String: NSImage] = [:]
    @State private var imageOverlayLoadingPaths: Set<String> = []
    
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
    @State private var pendingNumberStickerID: UUID?
    @State private var annotationDragMode: AnnotationDragMode = .translate
    
    // Cropping
    @State private var isCropMode = false
    @State private var cropRectNormalized: CGRect?
    @State private var cropRectAtDragStart: CGRect?
    
    private let colors: [Color] = [.red, .orange, .yellow, .green, .cyan, .purple, .black, .white]
    private let strokeWidths: [(CGFloat, String)] = [(2, "S"), (4, "M"), (6, "L")]
    
    // Transparent mode preference
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.elementCaptureEditorDefaultColor) private var defaultEditorColorToken = PreferenceDefault.elementCaptureEditorDefaultColor
    @AppStorage(AppPreferenceKey.elementCaptureEditorPrefer100Zoom) private var prefer100Zoom = PreferenceDefault.elementCaptureEditorPrefer100Zoom
    @AppStorage(AppPreferenceKey.elementCaptureEditorPinchZoomEnabled) private var pinchZoomEnabled = PreferenceDefault.elementCaptureEditorPinchZoomEnabled
    
    // Blur strength preference (5-30, lower = stronger pixelation)
    @AppStorage(AppPreferenceKey.editorBlurStrength) private var blurStrength = PreferenceDefault.editorBlurStrength
    @AppStorage(AppPreferenceKey.elementCaptureEditorBackgroundEnabled) private var editorBackgroundEnabled = PreferenceDefault.elementCaptureEditorBackgroundEnabled
    @AppStorage(AppPreferenceKey.elementCaptureEditorBackgroundPreset) private var editorBackgroundPresetRaw = PreferenceDefault.elementCaptureEditorBackgroundPreset
    @AppStorage(AppPreferenceKey.elementCaptureEditorBackgroundSource) private var editorBackgroundSourceRaw = PreferenceDefault.elementCaptureEditorBackgroundSource
    @AppStorage(AppPreferenceKey.elementCaptureEditorBackgroundCustomImagePath) private var editorBackgroundCustomImagePath = PreferenceDefault.elementCaptureEditorBackgroundCustomImagePath
    @AppStorage(AppPreferenceKey.elementCaptureEditorBackgroundPaddingRatio) private var editorBackgroundPaddingRatio = PreferenceDefault.elementCaptureEditorBackgroundPaddingRatio
    @AppStorage(AppPreferenceKey.elementCaptureEditorBackgroundCornerRadius) private var editorBackgroundCornerRadius = PreferenceDefault.elementCaptureEditorBackgroundCornerRadius
    @AppStorage(AppPreferenceKey.elementCaptureEditorScreenshotCornerRadius) private var editorScreenshotCornerRadius = PreferenceDefault.elementCaptureEditorScreenshotCornerRadius
    @AppStorage(AppPreferenceKey.elementCaptureEditorScreenshotShadowStrength) private var editorScreenshotShadowStrength = PreferenceDefault.elementCaptureEditorScreenshotShadowStrength
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar (draggable area)
            titleBar
            
            // Tools bar (scrollable)
            toolsBarContainer
            canvasViewport
        }
        .frame(minWidth: 600, idealWidth: 800, maxWidth: .infinity)
        .frame(minHeight: 400, idealHeight: 600, maxHeight: .infinity)
        .droppyTransparentBackground(useTransparentBackground)
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
            refreshWallpaperBackgroundImage()
            refreshCustomBackgroundImage()
            preloadImageOverlays(for: annotations)
        }
        .onDisappear {
            removeKeyboardMonitor()
            NSCursor.arrow.set()  // Reset cursor on close
        }
        .onChange(of: selectedTool) { _, _ in
            updateCursor()
            applyHighlighterDefaultColorIfNeeded()
            if !selectedTool.isSticker {
                showingStickerPickerPopover = false
            }
            if selectedTool != .imageOverlay {
                showingImageOverlayOptionsPopover = false
            }
            if selectedTool != .numberSticker {
                pendingNumberStickerID = nil
            }
        }
        .onChange(of: isCropMode) { _, _ in
            if !isCropMode {
                cropRectAtDragStart = nil
            }
            updateCursor()
        }
        .onChange(of: editorBackgroundSourceRaw) { _, newValue in
            if ScreenshotBackgroundSource(rawValue: newValue) == .currentWallpaper {
                refreshWallpaperBackgroundImage()
            }
            if ScreenshotBackgroundSource(rawValue: newValue) == .customWallpaper {
                refreshCustomBackgroundImage()
            }
        }
        .onChange(of: editorBackgroundCustomImagePath) { _, _ in
            refreshCustomBackgroundImage()
        }
        .onChange(of: annotationImageOverlayPathsSignature) { _, _ in
            preloadImageOverlays(for: annotations)
        }
        .onChange(of: currentAnnotationImagePath) { _, newPath in
            preloadImageOverlayIfNeeded(at: newPath)
        }
    }

    private var currentAnnotationImagePath: String {
        currentAnnotation?.imagePath ?? ""
    }

    private var annotationImageOverlayPathsSignature: String {
        annotations
            .filter { $0.tool == .imageOverlay }
            .map(\.imagePath)
            .joined(separator: "|")
    }

    private var canvasViewport: some View {
        GeometryReader { containerGeometry in
            let availableSize = containerGeometry.size
            let imageAspect = originalImage.size.width / originalImage.size.height
            let containerAspect = availableSize.width / availableSize.height

            let fittedSize: CGSize = {
                if imageAspect > containerAspect {
                    let width = availableSize.width
                    let height = width / imageAspect
                    return CGSize(width: width, height: height)
                } else {
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
                styledCanvasContent(
                    imageSize: scaledSize,
                    annotationImageSize: originalImage.size,
                    includeCropOverlay: true,
                    includeFloatingBadge: true,
                    interactive: true
                )
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
                editorViewportSize = availableSize
                editorFittedImageSize = fittedSize
            }
            .onChange(of: availableSize) { _, newValue in
                editorViewportSize = newValue
            }
            .onChange(of: fittedSize) { _, newValue in
                editorFittedImageSize = newValue
            }
        }
        .background(useTransparentBackground ? Color.clear : AdaptiveColors.panelBackgroundAuto)
    }
    
    // MARK: - Keyboard Shortcuts
    
    @State private var keyboardMonitor: Any?
    
    private func setupKeyboardMonitor() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }

        // Load shortcuts from manager
        let shortcuts = ElementCaptureManager.shared.editorShortcuts
        
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            // Don't capture if text input sheet is showing
            guard !showingTextInput else { return event }
            
            // Check for modifier keys
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let keyCode = Int(event.keyCode)

            if let digit = digitInput(from: event, flags: flags), pendingNumberStickerID != nil {
                applyPendingNumberStickerDigit(digit)
                return nil
            }
            
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
                    case .magnifier: selectedTool = .magnifier; return nil
                    case .text: selectedTool = .text; return nil
                    case .cursorSticker: selectedTool = .cursorSticker; return nil
                    case .pointerSticker: selectedTool = .pointerSticker; return nil
                    case .cursorStickerCircled: selectedTool = .cursorStickerCircled; return nil
                    case .pointerStickerCircled: selectedTool = .pointerStickerCircled; return nil
                    case .typingIndicatorSticker: selectedTool = .typingIndicatorSticker; return nil
                    case .numberSticker: selectedTool = .numberSticker; return nil
                    // Strokes
                    case .strokeSmall: strokeWidth = 2; return nil
                    case .strokeMedium: strokeWidth = 4; return nil
                    case .strokeLarge: strokeWidth = 6; return nil
                    // Zoom
                    case .zoomIn: zoomScale = min(4.0, zoomScale + 0.25); return nil
                    case .zoomOut: zoomScale = max(0.25, zoomScale - 0.25); return nil
                    case .zoomReset: fitCanvasToViewport(); return nil
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

    private func digitInput(from event: NSEvent, flags: NSEvent.ModifierFlags) -> Int? {
        // Allow bare numeric keys (and Shift for top-row symbols on some layouts).
        let nonDigitModifiers = flags.subtracting(.shift)
        guard nonDigitModifiers.isEmpty else { return nil }
        guard let chars = event.charactersIgnoringModifiers, chars.count == 1, let scalar = chars.unicodeScalars.first else {
            return nil
        }

        let value = scalar.value
        guard value >= 48 && value <= 57 else { return nil }
        return Int(value - 48)
    }

    private func applyPendingNumberStickerDigit(_ digit: Int) {
        guard let pendingNumberStickerID else { return }
        guard let index = annotations.firstIndex(where: { $0.id == pendingNumberStickerID }) else {
            self.pendingNumberStickerID = nil
            return
        }

        guard annotations[index].tool == .numberSticker else {
            self.pendingNumberStickerID = nil
            return
        }

        annotations[index].text = String(digit)
        self.pendingNumberStickerID = nil
        HapticFeedback.select()
    }
    
    private func removeKeyboardMonitor() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
    }
    
    // MARK: - Cursor Feedback
    
    private func updateCursor() {
        if isCropMode {
            NSCursor.crosshair.set()
            return
        }
        
        // Use crosshair cursor for drawing tools
        switch selectedTool {
        case .arrow, .curvedArrow, .line, .rectangle, .ellipse, .freehand, .highlighter, .blur, .magnifier, .imageOverlay:
            NSCursor.crosshair.set()
        case .text:
            NSCursor.iBeam.set()
        case .cursorSticker, .pointerSticker, .cursorStickerCircled, .pointerStickerCircled, .typingIndicatorSticker, .numberSticker:
            NSCursor.arrow.set()
        }
    }

    private func clampedZoomScale(_ value: CGFloat) -> CGFloat {
        min(4.0, max(0.25, value))
    }

    private func fitCanvasToViewport() {
        zoomScale = fitZoomScale()
    }

    private func fitZoomScale() -> CGFloat {
        guard editorFittedImageSize.width > 0, editorFittedImageSize.height > 0 else { return 1.0 }
        guard editorViewportSize.width > 0, editorViewportSize.height > 0 else { return 1.0 }

        let styledSize = styledCanvasFrameSize(for: editorFittedImageSize)
        guard styledSize.width > 0, styledSize.height > 0 else { return 1.0 }

        let widthScale = editorViewportSize.width / styledSize.width
        let heightScale = editorViewportSize.height / styledSize.height
        let fitScale = min(widthScale, heightScale, 1.0)
        return clampedZoomScale(fitScale)
    }

    private func annotationReferenceMinDimension(for containerSize: CGSize) -> CGFloat {
        let zoomIndependentSize = min(containerSize.width, containerSize.height) / max(zoomScale, 0.001)
        return max(1, zoomIndependentSize)
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
                        Label("Save to File…", systemImage: "square.and.arrow.down")
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
            
            Button(action: fitCanvasToViewport) {
                Text("Fit")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 28))
            .opacity(abs(zoomScale - fitZoomScale()) < 0.01 ? 0.4 : 1)
            
            toolbarDivider
            
            // Crop controls
            Button {
                if isCropMode {
                    isCropMode = false
                    cropRectAtDragStart = nil
                } else {
                    isCropMode = true
                }
            } label: {
                Image(systemName: "crop")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(DroppyToggleButtonStyle(
                isOn: isCropMode,
                size: 28,
                cornerRadius: 14,
                accentColor: .yellow
            ))
            .help("Crop")
            
            if hasActiveCropSelection {
                Button {
                    cropRectNormalized = nil
                    isCropMode = false
                    cropRectAtDragStart = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(DroppyCircleButtonStyle(size: 28))
                .help("Clear Crop")
            }
            
            if let cropDimensionText {
                Text(cropDimensionText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(AdaptiveColors.secondaryTextAuto)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AdaptiveColors.overlayAuto(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            
            toolbarDivider
            
            // Tools
            ForEach(toolbarPrimaryTools) { tool in
                if tool == .imageOverlay {
                    Button {
                        isCropMode = false
                        let wasSelected = (selectedTool == .imageOverlay)
                        selectedTool = .imageOverlay
                        showingStickerPickerPopover = false
                        showingColorPickerPopover = false
                        showingStrokePickerPopover = false
                        showingImageOverlayOptionsPopover = wasSelected ? !showingImageOverlayOptionsPopover : true
                    } label: {
                        toolIcon(for: tool)
                    }
                    .buttonStyle(DroppyToggleButtonStyle(
                        isOn: selectedTool == .imageOverlay || showingImageOverlayOptionsPopover,
                        size: 28,
                        cornerRadius: 14,
                        accentColor: .yellow
                    ))
                    .help(tool.tooltipWithShortcut)
                    .popover(isPresented: $showingImageOverlayOptionsPopover, arrowEdge: .top) {
                        imageOverlayOptionsPopover
                    }
                } else {
                    Button {
                        isCropMode = false
                        selectedTool = tool
                        showingStickerPickerPopover = false
                        showingImageOverlayOptionsPopover = false
                    } label: {
                        toolIcon(for: tool)
                    }
                    .buttonStyle(DroppyToggleButtonStyle(
                        isOn: selectedTool == tool,
                        size: 28,
                        cornerRadius: 14,
                        accentColor: .yellow
                    ))
                    .help(tool.tooltipWithShortcut)
                }
            }

            stickerPickerControl
            
            toolbarDivider
            
            colorPickerControl
            
            toolbarDivider
            
            strokeWidthPickerControl
            
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

            toolbarDivider

            Button {
                showingCanvasStylePopover.toggle()
            } label: {
                Image(systemName: "paintpalette")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(DroppyToggleButtonStyle(
                isOn: editorBackgroundEnabled,
                size: 28,
                cornerRadius: 14,
                accentColor: .blue
            ))
            .help("Background Style")
            .popover(isPresented: $showingCanvasStylePopover, arrowEdge: .top) {
                canvasStylePopover
            }
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

    private var numberStickerFloatingBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "number.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.yellow)
            Text("Click the screenshot to place a sticker, then tap a number")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(AdaptiveColors.panelBackgroundAuto.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 2)
    }

    private var magnifierFloatingBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.yellow)
            Text("Drag the magnifier edge to resize and increase zoom")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(AdaptiveColors.panelBackgroundAuto.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 2)
    }

    private var imageOverlayFloatingBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.rectangle.on.rectangle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.yellow)
            Text("Tap Add Photo, then click to place or drag to size")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(AdaptiveColors.panelBackgroundAuto.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 2)
    }
    
    private var toolbarDivider: some View {
        Rectangle()
            .fill(AdaptiveColors.overlayAuto(0.1))
            .frame(width: 1, height: 22)
    }

    private var toolbarPrimaryTools: [AnnotationTool] {
        AnnotationTool.allCases.filter { !$0.isSticker }
    }

    private var stickerTools: [AnnotationTool] {
        AnnotationTool.allCases.filter { $0.isSticker }
    }

    private var stickerPickerControl: some View {
        let previewTool = selectedTool.isSticker ? selectedTool : (stickerTools.first ?? .cursorSticker)

        return Button {
            showingColorPickerPopover = false
            showingStrokePickerPopover = false
            showingStickerPickerPopover.toggle()
        } label: {
            toolIcon(for: previewTool)
        }
        .buttonStyle(DroppyToggleButtonStyle(
            isOn: selectedTool.isSticker || showingStickerPickerPopover,
            size: 28,
            cornerRadius: 14,
            accentColor: .yellow
        ))
        .help(selectedTool.isSticker ? selectedTool.tooltipWithShortcut : "Stickers")
        .onHover { hovering in
            isHoveringStickerPicker = hovering
            if hovering {
                showingColorPickerPopover = false
                showingStrokePickerPopover = false
                showingStickerPickerPopover = true
            } else {
                scheduleStickerPickerPopoverClose()
            }
        }
        .popover(isPresented: $showingStickerPickerPopover, arrowEdge: .top) {
            HStack(spacing: 6) {
                ForEach(stickerTools) { tool in
                    Button {
                        isCropMode = false
                        selectedTool = tool
                        showingStickerPickerPopover = false
                    } label: {
                        toolIcon(for: tool)
                            .frame(width: 16, height: 16)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(selectedTool == tool ? Color.yellow.opacity(0.28) : AdaptiveColors.overlayAuto(0.12))
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        selectedTool == tool ? Color.yellow : AdaptiveColors.overlayAuto(0.24),
                                        lineWidth: selectedTool == tool ? 1.2 : 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .help(tool.tooltipWithShortcut)
                }
            }
            .padding(10)
            .droppyTransparentBackground(useTransparentBackground)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(useTransparentBackground ? 0.20 : 0.10), lineWidth: 1)
            )
            .onHover { hovering in
                isHoveringStickerPopover = hovering
                if !hovering {
                    scheduleStickerPickerPopoverClose()
                }
            }
        }
    }

    private var colorPickerControl: some View {
        Button {
            showingStrokePickerPopover = false
            showingStickerPickerPopover = false
            showingColorPickerPopover.toggle()
        } label: {
            Circle()
                .fill(selectedColor)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(AdaptiveColors.overlayAuto(0.25), lineWidth: 0.8)
                )
                .overlay(
                    Circle()
                        .stroke(AdaptiveColors.primaryTextAuto.opacity(0.85), lineWidth: 1.4)
                )
        }
        .buttonStyle(DroppyCircleButtonStyle(size: 28))
        .help("Color")
        .onHover { hovering in
            isHoveringColorPicker = hovering
            if hovering {
                showingStrokePickerPopover = false
                showingStickerPickerPopover = false
                showingColorPickerPopover = true
            } else {
                scheduleColorPickerPopoverClose()
            }
        }
        .popover(isPresented: $showingColorPickerPopover, arrowEdge: .top) {
            HStack(spacing: 6) {
                ForEach(colors, id: \.self) { color in
                    Button {
                        selectedColor = color
                        showingColorPickerPopover = false
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(AdaptiveColors.overlayAuto(0.3), lineWidth: 0.8)
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        selectedColor == color ? AdaptiveColors.primaryTextAuto : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .droppyTransparentBackground(useTransparentBackground)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(useTransparentBackground ? 0.20 : 0.10), lineWidth: 1)
            )
            .onHover { hovering in
                isHoveringColorPopover = hovering
                if !hovering {
                    scheduleColorPickerPopoverClose()
                }
            }
        }
    }

    private var strokeWidthPickerControl: some View {
        Button {
            showingColorPickerPopover = false
            showingStickerPickerPopover = false
            showingStrokePickerPopover.toggle()
        } label: {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(AdaptiveColors.primaryTextAuto.opacity(0.9))
                .frame(width: 16, height: max(3, min(strokeWidth + 1.5, 9)))
        }
        .buttonStyle(DroppyCircleButtonStyle(size: 28))
        .help("Stroke: \(selectedStrokeWidthLabel)")
        .onHover { hovering in
            isHoveringStrokePicker = hovering
            if hovering {
                showingColorPickerPopover = false
                showingStickerPickerPopover = false
                showingStrokePickerPopover = true
            } else {
                scheduleStrokePickerPopoverClose()
            }
        }
        .popover(isPresented: $showingStrokePickerPopover, arrowEdge: .top) {
            HStack(spacing: 6) {
                ForEach(strokeWidths, id: \.0) { width, name in
                    Button {
                        strokeWidth = width
                        showingStrokePickerPopover = false
                    } label: {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(strokeWidth == width ? Color.yellow : AdaptiveColors.overlayAuto(0.5))
                            .frame(width: 24, height: width + 5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .stroke(
                                        strokeWidth == width ? AdaptiveColors.primaryTextAuto.opacity(0.28) : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(width: 30, height: 28)
                    .help(name)
                }
            }
            .padding(10)
            .droppyTransparentBackground(useTransparentBackground)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(useTransparentBackground ? 0.20 : 0.10), lineWidth: 1)
            )
            .onHover { hovering in
                isHoveringStrokePopover = hovering
                if !hovering {
                    scheduleStrokePickerPopoverClose()
                }
            }
        }
    }

    private var imageOverlayOptionsPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo-in-Photo")
                .font(.system(size: 13, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text(imageOverlayFilename)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Button("Choose Image…") {
                    if let path = chooseImageOverlayFile() {
                        imageOverlaySelectedPath = path
                        preloadImageOverlayIfNeeded(at: path)
                    }
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Corners")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    imageOverlayOptionPickerCard(
                        title: "Rounded",
                        systemImage: "capsule",
                        isSelected: imageOverlayUseRoundedCorners
                    ) {
                        imageOverlayUseRoundedCorners = true
                    }
                    imageOverlayOptionPickerCard(
                        title: "Square",
                        systemImage: "square",
                        isSelected: !imageOverlayUseRoundedCorners
                    ) {
                        imageOverlayUseRoundedCorners = false
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 260)
        .droppyTransparentBackground(useTransparentBackground)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(useTransparentBackground ? 0.20 : 0.10), lineWidth: 1)
        )
    }

    private var imageOverlayFilename: String {
        guard !imageOverlaySelectedPath.isEmpty else { return "No image selected" }
        return URL(fileURLWithPath: imageOverlaySelectedPath).lastPathComponent
    }

    @ViewBuilder
    private func imageOverlayOptionPickerCard(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.blue : AdaptiveColors.primaryTextAuto.opacity(0.86))
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AdaptiveColors.overlayAuto(0.14),
                                AdaptiveColors.overlayAuto(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isSelected ? Color.blue.opacity(0.95) : AdaptiveColors.overlayAuto(0.12),
                        lineWidth: isSelected ? 1.6 : 1
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.blue)
                        .padding(5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var selectedStrokeWidthLabel: String {
        if let exact = strokeWidths.first(where: { abs($0.0 - strokeWidth) < 0.01 }) {
            return exact.1
        }
        return "\(Int(strokeWidth.rounded()))"
    }

    private func scheduleColorPickerPopoverClose() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            if !isHoveringColorPicker && !isHoveringColorPopover {
                showingColorPickerPopover = false
            }
        }
    }

    private func scheduleStrokePickerPopoverClose() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            if !isHoveringStrokePicker && !isHoveringStrokePopover {
                showingStrokePickerPopover = false
            }
        }
    }

    private func scheduleStickerPickerPopoverClose() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            if !isHoveringStickerPicker && !isHoveringStickerPopover {
                showingStickerPickerPopover = false
            }
        }
    }

    private var selectedBackgroundPreset: ScreenshotBackgroundPreset {
        ScreenshotBackgroundPreset(rawValue: editorBackgroundPresetRaw) ?? .midnight
    }

    private var selectedBackgroundPresetBinding: Binding<ScreenshotBackgroundPreset> {
        Binding(
            get: { selectedBackgroundPreset },
            set: { editorBackgroundPresetRaw = $0.rawValue }
        )
    }

    private var selectedBackgroundSource: ScreenshotBackgroundSource {
        ScreenshotBackgroundSource(rawValue: editorBackgroundSourceRaw) ?? .gradient
    }

    private var selectedBackgroundSourceBinding: Binding<ScreenshotBackgroundSource> {
        Binding(
            get: { selectedBackgroundSource },
            set: { editorBackgroundSourceRaw = $0.rawValue }
        )
    }

    private var selectedBackgroundImage: NSImage? {
        switch selectedBackgroundSource {
        case .gradient:
            return nil
        case .currentWallpaper:
            return wallpaperBackgroundImage
        case .customWallpaper:
            return customBackgroundImage
        }
    }

    private var customBackgroundImageFilename: String {
        guard !editorBackgroundCustomImagePath.isEmpty else { return "No image selected" }
        return URL(fileURLWithPath: editorBackgroundCustomImagePath).lastPathComponent
    }

    private var clampedBackgroundPaddingRatio: Double {
        min(max(editorBackgroundPaddingRatio, 0), 0.35)
    }

    private var clampedBackgroundCornerRadius: CGFloat {
        CGFloat(min(max(editorBackgroundCornerRadius, 0), 220))
    }

    private var clampedScreenshotCornerRadius: CGFloat {
        CGFloat(min(max(editorScreenshotCornerRadius, 0), 180))
    }

    private var clampedScreenshotShadowStrength: Double {
        min(max(editorScreenshotShadowStrength, 0), 1)
    }

    private var screenshotShadowStyle: (opacity: Double, radius: CGFloat, y: CGFloat) {
        let strength = clampedScreenshotShadowStrength
        return (
            opacity: 0.14 + (0.40 * strength),
            radius: 8 + (28 * strength),
            y: 2 + (10 * strength)
        )
    }

    private func canvasPadding(for imageSize: CGSize) -> CGFloat {
        guard editorBackgroundEnabled else { return 0 }
        let baseDimension = max(1, min(imageSize.width, imageSize.height))
        return baseDimension * CGFloat(clampedBackgroundPaddingRatio)
    }

    private func styledCanvasFrameSize(for imageSize: CGSize) -> CGSize {
        let padding = canvasPadding(for: imageSize)
        return CGSize(
            width: imageSize.width + (padding * 2),
            height: imageSize.height + (padding * 2)
        )
    }

    private func resetCanvasStyleSettings() {
        editorBackgroundPresetRaw = PreferenceDefault.elementCaptureEditorBackgroundPreset
        editorBackgroundSourceRaw = PreferenceDefault.elementCaptureEditorBackgroundSource
        editorBackgroundCustomImagePath = PreferenceDefault.elementCaptureEditorBackgroundCustomImagePath
        editorBackgroundPaddingRatio = PreferenceDefault.elementCaptureEditorBackgroundPaddingRatio
        editorBackgroundCornerRadius = PreferenceDefault.elementCaptureEditorBackgroundCornerRadius
        editorScreenshotCornerRadius = PreferenceDefault.elementCaptureEditorScreenshotCornerRadius
        editorScreenshotShadowStrength = PreferenceDefault.elementCaptureEditorScreenshotShadowStrength
        refreshWallpaperBackgroundImage()
        refreshCustomBackgroundImage()
    }

    private func refreshWallpaperBackgroundImage() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first,
              let wallpaperURL = NSWorkspace.shared.desktopImageURL(for: screen),
              let wallpaper = NSImage(contentsOf: wallpaperURL) else {
            wallpaperBackgroundImage = nil
            return
        }
        wallpaperBackgroundImage = wallpaper
    }

    private func refreshCustomBackgroundImage() {
        let path = editorBackgroundCustomImagePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            customBackgroundImage = nil
            return
        }
        customBackgroundImage = NSImage(contentsOfFile: path)
    }

    private func chooseCustomBackgroundImage() {
        let panel = NSOpenPanel()
        panel.title = "Choose Background Image"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        editorBackgroundCustomImagePath = url.path
        editorBackgroundSourceRaw = ScreenshotBackgroundSource.customWallpaper.rawValue
        refreshCustomBackgroundImage()
    }

    private func clearCustomBackgroundImage() {
        editorBackgroundCustomImagePath = ""
        customBackgroundImage = nil
    }

    private var canvasStylePopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Background Style")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Reset") {
                    resetCanvasStyleSettings()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            }

            Toggle("Enable styled background", isOn: $editorBackgroundEnabled)
                .toggleStyle(.switch)

            if editorBackgroundEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Background")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        canvasBackgroundSourceCard(.gradient)
                        canvasBackgroundSourceCard(.currentWallpaper)
                        canvasBackgroundSourceCard(.customWallpaper)
                    }
                }

                if selectedBackgroundSource == .gradient {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gradient")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(ScreenshotBackgroundPreset.allCases) { preset in
                                Button {
                                    selectedBackgroundPresetBinding.wrappedValue = preset
                                } label: {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(preset.gradient)
                                        .frame(height: 30)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(
                                                    selectedBackgroundPreset == preset ? Color.white.opacity(0.95) : Color.white.opacity(0.2),
                                                    lineWidth: selectedBackgroundPreset == preset ? 2 : 1
                                                )
                                        )
                                        .overlay(alignment: .bottomLeading) {
                                            Text(preset.title)
                                                .font(.system(size: 9, weight: .semibold))
                                                .foregroundStyle(Color.white.opacity(0.95))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 3)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else if selectedBackgroundSource == .currentWallpaper {
                    HStack(spacing: 8) {
                        Text("Uses your current macOS wallpaper.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            refreshWallpaperBackgroundImage()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Refresh wallpaper")
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        if let image = customBackgroundImage {
                            Image(nsImage: image)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFill()
                                .frame(height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(AdaptiveColors.overlayAuto(0.18), lineWidth: 1)
                                )
                        }
                        HStack(spacing: 8) {
                            Text(customBackgroundImageFilename)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            if !editorBackgroundCustomImagePath.isEmpty {
                                Button("Clear") {
                                    clearCustomBackgroundImage()
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                            }
                        }
                        Button("Choose Image…") {
                            chooseCustomBackgroundImage()
                        }
                        .buttonStyle(DroppyPillButtonStyle(size: .small))

                        if customBackgroundImage == nil {
                            Text("No custom image loaded. Gradient fallback is used.")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                canvasSliderRow(
                    title: "Background Padding",
                    value: $editorBackgroundPaddingRatio,
                    range: 0...0.25,
                    valueText: { "\(Int(($0 * 100).rounded()))%" }
                )
                canvasSliderRow(
                    title: "Background Radius",
                    value: $editorBackgroundCornerRadius,
                    range: 0...96,
                    valueText: { "\(Int($0.rounded())) px" }
                )
                canvasSliderRow(
                    title: "Screenshot Radius",
                    value: $editorScreenshotCornerRadius,
                    range: 0...64,
                    valueText: { "\(Int($0.rounded())) px" }
                )
                canvasSliderRow(
                    title: "Shadow Strength",
                    value: $editorScreenshotShadowStrength,
                    range: 0...1,
                    valueText: { "\(Int(($0 * 100).rounded()))%" }
                )
            } else {
                Text("Enable this to add gradients or wallpaper backgrounds, shadows, and rounded corners.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 320)
        .droppyTransparentBackground(useTransparentBackground)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                .stroke(
                    AdaptiveColors.overlayAuto(useTransparentBackground ? 0.22 : 0.10),
                    lineWidth: 1
                )
        )
    }

    @ViewBuilder
    private func canvasSliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        valueText: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(valueText(value.wrappedValue))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            Slider(value: value, in: range)
        }
    }

    @ViewBuilder
    private func canvasBackgroundSourceCard(_ source: ScreenshotBackgroundSource) -> some View {
        let isSelected = selectedBackgroundSource == source

        Button {
            selectedBackgroundSourceBinding.wrappedValue = source
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AdaptiveColors.overlayAuto(0.14),
                                    AdaptiveColors.overlayAuto(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(
                            isSelected ? Color.blue.opacity(0.95) : AdaptiveColors.overlayAuto(0.12),
                            lineWidth: isSelected ? 1.8 : 1
                        )
                        .padding(0.8)

                    canvasBackgroundSourceIcon(source, isSelected: isSelected)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.blue)
                            .padding(5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
                .frame(width: 92, height: 46)

                Text(source.title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: 92)
            }
            .frame(width: 92, height: 76, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func canvasBackgroundSourceIcon(_ source: ScreenshotBackgroundSource, isSelected: Bool) -> some View {
        switch source {
        case .gradient:
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(selectedBackgroundPreset.gradient)
                .frame(width: 34, height: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.white.opacity(0.26), lineWidth: 0.8)
                )
        case .currentWallpaper:
            Image(systemName: "photo")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isSelected ? Color.blue : AdaptiveColors.overlayAuto(0.5))
        case .customWallpaper:
            Image(systemName: "folder")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isSelected ? Color.blue : AdaptiveColors.overlayAuto(0.5))
        }
    }

    @ViewBuilder
    private func styledCanvasContent(
        imageSize: CGSize,
        annotationImageSize: CGSize,
        includeCropOverlay: Bool,
        includeFloatingBadge: Bool,
        interactive: Bool
    ) -> some View {
        let frameSize = styledCanvasFrameSize(for: imageSize)
        let padding = canvasPadding(for: imageSize)
        let screenshotRadius = min(clampedScreenshotCornerRadius, min(imageSize.width, imageSize.height) / 2)
        let shadow = screenshotShadowStyle

        ZStack {
            if editorBackgroundEnabled {
                canvasBackgroundLayer(size: frameSize)
                    .frame(width: frameSize.width, height: frameSize.height)
            }

            interactiveScreenshotLayer(
                imageSize: imageSize,
                annotationImageSize: annotationImageSize,
                includeCropOverlay: includeCropOverlay,
                includeFloatingBadge: includeFloatingBadge,
                interactive: interactive
            )
            .clipShape(RoundedRectangle(cornerRadius: editorBackgroundEnabled ? screenshotRadius : 0, style: .continuous))
            .shadow(
                color: .black.opacity(editorBackgroundEnabled ? shadow.opacity : 0),
                radius: editorBackgroundEnabled ? shadow.radius : 0,
                x: 0,
                y: editorBackgroundEnabled ? shadow.y : 0
            )
            .padding(padding)
        }
        .frame(width: frameSize.width, height: frameSize.height)
    }

    @ViewBuilder
    private func interactiveScreenshotLayer(
        imageSize: CGSize,
        annotationImageSize: CGSize,
        includeCropOverlay: Bool,
        includeFloatingBadge: Bool,
        interactive: Bool
    ) -> some View {
        if interactive {
            baseScreenshotLayer(
                imageSize: imageSize,
                annotationImageSize: annotationImageSize,
                includeCropOverlay: includeCropOverlay,
                includeFloatingBadge: includeFloatingBadge
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if isCropMode {
                            handleCropDrag(value, in: imageSize)
                        } else {
                            handleDrag(value, in: imageSize)
                        }
                    }
                    .onEnded { value in
                        if isCropMode {
                            handleCropDragEnd(value, in: imageSize)
                        } else {
                            handleDragEnd(value, in: imageSize)
                        }
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
        } else {
            baseScreenshotLayer(
                imageSize: imageSize,
                annotationImageSize: annotationImageSize,
                includeCropOverlay: includeCropOverlay,
                includeFloatingBadge: includeFloatingBadge
            )
        }
    }

    @ViewBuilder
    private func baseScreenshotLayer(
        imageSize: CGSize,
        annotationImageSize: CGSize,
        includeCropOverlay: Bool,
        includeFloatingBadge: Bool
    ) -> some View {
        ZStack {
            Image(nsImage: originalImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: imageSize.width, height: imageSize.height)

            AnnotationCanvas(
                annotations: annotations,
                currentAnnotation: currentAnnotation,
                originalImage: originalImage,
                imageSize: annotationImageSize,
                containerSize: imageSize,
                showMagnifierResizeIndicator: includeFloatingBadge,
                showCurveArrowHandleIndicator: includeFloatingBadge,
                overlayImagesByPath: imageOverlayPreviewCache
            )
            .frame(width: imageSize.width, height: imageSize.height)

            if includeCropOverlay && (isCropMode || hasActiveCropSelection) {
                CropSelectionOverlay(
                    selectionRect: cropRect(for: imageSize),
                    isActive: isCropMode,
                    dimensionText: cropDimensionText
                )
                .frame(width: imageSize.width, height: imageSize.height)
                .allowsHitTesting(false)
            }

            if includeFloatingBadge && selectedTool == .numberSticker {
                VStack {
                    numberStickerFloatingBadge
                        .padding(.top, 18)
                    Spacer()
                }
                .frame(width: imageSize.width, height: imageSize.height)
                .allowsHitTesting(false)
            } else if includeFloatingBadge && selectedTool == .magnifier {
                VStack {
                    magnifierFloatingBadge
                        .padding(.top, 18)
                    Spacer()
                }
                .frame(width: imageSize.width, height: imageSize.height)
                .allowsHitTesting(false)
            } else if includeFloatingBadge && selectedTool == .imageOverlay {
                VStack {
                    imageOverlayFloatingBadge
                        .padding(.top, 18)
                    Spacer()
                }
                .frame(width: imageSize.width, height: imageSize.height)
                .allowsHitTesting(false)
            }
        }
        .frame(width: imageSize.width, height: imageSize.height)
    }

    @ViewBuilder
    private func canvasBackgroundLayer(size: CGSize) -> some View {
        let radius = min(clampedBackgroundCornerRadius, min(size.width, size.height) / 2)

        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(selectedBackgroundPreset.gradient)
            if let backgroundImage = selectedBackgroundImage {
                Image(nsImage: backgroundImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
        }
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.24),
                                Color.clear,
                                Color.black.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.softLight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
    }

    @ViewBuilder
    private func toolIcon(for tool: AnnotationTool) -> some View {
        if tool.showsStickerCircle {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 1)
                    )
                    .frame(width: 16, height: 16)
                if let image = StickerToolRenderer.stickerImage(
                    for: tool,
                    pointSize: 10,
                    tintColor: tool.isNativeCursorSticker ? nil : .white,
                    outlineColor: tool.isNativeCursorSticker ? nil : .black
                ) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 10, height: 10)
                } else {
                    Image(systemName: StickerToolRenderer.resolvedSymbolName(for: tool) ?? tool.symbolName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.black.opacity(0.9))
                }
            }
        } else if tool.isSticker,
                  let image = StickerToolRenderer.stickerImage(
                      for: tool,
                      pointSize: 12,
                      tintColor: tool.isNativeCursorSticker ? nil : NSColor(selectedColor)
                  ) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 13, height: 13)
        } else {
            Image(systemName: StickerToolRenderer.resolvedSymbolName(for: tool) ?? tool.symbolName)
                .font(.system(size: 12, weight: .medium))
        }
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
                TextField("Enter text…", text: $textInput)
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

    private enum AnnotationDragMode {
        case translate
        case resizeMagnifier
        case curveArrow
    }
    
    private var hasActiveCropSelection: Bool {
        guard let cropRectNormalized else { return false }
        return cropRectNormalized.width > 0.002 && cropRectNormalized.height > 0.002
    }
    
    private var cropDimensionText: String? {
        guard let cropRectNormalized else { return nil }
        guard cropRectNormalized.width > 0.002, cropRectNormalized.height > 0.002 else { return nil }
        
        let width = max(1, Int((cropRectNormalized.width * originalImage.size.width).rounded()))
        let height = max(1, Int((cropRectNormalized.height * originalImage.size.height).rounded()))
        return "\(width) × \(height)"
    }
    
    private func cropRect(for containerSize: CGSize) -> CGRect? {
        guard let cropRectNormalized else { return nil }
        guard cropRectNormalized.width > 0.002, cropRectNormalized.height > 0.002 else { return nil }
        
        return CGRect(
            x: cropRectNormalized.minX * containerSize.width,
            y: cropRectNormalized.minY * containerSize.height,
            width: cropRectNormalized.width * containerSize.width,
            height: cropRectNormalized.height * containerSize.height
        )
    }
    
    private func handleCropDrag(_ value: DragGesture.Value, in containerSize: CGSize) {
        if cropRectAtDragStart == nil {
            cropRectAtDragStart = cropRectNormalized
        }
        
        let normalizedStart = normalizedPoint(value.startLocation, in: containerSize)
        let normalizedCurrent = normalizedPoint(value.location, in: containerSize)
        
        cropRectNormalized = normalizedRect(from: normalizedStart, to: normalizedCurrent)
    }
    
    private func handleCropDragEnd(_ value: DragGesture.Value, in containerSize: CGSize) {
        let normalizedStart = normalizedPoint(value.startLocation, in: containerSize)
        let normalizedEnd = normalizedPoint(value.location, in: containerSize)
        let normalizedSelection = normalizedRect(from: normalizedStart, to: normalizedEnd)
        
        if normalizedSelection.width > 0.002 && normalizedSelection.height > 0.002 {
            cropRectNormalized = normalizedSelection
            isCropMode = false
            HapticFeedback.select()
        } else {
            cropRectNormalized = cropRectAtDragStart
        }
        
        cropRectAtDragStart = nil
    }
    
    private func normalizedPoint(_ point: CGPoint, in containerSize: CGSize) -> CGPoint {
        let safeWidth = max(containerSize.width, 1)
        let safeHeight = max(containerSize.height, 1)
        
        return CGPoint(
            x: min(max(point.x / safeWidth, 0), 1),
            y: min(max(point.y / safeHeight, 0), 1)
        )
    }
    
    private func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)
        
        return CGRect(x: minX, y: minY, width: width, height: height)
    }

    private func defaultMagnifierLensPoint(from source: CGPoint, in containerSize: CGSize) -> CGPoint {
        let offset = max(80, min(containerSize.width, containerSize.height) * 0.16)
        return CGPoint(x: source.x + offset, y: source.y + offset)
    }

    private func clampMagnifierLensCenter(_ center: CGPoint, radius: CGFloat, in containerSize: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(center.x, radius + 4), max(radius + 4, containerSize.width - radius - 4)),
            y: min(max(center.y, radius + 4), max(radius + 4, containerSize.height - radius - 4))
        )
    }

    private func magnifierGeometry(
        for annotation: Annotation,
        in containerSize: CGSize,
        pointsOverride: [CGPoint]? = nil
    ) -> (source: CGPoint, lens: CGPoint, lensRadius: CGFloat, sourceRadius: CGFloat, defaultLensRadius: CGFloat)? {
        let points = pointsOverride ?? annotation.points
        guard let sourcePoint = points.first else { return nil }

        let source = scaleNormalizedPoint(sourcePoint, to: containerSize)
        let fallbackLens = defaultMagnifierLensPoint(from: source, in: containerSize)
        let rawLens = points.count > 1
            ? scaleNormalizedPoint(points[1], to: containerSize)
            : fallbackLens
        let displayStrokeWidth = effectiveStrokeWidth(for: annotation, in: containerSize)
        let defaultLensRadius = defaultMagnifierRadius(forStrokeWidth: displayStrokeWidth)
        let lensRadius = magnifierDisplayRadius(
            for: annotation,
            displayStrokeWidth: displayStrokeWidth,
            containerMinDimension: max(1, min(containerSize.width, containerSize.height))
        )
        let lens = clampMagnifierLensCenter(rawLens, radius: lensRadius, in: containerSize)
        let sourceRadius = max(14, lensRadius * 0.34)

        return (source, lens, lensRadius, sourceRadius, defaultLensRadius)
    }

    private func isPointOnMagnifierResizeEdge(_ normalizedPoint: CGPoint, annotation: Annotation, in containerSize: CGSize) -> Bool {
        guard let geometry = magnifierGeometry(for: annotation, in: containerSize) else { return false }

        let hitPoint = scaleNormalizedPoint(normalizedPoint, to: containerSize)
        let distance = hypot(hitPoint.x - geometry.lens.x, hitPoint.y - geometry.lens.y)
        let displayStrokeWidth = effectiveStrokeWidth(for: annotation, in: containerSize)
        let edgeTolerance = max(10, displayStrokeWidth * 2.0)
        return abs(distance - geometry.lensRadius) <= edgeTolerance
    }

    private func resizeMagnifierAnnotation(index: Int, to dragLocation: CGPoint, in containerSize: CGSize) {
        guard index >= 0, index < annotations.count else { return }

        var annotation = annotations[index]
        guard annotation.tool == .magnifier else { return }
        guard let geometry = magnifierGeometry(
            for: annotation,
            in: containerSize,
            pointsOverride: draggedAnnotationInitialPoints.isEmpty ? nil : draggedAnnotationInitialPoints
        ) else { return }

        let maxRadius = max(
            24,
            min(
                geometry.lens.x - 4,
                containerSize.width - geometry.lens.x - 4,
                geometry.lens.y - 4,
                containerSize.height - geometry.lens.y - 4
            )
        )
        let minRadius = max(24, geometry.defaultLensRadius * 0.55)
        let rawRadius = hypot(dragLocation.x - geometry.lens.x, dragLocation.y - geometry.lens.y)
        let clampedRadius = min(max(rawRadius, minRadius), maxRadius)
        if annotation.referenceCanvasMinDimension <= 1 {
            annotation.referenceCanvasMinDimension = max(1, min(containerSize.width, containerSize.height))
        }

        annotation.magnifierRadius = magnifierStoredRadius(
            fromDisplayRadius: clampedRadius,
            annotation: annotation,
            containerMinDimension: max(1, min(containerSize.width, containerSize.height))
        )
        annotations[index] = annotation
    }

    private func chooseImageOverlayFile() -> String? {
        let panel = NSOpenPanel()
        panel.title = "Choose Image"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url.path
    }

    private func ensureImageOverlaySelection() -> Bool {
        if !imageOverlaySelectedPath.isEmpty, FileManager.default.fileExists(atPath: imageOverlaySelectedPath) {
            preloadImageOverlayIfNeeded(at: imageOverlaySelectedPath)
            return true
        }
        guard let pickedPath = chooseImageOverlayFile() else { return false }
        imageOverlaySelectedPath = pickedPath
        preloadImageOverlayIfNeeded(at: pickedPath)
        return true
    }

    private func preloadImageOverlays(for annotations: [Annotation]) {
        for annotation in annotations where annotation.tool == .imageOverlay {
            preloadImageOverlayIfNeeded(at: annotation.imagePath)
        }
    }

    private func preloadImageOverlayIfNeeded(at path: String) {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return }
        guard imageOverlayPreviewCache[trimmedPath] == nil else { return }
        guard !imageOverlayLoadingPaths.contains(trimmedPath) else { return }

        imageOverlayLoadingPaths.insert(trimmedPath)
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedImage = NSImage(contentsOfFile: trimmedPath)
            DispatchQueue.main.async {
                if let loadedImage {
                    imageOverlayPreviewCache[trimmedPath] = loadedImage
                }
                imageOverlayLoadingPaths.remove(trimmedPath)
            }
        }
    }

    private func defaultImageOverlayPoints(at location: CGPoint, in containerSize: CGSize, imagePath: String) -> [CGPoint] {
        let sourceSize = imageOverlayPreviewCache[imagePath]?.size ?? NSSize(width: 1280, height: 720)
        let safeSourceWidth = max(sourceSize.width, 1)
        let safeSourceHeight = max(sourceSize.height, 1)
        let sourceAspect = safeSourceWidth / safeSourceHeight

        let maxWidth = max(160, containerSize.width * 0.42)
        let maxHeight = max(120, containerSize.height * 0.42)
        var width = maxWidth
        var height = width / sourceAspect
        if height > maxHeight {
            height = maxHeight
            width = height * sourceAspect
        }

        let halfWidth = width / 2
        let halfHeight = height / 2
        let centerX = min(max(location.x, halfWidth + 4), max(halfWidth + 4, containerSize.width - halfWidth - 4))
        let centerY = min(max(location.y, halfHeight + 4), max(halfHeight + 4, containerSize.height - halfHeight - 4))
        let rect = CGRect(
            x: centerX - halfWidth,
            y: centerY - halfHeight,
            width: width,
            height: height
        )

        return [
            CGPoint(x: rect.minX / max(containerSize.width, 1), y: rect.minY / max(containerSize.height, 1)),
            CGPoint(x: rect.maxX / max(containerSize.width, 1), y: rect.maxY / max(containerSize.height, 1))
        ]
    }

    private func resolvedArrowCurveOffset(
        for annotation: Annotation,
        start: CGPoint,
        end: CGPoint,
        in containerSize: CGSize
    ) -> CGFloat {
        let distance = hypot(end.x - start.x, end.y - start.y)
        guard distance > 0.001 else { return 0 }

        if abs(annotation.curveOffset) > 0.001 {
            let containerMinDimension = max(1, min(containerSize.width, containerSize.height))
            guard annotation.referenceCanvasMinDimension > 1 else { return annotation.curveOffset }
            return annotation.curveOffset * (containerMinDimension / annotation.referenceCanvasMinDimension)
        }

        if annotation.tool == .curvedArrow {
            return min(max(distance * 0.28, 20), 120)
        }
        return 0
    }

    private func storedArrowCurveOffset(
        from displayOffset: CGFloat,
        annotation: Annotation,
        in containerSize: CGSize
    ) -> CGFloat {
        let containerMinDimension = max(1, min(containerSize.width, containerSize.height))
        guard annotation.referenceCanvasMinDimension > 1 else { return displayOffset }
        return displayOffset * (annotation.referenceCanvasMinDimension / containerMinDimension)
    }

    private func storedArrowCurveControlOffset(
        from displayOffset: CGSize,
        annotation: Annotation,
        in containerSize: CGSize
    ) -> CGSize {
        let containerMinDimension = max(1, min(containerSize.width, containerSize.height))
        guard annotation.referenceCanvasMinDimension > 1 else { return displayOffset }
        let scale = annotation.referenceCanvasMinDimension / containerMinDimension
        return CGSize(width: displayOffset.width * scale, height: displayOffset.height * scale)
    }

    private func resolvedArrowCurveControlPoint(
        for annotation: Annotation,
        start: CGPoint,
        end: CGPoint,
        in containerSize: CGSize
    ) -> CGPoint {
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)

        if annotation.hasCustomCurveControl {
            let containerMinDimension = max(1, min(containerSize.width, containerSize.height))
            let displayOffset: CGSize
            if annotation.referenceCanvasMinDimension > 1 {
                let scale = containerMinDimension / annotation.referenceCanvasMinDimension
                displayOffset = CGSize(
                    width: annotation.curveControlOffset.width * scale,
                    height: annotation.curveControlOffset.height * scale
                )
            } else {
                displayOffset = annotation.curveControlOffset
            }
            return CGPoint(x: mid.x + displayOffset.width, y: mid.y + displayOffset.height)
        }

        let fallbackOffset = resolvedArrowCurveOffset(
            for: annotation,
            start: start,
            end: end,
            in: containerSize
        )
        return curvedArrowControlPoint(from: start, to: end, curveOffset: fallbackOffset)
    }

    private func isPointOnArrowCurveHandle(_ normalizedPoint: CGPoint, annotation: Annotation, in containerSize: CGSize) -> Bool {
        guard (annotation.tool == .arrow || annotation.tool == .curvedArrow),
              annotation.points.count > 1 else { return false }

        let start = scaleNormalizedPoint(annotation.points[0], to: containerSize)
        let end = scaleNormalizedPoint(annotation.points[1], to: containerSize)
        let control = resolvedArrowCurveControlPoint(
            for: annotation,
            start: start,
            end: end,
            in: containerSize
        )
        let hitPoint = scaleNormalizedPoint(normalizedPoint, to: containerSize)
        let displayStrokeWidth = effectiveStrokeWidth(for: annotation, in: containerSize)
        let tolerance = max(11, displayStrokeWidth * 2.1)
        return hypot(hitPoint.x - control.x, hitPoint.y - control.y) <= tolerance
    }

    private func curveArrowAnnotation(index: Int, to dragLocation: CGPoint, in containerSize: CGSize) {
        guard index >= 0, index < annotations.count else { return }
        var annotation = annotations[index]
        guard (annotation.tool == .arrow || annotation.tool == .curvedArrow),
              draggedAnnotationInitialPoints.count > 1 else { return }

        let start = scaleNormalizedPoint(draggedAnnotationInitialPoints[0], to: containerSize)
        let end = scaleNormalizedPoint(draggedAnnotationInitialPoints[1], to: containerSize)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        guard distance > 0.001 else { return }

        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let vector = CGPoint(x: dragLocation.x - mid.x, y: dragLocation.y - mid.y)
        let clampedVector = CGSize(width: vector.x, height: vector.y)
        if annotation.referenceCanvasMinDimension <= 1 {
            annotation.referenceCanvasMinDimension = max(1, min(containerSize.width, containerSize.height))
        }

        let normal = CGPoint(x: -dy / distance, y: dx / distance)
        let projectedOffset = (clampedVector.width * normal.x) + (clampedVector.height * normal.y)

        annotation.curveOffset = storedArrowCurveOffset(
            from: projectedOffset,
            annotation: annotation,
            in: containerSize
        )
        annotation.curveControlOffset = storedArrowCurveControlOffset(
            from: clampedVector,
            annotation: annotation,
            in: containerSize
        )
        annotation.hasCustomCurveControl = true
        annotations[index] = annotation
    }
    
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
            switch annotationDragMode {
            case .translate:
                // Move annotation by drag delta while keeping normalized points in bounds.
                let proposedDelta = CGPoint(
                    x: normalizedPoint.x - normalizedStart.x,
                    y: normalizedPoint.y - normalizedStart.y
                )
                annotations[index].points = translatePoints(
                    draggedAnnotationInitialPoints,
                    by: proposedDelta
                )
            case .resizeMagnifier:
                resizeMagnifierAnnotation(index: index, to: value.location, in: containerSize)
            case .curveArrow:
                curveArrowAnnotation(index: index, to: value.location, in: containerSize)
            }
            return
        }
        
        // Check if clicking on existing annotation (to select for moving)
        if abs(value.translation.width) <= 1 && abs(value.translation.height) <= 1 {
            // This is the start of a drag - check for annotation under cursor
            let normalizedClickPoint = CGPoint(
                x: value.startLocation.x / containerSize.width,
                y: value.startLocation.y / containerSize.height
            )
            if let curveHandleIndex = findCurveArrowHandleAt(point: normalizedClickPoint, in: containerSize) {
                selectedAnnotationIndex = curveHandleIndex
                draggedAnnotationInitialPoints = annotations[curveHandleIndex].points
                annotationDragMode = .curveArrow
                isDraggingAnnotation = true
                return
            }
            if let annotationIndex = findAnnotationAt(point: normalizedClickPoint, in: containerSize) {
                selectedAnnotationIndex = annotationIndex
                draggedAnnotationInitialPoints = annotations[annotationIndex].points
                if annotations[annotationIndex].tool == .magnifier,
                   isPointOnMagnifierResizeEdge(normalizedClickPoint, annotation: annotations[annotationIndex], in: containerSize) {
                    annotationDragMode = .resizeMagnifier
                } else {
                    annotationDragMode = .translate
                }
                isDraggingAnnotation = true
                return
            }
        }
        
        if selectedTool == .text || selectedTool.isSticker {
            // Text and sticker tools are single-click tools.
            return
        }

        if selectedTool == .imageOverlay && currentAnnotation == nil {
            guard ensureImageOverlaySelection() else { return }
        }
        
        let isShiftHeld = NSEvent.modifierFlags.contains(.shift)

        if currentAnnotation == nil {
            // Start new annotation
            var annotation = Annotation(
                tool: selectedTool,
                color: selectedColor,
                strokeWidth: strokeWidth
            )
            annotation.referenceCanvasMinDimension = annotationReferenceMinDimension(for: containerSize)
            // Capture blur strength for blur tool
            if selectedTool == .blur {
                annotation.blurStrength = blurStrength
            }
            if selectedTool == .magnifier {
                annotation.magnifierRadius = defaultMagnifierRadius(forStrokeWidth: annotation.strokeWidth)
            }
            if selectedTool == .imageOverlay {
                annotation.imagePath = imageOverlaySelectedPath
                annotation.imageCornerRadius = imageOverlayUseRoundedCorners ? 16 : 0
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
        case .arrow, .curvedArrow, .line, .freehand, .highlighter, .magnifier:
            // Snap to nearest 45° angle (0°, 45°, 90°, 135°, 180°, 225°, 270°, 315°)
            let angle = atan2(dy, dx)
            let snappedAngle = round(angle / (.pi / 4)) * (.pi / 4)
            let distance = hypot(dx, dy)
            return CGPoint(
                x: start.x + cos(snappedAngle) * distance,
                y: start.y + sin(snappedAngle) * distance
            )
            
        case .rectangle, .ellipse, .blur, .imageOverlay:
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
            annotationDragMode = .translate
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

        if selectedTool.isSticker {
            var annotation = Annotation(
                tool: selectedTool,
                color: selectedColor,
                strokeWidth: strokeWidth
            )
            annotation.referenceCanvasMinDimension = annotationReferenceMinDimension(for: containerSize)
            annotation.points = [CGPoint(
                x: value.location.x / containerSize.width,
                y: value.location.y / containerSize.height
            )]
            if selectedTool == .numberSticker {
                annotation.text = "?"
            }
            annotations.append(annotation)
            undoStack.removeAll()
            pendingNumberStickerID = selectedTool == .numberSticker ? annotation.id : nil
            currentAnnotation = nil
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

            if selectedTool == .imageOverlay {
                if annotation.imagePath.isEmpty {
                    guard ensureImageOverlaySelection() else {
                        currentAnnotation = nil
                        return
                    }
                    annotation.imagePath = imageOverlaySelectedPath
                }
                annotation.imageCornerRadius = imageOverlayUseRoundedCorners ? 16 : 0

                let dragDistance = hypot(
                    value.location.x - value.startLocation.x,
                    value.location.y - value.startLocation.y
                )

                if dragDistance <= 5 {
                    annotation.points = defaultImageOverlayPoints(
                        at: value.location,
                        in: containerSize,
                        imagePath: annotation.imagePath
                    )
                } else if annotation.points.count > 1 {
                    let normalizedWidth = abs(annotation.points[1].x - annotation.points[0].x)
                    let normalizedHeight = abs(annotation.points[1].y - annotation.points[0].y)
                    if normalizedWidth < 0.01 || normalizedHeight < 0.01 {
                        annotation.points = defaultImageOverlayPoints(
                            at: value.location,
                            in: containerSize,
                            imagePath: annotation.imagePath
                        )
                    }
                }

                annotations.append(annotation)
                undoStack.removeAll()
                pendingNumberStickerID = nil
                currentAnnotation = nil
                return
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
        annotation.referenceCanvasMinDimension = annotationReferenceMinDimension(for: canvasSize)
        annotation.points = [textPosition]
        annotation.text = textInput
        annotation.font = selectedFont
        annotations.append(annotation)
        undoStack.removeAll()
        pendingNumberStickerID = nil
        
        showingTextInput = false
        textInput = ""
    }
    
    private func undo() {
        guard !annotations.isEmpty else { return }
        undoStack.append(annotations)
        annotations.removeLast()
        clearPendingNumberStickerIfNeeded()
    }
    
    private func redo() {
        guard let lastState = undoStack.popLast() else { return }
        annotations = lastState
        clearPendingNumberStickerIfNeeded()
    }

    private func clearPendingNumberStickerIfNeeded() {
        guard let pendingNumberStickerID else { return }
        if !annotations.contains(where: { $0.id == pendingNumberStickerID }) {
            self.pendingNumberStickerID = nil
        }
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

    private func findCurveArrowHandleAt(point: CGPoint, in containerSize: CGSize) -> Int? {
        for (index, annotation) in annotations.enumerated().reversed() {
            guard annotation.tool == .arrow || annotation.tool == .curvedArrow else { continue }
            if isPointOnArrowCurveHandle(point, annotation: annotation, in: containerSize) {
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
        case .line:
            guard let endPoint = annotation.points.last else { return false }
            let start = scaleNormalizedPoint(annotation.points[0], to: containerSize)
            let end = scaleNormalizedPoint(endPoint, to: containerSize)
            return pointToSegmentDistance(hitPoint, start: start, end: end) <= baseTolerance
            
        case .arrow, .curvedArrow:
            guard let endPoint = annotation.points.last else { return false }
            let start = scaleNormalizedPoint(annotation.points[0], to: containerSize)
            let end = scaleNormalizedPoint(endPoint, to: containerSize)
            let controlPoint = resolvedArrowCurveControlPoint(
                for: annotation,
                start: start,
                end: end,
                in: containerSize
            )
            return pointToCurvedArrowDistance(
                hitPoint,
                start: start,
                end: end,
                controlPoint: controlPoint
            ) <= baseTolerance
            
        case .rectangle, .blur:
            guard let endPoint = annotation.points.last else { return false }
            let rect = rectFromNormalizedPoints(annotation.points[0], endPoint, in: containerSize)
            return rect.insetBy(dx: -baseTolerance, dy: -baseTolerance).contains(hitPoint)

        case .imageOverlay:
            guard let endPoint = annotation.points.last else { return false }
            let rect = rectFromNormalizedPoints(annotation.points[0], endPoint, in: containerSize)
            return rect.insetBy(dx: -baseTolerance, dy: -baseTolerance).contains(hitPoint)

        case .magnifier:
            guard let geometry = magnifierGeometry(for: annotation, in: containerSize) else { return false }

            if hypot(hitPoint.x - geometry.source.x, hitPoint.y - geometry.source.y) <= (geometry.sourceRadius + baseTolerance) {
                return true
            }
            if hypot(hitPoint.x - geometry.lens.x, hitPoint.y - geometry.lens.y) <= (geometry.lensRadius + baseTolerance) {
                return true
            }

            return pointToSegmentDistance(hitPoint, start: geometry.source, end: geometry.lens) <= baseTolerance
            
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
            
        case .cursorSticker, .pointerSticker, .cursorStickerCircled, .pointerStickerCircled, .typingIndicatorSticker, .numberSticker:
            guard let stickerRect = stickerBounds(for: annotation, in: containerSize) else { return false }
            return stickerRect.insetBy(dx: -8, dy: -8).contains(hitPoint)
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

    private func stickerBounds(for annotation: Annotation, in containerSize: CGSize) -> CGRect? {
        guard let normalizedPoint = annotation.points.first else { return nil }
        let anchor = scaleNormalizedPoint(normalizedPoint, to: containerSize)
        let displayStrokeWidth = effectiveStrokeWidth(for: annotation, in: containerSize)
        return StickerToolRenderer.layout(
            for: annotation.tool,
            anchor: anchor,
            displayStrokeWidth: displayStrokeWidth
        )?.bounds
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
    
    private func pointToCurvedArrowDistance(
        _ point: CGPoint,
        start: CGPoint,
        end: CGPoint,
        controlPoint: CGPoint
    ) -> CGFloat {
        let sampledPoints = sampledCurvedArrowPoints(from: start, to: end, controlPoint: controlPoint)
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
    
    private func sampledCurvedArrowPoints(
        from start: CGPoint,
        to end: CGPoint,
        controlPoint: CGPoint,
        segments: Int = 20
    ) -> [CGPoint] {
        let clampedSegments = max(2, segments)

        var points: [CGPoint] = []
        points.reserveCapacity(clampedSegments + 1)

        for index in 0...clampedSegments {
            let t = CGFloat(index) / CGFloat(clampedSegments)
            let oneMinusT = 1 - t
            let startWeight = oneMinusT * oneMinusT
            let controlWeight = 2 * oneMinusT * t
            let endWeight = t * t

            let x = (startWeight * start.x) + (controlWeight * controlPoint.x) + (endWeight * end.x)
            let y = (startWeight * start.y) + (controlWeight * controlPoint.y) + (endWeight * end.y)
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
    
    private func curvedArrowControlPoint(from start: CGPoint, to end: CGPoint, curveOffset: CGFloat? = nil) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        guard distance > 0.001 else {
            return CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        }
        
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let normal = CGPoint(x: -dy / distance, y: dx / distance)
        let curveAmount = curveOffset ?? min(max(distance * 0.28, 20), 120)
        
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
            return applyCropIfNeeded(to: renderedImage, contentRenderSize: renderSize)
        }
        
        guard let bitmap = renderAnnotatedBitmap() else {
            return applyCropIfNeeded(to: originalImage, contentRenderSize: renderSize)
        }
        
        let image = NSImage(size: bitmap.size)
        image.addRepresentation(bitmap)
        return applyCropIfNeeded(to: image, contentRenderSize: renderSize)
    }
    
    private func renderAnnotatedPNGData() -> Data? {
        let image = renderAnnotatedImage()
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapRep.representation(using: .png, properties: [:])
    }
    
    private func applyCropIfNeeded(to image: NSImage, contentRenderSize: NSSize? = nil) -> NSImage {
        let contentSize = contentRenderSize ?? image.size
        guard let cropRect = cropRectInImageSpace(for: contentSize) else { return image }

        let mappedCropRect = mapCropRect(cropRect, from: contentSize, to: image.size)
        guard mappedCropRect.width > 1, mappedCropRect.height > 1 else { return image }
        
        let outputSize = NSSize(width: mappedCropRect.width, height: mappedCropRect.height)
        guard outputSize.width > 0, outputSize.height > 0 else { return image }
        
        let croppedImage = NSImage(size: outputSize)
        croppedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: outputSize),
            from: mappedCropRect,
            operation: .copy,
            fraction: 1.0
        )
        croppedImage.unlockFocus()
        return croppedImage
    }

    private func mapCropRect(_ cropRect: CGRect, from contentSize: NSSize, to renderedSize: NSSize) -> CGRect {
        let offsetX = (renderedSize.width - contentSize.width) / 2
        let offsetY = (renderedSize.height - contentSize.height) / 2
        let translated = cropRect.offsetBy(dx: offsetX, dy: offsetY)
        let bounds = CGRect(origin: .zero, size: renderedSize)
        let clipped = translated.intersection(bounds)
        guard clipped.width > 1, clipped.height > 1 else { return .zero }
        return clipped.integral
    }
    
    private func cropRectInImageSpace(for imageSize: NSSize) -> CGRect? {
        guard let cropRectNormalized else { return nil }
        guard cropRectNormalized.width > 0.002, cropRectNormalized.height > 0.002 else { return nil }
        
        let x = cropRectNormalized.minX * imageSize.width
        let width = cropRectNormalized.width * imageSize.width
        // Convert top-left normalized Y to NSImage's bottom-left coordinate system.
        let y = (1 - cropRectNormalized.maxY) * imageSize.height
        let height = cropRectNormalized.height * imageSize.height
        
        let rawRect = CGRect(x: x, y: y, width: width, height: height)
        let bounds = CGRect(origin: .zero, size: imageSize)
        let clipped = rawRect.intersection(bounds)
        
        guard clipped.width > 1, clipped.height > 1 else { return nil }
        return clipped.integral
    }
    
    private func renderRenderedViewImage(renderSize: NSSize) -> NSImage? {
        guard renderSize.width > 0, renderSize.height > 0 else { return nil }

        let outputSize = styledCanvasFrameSize(for: renderSize)

        let exportView = styledCanvasContent(
            imageSize: renderSize,
            annotationImageSize: renderSize,
            includeCropOverlay: false,
            includeFloatingBadge: false,
            interactive: false
        )
        .frame(width: outputSize.width, height: outputSize.height)

        // Primary path: offscreen AppKit snapshot for WYSIWYG parity with on-screen SwiftUI rendering.
        let hosting = NSHostingView(rootView: exportView)
        hosting.frame = NSRect(origin: .zero, size: outputSize)
        hosting.needsLayout = true
        
        if let bitmapRep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
            bitmapRep.size = outputSize
            hosting.cacheDisplay(in: hosting.bounds, to: bitmapRep)
            let image = NSImage(size: outputSize)
            image.addRepresentation(bitmapRep)
            return image
        }

        // Fallback: ImageRenderer.
        let renderer = ImageRenderer(content: exportView)
        renderer.proposedSize = ProposedViewSize(width: outputSize.width, height: outputSize.height)
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
            let start = scalePoint(annotation.points[0], to: size)
            let end = scalePoint(annotation.points.last ?? annotation.points[0], to: size)
            let controlPoint = resolvedArrowCurveControlPoint(
                for: annotation,
                start: start,
                end: end,
                in: CGSize(width: size.width, height: size.height)
            )
            drawArrow(
                from: annotation.points[0],
                to: annotation.points.last ?? annotation.points[0],
                strokeWidth: effectiveStrokeWidth,
                curveControlPoint: controlPoint,
                in: size
            )
            
        case .curvedArrow:
            let start = scalePoint(annotation.points[0], to: size)
            let end = scalePoint(annotation.points.last ?? annotation.points[0], to: size)
            let controlPoint = resolvedArrowCurveControlPoint(
                for: annotation,
                start: start,
                end: end,
                in: CGSize(width: size.width, height: size.height)
            )
            drawCurvedArrow(
                from: annotation.points[0],
                to: annotation.points.last ?? annotation.points[0],
                strokeWidth: effectiveStrokeWidth,
                curveControlPoint: controlPoint,
                in: size
            )
            
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

        case .magnifier:
            drawMagnifierAnnotation(annotation, in: size, sourceImage: sourceImage, effectiveStrokeWidth: effectiveStrokeWidth)

        case .imageOverlay:
            drawImageOverlayAnnotation(annotation, in: size, effectiveStrokeWidth: effectiveStrokeWidth)
            
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

        case .cursorSticker, .pointerSticker, .cursorStickerCircled, .pointerStickerCircled, .typingIndicatorSticker, .numberSticker:
            drawStickerAnnotation(annotation, in: size, effectiveStrokeWidth: effectiveStrokeWidth)
        }
    }

    private func drawStickerAnnotation(_ annotation: Annotation, in size: NSSize, effectiveStrokeWidth: CGFloat) {
        guard let point = annotation.points.first else { return }
        let anchor = scalePoint(point, to: size)
        guard let layout = StickerToolRenderer.layout(
            for: annotation.tool,
            anchor: anchor,
            displayStrokeWidth: effectiveStrokeWidth
        ) else { return }

        if annotation.tool == .numberSticker {
            drawNumberStickerAnnotation(annotation, in: layout.symbolRect)
            return
        }
        
        if let circleRect = layout.circleRect {
            NSColor.white.setFill()
            let circlePath = NSBezierPath(ovalIn: circleRect)
            circlePath.fill()
            NSColor.black.setStroke()
            circlePath.lineWidth = 1.6
            circlePath.stroke()
        }
        
        if let symbolImage = StickerToolRenderer.stickerImage(
            for: annotation.tool,
            pointSize: layout.symbolRect.height * 0.92,
            tintColor: annotation.tool.isNativeCursorSticker
                ? nil
                : (annotation.tool.showsStickerCircle ? .white : NSColor(annotation.color)),
            outlineColor: annotation.tool.isNativeCursorSticker
                ? nil
                : (annotation.tool.showsStickerCircle ? .black : nil)
        ) {
            let drawRect = StickerToolRenderer.fittedRect(for: symbolImage.size, in: layout.symbolRect)
            symbolImage.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        } else {
            drawStickerFallback(annotation.tool, in: layout.symbolRect)
        }
    }

    private func drawNumberStickerAnnotation(_ annotation: Annotation, in rect: CGRect) {
        let fillColor = NSColor(annotation.color)
        let textColor = numberStickerTextColor(for: fillColor)
        let strokeColor = textColor.withAlphaComponent(0.35)
        let value = annotation.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "?" : annotation.text

        let circlePath = NSBezierPath(ovalIn: rect)
        fillColor.setFill()
        circlePath.fill()

        strokeColor.setStroke()
        circlePath.lineWidth = max(1.2, rect.width * 0.05)
        circlePath.stroke()

        let font = NSFont.systemFont(ofSize: max(10, rect.height * 0.56), weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        let textSize = value.size(withAttributes: attributes)
        let textRect = CGRect(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        value.draw(in: textRect, withAttributes: attributes)
    }

    private func numberStickerTextColor(for fillColor: NSColor) -> NSColor {
        let color = fillColor.usingColorSpace(.sRGB) ?? fillColor
        let luminance = (0.2126 * color.redComponent) + (0.7152 * color.greenComponent) + (0.0722 * color.blueComponent)
        return luminance >= 0.58 ? .black : .white
    }

    private func drawStickerFallback(_ tool: AnnotationTool, in rect: CGRect) {
        NSColor.black.setFill()
        NSColor.black.setStroke()
        
        switch tool {
        case .typingIndicatorSticker:
            let path = NSBezierPath()
            path.lineWidth = max(1.5, rect.width * 0.2)
            path.lineCapStyle = .round
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.line(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.line(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.line(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.stroke()
        case .numberSticker:
            let circlePath = NSBezierPath(ovalIn: rect)
            circlePath.fill()
        default:
            let cursorPath = NSBezierPath()
            cursorPath.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            cursorPath.line(to: CGPoint(x: rect.maxX * 0.82 + rect.minX * 0.18, y: rect.midY))
            cursorPath.line(to: CGPoint(x: rect.midX, y: rect.minY))
            cursorPath.close()
            cursorPath.fill()
        }
    }

    private func drawMagnifierAnnotation(
        _ annotation: Annotation,
        in size: NSSize,
        sourceImage: NSImage?,
        effectiveStrokeWidth: CGFloat
    ) {
        guard let sourcePoint = annotation.points.first else { return }

        let source = scalePoint(sourcePoint, to: size)
        let fallbackLens = defaultMagnifierLensPoint(
            from: source,
            in: CGSize(width: size.width, height: size.height)
        )
        let rawLens: CGPoint
        if annotation.points.count > 1 {
            rawLens = scalePoint(annotation.points[1], to: size)
        } else {
            rawLens = fallbackLens
        }

        let containerMinDimension = max(1, min(size.width, size.height))
        let defaultLensRadius = defaultMagnifierRadius(forStrokeWidth: effectiveStrokeWidth)
        let lensRadius = magnifierDisplayRadius(
            for: annotation,
            displayStrokeWidth: effectiveStrokeWidth,
            containerMinDimension: containerMinDimension
        )
        let sourceRadius = max(14, lensRadius * 0.34)
        let lens = clampMagnifierLensCenter(
            rawLens,
            radius: lensRadius,
            in: CGSize(width: size.width, height: size.height)
        )

        let connectorPath = NSBezierPath()
        connectorPath.lineWidth = max(2.0, effectiveStrokeWidth * 0.9)
        connectorPath.lineCapStyle = .round

        let connectorVector = CGPoint(x: lens.x - source.x, y: lens.y - source.y)
        let connectorDistance = hypot(connectorVector.x, connectorVector.y)
        if connectorDistance > 0.001 {
            let ux = connectorVector.x / connectorDistance
            let uy = connectorVector.y / connectorDistance
            connectorPath.move(
                to: CGPoint(
                    x: source.x + ux * sourceRadius,
                    y: source.y + uy * sourceRadius
                )
            )
            connectorPath.line(
                to: CGPoint(
                    x: lens.x - ux * lensRadius,
                    y: lens.y - uy * lensRadius
                )
            )
            NSColor(annotation.color).setStroke()
            connectorPath.stroke()
        }

        let sourceMarkerRect = CGRect(
            x: source.x - sourceRadius,
            y: source.y - sourceRadius,
            width: sourceRadius * 2,
            height: sourceRadius * 2
        )
        let sourceMarkerPath = NSBezierPath(ovalIn: sourceMarkerRect)
        NSColor(annotation.color).setStroke()
        sourceMarkerPath.lineWidth = max(1.8, effectiveStrokeWidth * 0.85)
        sourceMarkerPath.stroke()

        let lensRect = CGRect(
            x: lens.x - lensRadius,
            y: lens.y - lensRadius,
            width: lensRadius * 2,
            height: lensRadius * 2
        )
        let magnification = magnifierMagnification(for: lensRadius, defaultRadius: defaultLensRadius)
        let sampleDiameter = max(8, lensRect.width / magnification)
        let sampleRect = CGRect(
            x: source.x - sampleDiameter / 2,
            y: source.y - sampleDiameter / 2,
            width: sampleDiameter,
            height: sampleDiameter
        )

        NSGraphicsContext.saveGraphicsState()
        let clipPath = NSBezierPath(ovalIn: lensRect)
        clipPath.addClip()
        NSColor.white.withAlphaComponent(0.95).setFill()
        clipPath.fill()

        let bounds = CGRect(origin: .zero, size: size)
        let clippedSourceRect = sampleRect.intersection(bounds)
        if clippedSourceRect.width > 1, clippedSourceRect.height > 1 {
            NSGraphicsContext.current?.imageInterpolation = .high
            (sourceImage ?? originalImage).draw(
                in: lensRect,
                from: clippedSourceRect,
                operation: .copy,
                fraction: 1.0
            )
        }
        NSGraphicsContext.restoreGraphicsState()

        let outerRing = NSBezierPath(ovalIn: lensRect)
        outerRing.lineWidth = max(2.2, effectiveStrokeWidth * 0.95)
        NSColor(annotation.color).setStroke()
        outerRing.stroke()

        let innerInset = max(1.4, effectiveStrokeWidth * 0.5)
        let innerRingRect = lensRect.insetBy(dx: innerInset, dy: innerInset)
        let innerRing = NSBezierPath(ovalIn: innerRingRect)
        innerRing.lineWidth = max(1.0, effectiveStrokeWidth * 0.45)
        NSColor.black.withAlphaComponent(0.82).setStroke()
        innerRing.stroke()
    }

    private func drawImageOverlayAnnotation(_ annotation: Annotation, in size: NSSize, effectiveStrokeWidth: CGFloat) {
        guard annotation.points.count > 1 else { return }

        let rect = rectFromPoints(annotation.points[0], annotation.points[1], in: size)
        guard rect.width > 2, rect.height > 2 else { return }

        let cornerRadius = imageOverlayCornerRadius(
            for: annotation,
            in: CGSize(width: size.width, height: size.height),
            rect: rect
        )

        let clipPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        NSGraphicsContext.saveGraphicsState()
        clipPath.addClip()

        if let overlayImage = imageOverlayPreviewCache[annotation.imagePath] ?? NSImage(contentsOfFile: annotation.imagePath) {
            NSGraphicsContext.current?.imageInterpolation = .high
            overlayImage.draw(
                in: aspectFillRect(for: overlayImage.size, in: rect),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0
            )
        } else {
            NSColor.black.withAlphaComponent(0.16).setFill()
            rect.fill()
        }

        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.28).setStroke()
        let borderPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        borderPath.lineWidth = max(1.2, effectiveStrokeWidth * 0.34)
        borderPath.stroke()
    }

    private func imageOverlayCornerRadius(for annotation: Annotation, in containerSize: CGSize, rect: CGRect) -> CGFloat {
        var radius = max(0, annotation.imageCornerRadius)
        if annotation.referenceCanvasMinDimension > 1 {
            radius *= max(1, min(containerSize.width, containerSize.height)) / annotation.referenceCanvasMinDimension
        }
        return min(radius, min(rect.width, rect.height) / 2)
    }

    private func aspectFillRect(for sourceSize: NSSize, in destinationRect: CGRect) -> CGRect {
        let safeSourceWidth = max(sourceSize.width, 1)
        let safeSourceHeight = max(sourceSize.height, 1)
        let widthScale = destinationRect.width / safeSourceWidth
        let heightScale = destinationRect.height / safeSourceHeight
        let scale = max(widthScale, heightScale)

        let drawSize = CGSize(width: safeSourceWidth * scale, height: safeSourceHeight * scale)
        return CGRect(
            x: destinationRect.midX - drawSize.width / 2,
            y: destinationRect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
    }

    private func drawArrow(
        from start: CGPoint,
        to end: CGPoint,
        strokeWidth: CGFloat,
        curveControlPoint: CGPoint? = nil,
        in size: NSSize
    ) {
        let scaledStart = scalePoint(start, to: size)
        let scaledEnd = scalePoint(end, to: size)

        let path = NSBezierPath()
        path.lineWidth = strokeWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        let directionVector: CGPoint
        let curveDistance = curveControlPoint.map { pointToSegmentDistance($0, start: scaledStart, end: scaledEnd) } ?? 0
        if let control = curveControlPoint, curveDistance > 0.5 {
            let cubicControl1 = CGPoint(
                x: scaledStart.x + (2.0 / 3.0) * (control.x - scaledStart.x),
                y: scaledStart.y + (2.0 / 3.0) * (control.y - scaledStart.y)
            )
            let cubicControl2 = CGPoint(
                x: scaledEnd.x + (2.0 / 3.0) * (control.x - scaledEnd.x),
                y: scaledEnd.y + (2.0 / 3.0) * (control.y - scaledEnd.y)
            )
            path.move(to: scaledStart)
            path.curve(to: scaledEnd, controlPoint1: cubicControl1, controlPoint2: cubicControl2)
            directionVector = CGPoint(x: scaledEnd.x - control.x, y: scaledEnd.y - control.y)
        } else {
            path.move(to: scaledStart)
            path.line(to: scaledEnd)
            directionVector = CGPoint(x: scaledEnd.x - scaledStart.x, y: scaledEnd.y - scaledStart.y)
        }
        path.stroke()

        let fallbackDirection = CGPoint(x: scaledEnd.x - scaledStart.x, y: scaledEnd.y - scaledStart.y)
        let headVector = hypot(directionVector.x, directionVector.y) > 0.001 ? directionVector : fallbackDirection
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

    private func drawCurvedArrow(
        from start: CGPoint,
        to end: CGPoint,
        strokeWidth: CGFloat,
        curveControlPoint: CGPoint,
        in size: NSSize
    ) {
        drawArrow(from: start, to: end, strokeWidth: strokeWidth, curveControlPoint: curveControlPoint, in: size)
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

private struct CropSelectionOverlay: View {
    let selectionRect: CGRect?
    let isActive: Bool
    let dimensionText: String?
    
    var body: some View {
        GeometryReader { geometry in
            if let selectionRect {
                let fullRect = CGRect(origin: .zero, size: geometry.size)
                
                // Dim outside the crop area so the final output is obvious.
                Path { path in
                    path.addRect(fullRect)
                    path.addRect(selectionRect)
                }
                .fill(
                    Color.black.opacity(isActive ? 0.32 : 0.18),
                    style: FillStyle(eoFill: true)
                )
                
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .path(in: selectionRect)
                    .stroke(
                        Color.white.opacity(0.95),
                        style: StrokeStyle(lineWidth: 2, dash: [7, 4])
                    )
                
                ForEach(Array(selectionHandles(for: selectionRect).enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 7, height: 7)
                        .position(point)
                }
                
                if let dimensionText {
                    Text(dimensionText)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .position(
                            x: selectionRect.midX,
                            y: max(16, selectionRect.minY - 12)
                        )
                }
            } else if isActive {
                Text("Drag to crop")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.95))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
    }
    
    private func selectionHandles(for rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.midY),
            CGPoint(x: rect.maxX, y: rect.midY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.midX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ]
    }
}

struct AnnotationCanvas: View {
    let annotations: [Annotation]
    let currentAnnotation: Annotation?
    let originalImage: NSImage
    let imageSize: CGSize
    let containerSize: CGSize
    let showMagnifierResizeIndicator: Bool
    let showCurveArrowHandleIndicator: Bool
    let overlayImagesByPath: [String: NSImage]
    
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
            let controlPoint = resolvedArrowCurveControlPoint(for: annotation, start: start, end: end, in: size)
            drawArrow(from: start, to: end, color: color, strokeStyle: strokeStyle, curveControlPoint: controlPoint, in: context)
            if showCurveArrowHandleIndicator {
                drawCurveArrowHandle(controlPoint: controlPoint, color: color, strokeStyle: strokeStyle, in: context)
            }
            
        case .curvedArrow:
            let start = scalePoint(annotation.points[0], to: size)
            let end = scalePoint(annotation.points.last ?? annotation.points[0], to: size)
            let controlPoint = resolvedArrowCurveControlPoint(for: annotation, start: start, end: end, in: size)
            drawCurvedArrow(from: start, to: end, color: color, strokeStyle: strokeStyle, curveControlPoint: controlPoint, in: context)
            if showCurveArrowHandleIndicator {
                drawCurveArrowHandle(controlPoint: controlPoint, color: color, strokeStyle: strokeStyle, in: context)
            }
            
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

        case .magnifier:
            drawMagnifierAnnotation(
                annotation,
                in: context,
                size: size,
                effectiveStrokeWidth: effectiveStrokeWidth,
                showResizeIndicator: showMagnifierResizeIndicator
            )

        case .imageOverlay:
            drawImageOverlayAnnotation(annotation, in: context, size: size, effectiveStrokeWidth: effectiveStrokeWidth)
            
        case .text:
            let scaledPoint = scalePoint(annotation.points[0], to: size)
            let fontName = annotation.font == "SF Pro"
                ? Font.system(size: effectiveStrokeWidth * 8, weight: .semibold)
                : Font.custom(annotation.font, size: effectiveStrokeWidth * 8)
            context.draw(Text(annotation.text).font(fontName).foregroundColor(color), at: scaledPoint, anchor: .topLeading)
            
        case .cursorSticker, .pointerSticker, .cursorStickerCircled, .pointerStickerCircled, .typingIndicatorSticker, .numberSticker:
            drawStickerAnnotation(annotation, in: context, size: size, effectiveStrokeWidth: effectiveStrokeWidth)
        }
    }

    private func drawStickerAnnotation(_ annotation: Annotation, in context: GraphicsContext, size: CGSize, effectiveStrokeWidth: CGFloat) {
        guard let point = annotation.points.first else { return }
        let anchor = scalePoint(point, to: size)
        guard let layout = StickerToolRenderer.layout(
            for: annotation.tool,
            anchor: anchor,
            displayStrokeWidth: effectiveStrokeWidth
        ) else { return }

        if annotation.tool == .numberSticker {
            drawNumberStickerAnnotation(annotation, in: layout.symbolRect, context: context)
            return
        }
        
        if let circleRect = layout.circleRect {
            let circlePath = Path(ellipseIn: circleRect)
            context.fill(circlePath, with: .color(.white))
            context.stroke(
                circlePath,
                with: .color(.black),
                style: StrokeStyle(lineWidth: 1.6)
            )
        }
        
        if let symbolImage = StickerToolRenderer.stickerImage(
            for: annotation.tool,
            pointSize: layout.symbolRect.height * 0.92,
            tintColor: annotation.tool.isNativeCursorSticker
                ? nil
                : (annotation.tool.showsStickerCircle ? .white : NSColor(annotation.color)),
            outlineColor: annotation.tool.isNativeCursorSticker
                ? nil
                : (annotation.tool.showsStickerCircle ? .black : nil)
        ) {
            let drawRect = StickerToolRenderer.fittedRect(for: symbolImage.size, in: layout.symbolRect)
            context.draw(Image(nsImage: symbolImage), in: drawRect)
        } else {
            drawStickerFallback(annotation.tool, in: layout.symbolRect, context: context)
        }
    }

    private func drawNumberStickerAnnotation(_ annotation: Annotation, in rect: CGRect, context: GraphicsContext) {
        let fillColor = NSColor(annotation.color)
        let textColor = numberStickerTextColor(for: fillColor)
        let value = annotation.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "?" : annotation.text

        let circlePath = Path(ellipseIn: rect)
        context.fill(circlePath, with: .color(Color(nsColor: fillColor)))
        context.stroke(
            circlePath,
            with: .color(textColor.opacity(0.35)),
            style: StrokeStyle(lineWidth: max(1.2, rect.width * 0.05))
        )
        context.draw(
            Text(value)
                .font(.system(size: max(10, rect.height * 0.56), weight: .bold, design: .rounded))
                .foregroundColor(textColor),
            at: CGPoint(x: rect.midX, y: rect.midY),
            anchor: .center
        )
    }

    private func numberStickerTextColor(for fillColor: NSColor) -> Color {
        let color = fillColor.usingColorSpace(.sRGB) ?? fillColor
        let luminance = (0.2126 * color.redComponent) + (0.7152 * color.greenComponent) + (0.0722 * color.blueComponent)
        return luminance >= 0.58 ? .black : .white
    }

    private func drawStickerFallback(_ tool: AnnotationTool, in rect: CGRect, context: GraphicsContext) {
        switch tool {
        case .typingIndicatorSticker:
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            context.stroke(
                path,
                with: .color(.black),
                style: StrokeStyle(lineWidth: max(1.5, rect.width * 0.2), lineCap: .round)
            )
        case .numberSticker:
            context.fill(Path(ellipseIn: rect), with: .color(.black))
        default:
            var cursorPath = Path()
            cursorPath.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            cursorPath.addLine(to: CGPoint(x: rect.minX + rect.width * 0.82, y: rect.midY))
            cursorPath.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            cursorPath.closeSubpath()
            context.fill(cursorPath, with: .color(.black))
        }
    }

    private func drawMagnifierAnnotation(
        _ annotation: Annotation,
        in context: GraphicsContext,
        size: CGSize,
        effectiveStrokeWidth: CGFloat,
        showResizeIndicator: Bool
    ) {
        guard let sourcePoint = annotation.points.first else { return }

        let source = scalePoint(sourcePoint, to: size)
        let fallbackLens = defaultMagnifierLensPoint(from: source, in: size)
        let rawLens: CGPoint
        if annotation.points.count > 1 {
            rawLens = scalePoint(annotation.points[1], to: size)
        } else {
            rawLens = fallbackLens
        }

        let containerMinDimension = max(1, min(size.width, size.height))
        let defaultLensRadius = defaultMagnifierRadius(forStrokeWidth: effectiveStrokeWidth)
        let lensRadius = magnifierDisplayRadius(
            for: annotation,
            displayStrokeWidth: effectiveStrokeWidth,
            containerMinDimension: containerMinDimension
        )
        let sourceRadius = max(14, lensRadius * 0.34)
        let lens = clampMagnifierLensCenter(rawLens, radius: lensRadius, in: size)

        let connectorColor = annotation.color
        var connectorPath = Path()
        let connectorVector = CGPoint(x: lens.x - source.x, y: lens.y - source.y)
        let connectorDistance = hypot(connectorVector.x, connectorVector.y)
        if connectorDistance > 0.001 {
            let ux = connectorVector.x / connectorDistance
            let uy = connectorVector.y / connectorDistance
            connectorPath.move(
                to: CGPoint(
                    x: source.x + ux * sourceRadius,
                    y: source.y + uy * sourceRadius
                )
            )
            connectorPath.addLine(
                to: CGPoint(
                    x: lens.x - ux * lensRadius,
                    y: lens.y - uy * lensRadius
                )
            )
            context.stroke(
                connectorPath,
                with: .color(connectorColor),
                style: StrokeStyle(lineWidth: max(2.0, effectiveStrokeWidth * 0.9), lineCap: .round)
            )
        }

        let sourceMarkerRect = CGRect(
            x: source.x - sourceRadius,
            y: source.y - sourceRadius,
            width: sourceRadius * 2,
            height: sourceRadius * 2
        )
        let sourceMarkerPath = Path(ellipseIn: sourceMarkerRect)
        context.stroke(
            sourceMarkerPath,
            with: .color(connectorColor),
            style: StrokeStyle(lineWidth: max(1.8, effectiveStrokeWidth * 0.85))
        )

        let lensRect = CGRect(
            x: lens.x - lensRadius,
            y: lens.y - lensRadius,
            width: lensRadius * 2,
            height: lensRadius * 2
        )
        let lensPath = Path(ellipseIn: lensRect)
        context.fill(lensPath, with: .color(.white.opacity(0.95)))

        let magnification = magnifierMagnification(for: lensRadius, defaultRadius: defaultLensRadius)
        let sampleDiameter = max(8, lensRect.width / magnification)
        let scaleX = max(1, imageSize.width) / max(1, size.width)
        let scaleY = max(1, imageSize.height) / max(1, size.height)
        let sourceCenter = CGPoint(
            x: source.x * scaleX,
            y: (size.height - source.y) * scaleY
        )
        let imageBounds = CGRect(origin: .zero, size: imageSize)
        let sampleRect = CGRect(
            x: sourceCenter.x - (sampleDiameter * scaleX) / 2,
            y: sourceCenter.y - (sampleDiameter * scaleY) / 2,
            width: sampleDiameter * scaleX,
            height: sampleDiameter * scaleY
        ).intersection(imageBounds)

        if sampleRect.width > 1, sampleRect.height > 1 {
            let lensImageSize = NSSize(width: lensRect.width, height: lensRect.height)
            let lensImage = NSImage(size: lensImageSize)
            lensImage.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .high
            originalImage.draw(
                in: NSRect(origin: .zero, size: lensImageSize),
                from: sampleRect,
                operation: .copy,
                fraction: 1.0
            )
            lensImage.unlockFocus()

            context.drawLayer { layer in
                layer.clip(to: lensPath)
                layer.draw(Image(nsImage: lensImage), in: lensRect)
            }
        }

        context.stroke(
            lensPath,
            with: .color(connectorColor),
            style: StrokeStyle(lineWidth: max(2.2, effectiveStrokeWidth * 0.95))
        )
        context.stroke(
            Path(ellipseIn: lensRect.insetBy(dx: max(1.4, effectiveStrokeWidth * 0.5), dy: max(1.4, effectiveStrokeWidth * 0.5))),
            with: .color(.black.opacity(0.82)),
            style: StrokeStyle(lineWidth: max(1.0, effectiveStrokeWidth * 0.45))
        )

        if showResizeIndicator {
            // Native-style resize knob: larger circular grip with diagonal expand arrows.
            let angle: CGFloat = -.pi / 4
            let handleRadius = max(8.2, effectiveStrokeWidth * 1.9)
            let handleDistance = lensRadius + handleRadius * 0.16
            let handleCenter = CGPoint(
                x: lens.x + cos(angle) * handleDistance,
                y: lens.y + sin(angle) * handleDistance
            )
            let handleRect = CGRect(
                x: handleCenter.x - handleRadius,
                y: handleCenter.y - handleRadius,
                width: handleRadius * 2,
                height: handleRadius * 2
            )
            let handlePath = Path(ellipseIn: handleRect)
            let shadowRect = handleRect.offsetBy(dx: 0, dy: -0.8)
            context.fill(
                Path(ellipseIn: shadowRect),
                with: .color(.black.opacity(0.34))
            )
            context.fill(handlePath, with: .color(.white.opacity(0.98)))
            context.stroke(
                handlePath,
                with: .color(.black.opacity(0.85)),
                style: StrokeStyle(lineWidth: max(1.0, effectiveStrokeWidth * 0.44))
            )

            let ux = cos(angle)
            let uy = sin(angle)
            let px = -uy
            let py = ux
            let shaftHalf = handleRadius * 0.34
            let tipDistance = handleRadius * 0.58
            let wingLength = handleRadius * 0.24
            let wingBack = handleRadius * 0.25

            var gripPath = Path()
            gripPath.move(
                to: CGPoint(
                    x: handleCenter.x - ux * shaftHalf,
                    y: handleCenter.y - uy * shaftHalf
                )
            )
            gripPath.addLine(
                to: CGPoint(
                    x: handleCenter.x + ux * shaftHalf,
                    y: handleCenter.y + uy * shaftHalf
                )
            )

            let tip1 = CGPoint(
                x: handleCenter.x + ux * tipDistance,
                y: handleCenter.y + uy * tipDistance
            )
            let back1 = CGPoint(
                x: tip1.x - ux * wingBack,
                y: tip1.y - uy * wingBack
            )
            gripPath.move(to: tip1)
            gripPath.addLine(to: CGPoint(x: back1.x + px * wingLength, y: back1.y + py * wingLength))
            gripPath.move(to: tip1)
            gripPath.addLine(to: CGPoint(x: back1.x - px * wingLength, y: back1.y - py * wingLength))

            let tip2 = CGPoint(
                x: handleCenter.x - ux * tipDistance,
                y: handleCenter.y - uy * tipDistance
            )
            let back2 = CGPoint(
                x: tip2.x + ux * wingBack,
                y: tip2.y + uy * wingBack
            )
            gripPath.move(to: tip2)
            gripPath.addLine(to: CGPoint(x: back2.x + px * wingLength, y: back2.y + py * wingLength))
            gripPath.move(to: tip2)
            gripPath.addLine(to: CGPoint(x: back2.x - px * wingLength, y: back2.y - py * wingLength))

            context.stroke(
                gripPath,
                with: .color(.black.opacity(0.84)),
                style: StrokeStyle(lineWidth: max(1.0, effectiveStrokeWidth * 0.34), lineCap: .round, lineJoin: .round)
            )
        }
    }
    
    private func drawImageOverlayAnnotation(
        _ annotation: Annotation,
        in context: GraphicsContext,
        size: CGSize,
        effectiveStrokeWidth: CGFloat
    ) {
        guard annotation.points.count > 1 else { return }
        let rect = rectFromPoints(annotation.points[0], annotation.points[1], size: size)
        guard rect.width > 2, rect.height > 2 else { return }

        let cornerRadius = imageOverlayCornerRadius(for: annotation, in: size, rect: rect)
        let clipPath = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)

        context.drawLayer { layer in
            layer.clip(to: clipPath)
            if let overlayImage = overlayImagesByPath[annotation.imagePath] {
                layer.draw(
                    Image(nsImage: overlayImage),
                    in: aspectFillRect(for: overlayImage.size, in: rect)
                )
            } else {
                layer.fill(Path(rect), with: .color(.black.opacity(0.16)))
            }
        }

        context.stroke(
            clipPath,
            with: .color(.white.opacity(0.28)),
            style: StrokeStyle(lineWidth: max(1.2, effectiveStrokeWidth * 0.34))
        )
    }

    private func imageOverlayCornerRadius(for annotation: Annotation, in size: CGSize, rect: CGRect) -> CGFloat {
        var radius = max(0, annotation.imageCornerRadius)
        if annotation.referenceCanvasMinDimension > 1 {
            radius *= max(1, min(size.width, size.height)) / annotation.referenceCanvasMinDimension
        }
        return min(radius, min(rect.width, rect.height) / 2)
    }

    private func aspectFillRect(for sourceSize: NSSize, in destinationRect: CGRect) -> CGRect {
        let safeSourceWidth = max(sourceSize.width, 1)
        let safeSourceHeight = max(sourceSize.height, 1)
        let scale = max(destinationRect.width / safeSourceWidth, destinationRect.height / safeSourceHeight)
        let drawSize = CGSize(width: safeSourceWidth * scale, height: safeSourceHeight * scale)
        return CGRect(
            x: destinationRect.midX - drawSize.width / 2,
            y: destinationRect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
    }

    private func resolvedArrowCurveOffset(for annotation: Annotation, start: CGPoint, end: CGPoint, in size: CGSize) -> CGFloat {
        let distance = hypot(end.x - start.x, end.y - start.y)
        guard distance > 0.001 else { return 0 }

        if abs(annotation.curveOffset) > 0.001 {
            let containerMinDimension = max(1, min(size.width, size.height))
            guard annotation.referenceCanvasMinDimension > 1 else { return annotation.curveOffset }
            return annotation.curveOffset * (containerMinDimension / annotation.referenceCanvasMinDimension)
        }

        if annotation.tool == .curvedArrow {
            return min(max(distance * 0.28, 20), 120)
        }
        return 0
    }

    private func resolvedArrowCurveControlPoint(for annotation: Annotation, start: CGPoint, end: CGPoint, in size: CGSize) -> CGPoint {
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)

        if annotation.hasCustomCurveControl {
            let containerMinDimension = max(1, min(size.width, size.height))
            let displayOffset: CGSize
            if annotation.referenceCanvasMinDimension > 1 {
                let scale = containerMinDimension / annotation.referenceCanvasMinDimension
                displayOffset = CGSize(
                    width: annotation.curveControlOffset.width * scale,
                    height: annotation.curveControlOffset.height * scale
                )
            } else {
                displayOffset = annotation.curveControlOffset
            }
            return CGPoint(x: mid.x + displayOffset.width, y: mid.y + displayOffset.height)
        }

        let fallbackOffset = resolvedArrowCurveOffset(for: annotation, start: start, end: end, in: size)
        return curvedArrowControlPoint(from: start, to: end, curveOffset: fallbackOffset)
    }

    private func drawCurveArrowHandle(
        controlPoint: CGPoint,
        color: Color,
        strokeStyle: StrokeStyle,
        in context: GraphicsContext
    ) {
        let handleCenter = controlPoint
        let handleRadius = max(5.0, strokeStyle.lineWidth * 1.25)
        let handleRect = CGRect(
            x: handleCenter.x - handleRadius,
            y: handleCenter.y - handleRadius,
            width: handleRadius * 2,
            height: handleRadius * 2
        )
        let handlePath = Path(ellipseIn: handleRect)
        context.fill(handlePath, with: .color(.white.opacity(0.94)))
        context.stroke(
            handlePath,
            with: .color(color),
            style: StrokeStyle(lineWidth: max(1.1, strokeStyle.lineWidth * 0.55))
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

    private func drawArrow(
        from start: CGPoint,
        to end: CGPoint,
        color: Color,
        strokeStyle: StrokeStyle,
        curveControlPoint: CGPoint? = nil,
        in context: GraphicsContext
    ) {
        var linePath = Path()
        let directionVector: CGPoint
        let curveDistance = curveControlPoint.map { pointToSegmentDistance($0, start: start, end: end) } ?? 0
        if let control = curveControlPoint, curveDistance > 0.5 {
            linePath.move(to: start)
            linePath.addQuadCurve(to: end, control: control)
            directionVector = CGPoint(x: end.x - control.x, y: end.y - control.y)
        } else {
            linePath.move(to: start)
            linePath.addLine(to: end)
            directionVector = CGPoint(x: end.x - start.x, y: end.y - start.y)
        }
        context.stroke(linePath, with: .color(color), style: strokeStyle)

        let fallback = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let headVector = hypot(directionVector.x, directionVector.y) > 0.001 ? directionVector : fallback
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

    private func drawCurvedArrow(
        from start: CGPoint,
        to end: CGPoint,
        color: Color,
        strokeStyle: StrokeStyle,
        curveControlPoint: CGPoint,
        in context: GraphicsContext
    ) {
        drawArrow(from: start, to: end, color: color, strokeStyle: strokeStyle, curveControlPoint: curveControlPoint, in: context)
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

    private func defaultMagnifierLensPoint(from source: CGPoint, in size: CGSize) -> CGPoint {
        let offset = max(80, min(size.width, size.height) * 0.16)
        return CGPoint(x: source.x + offset, y: source.y + offset)
    }

    private func clampMagnifierLensCenter(_ center: CGPoint, radius: CGFloat, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(center.x, radius + 4), max(radius + 4, size.width - radius - 4)),
            y: min(max(center.y, radius + 4), max(radius + 4, size.height - radius - 4))
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
    
    private func curvedArrowControlPoint(from start: CGPoint, to end: CGPoint, curveOffset: CGFloat? = nil) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        guard distance > 0.001 else {
            return CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        }
        
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let normal = CGPoint(x: -dy / distance, y: dx / distance)
        let curveAmount = curveOffset ?? min(max(distance * 0.28, 20), 120)
        
        return CGPoint(
            x: mid.x + normal.x * curveAmount,
            y: mid.y + normal.y * curveAmount
        )
    }
}
