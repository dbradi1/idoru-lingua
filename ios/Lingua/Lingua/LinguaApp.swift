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
                .preferredColorScheme(.dark)
                .tint(.linguaAccent)
        }
    }
}