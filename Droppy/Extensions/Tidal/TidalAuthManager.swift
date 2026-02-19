//
//  TidalAuthManager.swift
//  Droppy
//
//  Tidal extension cleanup manager
//

import Foundation

/// Manages cleanup for the Tidal extension.
final class TidalAuthManager {
    static let shared = TidalAuthManager()

    private init() {}

    // MARK: - Extension Removal Cleanup

    /// Clean up all Tidal resources when extension is removed
    func cleanup() {
        UserDefaults.standard.removeObject(forKey: "tidalTracked")
        print("TidalAuthManager: Cleanup complete")
    }
}
