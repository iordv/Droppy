//
//  AnalyticsService.swift
//  Droppy
//
//  Created by Jordy Spruit on 04/01/2026.
//

import Foundation
import SwiftUI

/// Service for tracking anonymous app usage statistics (installs and daily active users)
/// Privacy-focused: No personal data, just counts.
final class AnalyticsService: Sendable {
    static let shared = AnalyticsService()
    
    // TODO: Replace with actual values from Supabase project
    private let supabaseURL = URL(string: "https://anannmonpspjsnfgdglb.supabase.co/rest/v1/analytics_events")!
    private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFuYW5ubW9ucHNwanNuZmdkZ2xiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NDgxODQsImV4cCI6MjA4MzEyNDE4NH0.5BvuW5cS0kJCuA2Nm5HCVDLNWNzn6EA_8JVVrW6pfnY"
    
    // UserDefaults keys
    private let kAnalyticsID = "droppy_analytics_id"
    private let kHasTrackedInstall = "droppy_has_tracked_install"
    
    private init() {}
    
    /// Called on app launch to track stats
    func logAppLaunch() {
        Task {
            // 1. Ensure we have an anonymous ID
            let analyticsID = getOrGenerateAnalyticsID()
            
            // 2. Track install if new
            if !UserDefaults.standard.bool(forKey: kHasTrackedInstall) {
                await trackEvent(type: "install", id: analyticsID)
                UserDefaults.standard.set(true, forKey: kHasTrackedInstall)
            }
            
            // 3. Track launch (active user)
            await trackEvent(type: "launch", id: analyticsID)
        }
    }
    
    private func getOrGenerateAnalyticsID() -> String {
        if let existing = UserDefaults.standard.string(forKey: kAnalyticsID) {
            return existing
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: kAnalyticsID)
        return newID
    }
    
    private func trackEvent(type: String, id: String) async {
        // Construct payload
        let payload: [String: Any] = [
            "event_type": type,
            "anonymous_id": id,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "os_version": ProcessInfo.processInfo.operatingSystemVersionString
        ]
        
        do {
            var request = URLRequest(url: supabaseURL)
            request.httpMethod = "POST"
            request.addValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            request.addValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            // Prefer minimal representation to save bandwidth
            request.addValue("return=minimal", forHTTPHeaderField: "Prefer")
            
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("Analytics failed: \(httpResponse.statusCode)")
            }
        } catch {
            print("Analytics error: \(error)")
        }
    }
    
    /// Fetches the total number of unique installs (downloads)
    func fetchDownloadCount() async throws -> Int {
        // RPC endpoint: /rest/v1/rpc/get_download_count
        let rpcURL = URL(string: "https://anannmonpspjsnfgdglb.supabase.co/rest/v1/rpc/get_download_count")!
        
        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.addValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Supabase RPCs need a body, even if empty
        request.httpBody = try JSONSerialization.data(withJSONObject: [:])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Response is just the integer number (e.g. 42)
        if let str = String(data: data, encoding: .utf8), let count = Int(str.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return count
        }
        
        return 0
    }
    
    // MARK: - Extension Tracking
    
    private let extensionStatsURL = URL(string: "https://anannmonpspjsnfgdglb.supabase.co/rest/v1/extension_stats")!
    
    /// Track when an extension is activated (enabled)
    /// Also sets a local flag so UI can check installed state
    func trackExtensionActivation(extensionId: String) {
        // Set local install flag immediately for UI responsiveness
        // This persists the installed state so cards and filters work without network
        let localKey = "\(extensionId)Tracked"
        UserDefaults.standard.set(true, forKey: localKey)
        
        // Track to Supabase for analytics
        Task {
            let analyticsID = getOrGenerateAnalyticsID()
            await trackExtensionEvent(extensionId: extensionId, action: "activate", id: analyticsID)
        }
    }
    
    private func trackExtensionEvent(extensionId: String, action: String, id: String) async {
        let payload: [String: Any] = [
            "extension_id": extensionId,
            "anonymous_id": id,
            "action": action,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        ]
        
        do {
            var request = URLRequest(url: extensionStatsURL)
            request.httpMethod = "POST"
            request.addValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            request.addValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            // Use upsert to handle duplicate tracking (same user activating same extension)
            request.addValue("resolution=ignore-duplicates", forHTTPHeaderField: "Prefer")
            
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("Extension tracking failed: \(httpResponse.statusCode)")
            }
        } catch {
            print("Extension tracking error: \(error)")
        }
    }
    
    /// Fetches install counts for all extensions
    func fetchExtensionCounts() async throws -> [String: Int] {
        let rpcURL = URL(string: "https://anannmonpspjsnfgdglb.supabase.co/rest/v1/rpc/get_extension_counts")!
        
        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.addValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [:])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Response is array of {extension_id, install_count}
        if let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            var counts: [String: Int] = [:]
            for result in results {
                if let extId = result["extension_id"] as? String,
                   let count = result["install_count"] as? Int {
                    counts[extId] = count
                }
            }
            return counts
        }
        
        return [:]
    }
    
    // MARK: - Extension Ratings
    
    /// Rating data structure
    struct ExtensionRating {
        let averageRating: Double
        let ratingCount: Int
    }
    
    /// Submit a rating for an extension
    func submitExtensionRating(extensionId: String, rating: Int, feedback: String?) async throws {
        let ratingsURL = URL(string: "https://anannmonpspjsnfgdglb.supabase.co/rest/v1/extension_ratings")!
        let analyticsID = getOrGenerateAnalyticsID()
        
        var payload: [String: Any] = [
            "extension_id": extensionId,
            "anonymous_id": analyticsID,
            "rating": rating
        ]
        
        if let feedback = feedback, !feedback.isEmpty {
            payload["feedback"] = feedback
        }
        
        var request = URLRequest(url: ratingsURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.addValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // Upsert: update if exists, insert if not
        request.addValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    /// Fetch average ratings for all extensions
    func fetchExtensionRatings() async throws -> [String: ExtensionRating] {
        let rpcURL = URL(string: "https://anannmonpspjsnfgdglb.supabase.co/rest/v1/rpc/get_extension_ratings")!
        
        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.addValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [:])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Response is array of {extension_id, average_rating, rating_count}
        if let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            var ratings: [String: ExtensionRating] = [:]
            for result in results {
                if let extId = result["extension_id"] as? String,
                   let avg = (result["average_rating"] as? NSNumber)?.doubleValue,
                   let count = result["rating_count"] as? Int {
                    ratings[extId] = ExtensionRating(averageRating: avg, ratingCount: count)
                }
            }
            return ratings
        }
        
        return [:]
    }
    
    /// Fetch all individual reviews for a specific extension
    func fetchExtensionReviews(extensionId: String) async throws -> [ExtensionReview] {
        let url = URL(string: "https://anannmonpspjsnfgdglb.supabase.co/rest/v1/extension_ratings?extension_id=eq.\(extensionId)&order=created_at.desc")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.addValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Parse the JSON response
        if let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            var reviews: [ExtensionReview] = []
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            for result in results {
                if let rating = result["rating"] as? Int {
                    let feedback = result["feedback"] as? String
                    var createdAtDate = Date()
                    if let createdAtString = result["created_at"] as? String {
                        createdAtDate = dateFormatter.date(from: createdAtString) ?? Date()
                    }
                    
                    reviews.append(ExtensionReview(
                        id: result["id"] as? String ?? UUID().uuidString,
                        rating: rating,
                        feedback: feedback,
                        createdAt: createdAtDate
                    ))
                }
            }
            return reviews
        }
        
        return []
    }
}

// MARK: - Extension Review Model

struct ExtensionReview: Identifiable {
    let id: String
    let rating: Int
    let feedback: String?
    let createdAt: Date
}
