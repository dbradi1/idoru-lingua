//  StatsView.swift
//  Stats tab — retention curves, review history, leech queue.
//  Per Decision #27: retention data for memory tracking.

import SwiftUI
import Charts

struct StatsView: View {
    @State private var retention: [RetentionPoint] = []
    @State private var leeches: [LeechCard] = []
    @State private var selectedRange = 30

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Range picker
                    Picker("Range", selection: $selectedRange) {
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Retention chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Review History")
                            .font(.linguaHeading)
                        if retention.isEmpty {
                            Text("No data yet")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 150)
                        } else {
                            Chart(retention) { point in
                                BarMark(
                                    x: .value("Date", point.date),
                                    y: .value("Reviews", point.reviews)
                                )
                                .foregroundStyle(Color.linguaBlue)
                            }
                            .frame(height: 200)
                        }
                    }
                    .padding()
                    .background(Color.linguaSurface)
                    .clipShape(.rect(cornerRadius: 12))

                    // Accuracy
                    if !retention.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Accuracy")
                                .font(.linguaHeading)
                            let total = retention.reduce(0) { $0 + $1.reviews }
                            let correct = retention.reduce(0) { $0 + $1.correct }
                            let accuracy = total > 0 ? Int(Double(correct) / Double(total) * 100) : 0
                            Text("\(accuracy)% correct")
                                .font(.linguaDisplay)
                                .foregroundColor(accuracy >= 80 ? .linguaGood : accuracy >= 60 ? .linguaHard : .linguaAgain)
                        }
                        .padding()
                        .background(Color.linguaSurface)
                        .clipShape(.rect(cornerRadius: 12))
                    }

                    // Leeches
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Leech Queue")
                            .font(.linguaHeading)
                        if leeches.isEmpty {
                            Text("No leeches — great! 🎉")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(leeches) { leech in
                                HStack {
                                    Text(leech.italianText)
                                        .font(.body)
                                    Spacer()
                                    Text("\(leech.leechFailCount) fails")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding()
                    .background(Color.linguaSurface)
                    .clipShape(.rect(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle("Stats")
        }
        .task {
            await loadStats()
        }
        .onChange(of: selectedRange) {
            Task { await loadStats() }
        }
    }

    private func loadStats() async {
        do {
            retention = try await APIClient.shared.getHistory(days: selectedRange)
            leeches = try await APIClient.shared.getLeeches()
        } catch {}
    }
}