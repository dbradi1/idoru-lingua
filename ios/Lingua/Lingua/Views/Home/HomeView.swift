//  HomeView.swift
//  Home tab — welcome screen, due card count, start session button.
//  Per Decision #28: home shows due cards count and session start.
//  Per SOUL.md: "welcome back — N cards due" (no streaks, no guilt).

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var dueCards: [Card] = []
    @State private var isLoading = false
    @State private var activeSession: ActiveSession?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome header
                    VStack(spacing: 4) {
                        Text("Lingua")
                            .font(.linguaDisplay)
                        Text("🇮🇹")
                            .font(.system(size: 48))
                    }
                    .padding(.top, 20)

                    // Active session resume
                    if let session = activeSession {
                        SessionResumeCard(session: session) {
                            NotificationCenter.default.post(name: .switchToCardsTab, object: nil)
                        }
                    }

                    // Due cards
                    if appState.isOnline {
                        VStack(spacing: 8) {
                            Text("\(dueCards.count) cards due")
                                .font(.linguaHeading)

                            if dueCards.isEmpty {
                                Text("All caught up! 🎉")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            } else {
                                Button {
                                    startSession()
                                } label: {
                                    Label("Start Session", systemImage: "play.fill")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.horizontal, 40)
                            }
                        }
                    } else {
                        Text("Offline — connect Tailscale to continue")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    // Current city
                    if let city = appState.cachedProgress.first(where: { $0.isUnlocked == 1 }) {
                        CityCard(city: city)
                    }
                }
                .padding()
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await loadData()
        }
        
    }

    private func loadData() async {
        guard appState.isOnline else { return }
        isLoading = true

        do {
            dueCards = try await APIClient.shared.getDueCards()
            let active = try await APIClient.shared.getActiveSession()
            activeSession = active.session

            if let progress = try? await APIClient.shared.getProgressOverview() {
                appState.cachedProgress = progress
            }
        } catch {
            // Silently fail — offline banner handles UI
        }

        isLoading = false
    }

    private func startSession() {
        // Switch to Cards tab — NotificationCenter or AppState can handle this
        NotificationCenter.default.post(name: .switchToCardsTab, object: nil)
    }
}

// MARK: - Session Resume Card

struct SessionResumeCard: View {
    let session: ActiveSession
    let onResume: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.title2)
                    .foregroundColor(.linguaBlue)
                VStack(alignment: .leading) {
                    Text("Session in progress")
                        .font(.linguaHeading)
                    Text("\(session.cardsCompleted) / \(session.cardsTotal) cards completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            Button("Resume", action: onResume)
                .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.linguaSurfaceLight, in: .rect(cornerRadius: 12))
    }
}

// MARK: - City Card

struct CityCard: View {
    let city: CityProgress

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(city.nameEmoji ?? "")
                    .font(.title)
                VStack(alignment: .leading) {
                    Text(city.name)
                        .font(.linguaHeading)
                    Text(city.cefrLevel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if city.gateReached == 1 {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                }
            }
            Text(city.theme)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.linguaSurface, in: .rect(cornerRadius: 12))
    }
}