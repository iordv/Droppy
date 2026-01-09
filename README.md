
https://github.com/user-attachments/assets/4e97c39a-ea28-4734-89a3-66fa55a23e0a
<p align="center">
  <img src="https://i.postimg.cc/9FxZhRf3/1024-mac.webp" alt="Droppy Icon" width="128">
</p>

<h1 align="center">Droppy</h1>

<p align="center">
  <strong>Your files. Everywhere. Instantly.</strong>
</p>

<p align="center">
    <a href="https://github.com/iordv/Droppy/releases/latest"><img src="https://img.shields.io/github/v/release/iordv/Droppy?style=flat-square&color=007AFF" alt="Latest Release"></a>
    <a href="https://github.com/iordv/Droppy/releases/latest"><img src="https://img.shields.io/badge/⬇_Download-DMG-success?style=flat-square" alt="Download"></a>
    <img src="https://img.shields.io/badge/platform-macOS_14+-lightgrey?style=flat-square" alt="Platform">
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <a href="#-installation">Install</a> •
  <a href="#-capabilities">Features</a> •
  <a href="#-how-to-use">Usage</a> •
  <a href="#-whats-new">Changelog</a>
</p>

---

<div align="center">

![Demo Droppy!](https://github.com/user-attachments/assets/59ed67af-6719-4f83-918d-ed6d10183782)

</div>

---

<p align="center">
  <strong>Works on ANY Mac</strong> — non-notch displays get a gorgeous Dynamic Island-style pill interface!
</p>

---

## ✨ Capabilities

| | Feature | Description |
|:--|:--------|:------------|
| 🗂️ | **Notch Shelf** | Drag files to your notch — they vanish into a sleek shelf, ready when you need them |
| 🧺 | **Floating Basket** | Jiggle your mouse while dragging to summon a basket anywhere on screen |
| 📋 | **Clipboard Manager** | Full history with search, favorites, OCR text extraction, and drag-out support |
| 🎵 | **Media Player** | Now Playing controls in your notch with album art and seek slider |
| 🔊 | **Custom HUDs** | Beautiful volume, brightness, battery, and Caps Lock overlays |
| 🔮 | **Alfred Integration** | Push files to Droppy from Alfred with a quick action |

---

### ⚡ Power Features

| | Feature | Description |
|:--|:--------|:------------|
| 📦 | **Move To...** | Send files directly to saved folder locations like your NAS, cloud drives, or project folders |
| 📉 | **Smart Compression** | Compress images, PDFs, and videos with auto or target size options — keeps originals if larger |
| ✏️ | **Fast Actions** | Convert images, extract text (OCR), create ZIPs, rename — all from the shelf with one click |
| 🙈 | **Auto-Hide Basket** | Basket slides to screen edge when idle, peeks out on hover for quick access when you need it |
| 🖥️ | **Multi-Monitor** | Works on external displays with smart fullscreen detection and automatic positioning |
| 🏝️ | **Dynamic Island** | Non-notch Macs get a beautiful floating pill interface that matches the notch experience |

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

---

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

| Action | Shortcut | Description |
|:-------|:---------|:------------|
| Open | `⌘ + Shift + Space` | Opens the clipboard history panel from anywhere |
| Navigate | `↑` `↓` | Move through your clipboard history |
| Paste | `Enter` | Paste the selected item and close |
| Search | `⌘ + F` | Filter items by text content |
| Favorite | `⭐` | Pin important items to the top |

> Works everywhere — even in password fields and Terminal.

---

## �️ Pro Tips

### �🔮 Alfred Integration
Push files from Finder to Droppy: **Settings** → **About** → **Install in Alfred**, then use Alfred's Universal Actions on any file.

### � Smart Compression
- **Auto**: Balanced settings for most files
- **Target Size**: Need under 2MB? Right-click → Compress → **Target Size...**
- **Size Guard** 🛡️: If compression would make the file larger, Droppy keeps the original

### ✍️ Drag-and-Drop OCR
Drag an image into Droppy, hold **Shift** while dragging out, and drop into a text editor — **it's text!**

### 🙈 Auto-Hide Basket
Enable in Settings → Basket → **Auto-Hide**. The basket slides to the screen edge when not in use and peeks out on hover.

---

## 🆕 What's New

<details>
<summary><strong>v5.4.1 — Stability & Interaction Fixes</strong></summary>

<!-- CHANGELOG_START -->
### 🔧 Bug Fixes

**File Transfer Stability**
- Fixed file corruption when moving between Basket and Shelf multiple times
- Fixed ZIP creation failures after repeated file transfers

**Auto-Hide Basket**
- Fixed "peek" not hiding when moving cursor away after dropping files
- Improved drop detection with better mouse tracking

**Shelf Interaction**
- Instant drag from shelf without clicking to activate first
- Both shelf and basket now support first-click interaction

---

*Includes all features from v5.4: Caps Lock HUD, Media Player improvements, and performance optimizations.*
<!-- CHANGELOG_END -->

</details>

---

<p align="center">
  <a href="https://buymeacoffee.com/droppy"><img src="https://img.shields.io/badge/☕_Buy_Me_A_Coffee-FFDD00?style=for-the-badge" alt="Buy Me A Coffee"></a>
</p>

<p align="center">
  <a href="https://star-history.com/#iordv/droppy&Timeline"><img src="https://img.shields.io/badge/⭐_Star_History-View_Chart-blue?style=flat-square" alt="Star History"></a>
</p>

---

<p align="center">
  <strong>MIT License</strong> — Free and Open Source forever.<br>
  Made with ❤️ by <a href="https://github.com/iordv">Jordy Spruit</a>
</p>
