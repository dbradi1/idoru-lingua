//  JourneyView.swift
//  Journey tab — vertical timeline with city nodes.
//  Per Figma Make JourneyTab.tsx: circular nodes, connecting line,
//  white city cards with CEFR badge, progress bar.

import SwiftUI

struct JourneyView: View {
    @State private var cities: [CityProgress] = []
    @State private var selectedCity: CityProgress?

    var body: some View {
        ZStack {
            Color.linguaBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your Journey")
                        .font(.system(size: 28, weight: .heavy, design: .serif))
                        .foregroundColor(.linguaText)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 24)

                    // Timeline
                    ZStack(alignment: .topLeading) {
                        // Vertical background line
                        Rectangle()
                            .fill(Color(red: 0.91, green: 0.88, blue: 0.84))
                            .frame(width: 3)
                            .padding(.leading, 23)
                            .padding(.top, 24)
                            .padding(.bottom, 24)

                        // City rows
                        VStack(spacing: 24) {
                            ForEach(cities.sorted { $0.sortOrder < $1.sortOrder }) { city in
                                JourneyTimelineRow(
                                    city: city,
                                    isPreviousComplete: cities.sorted { $0.sortOrder < $1.sortOrder }
                                        .first(where: { $0.sortOrder == city.sortOrder - 1 })?
                                        .badgeEarned == 1
                                )
                                .onTapGesture {
                                    if city.isUnlocked == 1 {
                                        selectedCity = city
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadCities() }
        .sheet(item: $selectedCity) { city in CityDetailView(city: city) }
    }

    private func loadCities() async {
        do { cities = try await APIClient.shared.getProgressOverview() } catch {}
    }
}

// MARK: - Timeline Row

struct JourneyTimelineRow: View {
    let city: CityProgress
    let isPreviousComplete: Bool

    private var isComplete: Bool { city.badgeEarned == 1 }
    private var isLocked: Bool { city.isUnlocked == 0 }
    private var isActive: Bool { !isLocked && !isComplete }

    private var nodeColor: Color {
        if isComplete { return .linguaPrimary }
        if isLocked { return Color(red: 0.91, green: 0.88, blue: 0.84) }
        return .linguaSurface
    }

    private var nodeBorder: Color {
        if isComplete { return .linguaPrimary }
        if isLocked { return Color(red: 0.75, green: 0.71, blue: 0.66) }
        return .linguaPrimary
    }

    var body: some View {
        HStack(spacing: 16) {
            // Node
            ZStack {
                // Colored segment above (if previous is completed)
                if isPreviousComplete && !isLocked {
                    Rectangle()
                        .fill(Color.linguaPrimary)
                        .frame(width: 3, height: 24)
                        .offset(y: -36)
                }

                if isComplete {
                    Text("✓")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                } else if isLocked {
                    Text("🔒")
                        .font(.system(size: 18))
                } else {
                    Text(city.nameEmoji ?? "🏙️")
                        .font(.system(size: 22))
                }
            }
            .frame(width: 48, height: 48)
            .background(nodeColor, in: .rect(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(nodeBorder, lineWidth: 3)
            )
            .shadow(color: isActive ? Color.linguaPrimary.opacity(0.2) : .clear, radius: 4, y: 2)

            // City card
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(city.name)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.linguaText)
                    Spacer()
                    Text(city.cefrLevel)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(
                            isComplete ? .linguaPrimary :
                            isLocked ? .linguaSubtext :
                            .linguaBlue
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            (isComplete ? Color.linguaPrimary :
                             isLocked ? Color.linguaDivider :
                             Color.linguaBlue).opacity(0.1),
                            in: .rect(cornerRadius: 99)
                        )
                }

                Text(city.theme)
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .italic()
                    .foregroundColor(.linguaSubtext)

                if !isLocked {
                    ProgressView(
                        value: Double(city.gateReached),
                        total: 1.0
                    )
                    .tint(isComplete ? .linguaPrimary : .linguaBlue)
                    .frame(height: 4)
                    .clipShape(.rect(cornerRadius: 99))
                    .padding(.top, 4)

                    Text("\(Int(city.gateReached * 100))% complete")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 0.67, green: 0.67, blue: 0.67))
                }
            }
            .padding(12)
            .background(Color.linguaSurface, in: .rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.07), radius: 3, y: 2)
            .opacity(isLocked ? 0.6 : 1)
            .padding(.trailing, 20)
        }
        .padding(.leading, 20)
    }
}

// MARK: - City Detail

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
                            Text(city.nameEmoji ?? "").font(.system(size: 44))
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
                                Text(badge).foregroundColor(.linguaText)
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