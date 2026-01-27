import SwiftUI

// MARK: - Settings Preview Components
// Extracted from SettingsView.swift for faster incremental builds

// MARK: - Premium Settings Icon

/// Reusable premium circular icon with gradient and 3D lighting effect
/// Used throughout Settings for a consistent, polished look
struct PremiumSettingsIcon: View {
    let icon: String
    let primaryColor: Color
    let secondaryColor: Color
    var size: CGFloat = 40
    var iconSize: CGFloat = 20
    
    init(icon: String, baseHue: Double, size: CGFloat = 40, iconSize: CGFloat = 20) {
        self.icon = icon
        self.size = size
        self.iconSize = iconSize
        // Slightly brighter/lighter at top
        self.primaryColor = Color(hue: baseHue, saturation: 0.60, brightness: 0.95)
        // Slightly darker/more saturated at bottom
        self.secondaryColor = Color(hue: baseHue, saturation: 0.80, brightness: 0.70)
    }
    
    init(icon: String, primaryColor: Color, secondaryColor: Color, size: CGFloat = 40, iconSize: CGFloat = 20) {
        self.icon = icon
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.size = size
        self.iconSize = iconSize
    }
    
    var body: some View {
        ZStack {
            // Gradient background
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [primaryColor, secondaryColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)
            
            // Subtle inner highlight at top for 3D effect
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: size, height: size)
            
            // Icon with subtle shadow
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0, y: 0.5)
        }
    }
}

/// Now Playing premium icon (pink play button style - squircle)
struct NowPlayingIcon: View {
    var size: CGFloat = 40
    
    var body: some View {
        ZStack {
            // Pink gradient background (squircle)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: 0.97, saturation: 0.50, brightness: 0.98), // Light pink
                            Color(hue: 0.95, saturation: 0.65, brightness: 0.85)  // Deeper pink
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)
            
            // Subtle inner highlight
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.30), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: size, height: size)
            
            // Play icon
            Image(systemName: "play.fill")
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0, y: 0.5)
        }
    }
}

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
    @State private var animationTimer: Timer?
    
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
            animationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                withAnimation(DroppyAnimation.state) {
                    isPlaying.toggle()
                }
            }
        }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }
}

/// Clipboard Preview - realistic mock matching ClipboardManagerView list items
struct ClipboardPreview: View {
    var body: some View {
        VStack(spacing: 6) {
            // Flagged items section - 2-column grid with subtle red
            HStack(spacing: 6) {
                ClipboardMockGridItem(icon: "doc.text", title: "Meeting Notes", isFlagged: true)
                ClipboardMockGridItem(icon: "key.fill", title: "API Key", isFlagged: true)
            }
            
            // Divider between flagged and regular
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 4)
            
            // Regular items
            ClipboardMockRow(icon: "text.alignleft", title: "Hello World", subtitle: "Safari • 10:42", isSelected: true)
            ClipboardMockRow(icon: "link", title: "https://getdroppy.app", subtitle: "Chrome • 10:38", isSelected: false)
            ClipboardMockRow(icon: "photo", title: "Screenshot.png", subtitle: "Finder • 10:35", isSelected: false, showStar: true)
        }
        .padding(8)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .frame(width: 240)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

/// Flagged item for 2-column grid
private struct ClipboardMockGridItem: View {
    let icon: String
    let title: String
    var isFlagged: Bool = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.white)
                .font(.system(size: 10))
            
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Spacer(minLength: 0)
            
            if isFlagged {
                Image(systemName: "flag.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 7))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.red.opacity(0.15))
        )
    }
}

/// Single mock row for ClipboardPreview matching ClipboardItemRow exactly
private struct ClipboardMockRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var isSelected: Bool = false
    var showStar: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Icon in squircle - matches real 32x32 squircle
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 24, height: 24)
                
                Image(systemName: icon)
                    .foregroundStyle(.white)
                    .font(.system(size: 10))
            }
            
            // Title and subtitle
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            
            Spacer(minLength: 0)
            
            // Star icon if favorited
            if showStar {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.system(size: 8))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected
                      ? Color.blue.opacity(0.8)
                      : Color.white.opacity(0.12))
        )
    }
}

/// Battery HUD Preview - animated charging state with real battery icon
struct BatteryHUDPreview: View {
    @State private var isCharging = false
    @State private var batteryLevel: Int = 75
    @State private var animationTimer: Timer?
    
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
            animationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                withAnimation(DroppyAnimation.transition) {
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
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }
}

/// Caps Lock HUD Preview - animated ON/OFF state toggle
struct CapsLockHUDPreview: View {
    @State private var isCapsLockOn = true
    @State private var animationTimer: Timer?
    
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
            animationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                withAnimation(DroppyAnimation.transition) {
                    isCapsLockOn.toggle()
                }
            }
        }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }
}

/// AirPods HUD Preview - shows stylized AirPods with battery indicator
struct AirPodsHUDPreview: View {
    @State private var rotation: Double = 0
    @State private var animationTimer: Timer?
    
    // Match real notch dimensions
    private let hudWidth: CGFloat = 280
    private let notchWidth: CGFloat = 180
    private let notchHeight: CGFloat = 32
    
    private var wingWidth: CGFloat { (hudWidth - notchWidth) / 2 }
    
    var body: some View {
        ZStack {
            // Notch background
            NotchShape(bottomRadius: 16)
                .fill(Color.black)
                .frame(width: hudWidth, height: notchHeight)
                .overlay(
                    NotchShape(bottomRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            // Wings: AirPods icon (left) | Camera Gap | Battery (right)
            HStack(spacing: 0) {
                // Left wing - AirPods icon with subtle rotation
                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: "airpodspro")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
                    Spacer(minLength: 0)
                }
                .frame(width: wingWidth)
                
                // Camera notch gap
                Spacer().frame(width: notchWidth)
                
                // Right wing - Battery percentage
                HStack {
                    Spacer(minLength: 0)
                    Text("85%")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.green)
                    Spacer(minLength: 0)
                }
                .frame(width: wingWidth)
            }
            .frame(width: hudWidth, height: notchHeight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .onAppear {
            // Subtle rotation animation
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                rotation = 15
            }
        }
        .onDisappear {
            animationTimer?.invalidate()
        }
    }
}

/// Lock Screen HUD Preview - shows lock icon animation
struct LockScreenHUDPreview: View {
    @State private var isLocked = true
    @State private var animationTimer: Timer?
    
    // Match real notch dimensions
    private let hudWidth: CGFloat = 280
    private let notchWidth: CGFloat = 180
    private let notchHeight: CGFloat = 32
    
    private var wingWidth: CGFloat { (hudWidth - notchWidth) / 2 }
    
    var body: some View {
        ZStack {
            // Notch background
            NotchShape(bottomRadius: 16)
                .fill(Color.black)
                .frame(width: hudWidth, height: notchHeight)
                .overlay(
                    NotchShape(bottomRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            // Wings: Lock icon (left) | Camera Gap | Status (right)
            HStack(spacing: 0) {
                // Left wing - Lock icon
                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(isLocked ? .purple : .white)
                        .contentTransition(.symbolEffect(.replace))
                    Spacer(minLength: 0)
                }
                .frame(width: wingWidth)
                
                // Camera notch gap
                Spacer().frame(width: notchWidth)
                
                // Right wing - Locked/Unlocked text
                HStack {
                    Spacer(minLength: 0)
                    Text(isLocked ? "Locked" : "Unlocked")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(isLocked ? .purple : .white)
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
            animationTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
                withAnimation(DroppyAnimation.transition) {
                    isLocked.toggle()
                }
            }
        }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }
}

/// Focus Mode HUD Preview - shows moon icon toggle animation
struct FocusModeHUDPreview: View {
    @State private var isFocusOn = true
    @State private var animationTimer: Timer?
    
    // Match real notch dimensions
    private let hudWidth: CGFloat = 280
    private let notchWidth: CGFloat = 180
    private let notchHeight: CGFloat = 32
    
    private var wingWidth: CGFloat { (hudWidth - notchWidth) / 2 }
    
    private var accentColor: Color {
        isFocusOn ? Color(red: 0.55, green: 0.35, blue: 0.95) : .white
    }
    
    var body: some View {
        ZStack {
            // Notch background
            NotchShape(bottomRadius: 16)
                .fill(Color.black)
                .frame(width: hudWidth, height: notchHeight)
                .overlay(
                    NotchShape(bottomRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            // Wings: Moon icon (left) | Camera Gap | ON/OFF (right)
            HStack(spacing: 0) {
                // Left wing - Moon icon
                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: isFocusOn ? "moon.fill" : "moon")
                        .font(.system(size: 18))
                        .foregroundStyle(accentColor)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.pulse, options: .repeating, isActive: isFocusOn)
                    Spacer(minLength: 0)
                }
                .frame(width: wingWidth)
                
                // Camera notch gap
                Spacer().frame(width: notchWidth)
                
                // Right wing - ON/OFF text
                HStack {
                    Spacer(minLength: 0)
                    Text(isFocusOn ? "Focus On" : "Focus Off")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
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
            animationTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
                withAnimation(DroppyAnimation.transition) {
                    isFocusOn.toggle()
                }
            }
        }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }
}

/// Floating Basket Preview - realistic mock matching FloatingBasketView COLLAPSED state
struct FloatingBasketPreview: View {
    private let cornerRadius: CGFloat = 20
    private let previewWidth: CGFloat = 180
    private let previewHeight: CGFloat = 200
    
    // Match DroppyCircleButtonStyle(size: 32) scaled down for preview
    private let buttonSize: CGFloat = 24
    
    var body: some View {
        ZStack {
            // Background - solid black matching real basket
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black)
            
            VStack(spacing: 0) {
                // Drag handle - matches BasketDragHandle (44x5 capsule)
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 36, height: 4)
                    .padding(.top, 8)
                
                // Header with X and chevron buttons - matching DroppyCircleButtonStyle
                HStack(alignment: .center) {
                    // X close button - matches DroppyCircleButtonStyle
                    Image(systemName: "xmark")
                        .font(.system(size: buttonSize * 0.4, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: buttonSize / 4, style: .continuous))
                    
                    Spacer()
                    
                    // Chevron menu button - no background, just icon
                    Image(systemName: "chevron.down")
                        .font(.system(size: buttonSize * 0.45, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: buttonSize, height: buttonSize)
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
                
                Spacer()
                
                // Stacked file thumbnails in center
                ZStack {
                    // Back file (slightly rotated and offset)
                    MockStackedFile(rotation: -8, offsetX: -10, offsetY: -8)
                    
                    // Front file
                    MockStackedFile(rotation: 5, offsetX: 8, offsetY: 5)
                }
                .frame(height: 80)
                
                Spacer()
                
                // "2 Files >" pill button - matches DroppyPillButtonStyle
                HStack(spacing: 4) {
                    Text("2 Files")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                )
                .padding(.bottom, 12)
            }
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
    }
}

/// Mock stacked file thumbnail for basket preview
private struct MockStackedFile: View {
    let rotation: Double
    let offsetX: CGFloat
    let offsetY: CGFloat
    
    var body: some View {
        // Document icon with folded corner effect
        ZStack {
            // Page background
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white)
                .frame(width: 50, height: 60)
            
            // Mock text lines
            VStack(alignment: .leading, spacing: 3) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: .random(in: 25...38), height: 3)
                }
            }
            .padding(8)
        }
        .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 2)
        .rotationEffect(.degrees(rotation))
        .offset(x: offsetX, y: offsetY)
    }
}

/// Animated preview demonstrating the Auto-Hide Peek feature
struct PeekPreview: View {
    let edge: String
    
    @State private var isPeeking = false
    
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
            // Background - new solid basket design (no more dashed border)
            RoundedRectangle(cornerRadius: 20 * miniBasketScale, style: .continuous)
                .fill(Color.black.opacity(0.85))
            
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
    @State private var bounce = false
    
    // Notch dimensions
    private let notchWidth: CGFloat = 180
    private let notchHeight: CGFloat = 32
    private let shelfWidth: CGFloat = 280
    private let shelfHeight: CGFloat = 70
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Expanded shelf background with NotchShape
                NotchShape(bottomRadius: 16)
                    .fill(Color.black)
                    .frame(width: shelfWidth, height: shelfHeight)
                    // PREMIUM PRESSED EFFECT: Layered inner glow for 3D depth
                    .overlay(
                        ZStack {
                            // Layer 1: Soft inner border glow - premium edge highlight
                            NotchShape(bottomRadius: 14)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.25),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1.5
                                )
                                .padding(4)
                            
                            // Layer 2: Vignette - clear in center, white glow on edges
                            RadialGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.08)
                                ],
                                center: .center,
                                startRadius: 30,
                                endRadius: 100
                            )
                            .clipShape(NotchShape(bottomRadius: 12))
                            .padding(6)
                        }
                    )
                    .overlay(
                        NotchShape(bottomRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                
                // DropZoneIcon - centered within the shelf
                DropZoneIcon(type: .shelf, size: 44, isActive: bounce)
            }
            .frame(width: shelfWidth, height: shelfHeight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .onAppear {
            // Activate icon animation
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

/// Drop Indicator Preview - NotchFace that animates between normal and excited on hover
struct DropIndicatorPreview: View {
    @State private var isHovered = false
    
    var body: some View {
        NotchFace(size: 40, isExcited: isHovered)
            .padding(16) // Symmetrical padding for centered appearance
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            )
            .onHover { hovering in
                withAnimation(DroppyAnimation.state) {
                    isHovered = hovering
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
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

// MARK: - Compact Animated HUD Icons (for Settings Rows)
// 40x40 premium circular gradient icons matching the sidebar style

/// Compact animated volume/brightness icon for settings rows - morphs between both
struct VolumeHUDIcon: View {
    @State private var showBrightness = false
    
    private var icon: String {
        showBrightness ? "sun.max.fill" : "speaker.wave.3.fill"
    }
    
    // Yellow/amber hue for brightness, blue for volume
    private var primaryColor: Color {
        showBrightness ? Color(hue: 0.12, saturation: 0.60, brightness: 0.98) : Color(hue: 0.58, saturation: 0.55, brightness: 0.95)
    }
    
    private var secondaryColor: Color {
        showBrightness ? Color(hue: 0.10, saturation: 0.80, brightness: 0.85) : Color(hue: 0.60, saturation: 0.70, brightness: 0.75)
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [primaryColor, secondaryColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 40, height: 40)
            
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: 40, height: 40)
            
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace.byLayer))
                .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0, y: 0.5)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                withAnimation(DroppyAnimation.transition) {
                    showBrightness.toggle()
                }
            }
        }
    }
}

/// Compact animated battery icon for settings rows
struct BatteryHUDIcon: View {
    @State private var isCharging = true
    
    var body: some View {
        ZStack {
            // Green gradient
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: 0.38, saturation: 0.55, brightness: 0.90),
                            Color(hue: 0.36, saturation: 0.75, brightness: 0.65)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 40, height: 40)
            
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: 40, height: 40)
            
            Image(systemName: isCharging ? "battery.100.bolt" : "battery.75")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, options: .repeating, isActive: isCharging)
                .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0, y: 0.5)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                withAnimation { isCharging.toggle() }
            }
        }
    }
}

/// Compact animated caps lock icon for settings rows
struct CapsLockHUDIcon: View {
    @State private var isOn = true
    
    var body: some View {
        ZStack {
            // Green gradient when on, gray when off
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isOn ? [
                            Color(hue: 0.38, saturation: 0.55, brightness: 0.90),
                            Color(hue: 0.36, saturation: 0.75, brightness: 0.65)
                        ] : [
                            Color(hue: 0.0, saturation: 0.0, brightness: 0.50),
                            Color(hue: 0.0, saturation: 0.0, brightness: 0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 40, height: 40)
            
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: 40, height: 40)
            
            Image(systemName: isOn ? "capslock.fill" : "capslock")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.pulse, options: .repeating, isActive: isOn)
                .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0, y: 0.5)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                withAnimation(DroppyAnimation.transition) { isOn.toggle() }
            }
        }
    }
}

/// Premium 3D AirPods icon for settings rows
struct AirPodsHUDIcon: View {
    var body: some View {
        ZStack {
            // White/gray gradient
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: 0.0, saturation: 0.0, brightness: 0.95),
                            Color(hue: 0.0, saturation: 0.0, brightness: 0.70)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 40, height: 40)
            
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: 40, height: 40)
            
            Image(systemName: "airpodspro")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(white: 0.2))
                .shadow(color: .white.opacity(0.5), radius: 0.5, x: 0, y: -0.5)
        }
    }
}

/// Compact animated lock icon for settings rows
struct LockScreenHUDIcon: View {
    @State private var isLocked = true
    
    var body: some View {
        ZStack {
            // Gray/silver gradient
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: 0.0, saturation: 0.0, brightness: 0.70),
                            Color(hue: 0.0, saturation: 0.0, brightness: 0.45)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 40, height: 40)
            
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: 40, height: 40)
            
            Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0, y: 0.5)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
                withAnimation(DroppyAnimation.transition) { isLocked.toggle() }
            }
        }
    }
}

/// Compact animated focus mode icon for settings rows
struct FocusModeHUDIcon: View {
    @State private var isOn = true
    
    var body: some View {
        ZStack {
            // Purple gradient when on, gray when off
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isOn ? [
                            Color(hue: 0.75, saturation: 0.50, brightness: 0.95),
                            Color(hue: 0.78, saturation: 0.70, brightness: 0.70)
                        ] : [
                            Color(hue: 0.0, saturation: 0.0, brightness: 0.50),
                            Color(hue: 0.0, saturation: 0.0, brightness: 0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 40, height: 40)
            
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: 40, height: 40)
            
            Image(systemName: isOn ? "moon.fill" : "moon")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.pulse, options: .repeating, isActive: isOn)
                .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0, y: 0.5)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                withAnimation(DroppyAnimation.transition) { isOn.toggle() }
            }
        }
    }
}

/// Compact animated media player icon for settings rows - uses NowPlayingIcon style
struct MediaPlayerHUDIcon: View {
    var body: some View {
        NowPlayingIcon(size: 40)
    }
}
