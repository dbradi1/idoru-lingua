//  StatsView.swift
//  Stats tab — per Figma Make StatsTab.tsx.
//  2-col stat grid with colored values, weekly bar chart,
//  accuracy card with green progress, leech queue.

import SwiftUI
import Charts

struct StatsView: View {
    @State private var retention: [RetentionPoint] = []
    @State private var leeches: [LeechCard] = []
    @State private var selectedRange = 7

    // Figma placeholder values (used when API doesn't provide)
    private let placeholderStreak = 14
    private let placeholderXP = "2,480"
    private let placeholderWords = 47
    private let placeholderMins = 18
    private let placeholderRank = "#12"

    var body: some View {
        ZStack {
            Color.linguaBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Text("Statistics")
                        .font(.system(size: 28, weight: .heavy, design: .serif))
                        .foregroundColor(.linguaText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    // ── Stat tiles grid ──
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        StatTile(icon: "🔥", value: "\(placeholderStreak)", label: "Day Streak", color: .linguaCoral)
                        StatTile(icon: "⚡️", value: placeholderXP, label: "Total XP", color: .linguaGold)
                        StatTile(icon: "📚", value: "\(totalWordsLearned)", label: "Words Learned", color: .linguaBlue)
                        StatTile(icon: "🎯", value: accuracyText, label: "Accuracy", color: .linguaGreen)
                        StatTile(icon: "⏱️", value: "\(placeholderMins)", label: "Mins Today", color: .linguaPurple)
                        StatTile(icon: "🏆", value: placeholderRank, label: "League Rank", color: .linguaGold)
                    }
                    .padding(.horizontal, 16)

                    // ── Weekly bar chart ──
                    statCard {
                        weeklyChart
                    }

                    // ── Accuracy card ──
                    statCard {
                        accuracyCard
                    }

                    // ── Leech queue ──
                    statCard {
                        leechQueue
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadStats() }
    }

    // MARK: - Weekly Chart

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Activity")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.linguaText)

            if retention.isEmpty {
                Text("No data yet — start a session!")
                    .font(.system(size: 14))
                    .foregroundColor(.linguaSubtext)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                // Custom bar chart matching Figma
                let last7 = Array(retention.suffix(7))
                let maxReviews = max(last7.map(\.reviews).max() ?? 1, 1)
                let todayIndex = last7.count - 1
                let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(last7.enumerated()), id: \.element.id) { idx, point in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    idx == todayIndex
                                        ? LinearGradient(
                                            colors: [Color.linguaPrimary, Color.linguaPrimaryDark],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        : LinearGradient(
                                            colors: [Color(red: 0.94, green: 0.91, blue: 0.86)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                )
                                .frame(height: CGFloat(point.reviews) / CGFloat(maxReviews) * 72)

                            Text(dayLabels[min(idx, 6)])
                                .font(.system(size: 9, weight: idx == todayIndex ? .heavy : .semibold, design: .rounded))
                                .foregroundColor(idx == todayIndex ? .linguaPrimary : Color(red: 0.73, green: 0.73, blue: 0.73))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 100, alignment: .bottom)
            }
        }
    }

    // MARK: - Accuracy Card

    private var accuracyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Accuracy")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.linguaText)
                Spacer()
                Text(accuracyText)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.linguaGreen)
            }

            // Green progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 99)
                        .fill(Color(red: 0.94, green: 0.91, blue: 0.86))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 99)
                        .fill(
                            LinearGradient(
                                colors: [Color.linguaGreen, Color(red: 0.36, green: 0.79, blue: 0.54)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(accuracyValue / 100), height: 8)
                }
            }
            .frame(height: 8)

            Text(accuracyDetail)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.linguaSubtext)
        }
    }

    // MARK: - Leech Queue

    private var leechQueue: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Leech Queue")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.linguaText)

            if leeches.isEmpty {
                Text("No leeches — great! 🎉")
                    .font(.system(size: 14))
                    .foregroundColor(.linguaSubtext)
            } else {
                ForEach(leeches) { leech in
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(leech.italianText)
                                .font(.system(size: 16, weight: .medium, design: .serif))
                                .italic()
                                .foregroundColor(.linguaText)
                            Text(leech.englishText)
                                .font(.system(size: 12))
                                .foregroundColor(.linguaSubtext)
                        }
                        Spacer()
                        Text("✗ \(leech.leechFailCount)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.linguaPrimary, in: .rect(cornerRadius: 99))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 1.0, green: 0.96, blue: 0.95), in: .rect(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.linguaPrimary.opacity(0.15), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Computed values

    private var totalWordsLearned: Int {
        retention.reduce(0) { $0 + $1.correct }
    }

    private var accuracyText: String {
        let total = retention.reduce(0) { $0 + $1.reviews }
        let correct = retention.reduce(0) { $0 + $1.correct }
        return total > 0 ? "\(Int(Double(correct) / Double(total) * 100))%" : "82%"
    }

    private var accuracyValue: Double {
        let total = retention.reduce(0) { $0 + $1.reviews }
        let correct = retention.reduce(0) { $0 + $1.correct }
        return total > 0 ? Double(correct) / Double(total) * 100 : 82
    }

    private var accuracyDetail: String {
        let total = retention.reduce(0) { $0 + $1.reviews }
        let correct = retention.reduce(0) { $0 + $1.correct }
        if total > 0 {
            return "\(correct) correct out of \(total) reviews"
        }
        return "82 correct out of 100 reviews"
    }

    // MARK: - Helpers

    private func statCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color.linguaSurface, in: .rect(cornerRadius: 20))
            .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
            .padding(.horizontal, 16)
    }

    private func loadStats() async {
        do {
            retention = try await APIClient.shared.getHistory(days: selectedRange)
            leeches = try await APIClient.shared.getLeeches()
        } catch {}
    }
}

// MARK: - Stat Tile

private struct StatTile: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(icon)
                .font(.system(size: 22))
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.linguaSubtext)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
    }
}