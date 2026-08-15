//  HomeView.swift
//  Home tab — warm greeting, stats, daily goal, lesson cards.
//  Redesigned per Drew's Figma mockup: coral header, stats row,
//  daily goal progress, lesson clusters with color-coded progress.

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var dueCards: [Card] = []
    @State private var cities: [CityProgress] = []
    @State private var clusters: [ClusterStrength] = []
    @State private var settings: ServerSettings?
    @State private var reviewCount = 0
    @State private var wordsLearned = 0

    var body: some View {
        ZStack(alignment: .top) {
            // Coral background fills the safe area behind the notch
            Color.linguaPrimary
                .ignoresSafeArea(edges: .top)
                .frame(height: 0) // Just fills the safe area, doesn't take space

            ScrollView {
                VStack(spacing: 0) {
                    // Coral header with greeting + stats
                    headerSection

                    // Daily goal
                    dailyGoalSection
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // Lessons
                    lessonsSection
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                        .padding(.bottom, 32)
                }
            }
            .background(Color.linguaBackground)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadData() }
    }

    // MARK: - Header (shared coral component)

    private var headerSection: some View {
        SharedHeader(
            streak: 0,
            xp: reviewCount,
            words: wordsLearned,
            cities: cities
        )
    }

    // MARK: - Daily Goal

    private var dailyGoalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Daily Goal")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Spacer()
                Text("\(min(reviewCount, settings?.dailyReviewCap ?? 20)) / \(settings?.dailyReviewCap ?? 20)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.linguaPrimary)
            }

            ProgressView(
                value: min(Double(reviewCount), Double(settings?.dailyReviewCap ?? 20)),
                total: Double(settings?.dailyReviewCap ?? 20)
            )
            .tint(.linguaPrimary)
            .frame(height: 12)
            .clipShape(.rect(cornerRadius: 6))

            Text("\(max((settings?.dailyReviewCap ?? 20) - reviewCount, 0)) cards to reach your daily goal")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Lessons

    private var lessonsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Lessons")
                .font(.system(size: 24, weight: .bold, design: .rounded))

            if clusters.isEmpty {
                Text("Loading lessons...")
                    .foregroundColor(.secondary)
            } else {
                ForEach(clusters) { cluster in
                    LessonCard(cluster: cluster)
                }
            }
        }
    }

    // MARK: - Load data

    private func loadData() async {
        guard appState.isOnline else { return }

        do {
            dueCards = try await APIClient.shared.getDueCards()
            reviewCount = dueCards.count
            cities = try await APIClient.shared.getProgressOverview()

            if let firstCity = cities.first(where: { $0.isUnlocked == 1 }) {
                clusters = try await APIClient.shared.getClusterStrength(cityId: firstCity.id)
            }

            settings = try await APIClient.shared.getSettings()

            // Count total words learned (cards with FSRS state)
            // For now use dueCards count as proxy
            wordsLearned = 5 // placeholder until we have a real count endpoint

        } catch {
            // Silently fail — offline banner handles UI
        }
    }
}

// MARK: - Lesson Card

private struct LessonCard: View {
    let cluster: ClusterStrength

    // Color mapping based on cluster name
    private var lessonColor: Color {
        let name = cluster.name.lowercased()
        if name.contains("greet") || name.contains("salut") { return .linguaCoral }
        if name.contains("café") || name.contains("caff") || name.contains("cafe") { return .linguaBlue }
        if name.contains("number") || name.contains("numer") { return .linguaGold }
        if name.contains("family") || name.contains("famig") { return .linguaGreen }
        if name.contains("travel") || name.contains("viagg") { return .linguaPurple }
        return .linguaCoral
    }

    private var lessonEmoji: String {
        let name = cluster.name.lowercased()
        if name.contains("greet") || name.contains("salut") { return "👋" }
        if name.contains("café") || name.contains("caff") || name.contains("cafe") { return "☕️" }
        if name.contains("number") || name.contains("numer") { return "🔢" }
        if name.contains("family") || name.contains("famig") { return "👨‍👩‍👧" }
        if name.contains("travel") || name.contains("viagg") { return "✈️" }
        return "📖"
    }

    private var italianName: String {
        let name = cluster.name.lowercased()
        if name.contains("greet") { return "Saluti" }
        if name.contains("café") || name.contains("cafe") { return "Al Caffè" }
        if name.contains("number") { return "Numeri" }
        if name.contains("family") { return "Famiglia" }
        if name.contains("travel") { return "Viaggi" }
        return cluster.name
    }

    private var completionPercent: Int {
        Int(cluster.strength * 100)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Text(lessonEmoji)
                .font(.system(size: 24))
                .frame(width: 48, height: 48)
                .background(lessonColor, in: .rect(cornerRadius: 12))

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(cluster.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("\(cluster.cardCount) words")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(lessonColor)
                }

                Text(italianName)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundColor(.secondary)

                ProgressView(value: cluster.strength, total: 1.0)
                    .tint(lessonColor)
                    .frame(height: 8)
                    .clipShape(.rect(cornerRadius: 4))

                Text("\(completionPercent)% complete")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(lessonColor.opacity(0.08), in: .rect(cornerRadius: 16))
    }
}