//  RootView.swift
//  Root tab navigation. 5 tabs: Home, Cards, Journey, Stats, Settings.
//  Dark theme: pill-style tab bar with terracotta active state.

import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Content
            ZStack {
                switch selectedTab {
                case 0: HomeView()
                case 1: CardSessionView()
                case 2: JourneyView()
                case 3: StatsView()
                case 4: SettingsView()
                default: HomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom dark pill tab bar
            DarkTabBar(selectedTab: $selectedTab)
        }
        .background(Color.linguaBackground)
        .ignoresSafeArea(edges: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: .switchToCardsTab)) { _ in
            selectedTab = 1
        }
        .task {
            await appState.checkConnection()
        }
    }
}

// MARK: - Dark Pill Tab Bar

struct DarkTabBar: View {
    @Binding var selectedTab: Int

    private let tabs: [(Int, String, String)] = [
        (0, "Home", "house"),
        (1, "Cards", "rectangle.stack"),
        (2, "Journey", "map"),
        (3, "Stats", "chart.bar"),
        (4, "Settings", "gearshape"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.0) { tab in
                let active = selectedTab == tab.0
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab.0
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: active ? "\(tab.2).fill" : tab.2)
                            .font(.system(size: 18, weight: .semibold))
                        if active {
                            Text(tab.1)
                                .font(.linguaTab)
                        }
                    }
                    .foregroundColor(active ? .white : .linguaSubtext)
                    .padding(.vertical, 8)
                    .padding(.horizontal, active ? 18 : 10)
                    .background(active ? Color.linguaPrimary : Color.clear, in: .rect(cornerRadius: 20))
                    .animation(.easeInOut(duration: 0.2), value: active)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .padding(.bottom, 24)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}