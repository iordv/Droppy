# Obsidian Extension Technical Documentation

Last updated: 2026-02-15

This document describes how the Obsidian extension is implemented in Droppy, including architecture, behavior, persistence, UI flows, and known constraints.

## Scope

Primary implementation files:

- `Droppy/Extensions/Obsidian/ObsidianExtension.swift`
- `Droppy/Extensions/Obsidian/ObsidianManager.swift`
- `Droppy/Extensions/Obsidian/ObsidianSettingsView.swift`
- `Droppy/Extensions/Obsidian/ObsidianShelfBar.swift`
- `Droppy/Extensions/Obsidian/ObsidianQuickPanel.swift`
- `Droppy/Extensions/Obsidian/ObsidianFullEditor.swift`
- `Droppy/Extensions/Obsidian/ObsidianPreviewView.swift`

Key integration points outside the extension folder:

- `Droppy/NotchShelfView.swift` (button, visibility, hotkey handling, sizing)
- `Droppy/UserPreferences.swift` (preference keys/defaults)
- `Droppy/ExtensionsShopView.swift` and `Droppy/ExtensionInfoView.swift` (store/config entry points)
- `Droppy/GlobalHotKey.swift` and `Droppy/KeyShortcutRecorder.swift` (global shortcut capture + registration)

## Extension Overview

Obsidian is a productivity extension that lets users:

- Configure a vault path.
- Pin markdown notes (plus a built-in Daily note).
- Append/prepend text quickly from the notch shelf.
- Target entire notes or specific markdown headings.
- Open a split full editor with syntax highlighting and save support for non-daily notes.
- Trigger the extension from a global hotkey.

## Architecture

### Definition Layer

`ObsidianExtension` provides metadata for the extension system:

- ID: `obsidian`
- Category: `.productivity`
- Icon: `book.pages`, purple accent
- Preview: `ObsidianPreviewView`
- Cleanup hook: `ObsidianManager.shared.cleanup()`

### State + Logic Layer

`ObsidianManager` is a singleton `@Observable` and is the source of truth for:

- Pinned notes and current selection.
- Quick panel/full editor visibility.
- Input text and last-used action (`append` or `prepend`).
- Vault validation status and error state.
- Current note content/headings.
- External-change tracking and success flash state.
- Global hotkey registration.

### View Layer

- `ObsidianShelfBar`: chip bar, optional quick panel, optional split editor.
- `ObsidianQuickPanel`: heading picker, short input, append/prepend actions.
- `ObsidianFullEditor`: markdown editor wrapper with heading jump + save button.
- `ObsidianSettingsView` (`ObsidianInfoView`): install/configuration UI in extension settings/store.
- `ObsidianPreviewView`: static preview card for extension gallery.

## Data Model

### `PinnedNote`

Fields:

- `id: UUID`
- `fileName: String`
- `relativePath: String` (relative to vault root)
- `defaultHeading: String?`
- `displayName: String`
- `isDaily: Bool`

Notes:

- Backward-compatible decode defaults missing `isDaily` to `false`.
- Built-in daily note factory creates `Daily.md` with display name `Daily` and `isDaily = true`.

### `NoteAction`

- `append`
- `prepend`

### `VaultStatus`

- `notConfigured`
- `valid`
- `invalid`
- `cliUnavailable`

## Persistence and Preferences

### UserDefaults keys

Defined in `AppPreferenceKey`:

- `obsidian_installed`
- `obsidian_enabled`
- `obsidian_vaultPath`
- `obsidian_useCLI`
- `obsidian_shortcut` (JSON-encoded `SavedShortcut`)
- `obsidian_lastSelectedNoteID`

Default values in `PreferenceDefault`:

- installed: `false`
- enabled: `true`
- vault path: `""`
- use CLI: `true`
- last selected note ID: `""`

### Pinned notes file

Pinned notes are persisted as JSON at:

- `~/Library/Application Support/Droppy/obsidian_pinned.json`

Behavior:

- First run with no file seeds one note: built-in Daily.
- Writes are debounced (`~80ms`) on a utility queue.

## Setup and Lifecycle

### Install/Uninstall

- Install sets `obsidian_installed = true`, clears removed state, posts `extensionStateChanged`.
- Uninstall sets `obsidian_installed = false`, marks extension removed, calls manager cleanup, posts `extensionStateChanged`.

### Manager lifecycle

- `init`: registers defaults, loads pinned notes, validates vault, restores hotkey.
- `show`: opens extension and auto-opens quick panel for preferred note.
- `hide`: collapses quick panel/editor and editing state.
- `cleanup`: hides UI, deregisters hotkey, cancels save work, stops change detection.

## Vault Validation

Validation checks:

1. Vault path non-empty.
2. Path exists and is a directory.
3. If CLI mode is enabled, `/Applications/Obsidian.app/Contents/MacOS/obsidian` must be executable.

Outcomes map to `VaultStatus` values.

## Note Selection and Pinned Note Management

### Selection behavior

- Selecting a note updates `selectedNoteID`, persists last selected ID, applies note default heading, starts external change detection, and loads content.
- Deselecting clears current content/headings/selection and collapses quick/full panels.

### Preferred note selection logic

When opening from hidden state, manager prefers:

1. Currently selected note (if still present).
2. Persisted last selected note.
3. First pinned note.

### Pin/unpin behavior

- Add note stores path relative to vault root.
- Duplicate relative paths are ignored.
- Removing selected note deselects it and adjusts persisted selection if needed.
- Daily note can be re-added from settings if removed.

## Backends: CLI vs Filesystem

The extension supports two operation backends:

- Obsidian CLI (preferred when enabled and available).
- Direct filesystem reads/writes (fallback and heading-target operations).

### CLI command execution details

- CLI path: `/Applications/Obsidian.app/Contents/MacOS/obsidian`
- Commands run through `/bin/zsh -l -c ...` (not direct `Process` launch of Electron binary).
- Manager prepends `vault=<vaultFolderName>` argument when vault is set.
- Each arg is shell-escaped.
- Timeout: 5 seconds (process terminated on timeout).
- Stdout is cleaned to remove Obsidian startup noise (`Loading updated app package`).

### Routing matrix (summary)

- Read note:
  - Non-daily: CLI `read path=<relativePath>` then filesystem fallback.
  - Daily: CLI `daily:read` then filesystem fallback.
- Append/prepend without heading:
  - Non-daily: CLI `append` / `prepend` then filesystem fallback.
  - Daily: CLI `daily:append` / `daily:prepend` then filesystem fallback.
- Append/prepend with heading:
  - Always filesystem path write (CLI does not support heading targeting).
- Full note save:
  - Non-daily: CLI `create path=<relativePath> content=<content> overwrite silent` then filesystem fallback.
  - Daily: CLI `daily silent` (resolve path) + `create ... overwrite silent` then filesystem fallback.

## Daily Note Resolution

For filesystem daily-note operations, manager resolves today’s file by:

1. Reading vault config at `.obsidian/daily-notes.json` if present.
2. Using:
   - `folder` (optional)
   - `format` (Moment-style, default `YYYY-MM-DD`)
3. Converting format tokens to Swift `DateFormatter` style:
   - `YYYY -> yyyy`
   - `YY -> yy`
   - `DD -> dd`
   - `Do -> d`
4. Building `<folder>/<date>.md` (or `<date>.md` if folder empty).
5. Returning `nil` if resulting file does not exist.

If unresolved, daily actions/read return user-facing errors.

## Text Insertion Semantics

### Heading parsing

- Headings are parsed from current content via regex `^#{1,6}\s+(.+)$`.
- Parsing skips fenced code block regions delimited by triple backticks.
- Stored heading strings include the markdown prefix (for example `## Tasks`).

### Append behavior

- No heading target:
  - Ensures file ends in newline.
  - Appends `content + "\n"` at EOF.
- Heading target:
  - Finds exact heading line match.
  - Inserts content before next section boundary:
    - next markdown heading, or
    - thematic break line equivalent to `---` (spaces ignored).
  - If no later boundary, inserts at end.

### Prepend behavior

- No heading target:
  - Inserts after YAML frontmatter if present, else at top.
- Heading target:
  - Inserts immediately after matching heading line.
  - If heading not found, falls back to prepend-after-frontmatter behavior.

## Quick Panel Behavior

Quick panel includes:

- Heading scope menu (`Entire note` + parsed headings).
- Multiline text field (`2...3` lines).
- Prepend and Append actions.
- Success flash indicator.
- Expand control to full editor.

Interaction details:

- Enter submits using `lastUsedAction`.
- Clicking action buttons sets `lastUsedAction` and executes immediately.
- On success, input clears and checkmark flash appears for `~1.2s`.
- Focus is aggressively retried on appear/window activation (0/60/160/320ms) to avoid first-responder races.

## Full Editor Behavior

The split editor view supports:

- Large editable markdown area (`NSTextView` wrapper).
- Heading jump menu (scrolls to selected heading in text).
- Save button for both daily and non-daily notes.
- While CLI mode is active, full-save button shows a spinner during save execution.
- External-change warning banner with reload action.

### Syntax highlighting rules

- Headings (`#` to `######`): bold + white.
- Wikilinks `[[...]]`: purple.
- Markdown links `[...](...)`:
  - Link label: purple accent.
  - URL target: blue + underline.
- Frontmatter at file start (`--- ... ---`): dimmed block; `key::` style keys tinted.
- Fenced code blocks:
  - Supports both backticks (```) and tildes (`~~~`).
  - Fence markers dimmed; optional language hint tinted.
  - Body uses code tint plus lightweight language-aware token colors:
    - Comments, strings, numbers.
    - Keyword sets for Swift, JS/TS, Python, and shell.
- Inline code spans (`` `...` ``): green tint with subtle background.
- Emphasis: bold (`**`/`__`), italic (`*`/`_`), strikethrough (`~~`).
- Lists:
  - Ordered/unordered list markers tinted.
  - Task checkboxes (`- [ ]`, `- [x]`) colorized by state.
- Blockquotes and callouts (`>`, `> [!...]`) colorized.
- Horizontal rules (`---`, `***`, `___`) dimmed.
- Tables (pipe rows + separators) tinted.
- Footnotes (`[^id]` refs and definitions) tinted.
- Tags (`#tag`) tinted.

Highlighting performance:

- For documents >5KB, highlighting is debounced (~100ms).

## External Change Detection

- Enabled only when a non-daily note is selected.
- Timer polls every 3 seconds for file modification date changes.
- If changed externally, `hasExternalChanges` becomes true and banner appears.
- Reload action re-reads current note and clears unsaved-change state in editor.

## Global Hotkey Flow

1. Settings UI records shortcut via `KeyShortcutRecorder`.
2. `SavedShortcut` JSON is stored in `obsidian_shortcut`.
3. Manager registers `GlobalHotKey` with callback posting `.obsidianHotkeyTriggered`.
4. `NotchShelfView` receives notification and:
   - Resolves target display (main/active display logic).
   - Expands shelf on target display.
   - Toggles Obsidian visibility.
   - Activates app when opening (for reliable text focus).
   - Closes conflicting panels (terminal/camera/caffeine/todo list).

## Notch/Shelf Integration

### Visibility and exclusivity

Obsidian button is shown when:

- Installed (`obsidian_installed`), enabled (`obsidian_enabled`), not removed.
- No shelf items are occupying the display slot (`shelfDisplaySlotCount == 0`).

When Obsidian opens, it closes:

- Terminal Notch
- Camera/Notchface
- Caffeine
- To-do expanded list state

### Layout behavior

`ObsidianShelfBar` heights:

- Chip-only: 28pt content region (+ notch insets).
- Quick panel + chips: 132 + 6 + 28 = 166pt content region (+ insets).
- Full split editor: 340pt content region (+ insets).

Split editor width behavior:

- Shelf width expands to at least ~720 when full editor is open.

Auto-collapse behavior:

- Auto-shrink is suppressed while user is actively editing Obsidian (`isUserEditingObsidian`).

## Error and Status Surfaces

Manager stores user-facing error text in `errorMessage` for:

- Failed read/write operations.
- Daily note path resolution failures.
- Save failures (CLI + filesystem fallback path).

Vault status indicators in settings:

- Green: valid
- Red: invalid path or CLI unavailable
- Gray: not configured

## Known Constraints

- Heading-target append/prepend is filesystem-only; CLI cannot target heading sections.
- Daily note path resolution depends on today’s file existing on disk.
- Heading matching is exact string comparison (including markdown hash prefix).
- External change detection is disabled for daily notes.

## Recommended QA Checklist

1. Install extension, verify button appears only when enabled and slot is free.
2. Set vault path and confirm status transitions (not configured -> valid/invalid).
3. Toggle CLI on/off and verify fallback when Obsidian app binary is unavailable.
4. Pin regular note + daily note; verify persistence after app restart.
5. Test quick append/prepend to entire note and to specific headings.
6. Test heading-target append/prepend with fenced code blocks and frontmatter.
7. Open full editor, modify regular note, save, and confirm file content updates.
8. Verify both regular and daily notes can be full-saved from editor (CLI mode on).
9. Verify save falls back to filesystem when CLI fails/unavailable.
10. Edit selected file externally; verify change banner and reload behavior.
11. Configure global hotkey; verify toggle/focus behavior and cross-display handling.
12. Confirm Obsidian opening closes terminal/camera/caffeine/todo views.
13. Confirm auto-collapse does not interrupt active text editing.
