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

🚀 **Version 2.7.1 is here!** Introducing the **Liquid Clipboard Manager** with Direct Editing, Morphing UI, and rock-solid stability!

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
|**📋 Clipboard Manager**|A powerful liquid history. Search, **Edit**, Rename, Favorite, and Drag & Drop.|

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
- **Summon**: Press `Cmd + Shift + Space` (default) to bring up your clipboard history.
- **Search & Rename**: Type to search, or right-click to rename entries for better organization.
- **Multi-Drag**: Select multiple items and drag them directly into the Notch, Basket, or any other app.
- **Direct Paste**: Click "Paste" on any item to send it immediately to your last active window.
- **Edit Content**: Click the **Pencil** icon on any text item to edit it directly. The UI morphs into a focused editor.
- **Smart Drag**: Drag items from the clipboard directly to the Shelf or other apps.

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
# Droppy v2.7.2: The "Liquid" Update Experience ✨

*This release introduces a stunning new update screen and solidifies v2.7.x stability.*

This release marks a major milestone for Droppy, ensuring that even the update process feels like a premium, fluid experience.

### ✨ New Update Experience
- **Liquid Glass UI**: The update screen is no longer a boring system alert. It is now a beautiful, translucent window that follows the macOS 26 design language.
- **Rich Release Notes**: Release notes now support **bold**, *italics*, and lists, making it easier to see what's new.
- **Scrollable Content**: No more truncated text! You can now scroll through the full history of changes.

### 📋 Liquid Clipboard Manager
- **Direct Content Editing**: Edit text and URLs directly in the history. The UI morphs seamlessly into a dedicated editor.
- **Smart Deduplication**: Copying an existing item now intelligently moves it to the top without creating duplicates.
- **Persistent Metadata**: Your "Favorites" and "Renamed Titles" are preserved even if you copy the item again.
- **Visual History**: Rich previews for text, images, files, and colors.
- **Fluid Animations**: "Marching ants" animations for search, rename, and editing modes indicate active states clearly.
- **Drag & Drop**: Seamlessly drag items from history directly to the Shelf, Basket, or other apps.

### 🛡️ Core Stability & Performance
- **Crash Fixed**: Resolved a critical crash (`objc_release`) affecting the Notch Window by separating high-frequency interaction logic (50ms) from heavy environment checks.
- **Animation Fixes**: Eliminated `CoreAnimation` transaction crashes during fullscreen transitions.
- **Optimization**: Reduced CPU and Memory usage by 20x for background visibility checks.

### 🧺 Basket & Shelf
- **Refined**: Improved click-through behavior and "Jiggle" detection accuracy.

Update now for the smoothest, most stable Droppy experience yet! 🚀
<!-- CHANGELOG_END -->

---

## License
MIT License. Free and Open Source forever.
Made with ❤️ by [Jordy Spruit](https://github.com/iordv).
