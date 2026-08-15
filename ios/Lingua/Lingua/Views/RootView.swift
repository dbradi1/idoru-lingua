//  RootView.swift
//  Root tab navigation. 5 tabs: Home, Cards, Journey, Stats, Settings.
//  Per Figma Make: frosted glass tab bar with coral active pill, emoji icons.

import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
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

            FigTabBar(selectedTab: $selectedTab)
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

// MARK: - Figma Tab Bar (emoji icons + coral pill)

struct FigTabBar: View {
    @Binding var selectedTab: Int

    private let tabs: [(Int, String, String)] = [
        (0, "🏠", "Home"),
        (1, "🃏", "Cards"),
        (2, "🗺️", "Journey"),
        (3, "📊", "Stats"),
        (4, "⚙️", "Settings"),
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
                    VStack(spacing: 2) {
                        // Emoji icon in pill background
                        Text(tab.1)
                            .font(.system(size: 18))
                            .frame(width: 44, height: 28)
                            .background(
                                active
                                    ? Color.linguaPrimary.opacity(0.15)
                                    : Color.clear,
                                in: .rect(cornerRadius: 14)
                            )

                        Text(tab.2)
                            .font(.linguaTab)
                            .foregroundColor(active ? .linguaPrimary : .linguaSubtext)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1),
            alignment: .top
        )
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}