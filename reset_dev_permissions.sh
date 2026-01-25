#!/bin/bash
# Droppy Development Reset Script
# Run this ONCE to fix broken permissions on your dev machine

echo "🔧 Droppy Development Reset"
echo "============================"

# 1. Kill Droppy if running
echo "1. Killing Droppy..."
killall Droppy 2>/dev/null || echo "   (not running)"

# 2. Reset TCC database entries
echo "2. Resetting TCC database..."
tccutil reset Accessibility iordv.Droppy
tccutil reset ScreenCapture iordv.Droppy
tccutil reset ListenEvent iordv.Droppy

# 3. Clear Droppy's UserDefaults cache
echo "3. Clearing permission cache..."
defaults delete iordv.Droppy accessibilityGranted 2>/dev/null || true
defaults delete iordv.Droppy screenRecordingGranted 2>/dev/null || true
defaults delete iordv.Droppy inputMonitoringGranted 2>/dev/null || true
defaults delete iordv.Droppy permissionCacheVersion 2>/dev/null || true

# 4. Clean Xcode build
echo "4. Cleaning Xcode build..."
cd /Users/jordyspruit/Desktop/Droppy
xcodebuild clean -scheme Droppy -quiet 2>/dev/null || true

echo ""
echo "✅ Reset complete!"
echo ""
echo "Now do this:"
echo "1. Open Xcode"
echo "2. Build and Run (Cmd+R)"
echo "3. Grant ALL permissions when prompted"
echo "4. Quit and relaunch Droppy"
echo ""
echo "Everything should work after this."
