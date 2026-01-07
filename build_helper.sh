#!/bin/bash
# Build DroppyUpdater helper and copy to app bundle

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
HELPER_SRC="$PROJECT_DIR/DroppyUpdater/main.swift"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/Release/Droppy.app"
HELPERS_DIR="$APP_BUNDLE/Contents/Helpers"

echo "Building DroppyUpdater helper..."

# Create build directory
mkdir -p "$BUILD_DIR"

# Compile the helper
swiftc -o "$BUILD_DIR/DroppyUpdater" \
    "$HELPER_SRC" \
    -framework AppKit \
    -framework SwiftUI \
    -O \
    -target arm64-apple-macos14.0

echo "✅ DroppyUpdater built successfully"

# If app bundle exists, copy helper to it
if [ -d "$APP_BUNDLE" ]; then
    mkdir -p "$HELPERS_DIR"
    cp "$BUILD_DIR/DroppyUpdater" "$HELPERS_DIR/"
    echo "✅ Copied to $HELPERS_DIR"
fi
