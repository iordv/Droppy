//
//  TidalAuthManager.swift
//  Droppy
//
//  Tidal lyrics fetching via LRCLIB (no authentication required)
//

import Foundation

/// Fetches synced lyrics from LRCLIB for Tidal tracks.
/// No API keys or authentication needed — LRCLIB is a free community service.
final class TidalAuthManager {
    static let shared = TidalAuthManager()

    private init() {}

    // MARK: - Lyrics (LRCLIB)

    /// Fetch synced lyrics via LRCLIB (lrclib.net) — free, no API key needed.
    /// Returns (syncedLyrics, plainLyrics) in LRC format.
    func fetchLyrics(title: String, artist: String, album: String, duration: Int, completion: @escaping (String?, String?) -> Void) {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "album_name", value: album),
            URLQueryItem(name: "duration", value: String(duration))
        ]

        guard let url = components.url else {
            completion(nil, nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Droppy/1.0 (https://droppy.app)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion(nil, nil)
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let synced = json["syncedLyrics"] as? String
                    let plain = json["plainLyrics"] as? String
                    completion(synced, plain)
                } else {
                    completion(nil, nil)
                }
            } catch {
                completion(nil, nil)
            }
        }.resume()
    }

    // MARK: - Extension Removal Cleanup

    /// Clean up all Tidal resources when extension is removed
    func cleanup() {
        UserDefaults.standard.removeObject(forKey: "tidalTracked")
        print("TidalAuthManager: Cleanup complete")
    }
}
