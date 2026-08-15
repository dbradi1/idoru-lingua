//  StatsView.swift
//  Stats tab — retention curves, review history, leech queue.
//  Light warm theme matching HomeView.

import SwiftUI
import Charts

struct StatsView: View {
    @State private var retention: [RetentionPoint] = []
    @State private var leeches: [LeechCard] = []
    @State private var selectedRange = 30

    var body: some View {
        NavigationStack {
            ZStack {
                Color.linguaBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Range picker
                        Picker("Range", selection: $selectedRange) {
                            Text("7 days").tag(7)
                            Text("30 days").tag(30)
                            Text("90 days").tag(90)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 20)

                        // Review history chart
                        statCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Review History")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))

                                if retention.isEmpty {
                                    Text("No data yet — start a session!")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, minHeight: 150)
                                } else {
                                    Chart(retention) { point in
                                        BarMark(
                                            x: .value("Date", point.date),
                                            y: .value("Reviews", point.reviews)
                                        )
                                        .foregroundStyle(Color.linguaPrimary)
                                    }
                                    .frame(height: 200)
                                }
                            }
                        }

                        // Accuracy
                        if !retention.isEmpty {
                            statCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Accuracy")
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))

                                    let total = retention.reduce(0) { $0 + $1.reviews }
                                    let correct = retention.reduce(0) { $0 + $1.correct }
                                    let accuracy = total > 0 ? Int(Double(correct) / Double(total) * 100) : 0

                                    HStack {
                                        Text("\(accuracy)%")
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .foregroundColor(accuracy >= 80 ? .linguaGood : accuracy >= 60 ? .linguaHard : .linguaAgain)
                                        Spacer()
                                        Text("\(correct) correct / \(total) total")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }

                        // Leeches
                        statCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Leech Queue")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))

                                if leeches.isEmpty {
                                    Text("No leeches — great! 🎉")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(leeches) { leech in
                                        HStack {
                                            Text(leech.italianText)
                                                .font(.system(size: 15, weight: .medium))
                                            Spacer()
                                            Text("\(leech.leechFailCount) fails")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.linguaAgain)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await loadStats() }
        .onChange(of: selectedRange) { Task { await loadStats() } }
    }

    // Helper for consistent card styling
    private func statCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(20)
            .background(Color.linguaSurface, in: .rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
            .padding(.horizontal, 20)
    }

    private func loadStats() async {
        do {
            retention = try await APIClient.shared.getHistory(days: selectedRange)
            leeches = try await APIClient.shared.getLeeches()
        } catch {}
    }
}