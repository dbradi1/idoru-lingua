//  RootView.swift
//  Root tab navigation. 5 tabs: Home, Card (Session), Journey, Stats, Settings.
//  Per Decision #26: native iOS app with tab-based navigation.
//  Per SOUL.md: the app is the face; Lingua is the engine behind it.

import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            CardSessionView()
                .tabItem {
                    Label("Cards", systemImage: "rectangle.stack.fill")
                }
                .tag(1)

            JourneyView()
                .tabItem {
                    Label("Journey", systemImage: "map.fill")
                }
                .tag(2)

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .tint(.linguaAccent)
        .background(Color.linguaBackground)
        .overlay(alignment: .top) {
            if !appState.isOnline {
                OfflineBanner()
                    .transition(.move(edge: .top))
            }
        }
        .task {
            await appState.checkConnection()
        }
    }
}