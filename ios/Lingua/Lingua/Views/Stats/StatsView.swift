//  StatsView.swift
//  Stats tab — dark theme grid + chart per Figma Make design.
//  2-column stat grid, weekly bar chart, leech queue.

import SwiftUI
import Charts

struct StatsView: View {
    @State private var retention: [RetentionPoint] = []
    @State private var leeches: [LeechCard] = []
    @State private var selectedRange = 30

    var body: some View {
        ZStack {
            Color.linguaBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text("Statistics")
                        .font(.linguaHeading)
                        .foregroundColor(.linguaText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)

                    // Range picker
                    Picker("Range", selection: $selectedRange) {
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)

                    // Stat grid (2 columns)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatTile(icon: "🔥", label: "Day Streak", value: "14")
                        StatTile(icon: "⚡️", label: "Total XP", value: "2,480")
                        StatTile(icon: "📚", label: "Words Learned", value: "47")
                        StatTile(icon: "🎯", label: "Accuracy", value: accuracyText)
                        StatTile(icon: "⏱️", label: "Mins Today", value: "18")
                        StatTile(icon: "🏆", label: "League Rank", value: "#12")
                    }
                    .padding(.horizontal, 24)

                    // Weekly activity chart
                    statCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("This Week")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.linguaText)

                            if retention.isEmpty {
                                Text("No data yet — start a session!")
                                    .font(.system(size: 14))
                                    .foregroundColor(.linguaSubtext)
                                    .frame(maxWidth: .infinity, minHeight: 80)
                            } else {
                                Chart(retention) { point in
                                    BarMark(
                                        x: .value("Date", point.date),
                                        y: .value("Reviews", point.reviews)
                                    )
                                    .foregroundStyle(Color.linguaPrimary)
                                }
                                .frame(height: 160)
                            }
                        }
                    }

                    // Leeches
                    statCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Leech Queue")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(.linguaText)

                            if leeches.isEmpty {
                                Text("No leeches — great! 🎉")
                                    .font(.system(size: 14))
                                    .foregroundColor(.linguaSubtext)
                            } else {
                                ForEach(leeches) { leech in
                                    HStack {
                                        Text(leech.italianText)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.linguaText)
                                        Spacer()
                                        Text("\(leech.leechFailCount) fails")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.linguaAgain)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadStats() }
        .onChange(of: selectedRange) { Task { await loadStats() } }
    }

    private var accuracyText: String {
        let total = retention.reduce(0) { $0 + $1.reviews }
        let correct = retention.reduce(0) { $0 + $1.correct }
        let accuracy = total > 0 ? Int(Double(correct) / Double(total) * 100) : 0
        return "\(accuracy)%"
    }

    private func statCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .background(Color.linguaSurface, in: .rect(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.linguaBorder, lineWidth: 1)
            )
            .padding(.horizontal, 24)
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
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(icon)
                .font(.system(size: 24))
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(.linguaText)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.linguaSubtext)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.linguaBorder, lineWidth: 1)
        )
    }
}