//  RootView.swift
//  Root tab navigation. 5 tabs: Home, Card (Session), Journey, Stats, Settings.

import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            CardSessionView()
                .tabItem { Label("Cards", systemImage: "rectangle.stack.fill") }
                .tag(1)

            JourneyView()
                .tabItem { Label("Journey", systemImage: "map.fill") }
                .tag(2)

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(3)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(.linguaPrimary)
        .onReceive(NotificationCenter.default.publisher(for: .switchToCardsTab)) { _ in
            selectedTab = 1
        }
        .task {
            await appState.checkConnection()
        }
    }
}