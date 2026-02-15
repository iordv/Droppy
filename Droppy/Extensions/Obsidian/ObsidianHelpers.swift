//
//  ObsidianHelpers.swift
//  Droppy
//
//  Shared display utilities for Obsidian heading labels
//

import Foundation

enum ObsidianDisplay {
    /// Strips leading `#` characters and whitespace from a markdown heading.
    /// `"## Tasks"` → `"Tasks"`.
    static func headingDisplayText(_ heading: String) -> String {
        var s = heading[heading.startIndex...]
        while s.first == "#" { s = s.dropFirst() }
        return String(s).trimmingCharacters(in: .whitespaces)
    }

    /// Counts the `#` prefix length of a heading string.
    static func headingDepth(_ heading: String) -> Int {
        var count = 0
        for ch in heading {
            if ch == "#" { count += 1 } else { break }
        }
        return count
    }

    /// Leading padding for menu indentation: `(depth - 1) * 8` points.
    static func headingIndent(_ heading: String) -> CGFloat {
        CGFloat(max(0, headingDepth(heading) - 1)) * 8
    }
}
