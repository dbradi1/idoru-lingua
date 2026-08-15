//  JourneyView.swift
//  Journey tab — 8-city map of Italian learning progression.
//  Light warm theme matching HomeView.

import SwiftUI

struct JourneyView: View {
    @State private var cities: [CityProgress] = []
    @State private var selectedCity: CityProgress?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.linguaBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(cities.sorted { $0.sortOrder < $1.sortOrder }) { city in
                            CityRow(city: city)
                                .onTapGesture { selectedCity = city }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Journey")
            .navigationBarTitleDisplayMode(.large)
        }
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

// MARK: - City Row

struct CityRow: View {
    let city: CityProgress

    private var statusIcon: String {
        if city.isUnlocked == 0 { return "lock.fill" }
        if city.badgeEarned == 1 { return "checkmark.seal.fill" }
        if city.gateReached == 1 { return "checkmark.circle.fill" }
        return "circle"
    }

    private var statusColor: Color {
        if city.isUnlocked == 0 { return .secondary }
        if city.badgeEarned == 1 { return .linguaGold }
        if city.gateReached == 1 { return .linguaGood }
        return .linguaPrimary
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(city.nameEmoji ?? "🏙️")
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 4) {
                Text(city.name)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text("\(city.cefrLevel) · \(city.theme)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: statusIcon)
                .font(.system(size: 20))
                .foregroundColor(statusColor)
        }
        .padding(16)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}

// MARK: - City Detail

struct CityDetailView: View {
    let city: CityProgress
    @State private var clusters: [ClusterStrength] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.linguaBackground
                    .ignoresSafeArea()

                List {
                    Section {
                        HStack(spacing: 16) {
                            Text(city.nameEmoji ?? "")
                                .font(.system(size: 44))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(city.name)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                Text(city.cefrLevel)
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                                Text(city.theme)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.linguaSurface)

                    Section("Clusters") {
                        ForEach(clusters) { cluster in
                            HStack {
                                Text(cluster.name)
                                    .font(.system(size: 15, weight: .medium))
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
                                    .foregroundColor(city.badgeEarned == 1 ? .linguaGold : .secondary)
                                Text(badge)
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