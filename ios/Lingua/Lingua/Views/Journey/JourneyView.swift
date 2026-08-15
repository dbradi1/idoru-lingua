//  JourneyView.swift
//  Journey tab — dark theme timeline per Figma Make design.
//  Vertical timeline with circles, connecting lines, terracotta accents.

import SwiftUI

struct JourneyView: View {
    @State private var cities: [CityProgress] = []
    @State private var selectedCity: CityProgress?

    var body: some View {
        ZStack {
            Color.linguaBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your Journey")
                        .font(.linguaHeading)
                        .foregroundColor(.linguaText)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 24)

                    ForEach(cities.sorted { $0.sortOrder < $1.sortOrder }) { city in
                        JourneyTimelineRow(city: city)
                            .onTapGesture { selectedCity = city }
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadCities() }
        .sheet(item: $selectedCity) { city in
            CityDetailView(city: city)
        }
    }

    private func loadCities() async {
        do {
            cities = try await APIClient.shared.getProgressOverview()
        } catch {}
    }
}

// MARK: - Timeline Row

struct JourneyTimelineRow: View {
    let city: CityProgress
    @State private var clusters: [ClusterStrength] = []

    private var isComplete: Bool { city.badgeEarned == 1 }
    private var isUnlocked: Bool { city.isUnlocked == 1 }
    private var isLocked: Bool { !isUnlocked }

    private var statusIcon: String {
        if isLocked { return "lock.fill" }
        if isComplete { return "checkmark" }
        return city.nameEmoji ?? "🏙️"
    }

    private var circleColor: Color {
        if isComplete { return .linguaPrimary }
        if isLocked { return .linguaSurface }
        return .linguaSurface2
    }

    private var borderColor: Color {
        if isComplete { return .linguaPrimary }
        return .linguaBorder
    }

    var body: some View {
        HStack(spacing: 16) {
            // Timeline circle
            ZStack {
                if !isComplete {
                    Text(isLocked ? "🔒" : (city.nameEmoji ?? "🏙️"))
                        .font(.system(size: 18))
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 44, height: 44)
            .background(circleColor, in: .circle())
            .overlay(
                Circle().stroke(borderColor, lineWidth: 2)
            )

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(city.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(isLocked ? .linguaSubtext : .linguaText)
                Text("\(city.cefrLevel) · \(city.theme)")
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundColor(.linguaSubtext)

                if !isLocked {
                    ProgressView(value: Double(city.gateReached), total: 1.0)
                        .tint(.linguaPrimary)
                        .frame(width: 100, height: 3)
                        .clipShape(.rect(cornerRadius: 4))
                        .padding(.top, 4)
                }
            }
            .padding(.bottom, 28)

            Spacer()
        }
        .padding(.horizontal, 24)
        .overlay(alignment: .leading) {
            // Connecting line
            Rectangle()
                .fill(isComplete ? Color.linguaPrimary : Color.linguaBorder)
                .frame(width: 2, height: 28)
                .offset(x: 24 + 22, y: 46) // align with circle center + gap
        }
    }
}

// MARK: - City Detail (Dark)

struct CityDetailView: View {
    let city: CityProgress
    @State private var clusters: [ClusterStrength] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.linguaBackground.ignoresSafeArea()

                List {
                    Section {
                        HStack(spacing: 16) {
                            Text(city.nameEmoji ?? "")
                                .font(.system(size: 44))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(city.name)
                                    .font(.system(size: 24, weight: .heavy, design: .serif))
                                    .foregroundColor(.linguaText)
                                Text(city.cefrLevel)
                                    .font(.system(size: 15))
                                    .foregroundColor(.linguaSubtext)
                                Text(city.theme)
                                    .font(.system(size: 13))
                                    .foregroundColor(.linguaSubtext)
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.linguaSurface)
                    }

                    Section("Clusters") {
                        ForEach(clusters) { cluster in
                            HStack {
                                Text(cluster.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.linguaText)
                                Spacer()
                                ProgressView(value: cluster.strength, total: 1.0)
                                    .tint(.linguaPrimary)
                                    .frame(width: 80)
                            }
                            .listRowBackground(Color.linguaSurface)
                        }
                    }

                    if let badge = city.badgeName {
                        Section("Badge") {
                            HStack {
                                Image(systemName: city.badgeEarned == 1 ? "checkmark.seal.fill" : "seal")
                                    .foregroundColor(city.badgeEarned == 1 ? .linguaGold : .linguaSubtext)
                                Text(badge)
                                    .foregroundColor(.linguaText)
                            }
                            .listRowBackground(Color.linguaSurface)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(city.name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            do { clusters = try await APIClient.shared.getClusterStrength(cityId: city.id) } catch {}
        }
    }
}