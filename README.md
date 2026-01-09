<p align="center">
  <img src="https://i.postimg.cc/9FxZhRf3/1024-mac.webp" alt="Droppy Icon" width="128">
</p>

<h1 align="center">Droppy</h1>

<p align="center">
  <strong>Your files. Everywhere. Instantly.</strong><br>
  <em>Notch Shelf • Floating Basket • Clipboard Manager • Media Player • Custom HUDs</em>
</p>

<p align="center">
    <img src="https://img.shields.io/github/v/release/iordv/Droppy?style=flat-square&color=007AFF" alt="Latest Release">
    <img src="https://img.shields.io/badge/platform-macOS_14+-lightgrey?style=flat-square" alt="Platform">
    <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License">
</p>

<p align="center">
  <a href="#-installation">Install</a> •
  <a href="#-features">Features</a> •
  <a href="#-visual-tour">Screenshots</a> •
  <a href="#-whats-new">Changelog</a>
</p>

---

## What is Droppy?

**Droppy turns your Mac's notch into a powerful file shelf** — and so much more.

Drop files into your notch. Shake your mouse to summon a floating basket. Access your entire clipboard history. Control your music. Replace the ugly system volume HUD. All in one beautifully designed app.

> **Works on ANY Mac** — non-notch displays get a gorgeous Dynamic Island-style pill interface!

---

## ✨ Features

### Core Tools

| | Feature | Description |
|:--|:--------|:------------|
| 🗂️ | **Notch Shelf** | Drag files to your notch — they vanish into a sleek shelf, ready when you need them |
| 🧺 | **Floating Basket** | Jiggle your mouse while dragging to summon a basket anywhere on screen |
| 📋 | **Clipboard Manager** | Full history with search, favorites, OCR text extraction, and drag-out support |
| 🎵 | **Media Player** | Now Playing controls in your notch with album art and seek slider |
| 🔊 | **Custom HUDs** | Beautiful volume, brightness, and battery overlays that replace system HUDs |
| 🔮 | **Alfred Integration** | Push files to Droppy from Alfred with a quick action |

### Power Features

| | Feature | Description |
|:--|:--------|:------------|
| 📦 | **Move To...** | Send files directly to saved folder locations (like your NAS) |
| 📉 | **Smart Compression** | Compress images, PDFs, and videos with auto or target size options |
| ⚡ | **Fast Actions** | Convert images, extract text (OCR), create ZIPs, rename — all from the shelf |
| 🖥️ | **Multi-Monitor** | Works on external displays with smart fullscreen detection |
| 🏝️ | **Dynamic Island** | Non-notch Macs get a beautiful floating pill interface |

---

## 📦 Installation

### Homebrew (Recommended)
```bash
brew install --cask iordv/tap/droppy
```

### Manual Download
1. Download [**Droppy.dmg**](https://github.com/iordv/Droppy/releases/latest)
2. Open the DMG and drag Droppy to Applications
3. **Important:** Before first launch, run this command in Terminal:
   ```bash
   xattr -rd com.apple.quarantine /Applications/Droppy.app
   ```
4. Open Droppy from your Applications folder

> ⚠️ **"Droppy is damaged and can't be opened"?**
> 
> This happens because macOS quarantines apps downloaded from the internet. The `xattr` command above removes this flag. This is safe — Droppy is open source and you can verify the code yourself.
>
> Alternatively, use **Homebrew** which handles this automatically.



## 🕹️ How to Use

### Stash Files
- **Notch**: Drag any file to the black area around your webcam
- **Basket**: While dragging, **shake your mouse left-right** — a basket appears at your cursor

### Quick Actions
Right-click any item in the shelf to:
- **Move To...** — Send to saved locations
- **Compress** — Auto or specify a target size
- **Convert** — e.g., HEIC → JPEG
- **Extract Text** — OCR to copy text from images
- **Share** or **Reveal in Finder**

### Drop Files
Drag files out of the shelf and drop into any app. The file moves and vanishes from the shelf.

### Clipboard Manager

| Action | Shortcut |
|:-------|:---------|
| Open | `⌘ + Shift + Space` |
| Navigate | `↑` `↓` Arrow keys |
| Paste | `Enter` |
| Search | `⌘ + F` |
| Favorite | Click ⭐ |

> Works everywhere — even in password fields and Terminal.

---

## 🎨 Visual Tour

### The Notch Shelf
*Your files, hidden in plain sight.*
<p align="center">
  <img src="https://i.postimg.cc/jqkPwkRp/Schermopname2026-01-05om22-04-43-ezgif-com-video-to-gif-converter.gif" alt="Notch Shelf" width="100%">
</p>

### The Floating Basket
*Summoned anywhere with a quick jiggle.*
<p align="center">
  <img src="https://i.postimg.cc/dtHH09fB/Schermopname2026-01-05om22-01-22-ezgif-com-video-to-gif-converter.gif" alt="Floating Basket" width="100%">
</p>

### Clipboard Manager
*Your history, beautifully organized.*
<p align="center">
  <img src="https://i.postimg.cc/Kvc9c2Kr/Schermopname2026-01-06om18-05-02-ezgif-com-video-to-gif-converter.gif" alt="Clipboard Manager" width="100%">
</p>

### Media Player
*Now Playing, right in your notch.*
<p align="center">
  <img src="https://i.postimg.cc/SKjDMGrP/Schermopname2026-01-07om15-17-29-ezgif-com-video-to-gif-converter.gif" alt="Media Player" width="100%">
</p>

### Volume & Brightness HUD
*Beautiful replacements for the system HUDs.*
<p align="center">
  <img src="https://i.postimg.cc/qqQ3wPMV/Schermopname2026-01-07om15-20-48-ezgif-com-video-to-gif-converter.gif" alt="Volume HUD" width="100%">
</p>

### Battery HUD
*Elegant charging indicator.*
<p align="center">
  <img src="https://i.postimg.cc/Fznd6bvv/Schermopname2026-01-07om22-36-08-ezgif-com-video-to-gif-converter.gif" alt="Battery HUD" width="100%">
</p>

---

## 🔮 Alfred Integration

Push files from Finder to Droppy using Alfred!

1. Open **Droppy Settings** → **About** → **Install in Alfred**
2. Select files in Finder → Activate Alfred → Type "Actions"
3. Choose **Add to Droppy Shelf** or **Add to Droppy Basket**

> Requires Alfred 4+ with Powerpack

---

## 🛠️ Pro Tips

### Smart Compression
- **Auto**: Balanced settings for most files
- **Target Size**: Need under 2MB? Right-click → Compress → **Target Size...**
- **Size Guard** 🛡️: If compression would make the file larger, Droppy keeps the original

### Drag-and-Drop OCR
1. Drag an image into Droppy
2. Hold **Shift** while dragging it out
3. Drop into a text editor — **it's text!**

### Auto-Hide Basket
Enable in Settings → Basket → **Auto-Hide**. The basket slides to the screen edge when not in use and peeks out on hover.

---

## 🆕 What's New
<!-- CHANGELOG_START -->
# Droppy v5.4 - Caps Lock HUD & Enhanced Media Integration

## ✨ New Features

### Caps Lock HUD
- **Beautiful ON/OFF indicator** - Shows in the notch when you toggle Caps Lock
- **Green glow when active** - Matches the premium Battery HUD style
- **Animated preview in Settings** - See exactly how it looks before enabling
- **Onboarding integration** - Configure during first-time setup

## 🎯 Improvements

### Media Player Source Opening
- **Zen Browser support** - Now properly activates Firefox-based Zen browser
- **Brave Browser support** - Full AppleScript tab matching
- **Microsoft Edge support** - Full AppleScript tab matching
- **Improved fallback logic** - Apps activate even without URL lookup

### Performance Optimizations
- **Faster file drops** - UTType-based icon loading (~100x faster for bulk drops)
- **O(1) window focus checks** - Replaced O(n) window iteration in NotchWindowController

## 🔧 Fixes
- Fixed deprecated `activateIgnoringOtherApps` warnings (macOS 14+ compatibility)
- Fixed potential HUD overlap when Caps Lock and Media Player both active
- Improved notch wing visibility calculation for all HUD types
<!-- CHANGELOG_END -->

---

## ❤️ Support

If Droppy saves you time, consider buying me a coffee!

<p align="center">
  <a href="https://buymeacoffee.com/droppy">
    <img src="https://i.postimg.cc/yxRYWNqL/0x0.png" alt="Buy Me A Coffee" width="128">
  </a>
</p>

---

## ⭐ Star History

<a href="https://star-history.com/#iordv/droppy&Timeline">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=iordv/droppy&type=Timeline&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=iordv/droppy&type=Timeline" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=iordv/droppy&type=Timeline" />
 </picture>
</a>

---

## License

MIT License — Free and Open Source forever.

Made with ❤️ by [Jordy Spruit](https://github.com/iordv)
