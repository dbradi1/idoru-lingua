//  HomeView.swift
//  Home tab — coral gradient header with Memphis decorations,
//  stat cards, daily goal, continue button, lesson list.
//  Per Figma Make HomeTab.tsx — all layout matches exactly.

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var dueCards: [Card] = []
    @State private var cities: [CityProgress] = []
    @State private var clusters: [ClusterStrength] = []
    @State private var settings: ServerSettings?
    @State private var reviewCount = 0
    @State private var wordsLearned = 0
    @State private var streak = 14

    var body: some View {
        ZStack {
            Color.linguaBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── Coral header with Memphis decorations ──
                    homeHeader

                    // ── Content ──
                    VStack(spacing: 12) {
                        dailyGoalSection

                        // Continue Learning button
                        Button {
                            NotificationCenter.default.post(name: .switchToCardsTab, object: nil)
                        } label: {
                            HStack(spacing: 4) {
                                Text("▶")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Continue Learning")
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .background(
                            LinearGradient(
                                colors: [Color.linguaPrimary, Color.linguaPrimaryDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: .rect(cornerRadius: 16)
                        )
                        .shadow(color: Color.linguaPrimary.opacity(0.4), radius: 8, y: 4)

                        // Lessons heading
                        Text("Lessons")
                            .font(.system(size: 22, weight: .heavy, design: .serif))
                            .foregroundColor(.linguaText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

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
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadData() }
    }

    // MARK: - Header (coral gradient + Memphis)

    private var homeHeader: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.linguaPrimary, Color.linguaPrimaryDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Memphis decorations
            ZStack {
                // Top-right large circle
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 100, height: 100)
                    .offset(x: 140, y: -50)

                // Smaller circle
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 50, height: 50)
                    .offset(x: 80, y: -10)

                // Bottom-left rotated rect
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(25))
                    .offset(x: -120, y: 50)

                // Top-left rotated rect
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(15))
                    .offset(x: -150, y: -30)

                // Bottom-right small circle
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 40, height: 40)
                    .offset(x: 100, y: 60)
            }
            .allowsHitTesting(false)
            .clipped()

            // Content
            VStack(spacing: 16) {
                // Greeting row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ciao,")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                        Text("Drew! 🇮🇹")
                            .font(.system(size: 30, weight: .heavy, design: .serif))
                            .foregroundColor(.white)
                    }
                    Spacer()

                    // Profile avatar
                    ZStack {
                        Text("🧑")
                            .font(.system(size: 22))
                    }
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.95), in: .rect(cornerRadius: 22))
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Stat cards row
                HStack(spacing: 8) {
                    HeaderStatCard(icon: "🔥", value: "\(streak)", label: "day streak")
                    HeaderStatCard(icon: "⚡️", value: "\(reviewCount)", label: "XP total")
                    HeaderStatCard(icon: "📚", value: "\(wordsLearned)", label: "words")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .frame(height: 220)
        .clipped()
    }

    // MARK: - Daily Goal

    private var dailyGoalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Daily Goal")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.linguaText)
                Spacer()
                Text("\(min(reviewCount, settings?.dailyReviewCap ?? 20)) / \(settings?.dailyReviewCap ?? 20) XP")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(.linguaPrimary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 99)
                        .fill(Color(red: 0.94, green: 0.91, blue: 0.86))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 99)
                        .fill(
                            LinearGradient(
                                colors: [Color.linguaPrimary, Color.linguaPrimaryLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(min(Double(reviewCount), Double(settings?.dailyReviewCap ?? 20)) / Double(max(settings?.dailyReviewCap ?? 20, 1))), height: 8)
                }
            }
            .frame(height: 8)

            Text("\(max((settings?.dailyReviewCap ?? 20) - reviewCount, 0)) XP to reach your daily goal")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.linguaSubtext)
        }
        .padding(16)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.07), radius: 4, y: 2)
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
            wordsLearned = clusters.reduce(0) { $0 + $1.cardCount }
        } catch {}
    }
}

// MARK: - Header Stat Card (frosted glass)

private struct HeaderStatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(icon)
                .font(.system(size: 16))
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.15), in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Lesson Card (colorful, per Figma)

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
        if name.contains("café") || name.contains("caff") || name.contains("cafe") { return "☕" }
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
        if name.contains("travel") { return "Viaggiare" }
        return cluster.name
    }

    private var completionPercent: Int { Int(cluster.strength * 100) }

    var body: some View {
        HStack(spacing: 12) {
            // Icon box
            Text(lessonEmoji)
                .font(.system(size: 22))
                .frame(width: 46, height: 46)
                .background(lessonColor.opacity(0.1), in: .rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(lessonColor.opacity(0.2), lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(cluster.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.linguaText)
                    Spacer()
                    Text("\(completionPercent)%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(lessonColor)
                }

                Text("\(italianName) · \(cluster.cardCount) words")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .italic()
                    .foregroundColor(.linguaSubtext)

                ProgressView(value: cluster.strength, total: 1.0)
                    .tint(lessonColor)
                    .frame(height: 5)
                    .clipShape(.rect(cornerRadius: 99))
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
    }
}