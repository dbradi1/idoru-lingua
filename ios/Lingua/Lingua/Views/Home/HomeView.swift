//  HomeView.swift
//  Home tab — dark theme per Figma Make design.
//  Black background, surface cards, terracotta accents, lesson list.

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
        ZStack {
            Color.linguaBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    SharedHeader(
                        streak: 0,
                        xp: reviewCount,
                        words: wordsLearned,
                        cities: cities
                    )
                    .padding(.bottom, 12)

                    // Daily goal
                    dailyGoalSection
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    // Continue button
                    Button {
                        NotificationCenter.default.post(name: .switchToCardsTab, object: nil)
                    } label: {
                        HStack(spacing: 6) {
                            Text("▶")
                                .font(.system(size: 13, weight: .bold))
                            Text("Continue Learning")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .background(Color.linguaPrimary, in: .rect(cornerRadius: 18))
                    .shadow(color: Color.linguaPrimary.opacity(0.3), radius: 12, y: 4)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // Lessons
                    lessonsSection
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 100)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadData() }
    }

    // MARK: - Daily Goal

    private var dailyGoalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Daily Goal")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.linguaText)
                Spacer()
                Text("\(min(reviewCount, settings?.dailyReviewCap ?? 20)) / \(settings?.dailyReviewCap ?? 20)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.linguaPrimary)
            }

            ProgressView(
                value: min(Double(reviewCount), Double(settings?.dailyReviewCap ?? 20)),
                total: Double(settings?.dailyReviewCap ?? 20)
            )
            .tint(.linguaPrimary)
            .frame(height: 4)
            .clipShape(.rect(cornerRadius: 4))

            Text("\(max((settings?.dailyReviewCap ?? 20) - reviewCount, 0)) cards to reach your daily goal")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.linguaSubtext)
        }
        .padding(16)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.linguaBorder, lineWidth: 1)
        )
    }

    // MARK: - Lessons

    private var lessonsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Lessons")
                .font(.linguaHeading)
                .foregroundColor(.linguaText)

            if clusters.isEmpty {
                Text("Loading lessons...")
                    .font(.linguaBody)
                    .foregroundColor(.linguaSubtext)
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
            wordsLearned = 5 // placeholder until we have a real count endpoint

        } catch {
            // Silently fail — offline banner handles UI
        }
    }
}

// MARK: - Lesson Card (Dark)

private struct LessonCard: View {
    let cluster: ClusterStrength

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
        if name.contains("family") || name.contains("famig") { return "👨👩👧" }
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
                .font(.system(size: 22))
                .frame(width: 46, height: 46)
                .background(Color.linguaSurface2, in: .rect(cornerRadius: 13))

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(cluster.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.linguaText)
                    Spacer()
                    Text("\(cluster.cardCount) words")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.linguaSubtext)
                }

                Text(italianName)
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundColor(.linguaSubtext)

                ProgressView(value: cluster.strength, total: 1.0)
                    .tint(.linguaPrimary)
                    .frame(height: 3)
                    .clipShape(.rect(cornerRadius: 4))
            }
        }
        .padding(14)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.linguaBorder, lineWidth: 1)
        )
    }
}