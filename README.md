
<p align="center">
  <img src="docs/assets/app-icon.png" alt="Droppy Icon" width="128">
</p>

<h1 align="center">Droppy</h1>

<p align="center">
  <strong>The ultimate Mac productivity monster.</strong><br>
  <em>Free, open-source, and built entirely in Swift.</em>
</p>

<p align="center">
    <a href="https://iordv.github.io/Droppy/"><img src="https://img.shields.io/badge/🌐_Website-Visit-blueviolet?style=flat-square" alt="Website"></a>
    <a href="https://github.com/iordv/Droppy/releases/latest"><img src="https://img.shields.io/github/v/release/iordv/Droppy?style=flat-square&color=007AFF" alt="Latest Release"></a>
    <a href="https://github.com/iordv/Droppy/releases/latest"><img src="https://img.shields.io/badge/⬇_Download-DMG-success?style=flat-square" alt="Download"></a>
    <img src="https://img.shields.io/badge/platform-macOS_14+-lightgrey?style=flat-square" alt="Platform">
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square" alt="License"></a>
</p>

<p align="center">
    <a href="https://github.com/iordv/Droppy/stargazers"><img src="https://img.shields.io/github/stars/iordv/Droppy?style=flat-square&color=yellow" alt="Stars"></a>
    <a href="https://github.com/iordv/Droppy/network/members"><img src="https://img.shields.io/github/forks/iordv/Droppy?style=flat-square" alt="Forks"></a>
    <a href="https://github.com/iordv/Droppy/commits"><img src="https://img.shields.io/github/last-commit/iordv/Droppy?style=flat-square" alt="Last Commit"></a>
</p>

---

<div align="center">

<img src="https://i.postimg.cc/1tpKj1Wf/Droppy-demo-v2.gif" alt="Droppy Demo" width="100%">

**Visit [our website](https://iordv.github.io/Droppy/) or browse the [Extension Store](https://iordv.github.io/Droppy/extensions.html).**

</div>

---

## What's Droppy?

**The native productivity layer macOS is missing.**

Stop juggling single-purpose utilities. Droppy brings your clipboard history, file shelf, screenshot tools, and system HUDs together in one native interface—all living inside your notch.

**No notch?** Droppy adds a Dynamic Island-style pill to any Mac.

### The basics:

- **Shelf & Basket** — Drag files to the notch to stash them. Jiggle your mouse while dragging to summon a floating basket anywhere on screen.
- **Clipboard History** — Full history with search, favorites, OCR text extraction, and drag-out.
- **Native HUDs** — Clean replacements for volume, brightness, battery, caps lock, and more.
- **Media Controls** — Album art, playback controls, and a seek slider right in the notch.

---

## Requirements

| | |
|:---|:---|
| **macOS** | 14.0 (Sonoma) or later |
| **Architecture** | Apple Silicon (M1/M2/M3/M4) and Intel |
| **Permissions** | Accessibility (required for shortcuts & drag detection) |
| | Screen Recording (optional, for Element Capture extension) |

---

## Features at a Glance

<p align="center">
  <img src="docs/assets/images/features-overview-new.png" alt="Features Overview">
</p>

---

## Everything Included

Droppy packs a complete suite of power-user tools into a tiny package:

| | |
|:---|:---|
| **File Shelf & Basket** | Stash files in your notch or summon a floating basket with a mouse jiggle |
| **AirDrop Drop Zone** | Dedicated drop area for instant AirDrop sharing right from the basket |
| **Clipboard Manager** | Full history, search, favorites, OCR text extraction, drag-out |
| **Element Capture** | Screenshot any individual UI element with customizable shortcuts |
| **Window Snapping** | Snap windows to screen edges/corners with keyboard shortcuts or drag zones |
| **Now Playing** | Album art, playback controls, seek slider, lyrics (needs Spotify extension) |
| **Quick Actions** | Right-click to compress, convert formats, extract text, move, share |
| **Custom HUDs** | Volume, brightness, battery, caps lock, unlock — modern replacements for system overlays |
| **AirPods HUD** | Battery levels and connection status when your AirPods connect |
| **Transparency Mode** | Optional glass effect for all windows — blend seamlessly with your desktop |
| **Multi-Monitor** | Works on external displays with smart fullscreen detection |

<p align="center">
  <img src="docs/assets/images/clipboard-manager.png" alt="Clipboard Manager" width="30%">
  &nbsp;
  <img src="docs/assets/images/media-hud.png" alt="Media Controls" width="30%">
  &nbsp;
  <img src="docs/assets/images/voice-transcribe-screenshot.png" alt="Voice Transcribe" width="30%">
</p>

---

## 🧩 Extension Store

<p align="center">
  <img src="docs/assets/images/extension-store-new.png" width="100%" alt="Extension Store">
</p>

Droppy's built-in Extension Store lets you add powerful features on demand. Everything's free and included — just toggle what you need.

**Top Extensions:**

<img src="https://iordv.github.io/Droppy/assets/icons/voice-transcribe.jpg" height="20" style="vertical-align: middle; border-radius: 4px;"> **Voice Transcribe** — Record and transcribe speech to text with 100% on-device AI

<img src="https://iordv.github.io/Droppy/assets/icons/ai-bg.jpg" height="20" style="vertical-align: middle; border-radius: 4px;"> **AI Background Removal** — Remove backgrounds from images locally using machine learning

<img src="https://iordv.github.io/Droppy/assets/icons/window-snap.jpg" height="20" style="vertical-align: middle; border-radius: 4px;"> **Window Snap** — Snap windows to screen edges and corners with keyboard shortcuts

<img src="https://iordv.github.io/Droppy/assets/icons/element-capture.jpg" height="20" style="vertical-align: middle; border-radius: 4px;"> **Element Capture** — Screenshot any UI element with customizable shortcuts

<img src="https://iordv.github.io/Droppy/assets/icons/alfred.jpg" height="20" style="vertical-align: middle; border-radius: 4px;"> **Alfred Workflow** — Add files to Droppy directly from Alfred

<img src="https://iordv.github.io/Droppy/assets/icons/finder.jpg" height="20" style="vertical-align: middle; border-radius: 4px;"> **Finder Services** — Right-click any file in Finder to send it to Droppy

<p align="center">
  <a href="https://iordv.github.io/Droppy/extensions.html">
    <img src="https://img.shields.io/badge/🧩_Browse_Extensions-Extension_Store-blueviolet?style=for-the-badge" alt="Extension Store">
  </a>
</p>

---

## Install

### Homebrew (recommended)
```bash
brew install --cask iordv/tap/droppy
```

### Manual Download
1. Download [**Droppy.dmg**](https://github.com/iordv/Droppy/releases/latest)
2. Clear quarantine (required for unsigned apps):
   ```bash
   xattr -rd com.apple.quarantine ~/Downloads/Droppy-*.dmg
   ```
3. Open the DMG and drag Droppy to Applications

> 💡 Homebrew handles quarantine automatically and makes updates easy.

---

## Keyboard Shortcuts

### Core Shortcuts

| Action | Shortcut |
|:---|:---|
| Open Clipboard History | `⌘ + Shift + Space` |
| Navigate clipboard items | `↑` / `↓` |
| Paste selected item | `Enter` |
| Close Droppy | `Escape` |

### Window Snapping (with extension)

| Action | Shortcut |
|:---|:---|
| Snap left half | `⌃ + ⌥ + ←` |
| Snap right half | `⌃ + ⌥ + →` |
| Snap top half | `⌃ + ⌥ + ↑` |
| Snap bottom half | `⌃ + ⌥ + ↓` |
| Maximize window | `⌃ + ⌥ + Enter` |
| Center window | `⌃ + ⌥ + C` |

### Quick Actions

| Action | How |
|:---|:---|
| Stash a file | Drag to notch |
| Summon floating basket | Jiggle mouse while dragging |
| Context menu | Right-click any item |

---

## FAQ

<details>
<summary><strong>Is Droppy really free?</strong></summary>

Yes! Droppy is free forever with no ads, subscriptions, or paywalls. All extensions are included at no cost. If you find it useful, you can support development via [Buy Me a Coffee](https://buymeacoffee.com/droppy).
</details>

<details>
<summary><strong>Why does Droppy need Accessibility permissions?</strong></summary>

Accessibility permissions allow Droppy to:
- Detect when you're dragging files (to show the basket)
- Register global keyboard shortcuts
- Intercept media keys for custom HUDs

Droppy never collects or transmits any personal data.
</details>

<details>
<summary><strong>Does it work on Macs without a notch?</strong></summary>

Absolutely! On Macs without a notch, Droppy displays a Dynamic Island-style pill at the top of your screen. You get all the same features.
</details>

<details>
<summary><strong>Is my data private?</strong></summary>

100%. All processing happens locally on your Mac:
- Clipboard history stays on disk
- Voice transcription uses on-device AI (WhisperKit)
- Background removal uses local ML models
- No data is ever sent to external servers
</details>

<details>
<summary><strong>Can I use Droppy on multiple monitors?</strong></summary>

Yes! Droppy supports multi-monitor setups with smart fullscreen detection. The shelf and HUDs appear on whichever display has your cursor.
</details>

---

## Build from Source

```bash
# Clone the repository
git clone https://github.com/iordv/Droppy.git
cd Droppy

# Open in Xcode
open Droppy.xcodeproj

# Build and run (⌘ + R)
```

**Requirements:**
- Xcode 15.0+
- macOS 14.0+ SDK
- Swift 5.9+

---

## Contributing

Contributions are welcome! Here's how you can help:

- 🐛 **Report bugs** — [Open an issue](https://github.com/iordv/Droppy/issues/new)
- 💡 **Suggest features** — Share your ideas in [Discussions](https://github.com/iordv/Droppy/discussions)
- 🔧 **Submit PRs** — Fork, branch, and open a pull request

Please read the codebase and follow existing patterns. For major changes, open an issue first to discuss.

---

## Support the Project

<p align="center">
  <strong>Free forever — no ads, no subscriptions.</strong><br>
  If Droppy saves you time, consider buying me a coffee.
</p>

<p align="center">
  <a href="https://buymeacoffee.com/droppy">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" width="180">
  </a>
</p>

---

<p align="center">
  <strong><a href="LICENSE">GPL-3.0 + Commons Clause</a></strong> — Source available, not for resale.<br>
  <a href="TRADEMARK">Droppy™</a> by <a href="https://github.com/iordv">Jordy Spruit</a>
</p>
