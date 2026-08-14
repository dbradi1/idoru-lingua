//  JourneyView.swift
//  Journey tab — the 8-city map of Italian learning progression.
//  Per Decision #13: each city = CEFR level + theme, gates at 60%, badges at 85%.
//  Per SOUL.md: the app shows the journey; Lingua doesn't narrate it.

import SwiftUI

struct JourneyView: View {
    @State private var cities: [CityProgress] = []
    @State private var isLoading = false
    @State private var selectedCity: CityProgress?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(cities.sorted { $0.sortOrder < $1.sortOrder }) { city in
                        CityRow(city: city)
                            .onTapGesture {
                                selectedCity = city
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Journey")
        }
        .task {
            await loadCities()
        }
        .sheet(item: $selectedCity) { city in
            CityDetailView(city: city)
        }
    }

    private func loadCities() async {
        isLoading = true
        do {
            cities = try await APIClient.shared.getProgressOverview()
        } catch {
            // Use cached data if available
        }
        isLoading = false
    }
}

// MARK: - City Row

struct CityRow: View {
    let city: CityProgress

    var body: some View {
        HStack(spacing: 16) {
            Text(city.nameEmoji ?? "🏙️")
                .font(.system(size: 36))

            VStack(alignment: .leading, spacing: 4) {
                Text(city.name)
                    .font(.headline)
                Text("\(city.cefrLevel) · \(city.theme)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Lock/unlock state
            if city.isUnlocked == 1 {
                if city.badgeEarned == 1 {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.yellow)
                } else if city.gateReached == 1 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.blue)
                }
            } else {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - City Detail

struct CityDetailView: View {
    let city: CityProgress
    @State private var clusters: [ClusterStrength] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(city.nameEmoji ?? "")
                            .font(.system(size: 48))
                        VStack(alignment: .leading) {
                            Text(city.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(city.cefrLevel)
                                .foregroundColor(.secondary)
                            Text(city.theme)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Clusters") {
                    ForEach(clusters) { cluster in
                        HStack {
                            Text(cluster.name)
                            Spacer()
                            ProgressView(value: cluster.strength, total: 1.0)
                                .frame(width: 80)
                        }
                    }
                }

                if let badge = city.badgeName {
                    Section("Badge") {
                        HStack {
                            Image(systemName: city.badgeEarned == 1 ? "checkmark.seal.fill" : "seal")
                                .foregroundColor(city.badgeEarned == 1 ? .yellow : .secondary)
                            Text(badge)
                        }
                    }
                }
            }
            .navigationTitle(city.name)
        }
        .task {
            do {
                clusters = try await APIClient.shared.getClusterStrength(cityId: city.id)
            } catch {}
        }
    }
}