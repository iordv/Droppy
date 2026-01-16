
<p align="center">
  <img src="docs/assets/app-icon.png" alt="Droppy Icon" width="120">
</p>

<h1 align="center">Droppy</h1>

<p align="center">
  <strong>The native productivity layer macOS is missing.</strong><br>
  <em>Free, open-source, and built entirely in Swift.</em>
</p>

<p align="center">
    <a href="https://github.com/iordv/Droppy/releases/latest"><img src="https://img.shields.io/github/v/release/iordv/Droppy?style=flat-square&color=007AFF" alt="Latest Release"></a>
    <img src="https://img.shields.io/badge/macOS_14+-000?style=flat-square" alt="Platform">
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square" alt="License"></a>
</p>

---

<p align="center">
  ![Droppy demo v2](https://github.com/user-attachments/assets/b9ef10e8-44d6-498a-abed-38b53cd9599b)
</p>

<p align="center">
  <a href="https://iordv.github.io/Droppy/"><strong>🌐 Website</strong></a> · 
  <a href="https://github.com/iordv/Droppy/releases/latest"><strong>⬇️ Download</strong></a> · 
  <a href="https://iordv.github.io/Droppy/extensions.html"><strong>🧩 Extensions</strong></a>
</p>

---

## What is Droppy?

Stop juggling single-purpose utilities. Droppy brings your **clipboard history**, **file shelf**, **screenshot tools**, and **system HUDs** together in one native interface—all living inside your notch.

**No notch?** Droppy adds a Dynamic Island-style pill to any Mac.

---

## ✨ Clipboard Manager

Full history with search, favorites, OCR text extraction, and drag-out support. Use `⌘ + Shift + Space` to open (customizable in Settings).

<p align="center">
  <img src="docs/assets/images/clipboard-manager.png" alt="Clipboard Manager" width="70%">
</p>

---

## 🎵 Media Controls

Album art, playback controls, and a seek slider—right in your notch. With the Audio Visualizer enabled, see a live frequency spectrum dancing to your music.

<p align="center">
  <img src="docs/assets/images/media-hud.png" alt="Media Controls" width="70%">
</p>

---

## 🎤 Voice Transcribe

Record and transcribe speech to text with 100% on-device AI. Your voice never leaves your Mac.

<p align="center">
  <img src="docs/assets/images/voice-transcribe-screenshot.png" alt="Voice Transcribe" width="70%">
</p>

---

## Everything Included

| Feature | Description |
|:---|:---|
| **File Shelf & Basket** | Drag files to the notch. Jiggle your mouse to summon a floating basket. |
| **Clipboard Manager** | Full history, search, favorites, OCR, drag-out |
| **Native HUDs** | Volume, brightness, battery, caps lock, unlock, AirPods |
| **Media Controls** | Album art, seek slider, playback controls, audio visualizer |
| **Quick Actions** | Right-click to compress, convert formats, extract text, share |
| **Multi-Monitor** | Works on external displays with smart fullscreen detection |
| **Transparency Mode** | Optional glass effect for all windows |
| **Powerful Extensions** | Window snapping, voice transcription, AI background removal, and more—see below |

---

## 🧩 All Extensions

<p align="center">
Droppy's built-in Extension Store adds powerful features on demand. Everything's free.
</p>

<p align="center">
  <img src="docs/assets/images/extension-store-new.png" alt="Extension Store" width="80%">
</p>

<div align="center">

| | |
|:---:|:---:|
| <img src="https://iordv.github.io/Droppy/assets/icons/voice-transcribe.jpg" height="28"> **Voice Transcribe**<br>On-device speech-to-text using WhisperKit AI | <img src="https://iordv.github.io/Droppy/assets/icons/ai-bg.jpg" height="28"> **AI Background Removal**<br>Remove backgrounds locally using ML |
| <img src="https://iordv.github.io/Droppy/assets/icons/video-target-size.png" height="28"> **Video Target Size**<br>Compress videos to exact file sizes with FFmpeg | <img src="https://iordv.github.io/Droppy/assets/icons/window-snap.jpg" height="28"> **Window Snap**<br>Snap windows with keyboard shortcuts |
| <img src="https://iordv.github.io/Droppy/assets/icons/spotify.png" height="28"> **Spotify Integration**<br>Control Spotify playback from your notch | <img src="https://iordv.github.io/Droppy/assets/icons/element-capture.jpg" height="28"> **Element Capture**<br>Screenshot any UI element |
| <img src="https://iordv.github.io/Droppy/assets/icons/alfred.png" height="28"> **Alfred Workflow**<br>Add files to Droppy from Alfred | <img src="https://iordv.github.io/Droppy/assets/icons/finder.png" height="28"> **Finder Services**<br>Right-click in Finder to send files |

</div>

<p align="center">
  <a href="https://iordv.github.io/Droppy/extensions.html">
    <img src="https://img.shields.io/badge/Browse_Extension_Store-blueviolet?style=for-the-badge" alt="Extension Store">
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
2. Clear quarantine: `xattr -rd com.apple.quarantine ~/Downloads/Droppy-*.dmg`
3. Drag Droppy to Applications

---

## Permissions

Droppy requires a few permissions to work properly. All processing happens locally—no data ever leaves your Mac.

| Permission | Required | What it's used for |
|:---|:---:|:---|
| **Accessibility** | ✅ | Global keyboard shortcuts, drag detection, media key interception |
| **Screen Recording** | Optional | Element Capture extension, Audio Visualizer (to capture system audio) |
| **Microphone** | Optional | Voice Transcribe extension (speech-to-text recording) |

---

## Requirements

- **macOS** 14.0 (Sonoma) or later
- **Architecture**: Apple Silicon (M1–M4) and Intel

---

## FAQ

<details>
<summary><strong>Is Droppy really free?</strong></summary>
Yes! Free forever with no ads, subscriptions, or paywalls. All extensions are included at no cost.
</details>

<details>
<summary><strong>"Droppy is damaged and can't be opened" — how do I fix this?</strong></summary>

This is macOS Gatekeeper blocking unsigned apps. Run this command in Terminal:
```bash
xattr -rd com.apple.quarantine /Applications/Droppy.app
```
Or if you downloaded the DMG directly:
```bash
xattr -rd com.apple.quarantine ~/Downloads/Droppy-*.dmg
```
Using Homebrew (`brew install --cask iordv/tap/droppy`) avoids this issue entirely.
</details>

<details>
<summary><strong>Does it work on Macs without a notch?</strong></summary>
Absolutely. Droppy displays a Dynamic Island-style pill at the top of your screen with all the same features.
</details>

<details>
<summary><strong>Is my data private?</strong></summary>
100%. All processing happens locally—clipboard history, voice transcription, background removal, and audio visualization never leave your Mac.
</details>

<details>
<summary><strong>Why does Droppy need Accessibility permissions?</strong></summary>
Accessibility allows Droppy to detect when you're dragging files (to show the basket), register global keyboard shortcuts, and intercept media keys for custom HUDs. Droppy never collects or transmits any data.
</details>

<details>
<summary><strong>Why does Droppy need Screen Recording permission?</strong></summary>
Screen Recording is only needed for the Element Capture extension and the Audio Visualizer feature. Element Capture screenshots UI elements, and the Audio Visualizer needs to capture system audio output. Both are optional features.
</details>

<details>
<summary><strong>Can I use Droppy on multiple monitors?</strong></summary>
Yes! Droppy supports multi-monitor setups with smart fullscreen detection. The shelf and HUDs appear on whichever display has your cursor.
</details>

<details>
<summary><strong>How do I change the keyboard shortcuts?</strong></summary>
Go to Settings (click the gear icon) → Shortcuts. You can customize the shortcut for opening the clipboard and other actions.
</details>

<details>
<summary><strong>Does Droppy work with external keyboards?</strong></summary>
Yes. Keyboard shortcuts and media keys work with any keyboard, including external and Bluetooth keyboards.
</details>

<details>
<summary><strong>How do I uninstall Droppy?</strong></summary>
Drag Droppy from Applications to Trash. To remove all data, also delete:
- `~/Library/Application Support/Droppy`
- `~/Library/Preferences/iordv.Droppy.plist`

Or if you used Homebrew: `brew uninstall droppy`
</details>

<details>
<summary><strong>Is Droppy open-source?</strong></summary>
Yes! The source code is available under GPL-3.0 with Commons Clause (free for personal use, not for resale).
</details>

---

## Build from Source

```bash
git clone https://github.com/iordv/Droppy.git
cd Droppy && open Droppy.xcodeproj
# Build with ⌘ + R
```

---

## Support

<p align="center">
  <strong>Free forever — no ads, no subscriptions.</strong><br>
  If Droppy saves you time, consider buying me a coffee.
</p>

<p align="center">
  <a href="https://buymeacoffee.com/droppy">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" width="160">
  </a>
</p>

---

<p align="center">
  <strong><a href="LICENSE">GPL-3.0 + Commons Clause</a></strong> — Source available, not for resale.<br>
  <a href="TRADEMARK">Droppy™</a> by <a href="https://github.com/iordv">Jordy Spruit</a>
</p>
