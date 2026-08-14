//  AppState.swift
//  Global app state — connectivity, auth, session tracking.
//  Per Decision #28: offline detection with cached data fallback.
//  Per Decision #9: health endpoint for liveness check (no auth).

import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    // Connectivity
    @Published var isOnline: Bool = false
    @Published var isCheckingConnection: Bool = false
    @Published var lastHealthCheck: Date?

    // Auth
    @Published var isAuthenticated: Bool = false
    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "lingua_api_key")
            isAuthenticated = !apiKey.isEmpty
        }
    }

    // Active session (for resume)
    @Published var activeSession: ActiveSession?
    @Published var hasPendingSession: Bool = false

    // Cached data for offline display
    @Published var cachedProgress: [CityProgress] = []
    @Published var cachedDueCount: Int = 0

    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "lingua_api_key") ?? ""
        self.isAuthenticated = !apiKey.isEmpty
    }

    func checkConnection() async {
        guard !isCheckingConnection else { return }
        isCheckingConnection = true

        do {
            let response = try await APIClient.shared.health()
            isOnline = (response.status == "ok")
            lastHealthCheck = Date()
        } catch {
            isOnline = false
        }

        isCheckingConnection = false
    }

    func loadAPIKeyFromKeychain() {
        // TODO: Migrate from UserDefaults to Keychain
        // For now, UserDefaults is fine for dev — Drew's single device
    }
}