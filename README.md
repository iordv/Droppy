<p align="center">
  <img src="https://i.postimg.cc/9FxZhRf3/1024-mac.webp" alt="Droppy Icon" width="128">
</p>

<h1 align="center">Droppy</h1>

<p align="center">
  <strong>The ultimate drag-and-drop file shelf for macOS.</strong><br>
  <em>"It feels like it should have been there all along."</em>
</p>

<p align="center">
    <img src="https://img.shields.io/github/v/release/iordv/Droppy?style=flat-square&color=007AFF" alt="Latest Release">
    <img src="https://img.shields.io/badge/platform-macOS_14+-lightgrey?style=flat-square" alt="Platform">
    <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License">
</p>

<p align="center">
  <a href="#installation">Installation</a> •
  <a href="#key-features">Features</a> •
  <a href="#usage">Usage</a> •
  <a href="#whats-new">Changelog</a>
</p>

---

## What is Droppy?

Droppy provides a **temporary file shelf** that lives in your Mac's notch. Drag files to the top of your screen or **"jiggle"** your mouse to summon a floating basket anywhere. It's the perfect holding zone when moving files between apps, spaces, or folders.

---

## ✨ Key Features

| Feature | Description |
|:--------|:------------|
| **🗂️ Notch Shelf** | Drag files to the Notch — they vanish into a sleek shelf, ready when you need them. |
| **🧺 Floating Basket** | **"Jiggle" your mouse** while dragging to summon a basket instantly at your cursor. |
| **📋 Clipboard Manager** | A powerful clipboard history with full **keyboard navigation**, **search**, **favorites**, and **OCR text extraction**. |
| **📦 Move To...** | Move files directly to saved folders (like your NAS) from the shelf. Non-blocking & fast. |
| **📉 Smart Compression** | Right-click to compress images, PDFs, and videos. Includes **Target Size** and **Size Guard** 🛡️. |
| **⚡️ Fast Actions** | Convert images, extract text (OCR), zip, rename — all directly in the shelf. |
| **🖥️ Multi-Monitor** | Works on external displays. Auto-hides during fullscreen games and videos. |

---

## 🕹️ Usage

### 1. Stash Files 📥
- **Notch Shelf**: Drag any file to the black area around your webcam. It snaps in.
- **Floating Basket**: While dragging, **shake your mouse left-right**. A basket appears instantly.

### 2. Quick Actions 🪄
Right-click any item to:
- **Move To...** — Send to saved favorites or NAS folders
- **Compress** — Auto or specify a target size
- **Convert** — e.g., HEIC → JPEG
- **Extract Text** — OCR to copy text from images
- **Share** or **Reveal in Finder**

### 3. Drop Files 📤
Drag files out of the shelf and drop into any app — email, Discord, Photoshop, Finder.  
**Poof** — the file moves and vanishes from the shelf.

### 4. Clipboard Manager 📋
| Action | How |
|:-------|:----|
| **Open** | `Cmd + Shift + Space` (customizable) |
| **Navigate** | Arrow keys to browse entries |
| **Paste** | `Enter` to paste instantly |
| **Search** | `Cmd + F` or click the search icon |
| **Favorite** | Click ⭐ — favorites float to the top |
| **Extract Text** | Click "Extract Text" on any image to OCR |
| **Edit** | Click ✏️ to edit text entries inline |
| **Drag & Drop** | Drag entries directly into any app |

> **Works everywhere** — even in password fields and Terminal, thanks to low-level hotkey support.

---

## 🎨 Visual Tour

### The Notch Shelf
*Perfect for MacBook users. Utilizes the empty space around your webcam.*
<p align="center">
  <img src="https://i.postimg.cc/63TpswW4/image.png" alt="Notch Shelf Preview" width="100%">
</p>

### The Floating Basket
*Summoned anywhere with a quick jiggle. The perfect temporary holding zone.*
<p align="center">
  <img src="https://i.postimg.cc/50488cNj/image.png" alt="Floating Basket Preview" width="100%">
</p>

### The Clipboard Manager
*Your history, beautifully organized. Search, Edit, and Drag & Drop.*

<p align="center">
  <img src="https://i.postimg.cc/rpdpn8sH/image.png" alt="Multi-select, Favorite, and Paste" width="100%">
</p>

<p align="center">
  <img src="https://i.postimg.cc/63npKYdc/image.png" alt="Rename, Copy, and Delete" width="100%">
</p>

---

## 🛠️ Power User Tips

### 📉 Smart Compression
- **Auto**: Uses HEVC for videos (1080p) and balanced settings for images
- **Target Size**: Need under 2MB? Right-click → Compress → **Target Size...**
- **Size Guard**: If compression would make the file larger, Droppy keeps the original and shows a Green Shield 🛡️

### 📝 Drag-and-Drop OCR
1. Drag an image into Droppy
2. Hold **Shift** while dragging it out
3. Drop into a text editor — **it's text!**

---

## 📥 Installation

### Homebrew (Recommended)
```bash
brew install --cask iordv/tap/droppy
```

### Manual Download
1. Download [**Droppy.dmg**](https://github.com/iordv/Droppy/releases/latest)
2. Drag to Applications
3. **Right-click → Open** on first launch

> **Quarantine Issue?** If macOS says the app is damaged:
> ```bash
> xattr -d com.apple.quarantine /Applications/Droppy.app
> ```

---

## 🆕 What's New
<!-- CHANGELOG_START -->
Release v3.1.5

New:
- **Settings Shortcut**: Added a Settings (gear) icon to the shelf when it's empty.

Fixes:
- **Crash Fix**: Resolved a timer-related crash in Drag Monitor that could occur during usage.

Fixed in v3.1.4:
- **Icon Compatibility**: Ensured the new app icon uses the correct PNG format for compatibility with all macOS versions.
<!-- CHANGELOG_END -->

---

## License
MIT License. Free and Open Source forever.

Made with ❤️ by [Jordy Spruit](https://github.com/iordv)
