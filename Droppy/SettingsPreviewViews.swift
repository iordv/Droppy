import SwiftUI

// MARK: - Settings Preview Components
// Extracted from SettingsView.swift for faster incremental builds

struct FeaturePreviewGIF: View {
    let url: String
    
    var body: some View {
        AnimatedGIFView(url: url)
            .frame(maxWidth: 500, maxHeight: 200)
            .frame(maxWidth: .infinity, alignment: .center)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.4), location: 0),
                                .init(color: .white.opacity(0.1), location: 0.5),
                                .init(color: .black.opacity(0.2), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            .padding(.vertical, 8)
    }
}

/// Static image preview with same styling as GIF previews
struct FeaturePreviewImage: View {
    let url: String
    @State private var image: NSImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ProgressView()
                    .frame(height: 60)
            }
        }
        .frame(maxWidth: 250, maxHeight: 80)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
        .task {
            guard let imageURL = URL(string: url) else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                if let loadedImage = NSImage(data: data) {
                    await MainActor.run {
                        self.image = loadedImage
                    }
                }
            } catch {
                print("Failed to load preview image: \(error)")
            }
        }
    }
}

/// Native NSImageView-based GIF display (crash-safe, no WebKit)
struct AnimatedGIFView: NSViewRepresentable {
    let url: String
    
    func makeNSView(context: Context) -> NSView {
        // Container view to properly constrain the image
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.animates = true
        imageView.imageScaling = .scaleProportionallyDown  // Only scale DOWN, never up
        imageView.canDrawSubviewsIntoLayer = true
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        container.addSubview(imageView)
        
        // Center the image within the container and constrain its edges
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            imageView.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor),
            imageView.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        
        // Store imageView reference for loading
        context.coordinator.imageView = imageView
        
        // Load GIF data asynchronously
        if let gifURL = URL(string: url) {
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: gifURL)
                    if let image = NSImage(data: data) {
                        await MainActor.run {
                            context.coordinator.imageView?.image = image
                        }
                    }
                } catch {
                    print("GIF load failed: \(error)")
                }
            }
        }
        
        return container
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Ensure animation is running
        context.coordinator.imageView?.animates = true
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        weak var imageView: NSImageView?
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - U-Shape for Notch Icon Preview
/// Simple U-shape for notch mode icon in settings picker
struct UShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 6
        
        // Start top-left
        path.move(to: CGPoint(x: 0, y: 0))
        // Down left side
        path.addLine(to: CGPoint(x: 0, y: rect.height - radius))
        // Bottom-left corner
        path.addQuadCurve(
            to: CGPoint(x: radius, y: rect.height),
            control: CGPoint(x: 0, y: rect.height)
        )
        // Across bottom
        path.addLine(to: CGPoint(x: rect.width - radius, y: rect.height))
        // Bottom-right corner
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height - radius),
            control: CGPoint(x: rect.width, y: rect.height)
        )
        // Up right side
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        
        return path
    }
}

// MARK: - Display Mode Button
// Note: DisplayModeButton is now defined in SharedComponents.swift

// MARK: - HUD Toggle Button (2x2 Grid)

/// Compact toggle button for HUD settings grid - uses shared AnimatedHUDToggle
struct HUDToggleButton: View {
    let title: String
    let icon: String
    @Binding var isEnabled: Bool
    var color: Color = .white
    
    var body: some View {
        AnimatedHUDToggle(
            icon: icon,
            title: title,
            isOn: $isEnabled,
            color: color,
            fixedWidth: nil  // Flexible - fills grid cell
        )
    }
}

// MARK: - Volume & Brightness Toggle (Special Morph Animation)
// Note: VolumeAndBrightnessToggle is now defined in SharedComponents.swift

// MARK: - SwiftUI Feature Previews (Using REAL Components)

/// Volume/Brightness HUD Preview - uses REAL NotchShape and HUDSlider
struct VolumeHUDPreview: View {
    @State private var animatedValue: CGFloat = 0.65
    
    // Match real notch dimensions from NotchShelfView
    private let hudWidth: CGFloat = 280
    private let notchWidth: CGFloat = 180
    private let notchHeight: CGFloat = 32
    
    private var wingWidth: CGFloat { (hudWidth - notchWidth) / 2 }
    
    var body: some View {
        ZStack {
            // Notch background with proper rounded corners
            NotchShape(bottomRadius: 16)
                .fill(Color.black)
                .frame(width: hudWidth, height: notchHeight + 28)
                .overlay(
                    NotchShape(bottomRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            // HUD content - laid out exactly like real NotchHUDView
            VStack(spacing: 0) {
                // Wings: Icon (left) | Camera Gap | Percentage (right)
                HStack(spacing: 0) {
                    // Left wing - Icon
                    HStack {
                        Spacer(minLength: 0)
                        Image(systemName: volumeIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .symbolVariant(.fill)
                        Spacer(minLength: 0)
                    }
                    .frame(width: wingWidth)
                    
                    // Camera notch gap
                    Spacer().frame(width: notchWidth)
                    
                    // Right wing - Percentage (clipped to prevent animation overflow)
                    HStack {
                        Spacer(minLength: 0)
                        Text("\(Int(animatedValue * 100))%")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        Spacer(minLength: 0)
                    }
                    .frame(width: wingWidth)
                    .clipped()
                }
                .frame(height: notchHeight)
                
                // REAL HUDSlider below notch
                HUDSlider(
                    value: $animatedValue,
                    accentColor: .white,
                    isActive: false,
                    onChange: nil
                )
                .frame(height: 20)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                .allowsHitTesting(false)
            }
            .frame(width: hudWidth)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animatedValue = 0.35
            }
        }
    }
    
    private var volumeIcon: String {
        if animatedValue == 0 { return "speaker.slash.fill" }
        if animatedValue < 0.33 { return "speaker.wave.1.fill" }
        if animatedValue < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

/// Media Player Preview - uses REAL NotchShape, AudioSpectrumView, and MarqueeText
struct MediaPlayerPreview: View {
    @State private var isPlaying = true
    
    // Match real notch dimensions
    private let hudWidth: CGFloat = 280
    private let notchWidth: CGFloat = 180
    private let notchHeight: CGFloat = 32
    
    private var wingWidth: CGFloat { (hudWidth - notchWidth) / 2 }
    
    var body: some View {
        ZStack {
            // Notch background with proper rounded corners
            NotchShape(bottomRadius: 16)
                .fill(Color.black)
                .frame(width: hudWidth, height: notchHeight + 28)
                .overlay(
                    NotchShape(bottomRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            // HUD content - laid out exactly like real MediaHUDView
            VStack(spacing: 0) {
                // Wings: Album (left) | Camera Gap | Visualizer (right)
                HStack(spacing: 0) {
                    // Left wing - Album art
                    HStack {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.8))
                            )
                        Spacer(minLength: 0)
                    }
                    .frame(width: wingWidth)
                    
                    // Camera notch gap
                    Spacer().frame(width: notchWidth)
                    
                    // Right wing - REAL AudioSpectrumView
                    HStack {
                        Spacer(minLength: 0)
                        AudioSpectrumView(isPlaying: isPlaying, barCount: 4, barWidth: 3, spacing: 2, height: 16, color: .orange)
                            .frame(width: 4 * 3 + 3 * 2, height: 16)
                        Spacer(minLength: 0)
                    }
                    .frame(width: wingWidth)
                }
                .frame(height: notchHeight)
                
                // REAL MarqueeText below notch
                MarqueeText(text: "Purple Rain — Prince", speed: 30)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(height: 18)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }
            .frame(width: hudWidth)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPlaying.toggle()
                }
            }
        }
    }
}

/// Clipboard Preview - realistic split view matching ClipboardWindow
struct ClipboardPreview: View {
    var body: some View {
        HStack(spacing: 0) {
            // Left: Item list
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                    Text("History")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                
                Divider().background(Color.white.opacity(0.1))
                
                // Items
                VStack(spacing: 2) {
                    ClipboardMockItem(icon: "doc.text.fill", text: "Hello World", color: .blue, isSelected: true)
                    ClipboardMockItem(icon: "link", text: "droppy.app", color: .green, isSelected: false)
                    ClipboardMockItem(icon: "photo.fill", text: "Image.png", color: .purple, isSelected: false)
                }
                .padding(4)
                
                Spacer(minLength: 0)
            }
            .frame(width: 110)
            
            Divider().background(Color.white.opacity(0.1))
            
            // Right: Preview pane
            VStack {
                Spacer()
                VStack(spacing: 4) {
                    Text("Hello World")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                    Text("Copied text")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                
                // Paste button
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 8))
                    Text("Paste")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(.bottom, 8)
            }
            .frame(width: 90)
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .frame(width: 200, height: 120)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

/// Single mock item for ClipboardPreview
private struct ClipboardMockItem: View {
    let icon: String
    let text: String
    let color: Color
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(color)
                .frame(width: 12)
            
            Text(text)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.7))
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(isSelected ? Color.blue.opacity(0.3) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

/// Battery HUD Preview - animated charging state with real battery icon
struct BatteryHUDPreview: View {
    @State private var isCharging = false
    @State private var batteryLevel: Int = 75
    
    // Match real notch dimensions
    private let hudWidth: CGFloat = 280
    private let notchWidth: CGFloat = 180
    private let notchHeight: CGFloat = 32
    
    private var wingWidth: CGFloat { (hudWidth - notchWidth) / 2 }
    
    private var batteryIcon: String {
        if isCharging {
            return "battery.100.bolt"
        } else {
            switch batteryLevel {
            case 0...24: return "battery.25"
            case 25...49: return "battery.50"
            case 50...74: return "battery.75"
            default: return "battery.100"
            }
        }
    }
    
    private var batteryColor: Color {
        if isCharging { return .green }
        if batteryLevel <= 20 { return .red }
        return .white // White when not charging
    }
    
    var body: some View {
        ZStack {
            // Notch background with proper rounded corners
            NotchShape(bottomRadius: 16)
                .fill(Color.black)
                .frame(width: hudWidth, height: notchHeight)
                .overlay(
                    NotchShape(bottomRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            // Wings: Battery (left) | Camera Gap | Percentage (right)
            HStack(spacing: 0) {
                // Left wing - Battery icon with animation
                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: batteryIcon)
                        .font(.system(size: 22))
                        .foregroundStyle(batteryColor)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.pulse, options: .repeating, isActive: isCharging)
                    Spacer(minLength: 0)
                }
                .frame(width: wingWidth)
                
                // Camera notch gap
                Spacer().frame(width: notchWidth)
                
                // Right wing - Percentage
                HStack {
                    Spacer(minLength: 0)
                    Text("\(batteryLevel)%")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(batteryLevel)))
                    Spacer(minLength: 0)
                }
                .frame(width: wingWidth)
            }
            .frame(width: hudWidth, height: notchHeight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .onAppear {
            // Animate charging state and battery level
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isCharging.toggle()
                    // Animate battery level when charging
                    if isCharging {
                        batteryLevel = min(100, batteryLevel + 10)
                    } else {
                        batteryLevel = 75 // Reset
                    }
                }
            }
        }
    }
}

/// Caps Lock HUD Preview - animated ON/OFF state toggle
struct CapsLockHUDPreview: View {
    @State private var isCapsLockOn = true
    
    // Match real notch dimensions
    private let hudWidth: CGFloat = 280
    private let notchWidth: CGFloat = 180
    private let notchHeight: CGFloat = 32
    
    private var wingWidth: CGFloat { (hudWidth - notchWidth) / 2 }
    
    private var capsLockIcon: String {
        isCapsLockOn ? "capslock.fill" : "capslock"
    }
    
    private var accentColor: Color {
        isCapsLockOn ? .green : .white
    }
    
    var body: some View {
        ZStack {
            // Notch background with proper rounded corners
            NotchShape(bottomRadius: 16)
                .fill(Color.black)
                .frame(width: hudWidth, height: notchHeight)
                .overlay(
                    NotchShape(bottomRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            // Wings: Caps Lock (left) | Camera Gap | ON/OFF (right)
            HStack(spacing: 0) {
                // Left wing - Caps Lock icon with animation
                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: capsLockIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.pulse, options: .repeating, isActive: isCapsLockOn)
                    Spacer(minLength: 0)
                }
                .frame(width: wingWidth)
                
                // Camera notch gap
                Spacer().frame(width: notchWidth)
                
                // Right wing - ON/OFF text
                HStack {
                    Spacer(minLength: 0)
                    Text(isCapsLockOn ? "ON" : "OFF")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(accentColor)
                        .contentTransition(.interpolate)
                    Spacer(minLength: 0)
                }
                .frame(width: wingWidth)
            }
            .frame(width: hudWidth, height: notchHeight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .onAppear {
            // Animate ON/OFF state
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isCapsLockOn.toggle()
                }
            }
        }
    }
}

/// Floating Basket Preview - realistic mock matching FloatingBasketView
struct FloatingBasketPreview: View {
    @State private var dashPhase: CGFloat = 0
    
    private let cornerRadius: CGFloat = 20
    private let previewWidth: CGFloat = 220
    private let previewHeight: CGFloat = 150
    private let insetPadding: CGFloat = 20 // Symmetrical padding from dotted border
    
    var body: some View {
        ZStack {
                // Background with animated dashed border
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius - 10, style: .continuous)
                            .stroke(
                                Color.white.opacity(0.2),
                                style: StrokeStyle(
                                    lineWidth: 1.5,
                                    lineCap: .round,
                                    dash: [6, 8],
                                    dashPhase: dashPhase
                                )
                            )
                            .padding(10)
                    )
                
                // Content - symmetrical padding from dotted border
                VStack(spacing: 10) {
                    // Header - moved up for symmetry
                    HStack(spacing: 8) {
                        Text("3 items")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // To Shelf button - single line
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.to.line")
                                .font(.system(size: 8, weight: .bold))
                            Text("To Shelf")
                                .font(.system(size: 8, weight: .semibold))
                                .fixedSize() // Prevent wrapping
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        
                        // Clear button
                        Image(systemName: "eraser.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Mock items grid - centered
                    HStack(spacing: 12) {
                        MockFileItem(icon: "doc.fill", color: .blue, name: "Document")
                        MockFileItem(icon: "photo.fill", color: .purple, name: "Image.png")
                        MockFileItem(icon: "folder.fill", color: .cyan, name: "Folder")
                    }
                }
                .padding(insetPadding) // Symmetrical padding on all sides
            }
            .frame(width: previewWidth, height: previewHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .onAppear {
            // Dashed border animation
            withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
                dashPhase -= 280
            }
        }
    }
}

/// Animated preview demonstrating the Auto-Hide Peek feature
struct PeekPreview: View {
    let edge: String
    
    @State private var isPeeking = false
    @State private var dashPhase: CGFloat = 0
    
    private let containerWidth: CGFloat = 280
    private let containerHeight: CGFloat = 100
    private let basketWidth: CGFloat = 100
    private let basketHeight: CGFloat = 70
    private let peekAmount: CGFloat = 20 // How much stays visible
    
    var body: some View {
        ZStack {
            // Container representing the screen
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.12))
                .overlay(
                    Text("Screen")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.quaternary)
                        .padding(.leading, 8)
                        .padding(.top, 6)
                    , alignment: .topLeading
                )
            
            // Mini basket that peeks
            miniBasket
                .offset(basketOffset)
                .rotation3DEffect(
                    .degrees(isPeeking ? rotationAngle : 0),
                    axis: rotationAxis,
                    perspective: 0.5
                )
                .scaleEffect(isPeeking ? 0.92 : 1.0)
                .animation(.easeInOut(duration: isPeeking ? 0.55 : 0.25), value: isPeeking)
        }
        .frame(width: containerWidth, height: containerHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .onAppear {
            // Delay initial start
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                startAnimationCycle()
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                dashPhase -= 280
            }
        }
        .onChange(of: edge) { _, _ in
            isPeeking = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                startAnimationCycle()
            }
        }
    }
    
    private let miniBasketScale: CGFloat = 0.5
    
    private var miniBasket: some View {
        ZStack {
            // Background with animated dashed border
            RoundedRectangle(cornerRadius: 20 * miniBasketScale, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 12 * miniBasketScale, style: .continuous)
                        .stroke(
                            Color.white.opacity(0.2),
                            style: StrokeStyle(
                                lineWidth: 1.5 * miniBasketScale,
                                lineCap: .round,
                                dash: [6 * miniBasketScale, 8 * miniBasketScale],
                                dashPhase: dashPhase * miniBasketScale
                            )
                        )
                        .padding(10 * miniBasketScale)
                )
            
            // Content - matching real basket layout
            VStack(spacing: 6 * miniBasketScale) {
                // Header row
                HStack(spacing: 4 * miniBasketScale) {
                    Text("3 items")
                        .font(.system(size: 10 * miniBasketScale, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // To Shelf button
                    HStack(spacing: 2 * miniBasketScale) {
                        Image(systemName: "arrow.up.to.line")
                            .font(.system(size: 8 * miniBasketScale, weight: .bold))
                        Text("To Shelf")
                            .font(.system(size: 8 * miniBasketScale, weight: .semibold))
                            .fixedSize()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6 * miniBasketScale)
                    .padding(.vertical, 4 * miniBasketScale)
                    .background(Color.blue.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 16 * miniBasketScale, style: .continuous))
                    
                    // Clear button
                    Image(systemName: "eraser.fill")
                        .font(.system(size: 8 * miniBasketScale, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 16 * miniBasketScale, height: 16 * miniBasketScale)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14 * miniBasketScale, style: .continuous))
                }
                
                Spacer(minLength: 0)
                
                // File items grid
                HStack(spacing: 8 * miniBasketScale) {
                    MiniFileItem(icon: "doc.fill", color: .blue, name: "Document", scale: miniBasketScale)
                    MiniFileItem(icon: "photo.fill", color: .purple, name: "Image.png", scale: miniBasketScale)
                    MiniFileItem(icon: "folder.fill", color: .cyan, name: "Folder", scale: miniBasketScale)
                }
            }
            .padding(12 * miniBasketScale)
        }
        .frame(width: basketWidth, height: basketHeight)
        .clipShape(RoundedRectangle(cornerRadius: 20 * miniBasketScale, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20 * miniBasketScale, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 8 * miniBasketScale, x: 0, y: 4 * miniBasketScale)
    }
    
    private var basketOffset: CGSize {
        if isPeeking {
            switch edge {
            case "left":
                return CGSize(width: -(containerWidth/2 - peekAmount + basketWidth/2), height: 0)
            case "right":
                return CGSize(width: (containerWidth/2 - peekAmount + basketWidth/2), height: 0)
            case "bottom":
                return CGSize(width: 0, height: (containerHeight/2 - peekAmount + basketHeight/2))
            default:
                return CGSize(width: (containerWidth/2 - peekAmount + basketWidth/2), height: 0)
            }
        } else {
            return .zero
        }
    }
    
    private var rotationAngle: Double {
        // Match real peek: ~10 degrees (0.18 radians ≈ 10.3°)
        switch edge {
        case "left": return 10
        case "right": return -10
        case "bottom": return 10
        default: return -10
        }
    }
    
    private var rotationAxis: (x: CGFloat, y: CGFloat, z: CGFloat) {
        switch edge {
        case "left", "right": return (x: 0, y: 1, z: 0)
        case "bottom": return (x: 1, y: 0, z: 0)
        default: return (x: 0, y: 1, z: 0)
        }
    }
    
    private func startAnimationCycle() {
        // Step 1: Slide to peek position (0.55s - matches real)
        isPeeking = true
        
        // Step 2: Stay peeking for 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            // Step 3: Reveal back (0.25s - matches real)
            isPeeking = false
            
            // Step 4: Stay visible for 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                // Step 5: Wait 4 more seconds before repeating
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    startAnimationCycle()
                }
            }
        }
    }
}

/// Scaled file item for PeekPreview mini basket
private struct MiniFileItem: View {
    let icon: String
    let color: Color
    let name: String
    let scale: CGFloat
    
    var body: some View {
        VStack(spacing: 4 * scale) {
            Image(systemName: icon)
                .font(.system(size: 22 * scale))
                .foregroundStyle(color)
                .frame(width: 44 * scale, height: 44 * scale)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
            
            Text(name)
                .font(.system(size: 7 * scale))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

/// Mock file item for basket and shelf previews
private struct MockFileItem: View {
    let icon: String
    let color: Color
    let name: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            
            Text(name)
                .font(.system(size: 7))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

/// Notch Shelf Preview - realistic mock matching NotchShelfView expanded state
struct NotchShelfPreview: View {
    @State private var dashPhase: CGFloat = 0
    @State private var bounce = false
    
    // Notch dimensions
    private let notchWidth: CGFloat = 180
    private let notchHeight: CGFloat = 32
    private let shelfWidth: CGFloat = 280
    private let shelfHeight: CGFloat = 70
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Expanded shelf background with NotchShape
                NotchShape(bottomRadius: 16)
                    .fill(Color.black)
                    .frame(width: shelfWidth, height: shelfHeight)
                    .overlay(
                        // BLUE marching ants - matches real drag indicator
                        NotchShape(bottomRadius: 12)
                            .stroke(
                                Color.blue,
                                style: StrokeStyle(
                                    lineWidth: 2,
                                    lineCap: .round,
                                    dash: [6, 8],
                                    dashPhase: dashPhase
                                )
                            )
                            .padding(8)
                    )
                    .overlay(
                        NotchShape(bottomRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                
                // REAL "Drop!" indicator - exact copy from NotchShelfView.dropIndicatorContent
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: notchHeight)
                    
                    // Real drop indicator content
                    HStack(spacing: 8) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white, .green)
                            .symbolEffect(.bounce, value: bounce)
                        
                        Text("Drop!")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                    )
                    
                    Spacer()
                }
            }
            .frame(width: shelfWidth, height: shelfHeight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .onAppear {
            // Blue marching ants animation
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                dashPhase -= 280
            }
            // Bounce animation for icon
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                bounce = true
            }
        }
    }
}

/// Mock shelf item (smaller than basket items)
private struct MockShelfItem: View {
    let icon: String
    let color: Color
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 18))
            .foregroundStyle(color)
            .frame(width: 36, height: 36)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Open Shelf Indicator Preview - REAL component from NotchShelfView
struct OpenShelfIndicatorPreview: View {
    @State private var bounce = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white, .blue)
                .symbolEffect(.bounce, value: bounce)
            
            Text("Open Shelf")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .shadow(radius: 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                bounce = true
            }
        }
    }
}

/// Drop Indicator Preview - REAL component from NotchShelfView
struct DropIndicatorPreview: View {
    @State private var bounce = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white, .green)
                .symbolEffect(.bounce, value: bounce)
            
            Text("Drop!")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .shadow(radius: 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                bounce = true
            }
        }
    }
}

// MARK: - AI Background Removal Settings Row

// MARK: - Extensions Shop View

enum ExtensionCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case installed = "Installed"
    case disabled = "Disabled"
    case ai = "AI"
    case productivity = "Productivity"
    case media = "Media"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .installed: return "checkmark.circle.fill"
        case .disabled: return "xmark.circle"
        case .ai: return "sparkles"
        case .productivity: return "bolt.fill"
        case .media: return "music.note"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .white
        case .installed: return .green
        case .disabled: return .gray
        case .ai: return .purple
        case .productivity: return .orange
        case .media: return .green
        }
    }
}

