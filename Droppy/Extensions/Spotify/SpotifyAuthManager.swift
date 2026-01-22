//
//  SpotifyAuthManager.swift
//  Droppy
//
//  Created by Droppy on 10/01/2026.
//  Spotify Web API OAuth 2.0 PKCE authentication and API calls
//

import AppKit
import Foundation
import Security

/// Manages Spotify Web API authentication and API calls for library features
final class SpotifyAuthManager {
    static let shared = SpotifyAuthManager()
    
    // MARK: - Configuration
    
    // TODO: Replace with your Spotify Developer App credentials
    // Create an app at: https://developer.spotify.com/dashboard
    private var clientId: String = ""
    private let redirectUri = "droppy://spotify-callback"
    private let scopes = "user-library-read user-library-modify user-read-playback-state"
    
    // MARK: - Token Storage Keys
    
    private let accessTokenKey = "SpotifyAccessToken"
    private let refreshTokenKey = "SpotifyRefreshToken"
    private let tokenExpiryKey = "SpotifyTokenExpiry"
    private let keychainService = "com.iordv.droppy.spotify"
    
    // MARK: - PKCE State
    
    private var codeVerifier: String?
    
    // MARK: - State
    
    var isAuthenticated: Bool {
        return getRefreshToken() != nil
    }
    
    var hasValidClientId: Bool {
        return clientId != "YOUR_SPOTIFY_CLIENT_ID" && !clientId.isEmpty
    }
    
    // MARK: - Initialization
    
    private init() {
        loadConfiguration()
    }

    private func loadConfiguration() {
        // Try to load from SpotifyConfig.plist
        guard let url = Bundle.main.url(forResource: "SpotifyConfig", withExtension: "plist") else {
            print("SpotifyAuthManager: SpotifyConfig.plist not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            if let config = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let id = config["SpotifyClientID"] as? String {
                self.clientId = id
            }
        } catch {
            print("SpotifyAuthManager: Failed to load configuration: \(error)")
        }
    }
    
    // MARK: - OAuth Flow
    
    /// Start the OAuth authorization flow
    func startAuthentication() {
        guard hasValidClientId else {
            print("SpotifyAuthManager: No valid Client ID configured")
            return
        }
        
        // Generate PKCE code verifier and challenge
        codeVerifier = generateCodeVerifier()
        guard let verifier = codeVerifier,
              let challenge = generateCodeChallenge(from: verifier) else {
            print("SpotifyAuthManager: Failed to generate PKCE challenge")
            return
        }
        
        // Build authorization URL
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge)
        ]
        
        guard let url = components.url else {
            print("SpotifyAuthManager: Failed to build authorization URL")
            return
        }
        
        print("SpotifyAuthManager: Opening authorization URL")
        NSWorkspace.shared.open(url)
    }
    
    /// Handle OAuth callback URL
    func handleCallback(url: URL) -> Bool {
        guard url.scheme == "droppy",
              url.host == "spotify-callback" else {
            return false
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            print("SpotifyAuthManager: No authorization code in callback")
            return false
        }
        
        print("SpotifyAuthManager: Received authorization code")
        exchangeCodeForToken(code: code)
        return true
    }
    
    /// Exchange authorization code for access token
    private func exchangeCodeForToken(code: String) {
        guard let verifier = codeVerifier else {
            print("SpotifyAuthManager: No code verifier available")
            return
        }
        
        let url = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectUri,
            "client_id": clientId,
            "code_verifier": verifier
        ]
        
        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            self?.codeVerifier = nil  // Clear verifier
            
            if let error = error {
                print("SpotifyAuthManager: Token exchange error: \(error)")
                return
            }
            
            guard let data = data else {
                print("SpotifyAuthManager: No data in token response")
                return
            }
            
            self?.parseTokenResponse(data: data)
        }.resume()
    }
    
    /// Refresh the access token using refresh token
    func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        guard let refreshToken = getRefreshToken() else {
            print("SpotifyAuthManager: No refresh token available")
            completion(false)
            return
        }
        
        let url = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId
        ]
        
        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("SpotifyAuthManager: Token refresh error: \(error)")
                completion(false)
                return
            }
            
            guard let data = data else {
                print("SpotifyAuthManager: No data in refresh response")
                completion(false)
                return
            }
            
            if self?.parseTokenResponse(data: data) == true {
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }
    
    @discardableResult
    private func parseTokenResponse(data: Data) -> Bool {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("SpotifyAuthManager: Invalid JSON response")
                return false
            }
            
            if let error = json["error"] as? String {
                print("SpotifyAuthManager: API error: \(error)")
                return false
            }
            
            guard let accessToken = json["access_token"] as? String,
                  let expiresIn = json["expires_in"] as? Int else {
                print("SpotifyAuthManager: Missing token fields")
                return false
            }
            
            // Store tokens
            saveToKeychain(key: accessTokenKey, value: accessToken)
            
            if let refreshToken = json["refresh_token"] as? String {
                saveToKeychain(key: refreshTokenKey, value: refreshToken)
            }
            
            // Store expiry time
            let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
            UserDefaults.standard.set(expiryDate, forKey: tokenExpiryKey)
            
            print("SpotifyAuthManager: Tokens saved successfully")
            
            // Notify controller
            DispatchQueue.main.async {
                SpotifyController.shared.updateAuthState()
            }
            
            return true
        } catch {
            print("SpotifyAuthManager: JSON parse error: \(error)")
            return false
        }
    }
    
    // MARK: - API Calls
    
    /// Get valid access token, refreshing if needed
    private func getValidAccessToken(completion: @escaping (String?) -> Void) {
        // Check if token is expired
        if let expiry = UserDefaults.standard.object(forKey: tokenExpiryKey) as? Date,
           expiry < Date() {
            // Token expired, refresh it
            refreshAccessToken { [weak self] success in
                if success {
                    completion(self?.getAccessToken())
                } else {
                    completion(nil)
                }
            }
            return
        }
        
        completion(getAccessToken())
    }
    
    /// Save a track to user's Liked Songs
    func saveTrack(uri: String, completion: @escaping (Bool) -> Void) {
        // Extract track ID from URI (spotify:track:xxxxx -> xxxxx)
        let trackId = uri.replacingOccurrences(of: "spotify:track:", with: "")
        
        getValidAccessToken { [weak self] token in
            guard let token = token else {
                completion(false)
                return
            }
            
            self?.makeAPIRequest(
                endpoint: "https://api.spotify.com/v1/me/tracks",
                method: "PUT",
                body: ["ids": [trackId]],
                token: token
            ) { success, _ in
                completion(success)
            }
        }
    }
    
    /// Remove a track from user's Liked Songs
    func removeTrack(uri: String, completion: @escaping (Bool) -> Void) {
        let trackId = uri.replacingOccurrences(of: "spotify:track:", with: "")
        
        getValidAccessToken { [weak self] token in
            guard let token = token else {
                completion(false)
                return
            }
            
            self?.makeAPIRequest(
                endpoint: "https://api.spotify.com/v1/me/tracks",
                method: "DELETE",
                body: ["ids": [trackId]],
                token: token
            ) { success, _ in
                completion(success)
            }
        }
    }
    
    /// Check if a track is saved in user's library
    func checkIfTrackIsSaved(uri: String, completion: @escaping (Bool) -> Void) {
        let trackId = uri.replacingOccurrences(of: "spotify:track:", with: "")
        
        getValidAccessToken { [weak self] token in
            guard let token = token else {
                completion(false)
                return
            }
            
            let endpoint = "https://api.spotify.com/v1/me/tracks/contains?ids=\(trackId)"
            self?.makeAPIRequest(endpoint: endpoint, method: "GET", body: nil, token: token) { success, data in
                guard success, let data = data,
                      let results = try? JSONSerialization.jsonObject(with: data) as? [Bool],
                      let isSaved = results.first else {
                    completion(false)
                    return
                }
                completion(isSaved)
            }
        }
    }
    
    private func makeAPIRequest(
        endpoint: String,
        method: String,
        body: [String: Any]?,
        token: String,
        completion: @escaping (Bool, Data?) -> Void
    ) {
        guard let url = URL(string: endpoint) else {
            completion(false, nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("SpotifyAuthManager: API error: \(error)")
                completion(false, nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                let success = (200...299).contains(httpResponse.statusCode)
                completion(success, data)
            } else {
                completion(false, nil)
            }
        }.resume()
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        deleteFromKeychain(key: accessTokenKey)
        deleteFromKeychain(key: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: tokenExpiryKey)
        print("SpotifyAuthManager: Signed out")
    }
    
    // MARK: - Extension Removal Cleanup
    
    /// Clean up all Spotify resources when extension is removed
    func cleanup() {
        // Sign out (clears tokens)
        signOut()
        
        // Clear tracking state
        UserDefaults.standard.removeObject(forKey: "spotifyTracked")
        
        // Notify controller
        DispatchQueue.main.async {
            SpotifyController.shared.updateAuthState()
        }
        
        print("SpotifyAuthManager: Cleanup complete")
    }

    
    // MARK: - PKCE Helpers
    
    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private func generateCodeChallenge(from verifier: String) -> String? {
        guard let data = verifier.data(using: .utf8) else { return nil }
        
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    // MARK: - Keychain Helpers
    
    private func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
        
        var newItem = query
        newItem[kSecValueData as String] = data
        
        let status = SecItemAdd(newItem as CFDictionary, nil)
        if status != errSecSuccess {
            print("SpotifyAuthManager: Keychain save error: \(status)")
        }
    }
    
    private func getFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    private func getAccessToken() -> String? {
        return getFromKeychain(key: accessTokenKey)
    }
    
    private func getRefreshToken() -> String? {
        return getFromKeychain(key: refreshTokenKey)
    }
}

// MARK: - CommonCrypto Bridge

import CommonCrypto
