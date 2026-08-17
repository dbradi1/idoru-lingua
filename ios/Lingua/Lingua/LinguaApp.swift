//  LinguaApp.swift
//  Lingua — Italian learning app
//
//  Main app entry point. Tab-based navigation.
//  Per Decision #26: native iOS app, SwiftUI, iOS 17+ deployment target.
//  Per Decision #28: talks to FastAPI backend at Tailscale IP:5051.

import SwiftUI

@main
struct LinguaApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .tint(.linguaAccent)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Expected format: lingua://api-key?key=<API_KEY>
        guard url.scheme == "lingua" else { return }

        let path = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        switch path {
        case "api-key":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let key = components.queryItems?.first(where: { $0.name == "key" })?.value,
               !key.isEmpty {
                UserDefaults.standard.set(key, forKey: "lingua_api_key")
                appState.apiKey = key
                appState.isAuthenticated = true
                NotificationCenter.default.post(name: .deepLinkAPIKeyReceived, object: nil)
            }
        default:
            break
        }
    }
}

// MARK: - Deep Link Notifications

extension Notification.Name {
    static let deepLinkAPIKeyReceived = Notification.Name("deepLinkAPIKeyReceived")
}