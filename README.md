<p align="center">
  <img src="https://i.postimg.cc/PxdpGc3S/appstore.png" alt="Droppy Icon" width="128">
</p>

<h1 align="center">Droppy</h1>

<p align="center">
  <strong>The ultimate drag-and-drop file shelf for macOS.</strong><br>
  <em>"It feels like it should have been there all along."</em>
</p>

<p align="center">
    <img src="https://img.shields.io/github/v/release/iordv/Droppy?style=flat-square&color=007AFF" alt="Latest Release">
    <img src="https://img.shields.io/badge/platform-macOS-lightgrey?style=flat-square" alt="Platform">
    <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License">
</p>

<p align="center">
  <a href="#installation">Installation</a> •
  <a href="#key-features">Features</a> •
  <a href="#usage">Usage</a>
</p>

---

## What is Droppy?

Droppy provides a **temporary shelf** for your files. Drag files to the top of your screen (the Notch) or "jiggle" your mouse to summon a Basket right where you are. It's the perfect holding zone when moving files between apps, spaces, or folders.

🚀 **Version 2.9.0 is here!** Introducing the **Clipboard Overhaul** with low-level hotkey support, full keyboard navigation, and multi-item capture!

---

## ✨ Key Features

|Feature|Description|
|:---|:---|
|**🗂️ Notch Shelf**|Drag files to the Notch. They vanish into a sleek shelf, ready when you are.|
|**🧺 Floating Basket**|**"Jiggle" your mouse** while dragging to summon a basket instantly at your cursor.|
|**📦 Move To...**|Move files directly to saved folders (like your NAS) from the shelf. **Non-blocking** & fast.|
|**📉 Smart Compression**|Right-click to compress Images, PDFs, and Videos. Now with **Size Guard** 🛡️ to prevent bloat.|
|**⚡️ Fast Actions**|Convert images/docs, extract text (OCR), zip, or rename directly in the shelf.|
|**🖥️ Multi-Monitor**|Works beautifully on external displays. Auto-hides on fullscreen games/videos.|
|**📋 Clipboard Manager**|A powerful liquid history. Full **Keyboard Navigation** (Arrows/Enter), **Secure Input Support**, and multi-item capture.|

---

## 🕹️ Usage

### 1. Stash it 📥
- **Notch**: Drag any file to the black area around your webcam. It snaps in.
- **Basket**: While dragging a file, **shake your mouse cursor** left and right. A basket appears under your pointer.

### 2. Tweak it 🪄
- **Hover** over the Notch or Basket to see your files.
- **Right-click** any item to:
    - **Move To...** (Quickly send to saved Favorites/NAS).
    - **Compress** (Auto or Target Size).
    - **Convert** (e.g., HEIC towards JPEG).
    - **Extract Text** (Copy text from images).
    - **Share** or **Reveal in Finder**.

### 3. Drop it 📤
- Drag the file out of the shelf and drop it into your email, Discord, Photoshop, or Finder folder.
- **Poof**: The file is moved (or copied) and vanishes from the shelf.

### 4. Clipboard Magic 📋
- **Summon**: Press `Cmd + Shift + Space` (default). Now works in **Password Fields** and Terminal thanks to our new low-level input engine.
- **Keyboard Navigation**: Use **Arrow Keys** to browse and **Enter** to paste instantly.
- **Multi-Item Support**: Copy multiple files, photos, or text snippets—Droppy captures them all simultaneously.
- **Search & Rename**: Type to search, or right-click to rename entries for better organization.
- **Direct Paste**: Click "Paste" on any item to send it immediately to your last active window.
- **Edit Content**: Click the **Pencil** icon on any text item to edit it directly—the UI morphs into a focused editor.
- **Fade Animation**: Dismiss the window with a smooth, fluid fade.

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

## 🛠️ Power User Tools

### 📉 Intelligent Compression (New in v2.3)
Droppy doesn't just squash files; it optimizes them.
- **Smart Defaults**: "Auto" uses HEVC for videos (1080p) and balanced settings for images.
- **Target Size**: Need a JPEG under 2MB? Right-click → Compress → **Target Size...** and tell it exactly what you need.
- **Size Guard**: If compression would make the file larger (common with some PDFs), Droppy **shakes no** and pulses a Green Shield 🛡️ to let you know it kept the original.

### 📝 Drag-and-Drop OCR
Need text from an image?
1. Drag an image into Droppy.
2. Hold **Shift** while dragging it out.
3. Drop it into a text editor. **Boom. It's text.**

---

## 📥 Installation

### Option 1: Homebrew (Recommended)
Updates are easy.
```bash
brew install --cask iordv/tap/droppy
```

### Option 2: Manual Download
1. Download [**Droppy.dmg**](https://github.com/iordv/Droppy/raw/main/Droppy.dmg).
2. Drag to Applications.
3. **Right-click → Open** on first launch.

> **Note**: If macOS says the app is damaged (Quarantine issue):
> ```bash
> xattr -d com.apple.quarantine /Applications/Droppy.app
> ```

---

## 🆕 What's New
<!-- CHANGELOG_START -->
Release v2.9.2

New Features:
- OCR for Images: You can now extract text directly from images in your clipboard using the new "Extract Text" button.
- RTF Support: Enhanced rendering for Rich Text content in the clipboard preview.
- UI Refinements: Improved OCR result view and window layering.
<!-- CHANGELOG_END -->

---

## License
MIT License. Free and Open Source forever.
Made with ❤️ by [Jordy Spruit](https://github.com/iordv).
