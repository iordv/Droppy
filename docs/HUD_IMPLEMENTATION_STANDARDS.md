# HUD Implementation Standards

> **Version**: 8.1.x | **Last Updated**: 2026-01-17

## Quick Reference Table

| Property | Dynamic Island (37pt) | Notch Mode (~32pt) |
|----------|----------------------|-------------------|
| Icon size | **18px** | **20px** |
| Text size | **13pt** semibold | **15pt** semibold |
| Symmetric padding | `(37-18)/2 = 9.5px` | `max((height-20)/2, 6)` |
| Icon frame | `.frame(width: 20, height: iconSize, alignment: .leading)` | `.frame(width: iconSize, height: iconSize, alignment: .leading)` |
| Album art corners | Circular (`iconSize/2`) | Rounded rect (`5px`) |
| Visualizer height | 18px | 20px |

---

## 1. Size Standards

### Dynamic Island Mode
```swift
let iconSize: CGFloat = 18
let symmetricPadding = (notchHeight - iconSize) / 2  // = 9.5px for 37pt height
```

### Notch Mode
```swift
let iconSize: CGFloat = 20
let symmetricPadding = max((notchHeight - iconSize) / 2, 6)  // Min 6px
```

---

## 2. Layout Pattern (symmetric padding)

### Dynamic Island: Single HStack with symmetric padding
```swift
HStack {
    Image(systemName: "icon.name")
        .font(.system(size: iconSize, weight: .semibold))
        .frame(width: 20, height: iconSize, alignment: .leading)
    
    Spacer()
    
    Text("Value")
        .font(.system(size: 13, weight: .semibold))
}
.padding(.horizontal, symmetricPadding)
.frame(height: notchHeight)
```

### Notch Mode: Two wings with notch spacer
```swift
HStack(spacing: 0) {
    // Left wing
    HStack {
        Image(systemName: "icon.name")
            .font(.system(size: 20, weight: .semibold))
            .frame(width: iconSize, height: iconSize, alignment: .leading)
        Spacer(minLength: 0)
    }
    .padding(.leading, symmetricPadding)
    .frame(width: wingWidth)
    
    // Notch spacer
    Spacer().frame(width: notchWidth)
    
    // Right wing
    HStack {
        Spacer(minLength: 0)
        Text("Value")
            .font(.system(size: 15, weight: .semibold))
    }
    .padding(.trailing, symmetricPadding)
    .frame(width: wingWidth)
}
.frame(height: notchHeight)
```

---

## 3. Animations

### Appear/Disappear
```swift
.transition(.opacity.combined(with: .scale(scale: 0.8)))
.animation(.spring(response: 0.25, dampingFraction: 0.8), value: isVisible)
```

### Symbol transitions
```swift
.contentTransition(.symbolEffect(.replace.byLayer))
```

### Value changes (sliders)
```swift
// Use interpolating spring for buttery smoothness
.animation(.interpolatingSpring(stiffness: 300, damping: 30), value: sliderValue)
```

---

## 4. HUD Collision Avoidance

### Priority system (in NotchShelfView)
```swift
// Only ONE HUD visible at a time - priority order:
// 1. Volume/Brightness (user-initiated, highest priority)
// 2. Battery (on connection change)
// 3. CapsLock (on toggle)
// 4. DND/Focus (on mode change)
// 5. AirPods (on connection)
// 6. Media (passive, lowest priority - shown when no other HUD active)
```

### Visibility guards
```swift
// Each HUD checks if another HUD is showing before appearing
guard !state.isAnyOtherHUDVisible else { return }

// Dismiss after timeout
DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) {
    withAnimation { isVisible = false }
}
```

---

## 5. Expanded Media Player Integration

### When shelf expands, HUDs hide:
```swift
.opacity(isExpandedOnThisScreen ? 0 : 1)
```

### Media HUD has special behavior:
- Collapsed: Shows album art + visualizer + song title
- Expanded: Full media player with controls, progress, album art

---

## 6. Album Art Styling

### Dynamic Island (pill-shaped edges)
```swift
.clipShape(RoundedRectangle(cornerRadius: iconSize / 2))  // Circular
```

### Notch Mode (rectangular wings)
```swift
.clipShape(RoundedRectangle(cornerRadius: 5))  // Apple Music style
```

---

## 7. Audio Visualizer Standards

### MiniAudioVisualizerBars (Notch mode)
```swift
AudioSpectrumView(
    isPlaying: musicManager.isPlaying,
    barCount: 5,
    barWidth: 3,
    spacing: 2,
    height: 20,  // Match 20px icon standard
    color: visualizerColor
)
.frame(width: 5 * 3 + 4 * 2, height: 20)
```

### Dynamic Island (compact)
```swift
AudioSpectrumView(
    isPlaying: musicManager.isPlaying,
    barCount: 3,
    barWidth: 2.5,
    spacing: 2,
    height: 18,  // Match 18px icon standard
    color: visualizerColor
)
.frame(width: 3 * 2.5 + 2 * 2, height: 18)
```

---

## 8. Color Standards

| Element | Color |
|---------|-------|
| Icons | `.white` |
| Text | `.white` |
| Muted icon | `.red` |
| Volume accent | `.white` |
| Brightness accent | `.yellow` |
| Battery low | `.red` |
| Battery charging | `.green` |
| Visualizer | Album art dominant color or `.white` |

---

## 9. Creating a New HUD Checklist

1. ☐ Create `[Name]HUDView.swift` with `isDynamicIslandMode` branching
2. ☐ Use **18px** icons for DI, **20px** for Notch
3. ☐ Use **13pt** text for DI, **15pt** for Notch
4. ☐ Apply `symmetricPadding` formula for padding
5. ☐ Add `.frame(alignment: .leading)` to icons
6. ☐ Implement wing layout for Notch mode
7. ☐ Add visibility guards to prevent collision with other HUDs
8. ☐ Add auto-dismiss timer with appropriate duration
9. ☐ Handle expanded media player (hide when expanded)
10. ☐ Register in `NotchShelfView`'s HUD rendering section
