//  SharedHeader.swift
//  Persistent coral header shown on Home and Cards tabs.
//  Contains greeting, journey city icons, and stats row.

import SwiftUI

struct SharedHeader: View {
    @EnvironmentObject var appState: AppState
    var streak: Int = 0
    var xp: Int = 0
    var words: Int = 0
    var cities: [CityProgress] = []

    var body: some View {
        VStack(spacing: 20) {
            // Greeting + journey icons
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ciao,")
                        .font(.system(size: 20, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    Text("Drew! 🇮🇹")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()

                // Journey city icons
                HStack(spacing: 6) {
                    ForEach(cities.prefix(4)) { city in
                        Text(city.nameEmoji ?? "🏙️")
                            .font(.system(size: 20))
                            .opacity(city.isUnlocked == 1 ? 1.0 : 0.3)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)

            // Stats cards row
            HStack(spacing: 12) {
                HeaderStatCard(icon: "🔥", value: "\(streak)", label: "day streak")
                HeaderStatCard(icon: "⚡️", value: "\(xp)", label: "XP total")
                HeaderStatCard(icon: "📚", value: "\(words)", label: "words")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(
            LinearGradient(
                colors: [Color.linguaPrimary, Color.linguaPrimary.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct HeaderStatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Text(icon)
                .font(.system(size: 24))
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.15), in: .rect(cornerRadius: 14))
    }
}