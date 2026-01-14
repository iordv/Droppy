---
description: Release a new version of Droppy
---

1. Ask the user for the **Version Number** (e.g., 2.0.3).

2. **Pre-Release Checklist** (verify before proceeding):
   - If new features require permissions (microphone, camera, etc.), verify the entitlement is in `Droppy.entitlements`:
     - Microphone: `com.apple.security.device.audio-input`
     - Camera: `com.apple.security.device.camera`
   - If new features require Info.plist usage descriptions, verify they exist.

3. **Generate Release Notes**:
   - Run `git describe --tags --abbrev=0` to get the last tag.
   - Run `git log [LAST_TAG]..HEAD --pretty=format:"- %s"` to get the changes.
   - Summarize these changes into a user-friendly format (Features, Fixes, Improvements).
   - **Write naturally** – avoid robotic/AI-generated phrasing. Use casual, human language like "Fixed a bug where..." instead of "Resolved an issue that caused...". Keep it concise and friendly.
   - Write the summarized notes to `release_notes.txt`.

4. Run the release script with the auto-confirm flag:
   ```bash
   ./release_droppy.sh [VERSION] release_notes.txt -y
   ```

5. **Post-Release Verification** (before notifying user):
   - Run `brew upgrade iordv/tap/droppy` to install the new version
   - Verify `codesign -dv --entitlements - /Applications/Droppy.app` shows expected entitlements
   - Quick smoke test any new features

6. Notify the user that the release is complete with the generated notes.
